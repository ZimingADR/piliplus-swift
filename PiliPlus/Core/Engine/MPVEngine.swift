import Foundation
import Libmpv
import QuartzCore
import UIKit

enum MPVEngineError: Error, LocalizedError {
    case creationFailed
    case initializationFailed

    var errorDescription: String? {
        switch self {
        case .creationFailed: "无法创建播放内核"
        case .initializationFailed: "播放内核初始化失败"
        }
    }
}

/// libmpv 播放内核的轻量封装。
///
/// - 视频输出：`vo=gpu-next` + Vulkan/MoltenVK，渲染到 SwiftUI 提供的 `CAMetalLayer`；
/// - 音频输出：`ao=audiounit`，配合 `AVAudioSession(.playback)` 支持后台播放；
/// - 音量平衡：通过 `af` 属性注入 `lavfi=[...]` 滤镜链（见 `AudioNormalization`）。
@MainActor
final class MPVEngine {
    /// 用引用类型托管 `mpv_handle`，让析构时的 `mpv_terminate_destroy`
    /// 不受 MainActor 析构隔离的影响。
    private final class Context {
        let pointer: OpaquePointer

        init?() {
            guard let pointer = mpv_create() else { return nil }
            self.pointer = pointer
        }

        deinit {
            mpv_terminate_destroy(pointer)
        }
    }

    private var context: Context?
    private var isInitialized = false

    private var pendingAudioURL: URL?
    private var didAttachAudioTrack = false

    init() {
        context = Context()
        if let pointer = context?.pointer {
            configureOptions(pointer)
        }
    }

    var isAvailable: Bool { context != nil }

    var isReady: Bool { isInitialized }

    func shutdown() {
        context = nil
        isInitialized = false
    }

    // MARK: - 生命周期

    /// 把 mpv 绑定到具体的 Metal 图层；`wid` 必须在 `mpv_initialize` 之前设置。
    func attach(layer: CAMetalLayer) throws {
        guard let pointer = context?.pointer else { throw MPVEngineError.creationFailed }
        guard !isInitialized else { return }

        layer.contentsScale = UIScreen.main.scale
        layer.framebufferOnly = true
        layer.backgroundColor = UIColor.black.cgColor

        var layerPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(layer).toOpaque())
        let status = withUnsafeMutablePointer(to: &layerPointer) { pointerToLayer in
            mpv_set_option(pointer, "wid", MPV_FORMAT_INT64, pointerToLayer)
        }
        guard status >= 0 else { throw MPVEngineError.initializationFailed }

