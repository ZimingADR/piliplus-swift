import SwiftUI

/// 首页推荐流。
///
/// iPhone 单列大卡片，iPad 双列；下拉刷新重新拉取推荐，滚动到末尾自动翻页。
struct HomeScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var model: HomeFeedModel?

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
        }
        return [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header

                if let model {
                    switch model.phase {
                    case .idle, .loading where model.videos.isEmpty:
                        LoadingStateView(style: .loading)
                    case .failed(let message) where model.videos.isEmpty:
                        LoadingStateView(style: .failure(message: message)) {
                            Task { await model.refresh() }
                        }
                    default:
                        feed(model)
                    }
                } else {
                    LoadingStateView(style: .loading)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("推荐")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model?.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("刷新推荐")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    environment.settings.appearance = environment.settings.appearance == .dark ? .light : .dark
                } label: {
                    Image(systemName: environment.settings.appearance == .dark ? "sun.max" : "moon")
                }
                .accessibilityLabel("切换深浅色")
            }
        }
        .task {
            if model == nil {
                model = HomeFeedModel(client: environment.client)
            }
            await model?.loadInitialIfNeeded()
        }
        .refreshable {
            await model?.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("为你推荐")
                .font(.largeTitle.weight(.bold))
            Text("无需登录 · 下拉刷新 · 上拉加载更多")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func feed(_ model: HomeFeedModel) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(model.videos) { card in
                Button {
                    play(card)
                } label: {
                    VideoCardTile(card: card, showsOwnerFace: true)
                }
                .buttonStyle(.plain)
                .task {
                    await model.loadMoreIfNeeded(current: card)
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

    private func play(_ card: VideoCard) {
        environment.playerRequest = PlayerRequest(card: card)
    }
}
