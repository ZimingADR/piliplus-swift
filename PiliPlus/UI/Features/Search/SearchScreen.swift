import SwiftUI

/// 搜索页（同时作为播放器内快速搜索浮层 `search_panel`）。
struct SearchScreen: View {
    var isPanel: Bool = false

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var model: SearchModel?
    @State private var query = ""
    @State private var showsSuggestions = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)

            content
        }
        .background(Color(.systemBackground))
        .navigationTitle(isPanel ? "快速搜索" : "搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPanel {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                orderMenu
            }
        }
        .task {
            if model == nil {
                model = SearchModel(client: environment.client)
            }
            await model?.loadTrendingIfNeeded()
        }
        .task(id: query) {
            guard !query.isEmpty else {
                showsSuggestions = false
                return
            }
            showsSuggestions = true
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await model?.loadSuggestions(for: query)
        }
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索视频、UP 主", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFieldFocused)
                .onSubmit(submit)
            if !query.isEmpty {
                Button {
                    query = ""
                    model?.clearResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("清空搜索词")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: .capsule)
        .overlay {
            Capsule().strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let model {
            if showsSuggestions, !model.suggestions.isEmpty {
                suggestionList(model)
            } else {
                switch model.phase {
                case .idle:
                    discovery(model)
                case .loading:
                    LoadingStateView(style: .loading)
                    Spacer(minLength: 0)
                case .failed(let message):
                    LoadingStateView(style: .failure(message: message)) {
                        submit()
                    }
                    Spacer(minLength: 0)
                case .loaded:
                    resultList(model)
                }
            }
        } else {
            LoadingStateView(style: .loading)
        }
    }

    // MARK: - 热搜 / 联想

    private func discovery(_ model: SearchModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "搜索发现", subtitle: "实时热搜")
                    .padding(.horizontal, Theme.screenPadding)

                if model.trending.isEmpty {
                    LoadingStateView(style: .loading)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(Array(model.trending.enumerated()), id: \.element.id) { index, item in
                            Button {
                                query = item.keyword
                                submit()
                            } label: {
                                trendingCell(item, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func trendingCell(_ item: TrendingKeyword, rank: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(rank)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(rank <= 3 ? Theme.accent : Color.secondary)
                .frame(width: 20, alignment: .trailing)
            Text(item.displayName)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func suggestionList(_ model: SearchModel) -> some View {
        List(model.suggestions, id: \.self) { suggestion in
            Button {
                query = suggestion
                model.selectSuggestion(suggestion)
                showsSuggestions = false
                isFieldFocused = false
            } label: {
                Label(suggestion, systemImage: "magnifyingglass")
                    .font(.subheadline)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 结果

    private func resultList(_ model: SearchModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("共 \(model.totalResults) 个结果")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(model.order.title)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 4)

                ForEach(model.results) { card in
                    Button {
                        play(card)
                    } label: {
                        VideoRow(
                            title: card.title,
                            coverURL: card.coverURL,
                            ownerName: card.ownerName,
                            bottomText: "\(card.durationText) · \(card.viewText) 播放",
                            durationText: card.durationText
                        )
                        .padding(.horizontal, Theme.screenPadding)
                    }
                    .buttonStyle(.plain)
                    .task {
                        await model.loadMoreIfNeeded(current: card)
                    }

                    Divider()
                        .padding(.leading, 168)
                }

                if model.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - 排序

    private var orderMenu: some View {
        Menu {
            ForEach(SearchOrder.allCases) { order in
                Button {
                    Task { await model?.changeOrder(order) }
                } label: {
                    if model?.order == order {
                        Label(order.title, systemImage: "checkmark")
                    } else {
                        Text(order.title)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .disabled(model?.phase != .loaded)
        .accessibilityLabel("排序方式")
    }

    // MARK: - Actions

    private func submit() {
        let term = query
        guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        showsSuggestions = false
        isFieldFocused = false
        Task { await model?.submit(term) }
    }

    private func play(_ card: VideoCard) {
        environment.playerRequest = PlayerRequest(card: card)
        if isPanel { dismiss() }
    }
}

/// 播放器 / 首页唤起的快速搜索浮层。
struct SearchPanelSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SearchScreen(isPanel: true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
