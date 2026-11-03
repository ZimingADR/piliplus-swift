import SwiftUI

/// 关注的主播直播列表。
struct LiveFollowScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var rooms: [LiveRoom] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var phase: Phase = .idle
    @State private var showsLogin = false

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case requiresLogin
        case failed(String)
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("关注的开播")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(reset: true) }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .requiresLogin:
            ContentUnavailableView {
                Label("登录后查看关注开播", systemImage: "heart")
            } description: {
                Text("关注列表与账号绑定。")
            } actions: {
                Button("扫码登录") { showsLogin = true }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))
            }
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load(reset: true) }
            }
        case .loaded:
            if rooms.isEmpty {
                ContentUnavailableView {
                    Label("关注的主播都还没开播", systemImage: "dot.radiowaves.left.and.right")
                } description: {
                    Text("稍后再来看看吧。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(rooms) { room in
                            NavigationLink {
                                LiveRoomScreen(room: room)
                            } label: {
                                roomRow(room)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task { await loadMoreIfNeeded(room) }
                            }
                        }
                        if isLoading {
                            ProgressView().padding(.vertical, 12)
                        }
                        if !hasMore, !rooms.isEmpty {
                            Text("没有更多了")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func roomRow(_ room: LiveRoom) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: room.coverURL)
                .frame(width: 120, height: 70)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("直播中")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.85), in: .capsule)
                        .padding(5)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(room.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(room.uname)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(room.areaName)
                    if !room.watchedText.isEmpty {
                        Text(room.watchedText)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func load(reset: Bool) async {
        guard environment.account.isLoggedIn else {
            phase = .requiresLogin
            return
        }

        if reset {
            phase = .loading
            page = 0
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true

        do {
            let next = page + 1
            let result = try await environment.client.followedLiveRooms(page: next)
            if reset {
                rooms = result.0
            } else {
                let existing = Set(rooms.map(\.id))
                rooms.append(contentsOf: result.0.filter { !existing.contains($0.id) })
            }
            page = next
            hasMore = result.1
            phase = .loaded
        } catch {
            if reset {
                let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
                phase = message.contains("登录") ? .requiresLogin : .failed(message)
            }
        }
        isLoading = false
    }

    private func loadMoreIfNeeded(_ room: LiveRoom) async {
        guard hasMore, !isLoading, phase == .loaded else { return }
        guard rooms.suffix(3).contains(where: { $0.id == room.id }) else { return }
        await load(reset: false)
    }
}
