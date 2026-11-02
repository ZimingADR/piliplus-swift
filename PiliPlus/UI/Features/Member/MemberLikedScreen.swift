import SwiftUI

/// UP 主最近点赞的视频。
struct MemberLikedScreen: View {
    let mid: Int

    @Environment(AppEnvironment.self) private var environment

    @State private var videos: [VideoCard] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var phase: Phase = .idle

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("TA 的点赞")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(reset: true) }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load(reset: true) }
            }
        case .loaded:
            if videos.isEmpty {
                ContentUnavailableView {
                    Label("没有点赞视频", systemImage: "hand.thumbsup")
                } description: {
                    Text("该 UP 主还没有公开点赞的视频。")
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        VideoPosterGrid(
                            videos: videos,
                            onSelect: { card in
                                environment.playerRequest = PlayerRequest(card: card)
                            },
                            onAppear: { card in
                                Task { await loadMoreIfNeeded(card) }
                            }
                        )
                        if isLoading {
                            ProgressView().padding(.vertical, 12)
                        }
                        if !hasMore {
                            Text("没有更多了")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func load(reset: Bool) async {
        if reset {
            phase = .loading
            page = 0
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true

        do {
            let next = page + 1
            let result = try await environment.client.memberLikedVideos(mid: mid, page: next)
            if reset {
                videos = result.0
            } else {
                let existing = Set(videos.map(\.id))
                videos.append(contentsOf: result.0.filter { !existing.contains($0.id) })
            }
            page = next
            hasMore = result.1
            phase = .loaded
        } catch {
            if reset {
                phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
        isLoading = false
    }

    private func loadMoreIfNeeded(_ card: VideoCard) async {
        guard hasMore, !isLoading else { return }
        guard videos.suffix(4).contains(where: { $0.id == card.id }) else { return }
        await load(reset: false)
    }
}
