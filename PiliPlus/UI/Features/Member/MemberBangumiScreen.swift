import SwiftUI

/// UP 主追番列表。
struct MemberBangumiScreen: View {
    let mid: Int

    @Environment(AppEnvironment.self) private var environment

    @State private var items: [MemberBangumi] = []
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

    private let columns = [
        GridItem(.adaptive(minimum: 108), spacing: 12),
    ]

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("TA 的追番")
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
                    Label("没有追番", systemImage: "tv")
                } description: {
                    Text("该 UP 主还没有公开追番。")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink {
                                PGCSeasonScreen(seasonID: item.seasonID)
                            } label: {
                                card(item)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await loadMoreIfNeeded(item) }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)

                    if isLoading {
                        ProgressView().padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private func card(_ item: MemberBangumi) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            RemoteImage(url: item.coverURL)
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if !item.newEp.isEmpty {
                        Text(item.newEp)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
                            .padding(5)
                    }
                }

            Text(item.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let badge = item.badge, !badge.isEmpty {
                Text(badge)
                    .font(.caption2)
                    .foregroundStyle(Glass.pink)
                    .lineLimit(1)
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
            let result = try await environment.client.memberBangumi(mid: mid, page: next)
            if reset {
                items = result.0
            } else {
                let existing = Set(items.map(\.id))
                items.append(contentsOf: result.0.filter { !existing.contains($0.id) })
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

    private func loadMoreIfNeeded(_ item: MemberBangumi) async {
        guard hasMore, !isLoading else { return }
        guard items.suffix(4).contains(where: { $0.id == item.id }) else { return }
        await load(reset: false)
    }
}
