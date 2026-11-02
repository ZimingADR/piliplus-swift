import AVFoundation
import MediaPlayer
import Observation
import UIKit

/// 音频会话、锁屏控制与「正在播放」信息中心。
///
/// MPV 负责实际解码输出，本类型只负责把 App 的表现接到系统音频体系上：
/// 后台播放、锁屏控制、耳机线控、AirPlay 与通知中心的封面 / 进度。
@MainActor
@Observable
final class AudioSessionCoordinator {
    var onTogglePlayPause: (() -> Void)?
    var onSeekTo: ((Double) -> Void)?
    var onSkip: ((Double) -> Void)?

    @ObservationIgnored private var isConfigured = false
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var currentArtworkKey: String?
    @ObservationIgnored private var currentNowPlayingInfo: [String: Any]?

    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("[Audio] 激活音频会话失败：\(error)")
            #endif
        }
        configureRemoteCommandsIfNeeded()
    }

    func deactivate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    func updateNowPlaying(
        title: String,
        artist: String,
        duration: Double,
        elapsed: Double,
        isPlaying: Bool,
        coverURL: URL?
    ) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: max(duration, 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(elapsed, 0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
        ]

        if let coverURL {
            loadArtwork(for: coverURL) { [weak self] image in
                guard let self, let image else { return }
                var updated = self.currentNowPlayingInfo ?? info
                updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                    boundsSize: image.size
                ) { _ in image }
                self.currentNowPlayingInfo = updated
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
            }
        }

        currentNowPlayingInfo = info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func clearNowPlaying() {
        artworkTask?.cancel()
        currentArtworkKey = nil
        currentNowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Private

    private func configureRemoteCommandsIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onTogglePlayPause?() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onTogglePlayPause?() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onTogglePlayPause?() }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in self?.onSeekTo?(position) }
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self?.onSkip?(interval) }
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor in self?.onSkip?(-interval) }
            return .success
        }
    }

    private func loadArtwork(
        for url: URL,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) {
        let key = url.absoluteString
        guard currentArtworkKey != key else { return }
        currentArtworkKey = key
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard self != nil else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                completion(image)
            } catch {
                // 封面加载失败不影响播放。
            }
        }
    }
}
