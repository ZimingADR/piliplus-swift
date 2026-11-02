import SwiftUI
import UIKit

/// 全屏播放页。
///
/// 结构：
/// - 最底层是 `MPVSurfaceView`（CAMetalLayer）；
/// - 其上是 CoreAnimation 弹幕层；
/// - 再上是手势层与按需出现的控制层。
struct PlayerScreen: View {
    let request: PlayerRequest

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var controller: PlaybackController?
    @State private var showsControls = true
    @State private var showsEpisodes = false
    @State private var showsDanmakuSettings = false
    @State private var showsSearchPanel = false
    @State private var showsMember = false

    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var volume: Double = 100

    @State private var dragMode: DragMode = .none
    @State private var dragStartTime: Double = 0
    @State private var dragStartBrightness: Double = 0
    @State private var dragStartVolume: Double = 0
    @State private var horizontalPreview: Double?
    @State private var hud: HUD?
    @State private var hudTask: Task<Void, Never>?
    @State private var hideControlsTask: Task<Void, Never>?

    private enum DragMode {
        case none
        case horizontal
        case vertical
    }

    private struct HUD: Equatable {
        enum Kind: Equatable {
            case brightness
            case volume
            case seek
            case play
        }

        let kind: Kind
        let text: String
        let progress: Double
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let controller {
                videoLayer(controller)
                gestureLayer(controller)
                chrome(controller)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if let hud {
                hudView(hud)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .allowsHitTesting(false)
            }
        }
        .statusBarHidden(!showsControls)
        .persistentSystemOverlays(.hidden)
        .task { startIfNeeded() }
        .onChange(of: environment.settings.danmakuEnabled) { _, newValue in
            if controller?.danmakuVisible != newValue {
                controller?.setDanmakuVisible(newValue)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background,
                  environment.settings.pictureInPictureEnabled,
                  controller?.isPlaying == true,
                  controller?.isPictureInPictureSupported == true else { return }
            controller?.togglePictureInPicture()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            hudTask?.cancel()
            controller?.stop()
            controller?.detachEngine()
        }
    }

    // MARK: - 视频与弹幕

