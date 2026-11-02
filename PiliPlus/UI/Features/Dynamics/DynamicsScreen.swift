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
    @State private var showsCompose = false
    @State private var filter: DynamicFeedFilter = .all

    var body: some View {
        ZStack {
            LiquidBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    header
                    filterChips
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
        .sheet(isPresented: $showsCompose) {
            ComposeDynamicSheet {
                Task { await model?.loadInitial(force: true) }
            }
        }
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
            GlassIconButton(systemName: "square.and.pencil") {
                guard environment.account.isLoggedIn else {
                    showsLogin = true
                    return
                }
                showsCompose = true
            }
            .accessibilityLabel("发布动态")
            GlassIconButton(systemName: "arrow.clockwise") {
                Task { await model?.loadInitial(force: true) }
            }
            .accessibilityLabel("刷新动态")
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DynamicFeedFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                filter == item
                                    ? Glass.pink.opacity(0.26)
                                    : Color.white.opacity(0.08),
                                in: .capsule
                            )
                            .overlay {
                                if filter == item {
                                    Capsule().stroke(Glass.pink.opacity(0.6), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredItems: [DynamicItem] {
        guard let model else { return [] }
        switch filter {
        case .all:
            return model.items
        case .video:
            return model.items.filter { $0.kind == .video }
        case .article:
            return model.items.filter { $0.kind == .article }
        case .text:
            return model.items.filter { $0.kind == .text || $0.kind == .images }
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
                if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label(filter.emptyTitle, systemImage: "square.stack")
                    } description: {
                        Text(filter.emptyDescription)
                    }
                    .padding(.top, 32)
                } else {
                    ForEach(filteredItems) { item in
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

/// 发布纯文字动态。
struct ComposeDynamicSheet: View {
    var onPublished: () -> Void = {}

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showsLogin = false

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("分享新鲜事…", text: $text, axis: .vertical)
                        .lineLimit(4 ... 8)
                } header: {
                    Text("内容")
                } footer: {
                    HStack {
                        Text("支持 #话题# 与 [表情码]")
                        Spacer()
                        Text("\(text.count)/2000")
                            .monospacedDigit()
                            .foregroundStyle(text.count > 2000 ? .red : .secondary)
                    }
                }

                Section {
                    Button {
                        Task { await publish() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView().controlSize(.small)
                            }
                            Text("发布")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isSending || trimmed.isEmpty || text.count > 2000)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { LiquidBackground() }
            .navigationTitle("发布动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    private func publish() async {
        guard !trimmed.isEmpty else { return }
        guard environment.account.isLoggedIn else {
            showsLogin = true
            return
        }

        isSending = true
        errorMessage = nil
        do {
            try await environment.client.publishDynamic(text: trimmed)
            onPublished()
            dismiss()
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSending = false
    }
}

/// 动态类型筛选。
enum DynamicFeedFilter: String, CaseIterable, Identifiable {
    case all
    case video
    case article
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .video: "视频"
        case .article: "专栏"
        case .text: "图文"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "还没有动态"
        case .video: "还没有视频动态"
        case .article: "还没有专栏动态"
        case .text: "还没有图文动态"
        }
    }

    var emptyDescription: String {
        switch self {
        case .all: "去关注一些 UP 主吧。"
        default: "换个分类看看，或稍后刷新。"
        }
    }
}
