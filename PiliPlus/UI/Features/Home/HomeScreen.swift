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
                    case .idle:
                        LoadingStateView(style: .loading)
                    case .loading:
                        if model.videos.isEmpty {
                            LoadingStateView(style: .loading)
                        } else {
                            feed(model)
                        }
                    case .failed(let message):
                        if model.videos.isEmpty {
                            LoadingStateView(style: .failure(message)) {
                                Task { await model.refresh() }
                            }
                        } else {
                            feed(model)
                        }
                    case .loaded:
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
            Text("今日推荐")
                .font(.title2.weight(.semibold))
            Text("无需登录 · 下拉刷新 · 上拉加载")
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
