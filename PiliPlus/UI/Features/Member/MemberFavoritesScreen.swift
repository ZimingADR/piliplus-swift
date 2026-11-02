import SwiftUI

/// UP 主公开收藏夹列表。
struct MemberFavoritesScreen: View {
    let mid: Int

    @Environment(AppEnvironment.self) private var environment

    @State private var folders: [FavoriteFolder] = []
    @State private var phase: Phase = .idle

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
        .navigationTitle("TA 的收藏夹")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load() }
            }
        case .loaded:
            if folders.isEmpty {
                ContentUnavailableView {
                    Label("没有公开收藏夹", systemImage: "star")
                } description: {
                    Text("该 UP 主还没有公开收藏夹。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(folders) { folder in
                            NavigationLink {
                                FavoriteDetailScreen(folder: folder)
                            } label: {
                                folderRow(folder)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func folderRow(_ folder: FavoriteFolder) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: folder.coverURL)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(folder.mediaCount) 个内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .liquidGlass(cornerRadius: 20, elevation: 0.7)
    }

    private func load() async {
        phase = .loading
        do {
            folders = try await environment.client.favoriteFolders(mid: mid)
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
