import SwiftUI

/// UP 主专栏列表。
struct MemberArticlesScreen: View {
    let mid: Int

    @Environment(AppEnvironment.self) private var environment

    @State private var articles: [MemberArticle] = []
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
        .navigationTitle("TA 的专栏")
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
            if articles.isEmpty {
                ContentUnavailableView {
                    Label("没有专栏", systemImage: "doc.text")
                } description: {
                    Text("该 UP 主还没有发布专栏。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(articles) { article in
                            NavigationLink {
                                ArticleScreen(cvid: article.id)
                            } label: {
                                articleRow(article)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await loadMoreIfNeeded(article) }
                            }
                        }
                        if isLoading {
                            ProgressView().padding(.vertical, 12)
                        }
                        if !hasMore, !articles.isEmpty {
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

    private func articleRow(_ article: MemberArticle) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: article.coverURL)
                .frame(width: 92, height: 58)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if let publishedAt = article.publishedAt {
                        Text(publishedAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    if article.viewCount > 0 {
                        Label(VideoCard.formatCount(article.viewCount), systemImage: "eye")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
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
            let result = try await environment.client.memberArticles(mid: mid, page: next)
            if reset {
                articles = result.0
            } else {
                let existing = Set(articles.map(\.id))
                articles.append(contentsOf: result.0.filter { !existing.contains($0.id) })
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

    private func loadMoreIfNeeded(_ article: MemberArticle) async {
        guard hasMore, !isLoading else { return }
        guard articles.suffix(3).contains(where: { $0.id == article.id }) else { return }
        await load(reset: false)
    }
}
