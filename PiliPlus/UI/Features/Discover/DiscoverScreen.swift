import SwiftUI

/// 「发现」：内容矩阵入口（热门、排行、稍后再看、历史、设置）。
struct DiscoverScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showsSearch = false
    @State private var showsMemberSearch = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchBanner
                    featureGrid
                    footer
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsSearch) {
            SearchPanelSheet()
        }
        .sheet(isPresented: $showsMemberSearch) {
            MemberSearchSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("发现")
                .font(.system(size: 26, weight: .bold))
            Text("热门、榜单与账号内容")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var searchBanner: some View {
        Button {
            showsSearch = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("搜索视频、UP 主、番剧")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                GlassChip(title: "热搜", systemImage: "flame.fill", tint: Glass.pink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .liquidGlass(cornerRadius: 20, elevation: 0.7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("搜索")
    }

    private var featureGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            NavigationLink {
                VideoFeedScreen(kind: .hot)
            } label: {
                DiscoverCard(
                    title: "热门",
                    subtitle: "全站正在热议",
                    systemImage: "flame.fill",
                    tint: Glass.pink
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                VideoFeedScreen(kind: .rank)
            } label: {
                DiscoverCard(
                    title: "排行榜",
                    subtitle: "综合排行 · 每日更新",
                    systemImage: "chart.bar.fill",
                    tint: Glass.blue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PreciousScreen()
            } label: {
                DiscoverCard(
                    title: "入站必刷",
                    subtitle: "站内经典名场面",
                    systemImage: "sparkles",
                    tint: Glass.violet
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WeeklyScreen()
            } label: {
                DiscoverCard(
                    title: "每周必看",
                    subtitle: "每周精选合集",
                    systemImage: "calendar.badge.clock",
                    tint: Glass.mint
                )
            }
            .buttonStyle(.plain)

            Button {
                showsMemberSearch = true
            } label: {
                DiscoverCard(
                    title: "找 UP 主",
                    subtitle: "搜索用户主页",
                    systemImage: "person.crop.circle.badge.magnifyingglass",
                    tint: Glass.blue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                LaterScreen()
            } label: {
                DiscoverCard(
                    title: "稍后再看",
                    subtitle: "待看清单",
                    systemImage: "text.badge.clock",
                    tint: Glass.violet
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                HistoryScreen()
            } label: {
                DiscoverCard(
                    title: "播放历史",
                    subtitle: "断点续播",
                    systemImage: "clock.arrow.circlepath",
                    tint: Glass.mint
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FavoritesScreen()
            } label: {
                DiscoverCard(
                    title: "收藏夹",
                    subtitle: "我的收藏",
                    systemImage: "star.fill",
                    tint: Glass.pink
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                FollowScreen()
            } label: {
                DiscoverCard(
                    title: "关注",
                    subtitle: "我关注的 UP 主",
                    systemImage: "person.2.fill",
                    tint: Glass.mint
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PGCScreen()
            } label: {
                DiscoverCard(
                    title: "番剧",
                    subtitle: "追番与影视",
                    systemImage: "play.rectangle.fill",
                    tint: Glass.violet
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                LiveScreen()
            } label: {
                DiscoverCard(
                    title: "直播",
                    subtitle: "正在直播",
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: .red
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsScreen()
            } label: {
                DiscoverCard(
                    title: "设置",
                    subtitle: "播放与弹幕",
                    systemImage: "gearshape.fill",
                    tint: .orange
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AboutScreen()
            } label: {
                DiscoverCard(
                    title: "关于",
                    subtitle: AppInfo.versionText,
                    systemImage: "info.circle.fill",
                    tint: .gray
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("更多内容持续接入中")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text("收藏、关注、动态、番剧、直播与下载将按迁移计划陆续开放。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }
}

struct DiscoverCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.15), in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.8)
                }

            Spacer(minLength: 0)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 128)
        .padding(14)
        .liquidGlass(cornerRadius: 22, elevation: 0.7)
    }
}
