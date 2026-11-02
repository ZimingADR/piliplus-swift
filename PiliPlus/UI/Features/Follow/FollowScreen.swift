import SwiftUI

/// 关注列表。
struct FollowScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var users: [FollowUser] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var isLoading = false
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
        .navigationTitle("关注")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadInitial() }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .requiresLogin:
            ContentUnavailableView {
                Label("登录后查看关注", systemImage: "person.2")
            } description: {
                Text("关注列表与账号绑定。")
            } actions: {
                Button("扫码登录") { showsLogin = true }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))
            }
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await loadInitial() }
            }
        case .loaded:
            if users.isEmpty {
                ContentUnavailableView {
                    Label("还没有关注任何人", systemImage: "person.2")
                } description: {
                    Text("在 UP 主空间点击关注即可。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(users) { user in
                            NavigationLink {
                                MemberScreen(mid: user.mid)
                            } label: {
                                userRow(user)
                            }
                            .buttonStyle(.plain)
                        }
                        if isLoading {
                            ProgressView().padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func userRow(_ user: FollowUser) -> some View {
        HStack(spacing: 12) {
            AvatarImage(url: user.faceURL, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if user.isVip {
                        GlassChip(title: "大会员", systemImage: "crown.fill", isSelected: true, tint: Glass.pink)
                    }
                }
                Text(user.sign.isEmpty ? "这个人很神秘" : user.sign)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .liquidGlass(cornerRadius: 18, elevation: 0.6)
    }

    private func loadInitial() async {
        guard environment.account.isLoggedIn, let mid = environment.account.profile?.mid else {
            phase = .requiresLogin
            return
        }
        phase = .loading
        do {
            let result = try await environment.client.followings(mid: mid, page: 1)
            users = result.users
            page = 1
            hasMore = result.users.count >= 20
            phase = .loaded
        } catch {
            let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = message.contains("登录") ? .requiresLogin : .failed(message)
        }
    }
}
