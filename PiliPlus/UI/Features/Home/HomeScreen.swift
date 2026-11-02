import SwiftUI

/// 首页：推荐 / 热门 / 排行榜。
///
/// 信息架构对齐 Flutter 版 PiliPlus：顶部品牌栏 + 可切换内容流。
/// 视觉升级为 Liquid Glass——悬浮分段控件、玻璃卡片与光晕背景。
struct HomeScreen: View {
    enum Segment: String, CaseIterable, Hashable {
        case recommend
        case hot
        case rank

        var title: String {
            switch self {
            case .recommend: "推荐"
            case .hot: "热门"
            case .rank: "排行榜"
            }
        }

        var subtitle: String {
            switch self {
            case .recommend: "为你挑选的今日内容"
            case .hot: "全站正在热议"
            case .rank: "综合排行 · 每日更新"
            }
        }
    }

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Namespace private var segmentNamespace
    @State private var segment: Segment = .recommend
    @State private var model: HomeFeedModel?
    @State private var showsSearch = false

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    GlassSegmentedControl(
                        items: Segment.allCases,
                        title: { $0.title },
                        selection: $segment,
                        namespace: segmentNamespace
                    )

                    switch segment {
                    case .recommend:
                        recommendContent
                    case .hot:
                        VideoFeedContent(kind: .hot) { play($0) }
                            .transition(.opacity)
                    case .rank:
                        VideoFeedContent(kind: .rank) { play($0) }
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .refreshable {
                if segment == .recommend {
                    await model?.refresh()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model == nil {
                model = HomeFeedModel(client: environment.client)
            }
            await model?.loadInitialIfNeeded()
        }
        .sheet(isPresented: $showsSearch) {
            SearchPanelSheet()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PiliPlus")
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                Text(segment.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)

            GlassIconButton(systemName: "magnifyingglass") {
                showsSearch = true
            }
            .accessibilityLabel("搜索")

            NavigationLink {
                HistoryScreen()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: .circle)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                    }
            }
            .accessibilityLabel("播放历史")
        }
    }

    // MARK: - 推荐

    @ViewBuilder
    private var recommendContent: some View {
        if let model {
            switch model.phase {
            case .idle:
                LoadingStateView(style: .loading)
            case .loading:
                if model.videos.isEmpty {
                    skeletonFeed
                } else {
                    recommendGrid(model)
                }
            case .failed(let message):
                if model.videos.isEmpty {
                    LoadingStateView(style: .failure(message)) {
                        Task { await model.refresh() }
                    }
                } else {
                    recommendGrid(model)
                }
            case .loaded:
                if model.videos.isEmpty {
                    ContentUnavailableView {
                        Label("暂时没有推荐内容", systemImage: "sparkles")
                    } description: {
                        Text("下拉刷新试试。")
                    }
                } else {
                    recommendGrid(model)
                }
            }
        } else {
            skeletonFeed
        }
    }

    private func recommendGrid(_ model: HomeFeedModel) -> some View {
        LazyVGrid(columns: [GridItem(.flexible())], alignment: .leading, spacing: 20) {
            ForEach(model.videos) { card in
                Button {
                    play(card)
                } label: {
                    VideoCardTile(card: card, showsOwnerFace: true)
                }
                .buttonStyle(.plain)
                .onAppear {
                    Task { await model.loadMoreIfNeeded(current: card) }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if model.isLoadingMore {
                ProgressView()
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var skeletonFeed: some View {
        VStack(spacing: 20) {
            ForEach(0 ..< 3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(.quaternary)
                        .aspectRatio(Theme.coverAspect, contentMode: .fit)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: 140, height: 12)
                }
            }
        }
        .redacted(reason: .placeholder)
        .padding(.top, 8)
    }

    private func play(_ card: VideoCard) {
        environment.playerRequest = PlayerRequest(card: card)
    }
}
