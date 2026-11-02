import SwiftUI

/// 直播推荐列表。
struct LiveScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var rooms: [LiveRoom] = []
    @State private var page = 0
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var phase: Phase = .idle
    @State private var showsSearch = false

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
        .navigationTitle("直播")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("搜索直播")
            }
        }
        .sheet(isPresented: $showsSearch) {
            LiveSearchSheet()
        }
        .task { await loadInitial() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await loadInitial() }
            }
        case .loaded:
            if rooms.isEmpty {
                ContentUnavailableView {
                    Label("暂时没有直播", systemImage: "dot.radiowaves.left.and.right")
                } description: {
                    Text("下拉刷新或稍后再试。")
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 156), spacing: 12)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(rooms) { room in
                            NavigationLink {
                                LiveRoomScreen(room: room)
                            } label: {
                                LiveCard(room: room)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await loadMoreIfNeeded(room) }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)

                    if isLoadingMore {
                        ProgressView().padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private func loadInitial() async {
        phase = .loading
        page = 0
        hasMore = true
        rooms = []
        do {
            let result = try await environment.client.liveRooms(page: 1)
            rooms = result
            page = 1
            hasMore = !result.isEmpty
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func loadMoreIfNeeded(_ room: LiveRoom) async {
        guard hasMore, !isLoadingMore, phase == .loaded else { return }
        guard rooms.suffix(4).contains(where: { $0.id == room.id }) else { return }
        isLoadingMore = true
        do {
            let next = page + 1
            let result = try await environment.client.liveRooms(page: next)
            let existing = Set(rooms.map(\.id))
            rooms.append(contentsOf: result.filter { !existing.contains($0.id) })
            page = next
            hasMore = !result.isEmpty
        } catch {
            // 静默失败。
        }
        isLoadingMore = false
    }
}

struct LiveCard: View {
    let room: LiveRoom

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: room.coverURL)
                .aspectRatio(Theme.coverAspect, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("直播中")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.5), in: .capsule)
                    .padding(6)
                }

            Text(room.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Text(room.uname)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !room.watchedText.isEmpty {
                    Text(room.watchedText)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}
