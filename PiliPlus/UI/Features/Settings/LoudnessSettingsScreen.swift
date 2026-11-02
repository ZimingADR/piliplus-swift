import SwiftUI

/// 音量平衡二级设置页（BewlyCat 三级滤镜）。
struct LoudnessSettingsScreen: View {
    @Environment(AppEnvironment.self) private var environment

    private var summary: LoudnessSummary {
        AudioNormalization.summary(
            rawCode: environment.settings.audioNormalizationMode,
            targetLUFS: environment.settings.loudnessTargetLUFS,
            strength: environment.settings.loudnessStrength
        )
    }

    var body: some View {
        @Bindable var settings = environment.settings

        List {
            Section {
                Picker("模式", selection: $settings.audioNormalizationMode) {
                    Text("智能音量平衡").tag(AudioNormalizationMode.bewly.rawValue)
                    Text("动态平滑 dynaudnorm").tag(AudioNormalizationMode.dynaudnorm.rawValue)
                    Text("禁用").tag(AudioNormalizationMode.disabled.rawValue)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("模式")
            } footer: {
                Text("智能音量平衡会先按服务端测量的整体响度对齐不同视频，再做视频内的动态平滑与峰值限制。")
            }

            Section("参数") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目标响度")
                        Spacer()
                        Text("\(settings.loudnessTargetLUFS) LUFS")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.loudnessTargetLUFS) },
                            set: { settings.loudnessTargetLUFS = Int($0.rounded()) }
                        ),
                        in: Double(AudioNormalization.minTargetLUFS) ... Double(AudioNormalization.maxTargetLUFS),
                        step: 1
                    )
                    .tint(Theme.accent)
                    Text("数值越低越响。B 站推荐 -18 LUFS，夜间可调到 -20 ~ -22。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("强度")
                        Spacer()
                        Text("\(settings.loudnessStrength)%")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.loudnessStrength) },
                            set: { settings.loudnessStrength = Int($0.rounded()) }
                        ),
                        in: Double(AudioNormalization.minStrength) ... Double(AudioNormalization.maxStrength),
                        step: 5
                    )
                    .tint(Theme.accent)
                    Text("强度越高，局部提亮与平滑窗口越激进；75% 是日常观看的平衡点。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .disabled(settings.audioNormalizationMode != AudioNormalizationMode.bewly.rawValue)
            .opacity(settings.audioNormalizationMode == AudioNormalizationMode.bewly.rawValue ? 1 : 0.5)

            Section("当前生效") {
                Text(summary.statusText)
                    .font(.subheadline)
                Text(summary.filter.isEmpty ? "（未挂载滤镜）" : summary.filter)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(nil)
            }

            Section("工作原理") {
                stageRow(
                    index: 1,
                    title: "跨视频基准对齐",
                    detail: "读取服务端 `volume.measured_i`，按目标响度计算预增益（限制在 -18 ~ +9 dB）。"
                )
                stageRow(
                    index: 2,
                    title: "视频内动态平滑",
                    detail: "`dynaudnorm` 以 5 ~ 11 帧高斯窗口平滑响度，并设置 -50 LUFS 底噪门限，避免放大底噪。"
                )
                stageRow(
                    index: 3,
                    title: "峰值防爆音",
                    detail: "`alimiter` 使用 5ms 前瞻与 -1 dBFS 上限，自动补偿延迟，杜绝破音。"
                )
            }

            Section {
                Button("恢复默认（-18 LUFS / 75%）") {
                    settings.resetLoudnessDefaults()
                }
            }
        }
        .navigationTitle("音量平衡")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background { LiquidBackground() }
    }

    private func stageRow(index: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(width: 20, height: 20)
                .background(Theme.accent.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
