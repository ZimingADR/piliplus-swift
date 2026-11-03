import SwiftUI

/// 专栏所属合集。
struct ArticleCollectionScreen: View {
    let cvid: Int

    @Environment(AppEnvironment.self) private var environment

    @State private var collection: ArticleCollection?
    @State private var items: [ArticleCollectionItem] = []
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
        .navigationTitle(collection?.name ?? "专栏合集")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load() }
            }
        case .loaded:
            if items.isEmpty {
                ContentUnavailableView {
                    Label("暂无合集文章", systemImage: "doc.text")
                } description: {
                    Text("这篇文章暂未加入专栏合集。")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if let collection {
                            header(collection)
                        }
                        ForEach(items) { item in
                            NavigationLink {
                                ArticleScreen(cvid: item.id)
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func header(_ collection: ArticleCollection) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: collection.imageURL)
                .frame(width: 64, height: 80)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .lineLimit(2)
                Text("共 \(collection.articleCount) 篇 · \(VideoCard.formatCount(collection.read)) 阅读")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func row(_ item: ArticleCollectionItem) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: item.coverURL)
                .frame(width: 88, height: 56)
                .clipShape(.rect(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if item.viewCount > 0 {
                    Label(VideoCard.formatCount(item.viewCount), systemImage: "eye")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 14, elevation: 0.5)
    }

    private func load() async {
        phase = .loading
        do {
            let result = try await environment.client.articleCollection(cvid: cvid)
            collection = result.0
            items = result.1
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