    private func videoLayer(_ controller: PlaybackController) -> some View {
        ZStack {
            MPVSurfaceView { layer in
                controller.attachSurface(layer)
            }
            .ignoresSafeArea()

            if controller.danmakuVisible {
                DanmakuOverlayView(
                    items: controller.danmakuItems,
                    currentTime: controller.currentTime,
                    isPlaying: controller.isPlaying,
                    isEnabled: controller.danmakuVisible,
                    fontScale: environment.settings.danmakuFontScale,
                    opacity: environment.settings.danmakuOpacity,
                    speed: environment.settings.danmakuSpeed,
                    area: environment.settings.danmakuArea
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // AVPlayerLayer 宿主：交给 AVKit 做系统画中画。
            if let pipLayer = controller.pictureInPictureLayer {
                PiPHostView(playerLayer: pipLayer)
                    .frame(width: 2, height: 2)
                    .opacity(0.01)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 手势层

    private func gestureLayer(_ controller: PlaybackController) -> some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(.rect)
                .onTapGesture(count: 2, coordinateSpace: .local) { location in
                    handleDoubleTap(at: location, size: proxy.size, controller: controller)
                }
                .onTapGesture {
                    toggleControls()
                }
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            handleDragChanged(value, size: proxy.size, controller: controller)
                        }
                        .onEnded { value in
                            handleDragEnded(value, controller: controller)
                        }
                )
        }
        .ignoresSafeArea()
    }

    private func handleDoubleTap(
        at location: CGPoint,
        size: CGSize,
        controller: PlaybackController
    ) {
        let width = max(size.width, 1)
        if location.x < width / 3 {
            controller.seek(by: -10)
            flashHUD(.init(kind: .seek, text: "« 10 秒", progress: 0))
        } else if location.x > width * 2 / 3 {
            controller.seek(by: 10)
            flashHUD(.init(kind: .seek, text: "10 秒 »", progress: 0))
        } else {
            controller.togglePlayPause()
            flashHUD(.init(
                kind: .play,
                text: controller.isPlaying ? "播放" : "暂停",
                progress: 0
            ))
        }
        scheduleHideControls()
    }

    private func handleDragChanged(
        _ value: DragGesture.Value,
        size: CGSize,
        controller: PlaybackController
    ) {
        if dragMode == .none {
            dragMode = abs(value.translation.width) > abs(value.translation.height)
                ? .horizontal
                : .vertical
            dragStartTime = controller.currentTime
            dragStartBrightness = UIScreen.main.brightness
            dragStartVolume = volume
            scheduleHideControls()
        }

        let width = max(size.width, 1)
        let height = max(size.height, 1)
        switch dragMode {
        case .horizontal:
            guard controller.duration > 0 else { return }
            let delta = Double(value.translation.width / width) * 180
            let target = min(max(dragStartTime + delta, 0), controller.duration)
            horizontalPreview = target
            hud = HUD(
                kind: .seek,
                text: "\(VideoCard.formatDuration(Int(target))) / \(VideoCard.formatDuration(Int(controller.duration)))",
                progress: target / max(controller.duration, 1)
            )
        case .vertical:
            let delta = Double(-value.translation.height / height)
            if value.startLocation.x < width / 2 {
                let brightness = min(max(dragStartBrightness + delta, 0.02), 1)
                UIScreen.main.brightness = brightness
                hud = HUD(
                    kind: .brightness,
                    text: "亮度 \(Int(brightness * 100))%",
                    progress: brightness
                )
            } else {
                let newVolume = min(max(dragStartVolume + delta * 100, 0), 100)
                volume = newVolume
                controller.engine.setVolume(newVolume)
                hud = HUD(
                    kind: .volume,
                    text: "音量 \(Int(newVolume))%",
                    progress: newVolume / 100
                )
            }
        case .none:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, controller: PlaybackController) {
        if dragMode == .horizontal, let target = horizontalPreview {
            controller.seek(to: target)
        }
        dragMode = .none
        horizontalPreview = nil
        hideHUD(after: 0.6)
    }

    // MARK: - 控制层

    private func chrome(_ controller: PlaybackController) -> some View {
        VStack(spacing: 0) {
            topBar(controller)
            Spacer(minLength: 0)

            if controller.isBuffering {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            Spacer(minLength: 0)
            bottomBar(controller)
        }
        .opacity(showsControls ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showsControls)
        .allowsHitTesting(showsControls)
        .overlay {
            if case .failed(let message) = controller.loadState {
                failureOverlay(message, controller: controller)
            }
        }
        .sheet(isPresented: $showsEpisodes) {
            EpisodeSheet(controller: controller)
        }
        .sheet(isPresented: $showsDanmakuSettings) {
            DanmakuSettingsSheet()
        }
        .sheet(isPresented: $showsSearchPanel) {
            SearchPanelSheet()
        }
        .sheet(isPresented: $showsMember) {
            if let mid = controller.ownerMid {
                NavigationStack {
                    MemberScreen(mid: mid, showsCloseButton: true)
                }
            }
        }
    }

    private func topBar(_ controller: PlaybackController) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .playerChrome()
            }
            .accessibilityLabel("关闭播放器")

            VStack(alignment: .leading, spacing: 2) {
                Text(controller.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Button {
                    if controller.ownerMid != nil {
                        showsMember = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(controller.ownerName)\(controller.currentPage.map { " · \($0.title)" } ?? "")")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        if controller.ownerMid != nil {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(controller.ownerMid == nil)
            }

            Spacer(minLength: 0)

            Button {
                showsSearchPanel = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .playerChrome()
            }
            .accessibilityLabel("快速搜索")

            Button {
                controller.setDanmakuVisible(!controller.danmakuVisible)
            } label: {
                Image(systemName: controller.danmakuVisible ? "text.bubble.fill" : "text.bubble")
                    .playerChrome()
            }
            .accessibilityLabel(controller.danmakuVisible ? "关闭弹幕" : "打开弹幕")

            qualityMenu(controller)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func qualityMenu(_ controller: PlaybackController) -> some View {
        Menu {
            ForEach(controller.availableQualities) { quality in
                Button {
                    controller.selectQuality(quality.id)
                } label: {
                    if quality.id == controller.selectedQuality {
                        Label(quality.title, systemImage: "checkmark")
                    } else {
                        Text(quality.title)
                    }
                }
            }
        } label: {
            Text(BiliQuality.title(for: controller.selectedQuality))
                .font(.caption.weight(.medium))
                .playerChrome()
        }
        .accessibilityLabel("清晰度")
    }

    private func bottomBar(_ controller: PlaybackController) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(VideoCard.formatDuration(Int(currentPosition(controller))))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 48, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { currentPosition(controller) },
                        set: { seekValue = $0; isSeeking = true }
                    ),
                    in: 0 ... max(controller.duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            controller.seek(to: seekValue)
                            isSeeking = false
                            scheduleHideControls()
                        }
                    }
                )
                .tint(Theme.accent)

                Text("-\(VideoCard.formatDuration(Int(max(controller.duration - currentPosition(controller), 0))))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 52, alignment: .trailing)
            }

            HStack(spacing: 28) {
                Button {
                    controller.seek(by: -15)
                    scheduleHideControls()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title3)
                }
                .accessibilityLabel("后退 15 秒")

                Button {
                    controller.togglePlayPause()
                    scheduleHideControls()
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.16), in: .circle)
                }
                .accessibilityLabel(controller.isPlaying ? "暂停" : "播放")

