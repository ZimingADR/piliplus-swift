import SwiftUI

struct ArticleTarget: Identifiable, Hashable {
    let id: Int
}

/// 「动态」Tab：关注动态信息流。
struct DynamicsScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var model: DynamicsModel?
    @State private var showsLogin = false
    @State private var articleTarget: ArticleTarget?
    @State private var repostTarget: DynamicItem?
    @State private var actionError: String?

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    header
                    content
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable { await model?.loadInitial(force: true) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model == nil {
                model = DynamicsModel(client: environment.client, account: environment.account)
            }
            await model?.loadInitial()
        }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
        .sheet(item: $repostTarget) { item in
            RepostSheet(item: item)
        }
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button("好", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .navigationDestination(item: $articleTarget) { target in
            ArticleScreen(cvid: target.id)
        }
        .navigationDestination(item: $detailPath) { target in
            DynamicDetailScreen(id: target.id)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("动态")
                    .font(.system(size: 26, weight: .bold))
                Text("关注的人正在分享")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            GlassIconButton(systemName: "arrow.clockwise") {
                Task { await model?.loadInitial(force: true) }
            }
            .accessibilityLabel("刷新动态")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let model {
            switch model.phase {
            case .idle, .loading:
                LoadingStateView(style: .loading)
            case .requiresLogin:
                loginPrompt
            case .failed(let message):
                LoadingStateView(style: .failure(message)) {
                    Task { await model.loadInitial(force: true) }
                }
            case .loaded:
                if model.items.isEmpty {
                    ContentUnavailableView {
                        Label("还没有动态", systemImage: "square.stack")
                    } description: {
                        Text("去关注一些 UP 主吧。")
                    }
                    .padding(.top, 32)
                } else {
                    ForEach(model.items) { item in
                        DynamicCard(
                            item: item,
                            onOpenVideo: { card in
                                environment.playerRequest = PlayerRequest(card: card)
                            },
                            onOpenArticle: { cvid in
                                articleTarget = ArticleTarget(id: cvid)
                            },
                            onOpenDetail: { dynamic in
                                articleTarget = nil
                                detailPath = DynamicTarget(id: dynamic.id)
                            },
                            onLike: { liked in
                                Task { await like(item, liked: liked) }
                            },
                            onRepost: {
                                guard environment.account.isLoggedIn else {
                                    showsLogin = true
                                    return
                                }
                                repostTarget = item
                            }
                        )
                        .onAppear {
                            Task { await model.loadMoreIfNeeded(current: item) }
                        }
                    }
                    if model.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
        } else {
            LoadingStateView(style: .loading)
        }
    }

    private func like(_ item: DynamicItem, liked: Bool) async {
        guard environment.account.isLoggedIn else {
            showsLogin = true
            return
        }
        do {
            try await environment.client.likeDynamic(id: item.id, like: liked)
        } catch {
            actionError = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Glass.pink)
            Text("登录后查看关注动态")
                .font(.headline)
            Text("动态信息流与账号绑定，登录后可同步关注列表。")
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

    @State private var detailPath: DynamicTarget? = nil
}

/// 动态详情页。
struct DynamicDetailScreen: View {
    let id: String

    @Environment(AppEnvironment.self) private var environment
    @State private var item: DynamicItem?
    @State private var phase: Phase = .idle
    @State private var articleTarget: ArticleTarget?
    @State private var showsComments = false

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if let item {
                        DynamicCard(
                            item: item,
                            expandsText: true,
                            onOpenVideo: { card in
                                environment.playerRequest = PlayerRequest(card: card)
                            },
                            onOpenArticle: { cvid in
                                articleTarget = ArticleTarget(id: cvid)
                            },
                            onOpenDetail: { _ in }
                        )

                        Button {
                            showsComments = true
                        } label: {
                            Label("查看评论", systemImage: "text.bubble")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassButtonStyle(tint: Glass.blue))
                    } else if case .failed(let message) = phase {
                        LoadingStateView(style: .failure(message)) {
                            Task { await load() }
                        }
                    } else {
                        LoadingStateView(style: .loading)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("动态详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .navigationDestination(item: $articleTarget) { target in
            ArticleScreen(cvid: target.id)
        }
        .sheet(isPresented: $showsComments) {
            if let oid = Int(id) {
                CommentsSheet(source: .dynamic(id: oid))
            }
        }
    }

    private func load() async {
        guard item == nil else { return }
        phase = .loading
        do {
            item = try await environment.client.dynamicDetail(id: id)
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct DynamicTarget: Identifiable, Hashable {
    let id: String
}

/// 转发动态浮层。
struct RepostSheet: View {
    let item: DynamicItem

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showsLogin = false

    var body: some View {
        NavigationStack {
            Form {
                Section("转发内容") {
                    TextField("说点什么…", text: $text, axis: .vertical)
                        .lineLimit(2 ... 5)
                }

                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        Label("转发", systemImage: "arrowshape.turn.up.right")
                    }
                    .disabled(isSending)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("转发后会出现在你的动态中，并保留原动态引用。")
                }
            }
            .navigationTitle("转发动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    private func send() async {
        guard environment.account.isLoggedIn else {
            showsLogin = true
            return
        }
        isSending = true
        errorMessage = nil
        do {
            try await environment.client.repostDynamic(id: item.id, content: text)
            dismiss()
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSending = false
    }
}