        guard mpv_initialize(pointer) >= 0 else {
            throw MPVEngineError.initializationFailed
        }
        isInitialized = true
    }

    // MARK: - 播放控制

    func load(videoURL: URL, startAt: Double = 0) {
        pendingAudioURL = nil
        didAttachAudioTrack = false
        setPaused(true)
        command("loadfile \(Self.quoted(videoURL.absoluteString)) replace")
        if startAt > 1 {
            seek(to: startAt)
        }
    }

    func attachAudioTrack(_ url: URL) {
        pendingAudioURL = url
        didAttachAudioTrack = false
    }

    /// 文件加载完成后挂载独立音频轨（DASH 双轨播放）。
    func materializeAudioTrackIfNeeded() {
        guard !didAttachAudioTrack, let pendingAudioURL else { return }
        didAttachAudioTrack = true
        command("audio-add \(Self.quoted(pendingAudioURL.absoluteString)) select")
    }

    func play() {
        setPaused(false)
    }

    func pause() {
        setPaused(true)
    }

    func setPaused(_ paused: Bool) {
        setFlag("pause", paused ? 1 : 0)
    }

    func togglePause() {
        setPaused(!isPaused)
    }

    /// 仅音频模式：关闭视频轨输出。
    func setAudioOnly(_ enabled: Bool) {
        guard let pointer = context?.pointer else { return }
        mpv_set_property_string(pointer, "vid", enabled ? "no" : "auto")
    }

    func seek(to seconds: Double) {
        let clamped = max(0, seconds)
        command("seek \(String(format: "%.3f", clamped)) absolute+exact")
    }

    func setVolume(_ volume: Double) {
        setDouble("volume", min(max(volume, 0), 100))
    }

    func setAudioFilter(_ filter: String) {
        guard let pointer = context?.pointer else { return }
        mpv_set_property_string(pointer, "af", filter)
    }

    func stop() {
        command("stop")
    }

    // MARK: - 状态读取

    var currentTime: Double { double("time-pos") ?? 0 }
    var duration: Double { double("duration") ?? 0 }
    var isPaused: Bool { flag("pause") }
    var isIdle: Bool { flag("idle-active") }
    var hasEnded: Bool { flag("eof-reached") }
    var isBuffering: Bool { flag("paused-for-cache") }
    var volume: Double { double("volume") ?? 100 }

    var isFileLoaded: Bool { duration > 0 && !isIdle }

    // MARK: - 选项

    private func configureOptions(_ pointer: OpaquePointer) {
        // 视频输出：Metal 图层 + MoltenVK（MPVKit 官方示例路径）
        mpv_set_option_string(pointer, "vo", "gpu-next")
        mpv_set_option_string(pointer, "gpu-api", "vulkan")
        mpv_set_option_string(pointer, "gpu-context", "moltenvk")
        mpv_set_option_string(pointer, "hwdec", "videotoolbox")
        mpv_set_option_string(pointer, "keep-open", "yes")
        mpv_set_option_string(pointer, "idle", "yes")
        mpv_set_option_string(pointer, "osc", "no")
        mpv_set_option_string(pointer, "input-default-bindings", "no")
        mpv_set_option_string(pointer, "input-cursor", "no")
        mpv_set_option_string(pointer, "cursor-autohide", "no")
        mpv_set_option_string(pointer, "terminal", "no")
        mpv_set_option_string(pointer, "ytdl", "no")
        mpv_set_option_string(pointer, "force-seekable", "yes")
        mpv_set_option_string(pointer, "audio-client-name", "PiliPlus")
        mpv_set_option_string(pointer, "ao", "audiounit")
        mpv_set_option_string(pointer, "cache", "yes")
        mpv_set_option_string(pointer, "demuxer-max-bytes", "67108864")
        mpv_set_option_string(pointer, "demuxer-max-back-bytes", "33554432")
        mpv_set_option_string(pointer, "alang", "zh,chi,en")
        mpv_set_option_string(pointer, "sub-auto", "no")

        // B 站 CDN 防盗链：必须带 Referer / Origin / UA。
        let headers = [
            "Referer: https://www.bilibili.com/",
            "Origin: https://www.bilibili.com",
            "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
        ]
        .joined(separator: ",")
        mpv_set_option_string(pointer, "http-header-fields", headers)
    }

    // MARK: - Private helpers

    private func setFlag(_ name: String, _ value: Int32) {
        guard let pointer = context?.pointer else { return }
        var mutable = value
        mpv_set_property(pointer, name, MPV_FORMAT_FLAG, &mutable)
    }

    private func setDouble(_ name: String, _ value: Double) {
        guard let pointer = context?.pointer else { return }
        var mutable = value
        mpv_set_property(pointer, name, MPV_FORMAT_DOUBLE, &mutable)
    }

    private func flag(_ name: String) -> Bool {
        guard let pointer = context?.pointer else { return false }
        var value: Int32 = 0
        let status = mpv_get_property(pointer, name, MPV_FORMAT_FLAG, &value)
        return status >= 0 && value != 0
    }

    private func double(_ name: String) -> Double? {
        guard let pointer = context?.pointer else { return nil }
        var value = 0.0
        let status = mpv_get_property(pointer, name, MPV_FORMAT_DOUBLE, &value)
        return status >= 0 ? value : nil
    }

    @discardableResult
    private func command(_ command: String) -> Bool {
        guard let pointer = context?.pointer else { return false }
        return mpv_command_string(pointer, command) >= 0
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
