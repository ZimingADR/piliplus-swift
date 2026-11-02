import SwiftUI

/// 两列自适应视频网格（热门 / 排行榜 / 稍后再看共用）。
struct VideoPosterGrid: View {
    let videos: [VideoCard]
    let onSelect: (VideoCard) -> Void
    var showsOwner: Bool = false
    var onAppear: ((VideoCard) -> Void)?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 156), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(videos) { card in
                Button {
                    onSelect(card)
                } label: {
                    VideoCardTile(card: card, showsOwnerFace: showsOwner)
                }
                .buttonStyle(.plain)
                .onAppear {
                    onAppear?(card)
                }
            }
        }
    }
}

/// 热门 / 排行榜内容视图（可内嵌首页，也可独立成页）。
struct VideoFeedContent: View {
    let kind: VideoFeedModel.Kind
    var onSelect: (VideoCard) -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var model: VideoFeedModel?

    var body: some View {
        Group {
            if let model {
                switch model.phase {
                case .idle:
                    LoadingStateView(style: .loading)
                case .loading:
                    if model.videos.isEmpty {
                        LoadingStateView(style: .loading)
                    } else {
                        content(model)
                    }
                case .failed(let message):
                    if model.videos.isEmpty {
                        LoadingStateView(style: .failure(message)) {
                            Task { await model.refresh() }
                        }
                    } else {
                        content(model)
                    }
                case .loaded:
                    content(model)
                }
            } else {
                LoadingStateView(style: .loading)
            }
        }
        .task {
            if model == nil {
                model = VideoFeedModel(kind: kind, client: environment.client)
            }
            await model?.loadInitialIfNeeded()
        }
    }

    @ViewBuilder
    private func content(_ model: VideoFeedModel) -> some View {
        if kind == .rank {
            LazyVStack(spacing: 6) {
                ForEach(Array(model.videos.enumerated()), id: \.element.id) { index, card in
                    Button {
                        onSelect(card)
                    } label: {
                        RankRow(rank: index + 1, card: card)
                    }
                    .buttonStyle(.plain)
                    if index < model.videos.count - 1 {
                        Divider().opacity(0.4).padding(.leading, 44)
                    }
                }
            }
        } else {
            VideoPosterGrid(
                videos: model.videos,
                onSelect: onSelect,
                showsOwner: true,
                onAppear: { card in
                    Task { await model.loadMoreIfNeeded(current: card) }
                }
            )
        }
    }
}

/// 排行榜行：名次 + 封面 + 标题 + UP 主与播放量。
struct RankRow: View {
    let rank: Int
    let card: VideoCard

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(rank <= 3 ? Glass.pink : Color.secondary)
                .frame(width: 28, alignment: .center)

            RemoteImage(url: card.coverURL)
                .frame(width: 112, height: 112 / Theme.coverAspect)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(card.ownerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Label(card.viewText, systemImage: "play.fill")
                    Text(card.durationText)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}

/// 独立的热门 / 排行榜页面（用于「发现」入口）。
struct VideoFeedScreen: View {
    let kind: VideoFeedModel.Kind
    @Environment(AppEnvironment.self) private var environment
    @State private var showSearch = false

    var body: some View {
        ZStack {
            LiquidBackground()
            ScrollView {
                VideoFeedContent(kind: kind) { card in
                    environment.playerRequest = PlayerRequest(card: card)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GlassIconButton(systemName: "magnifyingglass") { showSearch = true }
            }
        }
        .sheet(isPresented: $showSearch) { SearchPanelSheet() }
    }
}

/// 稍后再看。
struct LaterScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: LaterModel?

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("稍后再看")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                model = LaterModel(client: environment.client, account: environment.account)
            }
            await model?.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let model {
            switch model.phase {
            case .idle, .loading:
                LoadingStateView(style: .loading)
            case .requiresLogin:
                ContentUnavailableView {
                    Label("登录后查看稍后再看", systemImage: "clock.badge")
                } description: {
                    Text("稍后再看与账号绑定，登录后可跨设备同步。")
                }
            case .failed(let message):
                LoadingStateView(style: .failure(message)) {
                    Task { await model.loadIfNeeded(force: true) }
                }
            case .loaded:
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if model.items.isEmpty {
                            ContentUnavailableView {
                                Label("暂时没有稍后再看", systemImage: "clock")
                            } description: {
                                Text("在视频详情页点击「稍后再看」即可加入。")
                            }
                            .padding(.top, 40)
                        }
                        ForEach(model.items) { item in
                            Button {
                                environment.playerRequest = PlayerRequest(card: item.card)
                            } label: {
                                VideoRow(
                                    title: item.card.title,
                                    coverURL: item.card.coverURL,
                                    ownerName: item.card.ownerName,
                                    bottomText: item.progress > 0
                                        ? "已看 \(VideoCard.formatDuration(item.progress)) / \(item.card.durationText)"
                                        : item.card.viewText + " 播放",
                                    progress: item.progressFraction,
                                    durationText: item.card.durationText
                                )
                                .padding(12)
                                .liquidGlass(cornerRadius: 18, elevation: 0.6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        } else {
            LoadingStateView(style: .loading)
        }
    }
}
