import Foundation

/// 服务端返回的整体响度测量值（`playurl.data.volume`）。
///
/// B 站会在 `measured_i` 中给出整段音频的积分响度（LUFS），
/// 有效范围约定为 `(-70, -0.5)`，超出该范围视为无测量值。
public struct LoudnessMeasurement: Sendable, Equatable {
    public var integratedLUFS: Double

    public init(integratedLUFS: Double) {
        self.integratedLUFS = integratedLUFS
    }

    public var isValid: Bool {
        integratedLUFS.isFinite && integratedLUFS > -70 && integratedLUFS < -0.5
    }
}

/// 音量平衡模式。原始值直接沿用 Flutter 版写入偏好的字符串编码，
/// 便于从旧版本迁移设置。
public enum AudioNormalizationMode: String, CaseIterable, Identifiable, Sendable {
    case disabled = "0"
    case bewly = "bewly"
    case dynaudnorm = "1"
    case loudnorm = "2"
    case custom = "3"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .disabled: "禁用"
        case .bewly: "智能音量平衡"
        case .dynaudnorm: "动态平滑 dynaudnorm"
        case .loudnorm: "标准响度 loudnorm"
        case .custom: "自定义参数"
        }
    }

    /// 内置滤镜的 `lavfi` 参数（BewlyCat 模式由算法动态生成，此处为空）。
    public var builtInFilter: String {
        switch self {
        case .dynaudnorm: "dynaudnorm=g=5:f=250:r=0.9:p=0.5"
        case .loudnorm: "loudnorm=I=-16:LRA=11:TP=-1.5"
        case .disabled, .bewly, .custom: ""
        }
    }

    public static func resolved(from code: String) -> AudioNormalizationMode? {
        AudioNormalizationMode(rawValue: code.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// BewlyCat 风格的三级音量平衡滤镜管线。
///
/// 移植自 Flutter 版 `lib/models/common/audio_normalization.dart`：
/// 1. `volume`：按服务端测量的整体响度做跨视频基准对齐（可选）；
/// 2. `dynaudnorm`：视频内局部动态平滑 + -50 LUFS 底噪门限；
/// 3. `alimiter`：5 ms 前瞻、-1 dBFS 峰值防爆音限制器。
public enum AudioNormalization {
    public static let minTargetLUFS = -24
    public static let maxTargetLUFS = -14
    public static let defaultTargetLUFS = -18

    public static let minStrength = 40
    public static let maxStrength = 100
    public static let defaultStrength = 75

    /// -1.0 dBFS 采样峰值上限（10^(-1/20)）。
    static let peakLimitLinear = 0.89125
    /// -50 LUFS 静音与底噪冻结门限对应的单路 RMS 阈值。
    static let silenceGateRMS = 0.0024

    public static func isEnabled(_ rawCode: String) -> Bool {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return !code.isEmpty && code != AudioNormalizationMode.disabled.rawValue
    }

    public static func title(for rawCode: String) -> String {
        guard let mode = AudioNormalizationMode.resolved(from: rawCode) else { return rawCode }
        guard mode == .custom else { return mode.title }
        return "自定义参数"
    }

    /// 跨视频基准对齐预增益（dB）。无有效服务端响度数据时返回 `nil`。
    public static func baseGainDB(
        targetLUFS: Int,
        strength: Int,
        measurement: LoudnessMeasurement?
    ) -> Double? {
        guard let measurement, measurement.isValid else { return nil }
        let target = clampTarget(targetLUFS)
        let normalizedStrength = normalizedStrength(strength)
        // 跨视频整体基准偏移按 75%~100% 权重先行拉齐，限制在 [-18 dB, +9 dB] 安全范围。
        let alignWeight = 0.75 + 0.25 * normalizedStrength
        let delta = (Double(target) - measurement.integratedLUFS) * alignWeight
        return min(max(delta, -18), 9)
    }

    /// 构建不含外层 `lavfi=[...]` 的滤镜图。
    public static func bewlyFilterGraph(
        targetLUFS: Int,
        strength: Int,
        measurement: LoudnessMeasurement?
    ) -> String {
        let target = clampTarget(targetLUFS)
        let normalized = normalizedStrength(strength)

        let baseGain = baseGainDB(
            targetLUFS: target,
            strength: strength,
            measurement: measurement
        )

        // 双声道 BS.1770 响度与每声道 RMS 映射：L_LUFS ≈ 2.319 + 20 * log10(rms)。
        let targetRMS = min(max(pow(10, (Double(target) - 2.319) / 20), 0.02), 0.35)

        // 高斯平滑窗口帧数（奇数，5~11）：强度越高窗口越紧凑
        // 40% -> 11 帧 ≈ 2.2s，75% -> 7 帧 ≈ 1.4s，100% -> 5 帧 ≈ 1.0s。
        var gaussianFrames = Int((11 - normalized * 6).rounded())
        if gaussianFrames.isMultiple(of: 2) {
            gaussianFrames -= 1
        }
        gaussianFrames = min(max(gaussianFrames, 5), 11)

        // 最大局部提亮增益：有服务端预增益时 +4~+9 dB，无预增益时放宽到 +6~+12 dB。
        let maxBoostDB = baseGain == nil ? 6 + 6 * normalized : 4 + 5 * normalized
        let maxGainLinear = pow(10, maxBoostDB / 20)

        var stages: [String] = []
        if let baseGain, abs(baseGain) >= 0.05 {
            stages.append("volume=\(format(baseGain, digits: 2))dB")
        }
        stages.append(
            "dynaudnorm=f=200:g=\(gaussianFrames)"
                + ":p=\(format(peakLimitLinear, digits: 5))"
                + ":m=\(format(maxGainLinear, digits: 2))"
                + ":r=\(format(targetRMS, digits: 4))"
                + ":n=1:b=1"
                + ":t=\(format(silenceGateRMS, digits: 4))"
        )
        stages.append(
            "alimiter=limit=\(format(peakLimitLinear, digits: 5))"
                + ":attack=5:release=80:level=0:latency=1"
        )
        return stages.joined(separator: ",")
    }

    /// 直接下发给 mpv `af` 属性的滤镜字符串；禁用时返回空串（用于清空滤镜）。
    public static func mpvAudioFilter(
        rawCode: String,
        targetLUFS: Int = defaultTargetLUFS,
        strength: Int = defaultStrength,
        measurement: LoudnessMeasurement? = nil
    ) -> String {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled(code), let mode = AudioNormalizationMode.resolved(from: code) else {
            return ""
        }
        switch mode {
        case .bewly:
            let graph = bewlyFilterGraph(
                targetLUFS: targetLUFS,
                strength: strength,
                measurement: measurement
            )
            return "lavfi=[\(graph)]"
        case .dynaudnorm, .loudnorm:
            return "lavfi=[\(mode.builtInFilter)]"
        case .disabled, .custom:
            return ""
        }
    }

    /// 当前生效状态的摘要，用于播放器顶栏与设置页展示。
    public static func summary(
        rawCode: String,
        targetLUFS: Int = defaultTargetLUFS,
        strength: Int = defaultStrength,
        measurement: LoudnessMeasurement? = nil
    ) -> LoudnessSummary {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let mode = AudioNormalizationMode.resolved(from: code)
        let filter = mpvAudioFilter(
            rawCode: code,
            targetLUFS: targetLUFS,
            strength: strength,
            measurement: measurement
        )
        return LoudnessSummary(
            isEnabled: !filter.isEmpty,
            modeTitle: title(for: code),
            isBewlyMode: mode == .bewly,
            measuredLUFS: (measurement?.isValid ?? false) ? measurement?.integratedLUFS : nil,
            baseGainDB: mode == .bewly
                ? baseGainDB(targetLUFS: targetLUFS, strength: strength, measurement: measurement)
                : nil,
            targetLUFS: clampTarget(targetLUFS),
            strength: clampStrength(strength),
            filter: filter
        )
    }

    // MARK: - Clamping

    public static func clampTarget(_ value: Int) -> Int {
        min(max(value, minTargetLUFS), maxTargetLUFS)
    }

    public static func clampStrength(_ value: Int) -> Int {
        min(max(value, minStrength), maxStrength)
    }

    static func normalizedStrength(_ value: Int) -> Double {
        Double(clampStrength(value) - minStrength) / Double(maxStrength - minStrength)
    }

    // MARK: - Formatting

    /// 与 Dart `toStringAsFixed` 对齐的定点格式化，避免出现 `-0.00`。
    static func format(_ value: Double, digits: Int) -> String {
        let normalized = value == 0 ? 0 : value
        return String(format: "%.\(digits)f", normalized)
    }
}

/// 音量平衡当前状态的可展示摘要。
public struct LoudnessSummary: Sendable, Equatable {
    public let isEnabled: Bool
    public let modeTitle: String
    public let isBewlyMode: Bool
    public let measuredLUFS: Double?
    public let baseGainDB: Double?
    public let targetLUFS: Int
    public let strength: Int
    public let filter: String

    public var statusText: String {
        guard isEnabled else { return "已关闭" }
        guard isBewlyMode else { return modeTitle }
        if let measuredLUFS, let baseGainDB {
            let sign = baseGainDB >= 0 ? "+" : ""
            return "原始 \(String(format: "%.1f", measuredLUFS)) LUFS · 预增益 \(sign)\(String(format: "%.1f", baseGainDB)) dB"
        }
        return "实时局部动态均衡生效中（目标 \(targetLUFS) LUFS）"
    }
}