                Button {
                    controller.seek(by: 15)
                    scheduleHideControls()
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title3)
                }
                .accessibilityLabel("前进 15 秒")

                Spacer()

                if controller.pages.count > 1 {
                    Button {
                        showsEpisodes = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title3)
                    }
                    .accessibilityLabel("选集（\(controller.pages.count) P）")
                }

                if controller.isPictureInPictureSupported {
                    Button {
                        controller.togglePictureInPicture()
                        scheduleHideControls()
                    } label: {
                        Image(systemName: "pip.enter")
                            .font(.title3)
                    }
                    .accessibilityLabel("画中画")
                }

                Button {
                    showsDanmakuSettings = true
                } label: {
                    Image(systemName: "textformat")
                        .font(.title3)
                }
                .accessibilityLabel("弹幕设置")
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background {
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func currentPosition(_ controller: PlaybackController) -> Double {
        isSeeking ? seekValue : controller.currentTime
    }

    private func failureOverlay(_ message: String, controller: PlaybackController) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("播放失败")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("重试") {
                    retry(controller)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
        .padding(24)
        .glassPanel(cornerRadius: 20)
        .padding(.horizontal, 32)
    }

    // MARK: - HUD

    private func hudView(_ hud: HUD) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: hud.kind))
                Text(hud.text)
                    .font(.subheadline.monospacedDigit())
            }
            if hud.progress > 0 {
                ProgressView(value: hud.progress)
                    .tint(.white)
                    .frame(width: 140)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassPanel(cornerRadius: 18)
    }

    private func icon(for kind: HUD.Kind) -> String {
        switch kind {
        case .brightness: "sun.max.fill"
        case .volume: "speaker.wave.2.fill"
        case .seek: "arrow.left.and.right"
        case .play: "playpause.fill"
        }
    }

    private func flashHUD(_ hud: HUD) {
        self.hud = hud
        hideHUD(after: 0.8)
    }

    private func hideHUD(after seconds: Double) {
        hudTask?.cancel()
        hudTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                hud = nil
            }
        }
    }

    // MARK: - 生命周期与交互

    private func startIfNeeded() {
        guard controller == nil else { return }
        let controller = PlaybackController(
            client: environment.client,
            settings: environment.settings,
            history: environment.history,
            audioSession: environment.audioSession
        )
        self.controller = controller

        if let card = request.card {
            controller.start(card: card)
        } else {
            controller.start(bvid: request.bvid, aid: request.aid, cid: request.cid)
        }
        scheduleHideControls()
    }

    private func retry(_ controller: PlaybackController) {
        if let card = request.card {
            controller.start(card: card)
        } else {
            controller.start(bvid: request.bvid, aid: request.aid, cid: request.cid)
        }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showsControls.toggle()
        }
        if showsControls {
            scheduleHideControls()
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        guard controller?.isPlaying == true || controller == nil else { return }
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showsControls = false
            }
        }
    }
}
