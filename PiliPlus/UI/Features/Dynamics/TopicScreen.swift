import SwiftUI

/// 话题详情与动态流。
struct TopicScreen: View {
    let topicID: Int

    @Environment(AppEnvironment.self) private var environment

    @State private var topic: TopicInfo?
    @State private var items: [DynamicItem] = []
    @State private var offset = ""
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var phase: Phase = .idle
    @State private var articleTarget: ArticleTarget?
    @State private var detailTarget: DynamicTarget?
    @State private var showsLogin = false

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle(topic?.name ?? "话题")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(reset: true) }
        .navigationDestination(item: $articleTarget) { target in
            ArticleScreen(cvid: target.id)
        }
        .navigationDestination(item: $detailTarget) { target in
            DynamicDetailScreen(id: target.id)
        }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load(reset: true) }
            }
        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let topic {
                        header(topic)
                    }

                    if items.isEmpty {
                        ContentUnavailableView {
                            Label("话题下还没有动态", systemImage: "number")
                        } description: {
                            Text("稍后再来看看。")
                        }
                        .padding(.top, 28)
                    } else {
                        ForEach(items) { item in
                            DynamicCard(
                                item: item,
                                onOpenVideo: { card in
                                    environment.playerRequest = PlayerRequest(card: card)
                                },
                                onOpenArticle: { cvid in
                                    articleTarget = ArticleTarget(id: cvid)
                                },
                                onOpenDetail: { dynamic in
                                    detailTarget = DynamicTarget(id: dynamic.id)
                                }
                            )
                            .onAppear {
                                Task { await loadMoreIfNeeded(item) }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private func header(_ topic: TopicInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("#\(topic.name)")
                .font(.title3.weight(.bold))
            if !topic.description.isEmpty {
                Text(topic.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            HStack(spacing: 14) {
                Label(VideoCard.formatCount(topic.view), systemImage: "eye")
                Label(VideoCard.formatCount(topic.discuss), systemImage: "text.bubble")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 18, elevation: 0.6)
    }

    private func load(reset: Bool) async {
        if reset {
            phase = .loading
            offset = ""
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true

        do {
            if reset, topic == nil {
                topic = try await environment.client.topicTop(topicID: topicID)
            }

            let result = try await environment.client.topicFeed(
                topicID: topicID,
                offset: offset
            )
            if reset {
                items = result.items
            } else {
                let existing = Set(items.map(\.id))
                items.append(contentsOf: result.items.filter { !existing.contains($0.id) })
            }
            offset = result.offset
            hasMore = result.hasMore
            phase = .loaded
        } catch {
            if reset {
                phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
        isLoading = false
    }

    private func loadMoreIfNeeded(_ item: DynamicItem) async {
        guard hasMore, !isLoading, phase == .loaded, !offset.isEmpty else { return }
        guard items.suffix(3).contains(where: { $0.id == item.id }) else { return }
        await load(reset: false)
    }
}

/// 话题搜索。
struct TopicSearchSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var topics: [TopicInfo] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                VStack(spacing: 0) {
                    searchBar
                    content
                }
            }
            .navigationTitle("话题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task { isFocused = true }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
            TextField("搜索话题", text: $keyword)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { Task { await search() } }
            Button {
                Task { await search() }
            } label: {
                if isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Text("搜索").font(.subheadline.weight(.semibold))
                }
            }
            .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            LoadingStateView(style: .failure(errorMessage)) {
                Task { await search() }
            }
        } else if isSearching {
            LoadingStateView(style: .loading)
        } else if hasSearched, topics.isEmpty {
            ContentUnavailableView {
                Label("没有找到话题", systemImage: "number")
            } description: {
                Text("换个关键词试试。")
            }
        } else if topics.isEmpty {
            ContentUnavailableView {
                Label("搜索话题", systemImage: "number")
            } description: {
                Text("输入关键词发现社区话题。")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(topics) { topic in
                        NavigationLink {
                            TopicScreen(topicID: topic.id)
                        } label: {
                            topicRow(topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 10)
            }
        }
    }

    private func topicRow(_ topic: TopicInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("#\(topic.name)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if !topic.description.isEmpty {
                Text(topic.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 12) {
                Label(VideoCard.formatCount(topic.view), systemImage: "eye")
                Label(VideoCard.formatCount(topic.discuss), systemImage: "text.bubble")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func search() async {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        do {
            topics = try await environment.client.searchTopics(keyword: query)
            hasSearched = true
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSearching = false
    }
}
