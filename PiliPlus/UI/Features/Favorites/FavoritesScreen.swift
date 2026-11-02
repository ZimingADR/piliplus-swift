import SwiftUI

/// 收藏夹列表。
struct FavoritesScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var folders: [FavoriteFolder] = []
    @State private var phase: Phase = .idle
    @State private var showsLogin = false
    @State private var showsCreate = false
    @State private var newFolderTitle = ""
    @State private var isCreating = false
    @State private var createError: String?
    @State private var folderSort: FavoriteFolderSort = .server

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("排序", selection: $folderSort) {
                        ForEach(FavoriteFolderSort.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("收藏夹排序")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard environment.account.isLoggedIn else {
                        showsLogin = true
                        return
                    }
                    newFolderTitle = ""
                    showsCreate = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel("新建收藏夹")
            }
        }
        .task { await load() }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
        .alert("新建收藏夹", isPresented: $showsCreate) {
            TextField("收藏夹名称", text: $newFolderTitle)
            Button("创建") {
                Task { await createFolder() }
            }
            .disabled(isCreating)
            Button("取消", role: .cancel) {}
        } message: {
            Text("新收藏夹默认为公开。")
        }
        .alert(
            "创建失败",
            isPresented: Binding(
                get: { createError != nil },
                set: { if !$0 { createError = nil } }
            )
        ) {
            Button("好", role: .cancel) { createError = nil }
        } message: {
            Text(createError ?? "")
        }
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
                        ForEach(sortedFolders) { folder in
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

    private var sortedFolders: [FavoriteFolder] {
        switch folderSort {
        case .server:
            folders
        case .name:
            folders.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .count:
            folders.sorted { $0.mediaCount > $1.mediaCount }
        }
    }

    private func createFolder() async {
        let title = newFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard environment.account.isLoggedIn else {
            showsLogin = true
            return
        }

        isCreating = true
        do {
            try await environment.client.createFavoriteFolder(title: title)
            await load()
        } catch {
            createError = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isCreating = false
    }

    private func load() async {        guard environment.account.isLoggedIn else {
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
    @State private var keyword = ""
    @State private var sortOrder: FavoriteSortOrder = .recent

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
        .searchable(text: $keyword, prompt: "搜索收藏内容")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("排序", selection: $sortOrder) {
                        ForEach(FavoriteSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("排序")
            }
        }
        .onChange(of: sortOrder) { _, _ in
            Task { await loadInitial() }
        }
        .onSubmit(of: .search) {
            Task { await loadInitial() }
        }
        .onChange(of: keyword) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { await loadInitial() }
            }
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
            if videos.isEmpty {
                ContentUnavailableView {
                    Label("没有找到收藏内容", systemImage: "bookmark")
                } description: {
                    Text(keyword.isEmpty ? "收藏夹还是空的。" : "换个关键词试试。")
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
    }

    private func loadInitial() async {
        phase = .loading
        do {
            let result = try await environment.client.favoritePage(
                mediaID: folder.id,
                page: 1,
                keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
                order: sortOrder.rawValue
            )
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
            let workspaceKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = try await environment.client.favoritePage(
                mediaID: folder.id,
                page: next,
                keyword: workspaceKeyword,
                order: sortOrder.rawValue
            )
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

/// 收藏夹文件夹排序。
enum FavoriteFolderSort: String, CaseIterable, Identifiable, Equatable {
    case server
    case name
    case count

    var id: String { rawValue }

    var title: String {
        switch self {
        case .server: "默认顺序"
        case .name: "按名称"
        case .count: "按内容数"
        }
    }
}

/// 收藏夹内容排序。
enum FavoriteSortOrder: String, CaseIterable, Identifiable, Equatable {
    case recent = "mtime"
    case views = "view"
    case published = "pubtime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: "最近收藏"
        case .views: "最多播放"
        case .published: "最近投稿"
        }
    }
}
