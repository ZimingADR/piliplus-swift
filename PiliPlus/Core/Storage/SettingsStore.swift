import Observation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// 全局播放偏好。用 `UserDefaults` 持久化，键名使用 `settings.` 前缀。
@MainActor
@Observable
final class SettingsStore {
    private enum Key {
        static let defaultQuality = "settings.defaultQuality"
        static let codecPreference = "settings.codecPreference"
        static let backgroundPlayback = "settings.backgroundPlayback"
        static let pictureInPicture = "settings.pictureInPicture"
        static let resumePlayback = "settings.resumePlayback"
        static let sponsorBlock = "settings.sponsorBlock"
        static let audioOnly = "settings.audioOnly"
        static let danmakuEnabled = "settings.danmakuEnabled"
        static let danmakuFontScale = "settings.danmakuFontScale"
        static let danmakuOpacity = "settings.danmakuOpacity"
        static let danmakuSpeed = "settings.danmakuSpeed"
        static let danmakuArea = "settings.danmakuArea"
        static let audioNormalization = "settings.audioNormalization"
        static let loudnessTarget = "settings.loudnessTarget"
        static let loudnessStrength = "settings.loudnessStrength"
        static let appearance = "settings.appearance"
        static let autoplayNext = "settings.autoplayNext"
    }

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: - 播放

    var defaultQuality: Int {
        didSet { defaults.set(defaultQuality, forKey: Key.defaultQuality) }
    }

    var codecPreference: VideoCodecPreference {
        didSet { defaults.set(codecPreference.rawValue, forKey: Key.codecPreference) }
    }

    var backgroundPlaybackEnabled: Bool {
        didSet { defaults.set(backgroundPlaybackEnabled, forKey: Key.backgroundPlayback) }
    }

    var pictureInPictureEnabled: Bool {
        didSet { defaults.set(pictureInPictureEnabled, forKey: Key.pictureInPicture) }
    }

    var resumePlaybackEnabled: Bool {
        didSet { defaults.set(resumePlaybackEnabled, forKey: Key.resumePlayback) }
    }

    /// 自动跳过 SponsorBlock 赞助/片头片尾片段。
    var sponsorBlockEnabled: Bool {
        didSet { defaults.set(sponsorBlockEnabled, forKey: Key.sponsorBlock) }
    }

    /// 仅音频播放（听视频）。
    var audioOnlyEnabled: Bool {
        didSet { defaults.set(audioOnlyEnabled, forKey: Key.audioOnly) }
    }

    // MARK: - 弹幕

    var danmakuEnabled: Bool {
        didSet { defaults.set(danmakuEnabled, forKey: Key.danmakuEnabled) }
    }

    var danmakuFontScale: Double {
        didSet { defaults.set(danmakuFontScale, forKey: Key.danmakuFontScale) }
    }

    var danmakuOpacity: Double {
        didSet { defaults.set(danmakuOpacity, forKey: Key.danmakuOpacity) }
    }

    var danmakuSpeed: Double {
        didSet { defaults.set(danmakuSpeed, forKey: Key.danmakuSpeed) }
    }

    /// 弹幕最多占据画面的比例（0.25 ~ 1.0）。
    var danmakuArea: Double {
        didSet { defaults.set(danmakuArea, forKey: Key.danmakuArea) }
    }

    // MARK: - 音量平衡

    var audioNormalizationMode: String {
        didSet { defaults.set(audioNormalizationMode, forKey: Key.audioNormalization) }
    }

    var loudnessTargetLUFS: Int {
        didSet { defaults.set(loudnessTargetLUFS, forKey: Key.loudnessTarget) }
    }

    var loudnessStrength: Int {
        didSet { defaults.set(loudnessStrength, forKey: Key.loudnessStrength) }
    }

    // MARK: - 外观

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaultQuality = defaults.object(forKey: Key.defaultQuality) as? Int ?? BiliQuality.defaultQuality
        codecPreference = (defaults.string(forKey: Key.codecPreference))
            .flatMap(VideoCodecPreference.init(rawValue:)) ?? .automatic
        backgroundPlaybackEnabled = defaults.bool(forKey: Key.backgroundPlayback, default: true)
        pictureInPictureEnabled = defaults.bool(forKey: Key.pictureInPicture, default: true)
        resumePlaybackEnabled = defaults.bool(forKey: Key.resumePlayback, default: true)
        sponsorBlockEnabled = defaults.bool(forKey: Key.sponsorBlock, default: true)
        audioOnlyEnabled = defaults.bool(forKey: Key.audioOnly, default: false)

        danmakuEnabled = defaults.bool(forKey: Key.danmakuEnabled, default: true)
        danmakuFontScale = defaults.double(forKey: Key.danmakuFontScale, default: 1.0)
        danmakuOpacity = defaults.double(forKey: Key.danmakuOpacity, default: 0.9)
        danmakuSpeed = defaults.double(forKey: Key.danmakuSpeed, default: 1.0)
        danmakuArea = defaults.double(forKey: Key.danmakuArea, default: 0.5)

        audioNormalizationMode = defaults.string(forKey: Key.audioNormalization) ?? AudioNormalizationMode.bewly.rawValue
        loudnessTargetLUFS = defaults.object(forKey: Key.loudnessTarget) as? Int
            ?? AudioNormalization.defaultTargetLUFS
        loudnessStrength = defaults.object(forKey: Key.loudnessStrength) as? Int
            ?? AudioNormalization.defaultStrength

        appearance = (defaults.string(forKey: Key.appearance))
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    /// 当前音量平衡滤镜（不含服务端测量值，测量值在每次起播时注入）。
    var audioNormalizationSummary: LoudnessSummary {
        AudioNormalization.summary(
            rawCode: audioNormalizationMode,
            targetLUFS: loudnessTargetLUFS,
            strength: loudnessStrength
        )
    }

    func resetDanmakuDefaults() {
        danmakuFontScale = 1.0
        danmakuOpacity = 0.9
        danmakuSpeed = 1.0
        danmakuArea = 0.5
    }

    func resetLoudnessDefaults() {
        audioNormalizationMode = AudioNormalizationMode.bewly.rawValue
        loudnessTargetLUFS = AudioNormalization.defaultTargetLUFS
        loudnessStrength = AudioNormalization.defaultStrength
    }
}

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }

    func double(forKey key: String, default defaultValue: Double) -> Double {
        object(forKey: key) == nil ? defaultValue : double(forKey: key)
    }
}
