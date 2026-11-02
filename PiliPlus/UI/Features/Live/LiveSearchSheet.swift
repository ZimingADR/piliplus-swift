import SwiftUI

/// 直播关键词搜索。
struct LiveSearchSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var rooms: [LiveRoom] = []
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
            .navigationTitle("搜索直播")
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

            TextField("搜索主播或直播间", text: $keyword)
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
        } else if hasSearched, rooms.isEmpty {
            ContentUnavailableView {
                Label("没有找到直播", systemImage: "dot.radiowaves.left.and.right")
            } description: {
                Text("换个关键词试试。")
            }
        } else if rooms.isEmpty {
            ContentUnavailableView {
                Label("搜索直播", systemImage: "magnifyingglass")
            } description: {
                Text("输入主播昵称或直播间标题。")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(rooms) { room in
                        NavigationLink {
                            LiveRoomScreen(room: room)
                        } label: {
                            roomRow(room)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 10)
            }
        }
    }

    private func roomRow(_ room: LiveRoom) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: room.coverURL)
                .frame(width: 116, height: 68)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(room.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(room.uname)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(room.areaName)
                    if !room.watchedText.isEmpty {
                        Text(room.watchedText)
                    }
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
            rooms = try await environment.client.searchLive(keyword: query)
            hasSearched = true
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSearching = false
    }
}
