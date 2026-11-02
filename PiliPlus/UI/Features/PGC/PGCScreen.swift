import SwiftUI

/// 番剧索引：海报网格 + 分页。
struct PGCScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var items: [PGCIndexItem] = []
    @State private var page = 0
    @State private var hasNext = true
    @State private var isLoadingMore = false
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
        .navigationTitle("番剧")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadInitial() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await loadInitial() }
            }
        case .loaded:
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: 12)],
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(items) { item in
                        NavigationLink {
                            PGCSeasonScreen(seasonID: item.id)
                        } label: {
                            posterCard(item)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task { await loadMoreIfNeeded(item) }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)

                if isLoadingMore {
                    ProgressView().padding(.vertical, 12)
                }
            }
        }
    }

    private func posterCard(_ item: PGCIndexItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: item.coverURL)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if let badge = item.badge, !badge.isEmpty {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Glass.pink.opacity(0.9), in: .rect(cornerRadius: 4))
                            .padding(6)
                    }
                }

            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(item.indexShow.isEmpty ? " " : item.indexShow)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private func loadInitial() async {
        phase = .loading
        page = 0
        hasNext = true
        items = []
        do {
            let result = try await environment.client.pgcIndex(page: 1)
            items = result.items
            page = 1
            hasNext = result.hasNext
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func loadMoreIfNeeded(_ item: PGCIndexItem) async {
        guard hasNext, !isLoadingMore, phase == .loaded else { return }
        guard items.suffix(4).contains(where: { $0.id == item.id }) else { return }
        isLoadingMore = true
        do {
            let next = page + 1
            let result = try await environment.client.pgcIndex(page: next)
            let existing = Set(items.map(\.id))
            items.append(contentsOf: result.items.filter { !existing.contains($0.id) })
            page = next
            hasNext = result.hasNext
        } catch {
            // 静默失败，滚动重试。
        }
        isLoadingMore = false
    }
}

/// 番剧季详情：资料头 + 剧集网格，点击剧集进入 PGC 播放。
struct PGCSeasonScreen: View {
    let seasonID: Int

    @Environment(AppEnvironment.self) private var environment
    @State private var season: PGCSeason?
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
        .navigationTitle(season?.title ?? "番剧")
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
            if let season {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(season)
                        episodes(season)

                        NavigationLink {
                            PGCReviewsScreen(
                                mediaID: season.mediaID,
                                seasonTitle: season.title
                            )
                        } label: {
                            Label("长评", systemImage: "text.quote")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassButtonStyle(tint: Glass.violet))
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func header(_ season: PGCSeason) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                RemoteImage(url: season.coverURL)
                    .frame(width: 112, height: 112 * 4 / 3)
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(season.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if season.score > 0 {
                            Label(String(format: "%.1f", season.score), systemImage: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        if !season.areas.isEmpty {
                            Text(season.areas.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !season.newEpisodeText.isEmpty {
                        GlassChip(title: season.newEpisodeText, systemImage: "play.circle", tint: Glass.pink)
                    }

                    Spacer(minLength: 0)

                    Button {
                        if let episode = season.episodes.first {
                            play(season: season, episode: episode)
                        }
                    } label: {
                        Label("开始观看", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))
                }
            }

            if !season.evaluate.isEmpty {
                Text(season.evaluate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 14) {
                Label(season.episodeCountText, systemImage: "rectangle.stack")
                if season.viewCount > 0 {
                    Label("\(VideoCard.formatCount(season.viewCount)) 播放", systemImage: "play.fill")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 24, tint: Glass.pink, elevation: 0.8)
    }

    private func episodes(_ season: PGCSeason) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LiquidSectionHeader(title: "选集", subtitle: season.episodeCountText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(season.episodes) { episode in
                    Button {
                        play(season: season, episode: episode)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(episode.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text(episode.longTitle.isEmpty ? " " : episode.longTitle)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(cornerRadius: 12, elevation: 0.4)
                }
            }
        }
    }

    private func play(season: PGCSeason, episode: PGCEpisode) {
        environment.playerRequest = PlayerRequest(pgcSeason: season, episode: episode)
    }

    private func load() async {
        guard season == nil else { return }
        phase = .loading
        do {
            season = try await environment.client.pgcSeason(seasonID: seasonID)
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
