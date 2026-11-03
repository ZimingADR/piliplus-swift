import SwiftUI

/// 搜索 UP 主。
struct MemberSearchSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var users: [UserSearchItem] = []
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
            .navigationTitle("找 UP 主")
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
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索 UP 主昵称", text: $keyword)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await search() }
                }

            Button {
                Task { await search() }
            } label: {
                if isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Text("搜索")
                        .font(.subheadline.weight(.semibold))
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
        } else if hasSearched, users.isEmpty {
            ContentUnavailableView {
                Label("没有找到 UP 主", systemImage: "person.crop.circle.badge.questionmark")
            } description: {
                Text("换个关键词试试。")
            }
        } else if users.isEmpty {
            ContentUnavailableView {
                Label("搜索 UP 主", systemImage: "person.2")
            } description: {
                Text("输入昵称查找用户主页。")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(users) { user in
                        NavigationLink {
                            MemberScreen(mid: user.mid)
                        } label: {
                            userRow(user)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 10)
            }
        }
    }

    private func userRow(_ user: UserSearchItem) -> some View {
        HStack(spacing: 12) {
            AvatarImage(url: user.faceURL, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("LV\(user.level)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Glass.blue)
                }
                if !user.sign.isEmpty {
                    Text(user.sign)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label(VideoCard.formatCount(user.fans), systemImage: "person.2")
                    Label(VideoCard.formatCount(user.videoCount), systemImage: "play.rectangle")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func search() async {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        do {
            users = try await environment.client.searchUsers(keyword: query)
            hasSearched = true
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSearching = false
    }
}
