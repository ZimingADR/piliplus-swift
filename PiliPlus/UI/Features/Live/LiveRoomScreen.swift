import QuartzCore
import SwiftUI

/// 直播间播放（MPV 直接播放 FLV / HLS）。
struct LiveRoomScreen: View {
    let room: LiveRoom

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var model = LiveRoomPlayerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MPVSurfaceView { layer in
                model.attach(layer)
            }
            .ignoresSafeArea()

            controls

            if case .loading = model.phase {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if case .failed(let message) = model.phase {
                failureOverlay(message)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            environment.audioSession.activate()
            await model.start(room: room, client: environment.client)
        }
        .onDisappear {
            model.stop()
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .playerChrome()
                }
                .accessibilityLabel("关闭直播间")

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(room.uname) · \(room.areaName)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: "playpause.fill")
                        .playerChrome()
                }
                .accessibilityLabel("播放或暂停")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            Text(model.phase == .playing ? "直播中 · 点击画面暂停" : "正在连接直播流…")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .padding(.bottom, 24)
        }
        .background {
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .contentShape(.rect)
        .onTapGesture {
            model.togglePlayback()
        }
    }

    private func failureOverlay(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("无法连接直播间")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("重试") {
                    Task { await model.start(room: room, client: environment.client) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Glass.pink)
                Button("返回") { dismiss() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
        .padding(24)
        .glassPanel(cornerRadius: 20)
        .padding(.horizontal, 32)
    }
}

@MainActor
@Observable
final class LiveRoomPlayerModel {
    enum Phase: Equatable {
        case loading
        case playing
        case failed(String)
    }

    private(set) var phase: Phase = .loading

    @ObservationIgnored private let engine = MPVEngine()
    @ObservationIgnored private var hasSurface = false
    @ObservationIgnored private var didLoad = false
    @ObservationIgnored private var pendingURL: URL?

    func start(room: LiveRoom, client: BiliClient) async {
        phase = .loading
        didLoad = false
        engine.stop()
        do {
            let info = try await client.livePlayInfo(roomID: room.id)
            pendingURL = info.playURL
            loadIfReady()
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func attach(_ layer: CAMetalLayer) {
        guard !hasSurface else { return }
        hasSurface = true
        do {
            try engine.attach(layer: layer)
            loadIfReady()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func togglePlayback() {
        guard phase == .playing else { return }
        engine.togglePause()
    }

    func stop() {
        engine.stop()
        engine.shutdown()
    }

    private func loadIfReady() {
        guard hasSurface, !didLoad, let url = pendingURL else { return }
        didLoad = true
        engine.load(videoURL: url)
        engine.play()
        phase = .playing
    }
}
