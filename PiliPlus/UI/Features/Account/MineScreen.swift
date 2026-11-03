import SwiftUI

/// 「我的」：账号资料、快捷入口与设置。
struct MineScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showsLogin = false
    @State private var showsLogout = false

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    shortcutCard
                    settingsCard
                    if environment.account.isLoggedIn {
                        logoutButton
                    }
                    disclaimer
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GlassIconButton(systemName: "arrow.clockwise") {
                    Task { await environment.account.refresh() }
                }
                .accessibilityLabel("刷新账号信息")
            }
        }
        .sheet(isPresented: $showsLogin) {
            LoginScreen()
        }
        .confirmationDialog("退出当前账号？", isPresented: $showsLogout) {
            Button("退出登录", role: .destructive) {
                Task { await environment.account.logout() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("本机将删除登录 Cookie，播放历史与设置不受影响。")
        }
    }

    // MARK: - 资料卡

    @ViewBuilder
    private var profileCard: some View {
        if let profile = environment.account.profile {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    AvatarImage(url: profile.faceURL, size: 64)
                        .overlay(alignment: .bottomTrailing) {
                            Text(profile.levelText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Glass.pink, in: .capsule)
                                .offset(x: 4, y: 4)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(profile.name)
                                .font(.headline)
                                .lineLimit(1)
                            if profile.isVip {
                                GlassChip(title: "大会员", systemImage: "crown.fill", isSelected: true, tint: Glass.pink)
                            }
                        }
                        Text("UID \(profile.mid)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 0) {
                    statItem(title: "关注", value: "\(profile.following)")
                    statDivider
                    statItem(title: "粉丝", value: "\(profile.follower)")
                    statDivider
                    statItem(title: "硬币", value: profile.coinsText)
                }
            }
            .padding(16)
            .liquidGlass(cornerRadius: 26, tint: Glass.pink)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Glass.pink)
                Text("登录 B 站账号")
                    .font(.headline)
                Text("同步收藏、关注、稍后再看，解锁大会员画质与杜比音效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showsLogin = true
                } label: {
                    Text("扫码登录")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassButtonStyle(tint: Glass.pink))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .liquidGlass(cornerRadius: 26, tint: Glass.pink)
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.6))
            .frame(width: 1, height: 26)
    }

    // MARK: - 入口

    private var shortcutCard: some View {
        VStack(spacing: 0) {
            NavigationLink { HistoryScreen() } label: {
                row(title: "播放历史", subtitle: "断点续播与本地搜索", systemImage: "clock.arrow.circlepath", tint: Glass.blue)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 56)

            NavigationLink { LaterScreen() } label: {
                row(title: "稍后再看", subtitle: "跨设备同步的待看清单", systemImage: "text.badge.clock", tint: Glass.violet)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 56)

            NavigationLink { FavoritesScreen() } label: {
                row(title: "收藏夹", subtitle: "收藏的视频合集", systemImage: "star", tint: Glass.pink)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 56)

            NavigationLink { FollowScreen() } label: {
                row(title: "关注", subtitle: "我关注的 UP 主", systemImage: "person.2", tint: Glass.mint)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 56)

            NavigationLink { DownloadsScreen() } label: {
                row(title: "离线下载", subtitle: "本地 DASH 双轨视频", systemImage: "arrow.down.circle", tint: Glass.blue)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 56)

            NavigationLink { IMSessionListScreen() } label: {
                row(title: "私信", subtitle: "会话与消息", systemImage: "bubble.left.and.bubble.right", tint: Glass.violet)
            }
            .buttonStyle(.plain)
        }
        .liquidGlass(cornerRadius: 22)
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            NavigationLink { SettingsScreen() } label: {
                row(title: "设置", subtitle: "播放、弹幕、音量平衡与外观", systemImage: "gearshape", tint: Glass.mint)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 56)

            NavigationLink { AboutScreen() } label: {
                row(title: "关于 PiliPlus", subtitle: AppInfo.versionText, systemImage: "info.circle", tint: Glass.pink)
            }
            .buttonStyle(.plain)
        }
        .liquidGlass(cornerRadius: 22)
    }

    private func row(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            showsLogout = true
        } label: {
            Text("退出登录")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassButtonStyle(tint: .red))
    }

    private var disclaimer: some View {
        Text("PiliPlus 为第三方客户端，与哔哩哔哩官方无关联。")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
    }
}
