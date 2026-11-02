import SwiftUI

/// 收藏夹列表。
struct FavoritesScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var folders: [FavoriteFolder] = []
    @State private var phase: Phase = .idle
    @State private var showsLogin = false

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case requiresLogin
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("收藏夹")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .requiresLogin:
            ContentUnavailableView {
                Label("登录后查看收藏夹", systemImage: "star")
            } description: {
                Text("收藏夹与账号绑定，登录后可浏览与同步。")
            } actions: {
                Button("扫码登录") { showsLogin = true }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))
            }
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load() }
            }
        case .loaded:
            if folders.isEmpty {
                ContentUnavailableView {
                    Label("还没有收藏夹", systemImage: "star")
                } description: {
                    Text("在视频页收藏后会自动创建默认收藏夹。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(folders) { folder in
                            NavigationLink {
                                FavoriteDetailScreen(folder: folder)
                            } label: {
                                folderRow(folder)
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

    private func folderRow(_ folder: FavoriteFolder) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: folder.coverURL)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(folder.mediaCount) 个内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .liquidGlass(cornerRadius: 20, elevation: 0.7)
    }

    private func load() async {
        guard environment.account.isLoggedIn else {
            phase = .requiresLogin
            return
        }
        guard let mid = environment.account.profile?.mid else {
            phase = .requiresLogin
            return
        }
        phase = .loading
        do {
            folders = try await environment.client.favoriteFolders(mid: mid)
            phase = .loaded
        } catch {
            let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = message.contains("登录") ? .requiresLogin : .failed(message)
        }
    }
}

/// 收藏夹详情（视频分页）。
struct FavoriteDetailScreen: View {
    let folder: FavoriteFolder

    @Environment(AppEnvironment.self) private var environment
    @State private var videos: [VideoCard] = []
    @State private var page = 0
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @State private var phase: LoadPhase = .idle

    private enum LoadPhase: Equatable {
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
        .navigationTitle(folder.title)
        .navigationBarTitleDisplayMode(.inline)
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
                    if isLoadingMore {
                        ProgressView().padding(.vertical, 12)
                    }
                    if !hasMore, !videos.isEmpty {
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

    private func loadInitial() async {
        phase = .loading
        do {
            let result = try await environment.client.favoritePage(mediaID: folder.id, page: 1)
            videos = result.videos
            page = 1
            hasMore = result.hasMore
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func loadMoreIfNeeded(_ card: VideoCard) async {
        guard hasMore, !isLoadingMore else { return }
        guard videos.suffix(4).contains(where: { $0.id == card.id }) else { return }
        isLoadingMore = true
        do {
            let next = page + 1
            let result = try await environment.client.favoritePage(mediaID: folder.id, page: next)
            let existing = Set(videos.map(\.id))
            videos.append(contentsOf: result.videos.filter { !existing.contains($0.id) })
            page = next
            hasMore = result.hasMore
        } catch {
            // 静默失败，滚动重试。
        }
        isLoadingMore = false
    }
}
