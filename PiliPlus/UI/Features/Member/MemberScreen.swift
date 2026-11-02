import SwiftUI

/// UP 主个人空间：资料头 + 投稿列表。
struct MemberScreen: View {
    let mid: Int
    var showsCloseButton: Bool = false

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var model: MemberViewModel?

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let model {
                        profileHeader(model)
                        orderPicker(model)
                        videos(model)
                    } else {
                        LoadingStateView(style: .loading)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(model?.profile?.name ?? "UP 主空间")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task {
            if model == nil {
                model = MemberViewModel(mid: mid, client: environment.client)
            }
            await model?.loadIfNeeded()
        }
    }

    private func profileHeader(_ model: MemberViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarImage(url: model.profile?.faceURL, size: 68)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(model.profile?.name ?? "加载中")
                            .font(.headline)
                            .lineLimit(1)
                        if model.profile?.isVip == true {
                            GlassChip(title: "大会员", systemImage: "crown.fill", isSelected: true, tint: Glass.pink)
                        }
                    }
                    Text(model.profile?.sign.isEmpty == false ? model.profile?.sign ?? "" : "这个人很神秘，什么都没有写")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                statItem(title: "粉丝", value: countText(model.profile?.follower ?? 0))
                divider
                statItem(title: "关注", value: countText(model.profile?.following ?? 0))
                divider
                statItem(title: "投稿", value: "\(model.totalCount)")
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 26, tint: Glass.pink)
    }

    private func orderPicker(_ model: MemberViewModel) -> some View {
        HStack(spacing: 8) {
            orderChip(model, title: "最新发布", value: "pubdate")
            orderChip(model, title: "最多播放", value: "click")
            Spacer(minLength: 0)
        }
    }

    private func orderChip(_ model: MemberViewModel, title: String, value: String) -> some View {
        Button {
            Task { await model.changeOrder(value) }
        } label: {
            GlassChip(title: title, isSelected: model.order == value)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func videos(_ model: MemberViewModel) -> some View {
        switch model.phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await model.refresh() }
            }
        case .loaded:
            if model.videos.isEmpty {
                ContentUnavailableView {
                    Label("没有投稿", systemImage: "video.slash")
                } description: {
                    Text("这个 UP 主暂时没有公开投稿。")
                }
            } else {
                VideoPosterGrid(
                    videos: model.videos,
                    onSelect: { card in
                        environment.playerRequest = PlayerRequest(card: card)
                    },
                    onAppear: { card in
                        Task { await model.loadMoreIfNeeded(current: card) }
                    }
                )
                if model.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.6))
            .frame(width: 1, height: 24)
    }

    private func countText(_ value: Int) -> String {
        VideoCard.formatCount(value)
    }
}
