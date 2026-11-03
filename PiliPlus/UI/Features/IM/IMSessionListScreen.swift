import SwiftUI

/// 私信会话列表。
struct IMSessionListScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var sessions: [IMSession] = []
    @State private var phase: Phase = .idle
    @State private var showsLogin = false

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case requiresLogin
        case failed(String)
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("私信")
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
                Label("登录后查看私信", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("私信与会话和账号绑定。")
            } actions: {
                Button("扫码登录") { showsLogin = true }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))
            }
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load() }
            }
        case .loaded:
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("还没有私信", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("收到或发起私信后会显示在这里。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sessions) { session in
                            NavigationLink {
                                IMChatScreen(talkerID: session.talkerID, name: session.name)
                            } label: {
                                sessionRow(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
                .refreshable { await load() }
            }
        }
    }

    private func sessionRow(_ session: IMSession) -> some View {
        HStack(spacing: 12) {
            AvatarImage(url: session.faceURL, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if session.timestamp > 0 {
                        Text(relativeTime(session.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                HStack(spacing: 8) {
                    Text(session.lastMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if session.unread > 0 {
                        Text("\(min(session.unread, 99))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Glass.pink, in: .capsule)
                    }
                }
            }
        }
        .padding(10)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func relativeTime(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<3_600: return "\(Int(seconds / 60)) 分钟前"
        case ..<86_400: return "\(Int(seconds / 3_600)) 小时前"
        default: return date.formatted(date: .numeric, time: .omitted)
        }
    }

    private func load() async {
        guard environment.account.isLoggedIn else {
            phase = .requiresLogin
            return
        }
        phase = .loading

        do {
            var loaded = try await environment.client.imSessions()
            let client = environment.client
            let mids = loaded.map(\.talkerID).prefix(20)

            var cards: [Int: (name: String, faceURL: URL?)] = [:]
            await withTaskGroup(of: (Int, String, URL?).self) { group in
                for mid in mids {
                    group.addTask {
                        if let card = try? await client.userCard(mid: mid) {
                            return (mid, card.name, card.faceURL)
                        }
                        return (mid, "用户 \(mid)", nil)
                    }
                }
                for await (mid, name, faceURL) in group {
                    cards[mid] = (name, faceURL)
                }
            }

            for index in loaded.indices {
                if let card = cards[loaded[index].talkerID] {
                    loaded[index].name = card.name
                    loaded[index].faceURL = card.faceURL
                }
            }

            sessions = loaded
            phase = .loaded
        } catch {
            let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = message.contains("登录") ? .requiresLogin : .failed(message)
        }
    }
}
