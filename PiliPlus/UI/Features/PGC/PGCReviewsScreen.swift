import SwiftUI

/// 番剧长评列表。
struct PGCReviewsScreen: View {
    let mediaID: Int
    let seasonTitle: String

    @Environment(AppEnvironment.self) private var environment

    @State private var items: [PGCReviewItem] = []
    @State private var cursor = ""
    @State private var total = 0
    @State private var isLoading = false
    @State private var hasMore = true
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
        .navigationTitle("长评")
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
            if items.isEmpty {
                ContentUnavailableView {
                    Label("还没有长评", systemImage: "text.quote")
                } description: {
                    Text("《\(seasonTitle)》还没有长评。")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(items) { review in
                            reviewCard(review)
                                .onAppear {
                                    Task { await loadMoreIfNeeded(review) }
                                }
                        }
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

    private func reviewCard(_ review: PGCReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarImage(url: review.avatarURL, size: 30)
                Text(review.authorName)
                    .font(.caption.weight(.semibold))
                if review.score > 0 {
                    Text(String(repeating: "★", count: min(review.score, 5)))
                        .font(.caption2)
                        .foregroundStyle(Glass.pink)
                }
                Spacer(minLength: 0)
                if !review.timeText.isEmpty {
                    Text(review.timeText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !review.title.isEmpty {
                Text(review.title)
                    .font(.subheadline.weight(.semibold))
            }

            Text(review.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)

            if review.likes > 0 {
                Label(VideoCard.formatCount(review.likes), systemImage: "hand.thumbsup")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .liquidGlass(cornerRadius: 18, elevation: 0.6)
    }

    private func load(reset: Bool) async {
        if reset {
            phase = .loading
            cursor = ""
            hasMore = true
        }
        guard !isLoading, hasMore else { return }
        isLoading = true

        do {
            let result = try await environment.client.pgcReviews(
                mediaID: mediaID,
                cursor: cursor
            )
            if reset {
                items = result.0
            } else {
                let existing = Set(items.map(\.id))
                items.append(contentsOf: result.0.filter { !existing.contains($0.id) })
            }
            cursor = result.1
            total = result.2
            hasMore = !cursor.isEmpty
            phase = .loaded
        } catch {
            if reset {
                phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
        isLoading = false
    }

    private func loadMoreIfNeeded(_ review: PGCReviewItem) async {
        guard hasMore, !isLoading else { return }
        guard items.suffix(3).contains(where: { $0.id == review.id }) else { return }
        await load(reset: false)
    }
}
