import AVFoundation
import AVKit
import Observation
import UIKit

/// 画中画协调器。
///
/// MPV 的 Metal 图层无法直接交给 AVKit，因此画中画使用 B 站 `platform=html5`
/// 的合流 MP4（最高 720P）交给系统播放器：进入画中画时暂停 MPV、由 AVPlayer
/// 接管音视频；退出画中画时把 AVPlayer 的进度回写给 MPV，实现无感续播。
@MainActor
@Observable
final class PictureInPictureManager {
    private(set) var playerLayer: AVPlayerLayer?
    private(set) var isActive = false

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var controller: AVPictureInPictureController?
    @ObservationIgnored private var timeObserver: Any?

    var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    var currentTime: Double {
        guard let player else { return 0 }
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    /// 准备系统播放器实例，返回需要挂到视图层级上的图层。
    func prepare(url: URL, at position: Double) -> AVPlayerLayer? {
        teardownPlayer()

        let headers: [String: String] = [
            "Referer": "https://www.bilibili.com/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
        ]
        let asset = AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = CGRect(x: 0, y: 0, width: 2, height: 2)

        let source = AVPictureInPictureController.ContentSource(playerLayer: layer)
        let controller = AVPictureInPictureController(contentSource: source)
        controller.canStartPictureInPictureAutomaticallyFromInline = true

        self.player = player
        self.playerLayer = layer
        self.controller = controller

        if position > 1 {
            player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
        }
        return layer
    }

    /// 尝试进入画中画；返回是否成功发起。
    @discardableResult
    func start() -> Bool {
        guard let controller, controller.isPictureInPicturePossible else { return false }
        controller.startPictureInPicture()
        player?.play()
        isActive = true
        return true
    }

    /// 主动退出画中画。
    func stop() {
        controller?.stopPictureInPicture()
        player?.pause()
        isActive = false
    }

    /// 系统侧结束（用户点关闭 / 回到 App）时调用，返回最后播放位置。
    func finish() -> Double {
        let time = currentTime
        stop()
        teardownPlayer()
        return time
    }

    private func teardownPlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
        playerLayer = nil
        controller = nil
        isActive = false
    }
}

/// 承载画中画 `AVPlayerLayer` 的宿主视图（保持极小的可见尺寸）。
struct PiPHostView: UIViewRepresentable {
    let playerLayer: AVPlayerLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        playerLayer.frame = uiView.bounds
    }
}
