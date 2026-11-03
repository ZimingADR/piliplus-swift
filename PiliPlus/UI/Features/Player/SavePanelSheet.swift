import SwiftUI

/// 收藏面板：选择要加入/移出的收藏夹。
struct SavePanelSheet: View {
    let aid: Int

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var folders: [FavoriteFolder] = []
    @State private var selectedIDs: Set<Int> = []
    @State private var phase: Phase = .idle
    @State private var errorMessage: String?
    @State private var showsLogin = false
    @State private var savingFolderID: Int?

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case requiresLogin
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                content
            }
            .navigationTitle("收藏到")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showsLogin) { LoginScreen() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .requiresLogin:
            ContentUnavailableView {
                Label("登录后收藏", systemImage: "star")
            } description: {
                Text("收藏夹与账号绑定。")
            } actions: {
                Button("扫码登录") { showsLogin = true }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))
            }
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load() }
            }
        case .loaded:
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    ForEach(folders) { folder in
                        Button {
                            Task { await toggle(folder) }
                        } label: {
                            folderRow(folder)
                        }
                        .buttonStyle(.plain)
                        .disabled(savingFolderID != nil)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private func folderRow(_ folder: FavoriteFolder) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: folder.coverURL)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(folder.mediaCount) 个内容")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if savingFolderID == folder.id {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: selectedIDs.contains(folder.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedIDs.contains(folder.id) ? Glass.pink : .tertiary)
            }
        }
        .padding(10)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func load() async {
        guard environment.account.isLoggedIn,
              let mid = environment.account.profile?.mid else {
            phase = .requiresLogin
            return
        }

        phase = .loading
        do {
            folders = try await environment.client.favoriteFolders(mid: mid)
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func toggle(_ folder: FavoriteFolder) async {
        guard aid > 0 else { return }
        savingFolderID = folder.id
        errorMessage = nil
        let adding = !selectedIDs.contains(folder.id)
        do {
            try await environment.client.favoriteVideo(
                aid: aid,
                addMediaIDs: adding ? [folder.id] : [],
                delMediaIDs: adding ? [] : [folder.id]
            )
            if adding {
                selectedIDs.insert(folder.id)
            } else {
                selectedIDs.remove(folder.id)
            }
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        savingFolderID = nil
    }
}
