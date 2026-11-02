import SwiftUI

/// UP 主合集/系列列表。
struct MemberCollectionsScreen: View {
    let mid: Int

    @Environment(AppEnvironment.self) private var environment

    @State private var collections: [MemberCollection] = []
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
        .navigationTitle("TA 的合集")
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
            if collections.isEmpty {
                ContentUnavailableView {
                    Label("没有合集", systemImage: "rectangle.stack")
                } description: {
                    Text("该 UP 主还没有创建合集或系列。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(collections) { collection in
                            collectionRow(collection)
                                .onAppear {
                                    Task { await loadMoreIfNeeded(collection) }
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

    private func collectionRow(_ collection: MemberCollection) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: collection.coverURL)
                .frame(width: 96, height: 60)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(collection.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(collection.isSeason ? "合集" : "系列")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Glass.pink)
                    Text("共 \(collection.count) 个视频")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
            let result = try await environment.client.memberCollections(mid: mid, page: next)
            if reset {
                collections = result.0
            } else {
                let existing = Set(collections.map(\.id))
                collections.append(contentsOf: result.0.filter { !existing.contains($0.id) })
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

    private func loadMoreIfNeeded(_ collection: MemberCollection) async {
        guard hasMore, !isLoading else { return }
        guard collections.suffix(3).contains(where: { $0.id == collection.id }) else { return }
        await load(reset: false)
    }
}
