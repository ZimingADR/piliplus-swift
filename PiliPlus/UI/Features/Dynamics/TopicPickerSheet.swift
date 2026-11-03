import SwiftUI

/// 选择话题（发布动态时附加）。
struct TopicPickerSheet: View {
    var onSelect: (TopicInfo) -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var topics: [TopicInfo] = []
    @State private var isSearching = false
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
            .navigationTitle("选择话题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
            .task { isFocused = true }
        }
        .presentationDetents([.medium, .large])
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
        } else if topics.isEmpty {
            ContentUnavailableView {
                Label("搜索话题", systemImage: "number")
            } description: {
                Text("输入关键词，选择一个话题附加到动态。")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(topics) { topic in
                        Button {
                            onSelect(topic)
                            dismiss()
                        } label: {
                            row(topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 10)
            }
        }
    }

    private func row(_ topic: TopicInfo) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
        .liquidGlass(cornerRadius: 14, elevation: 0.5)
    }

    private func search() async {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        do {
            topics = try await environment.client.searchTopics(keyword: query)
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSearching = false
    }
}
