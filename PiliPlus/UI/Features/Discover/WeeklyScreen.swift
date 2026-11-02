import SwiftUI

/// 每周必看：系列切换 + 当期视频网格。
struct WeeklyScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var series: [PopularSeries] = []
    @State private var selectedNumber: Int?
    @State private var videos: [VideoCard] = []
    @State private var isLoadingVideos = false
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
        .navigationTitle("每周必看")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSeries() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await loadSeries() }
            }
        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    seriesPicker
                    if isLoadingVideos {
                        LoadingStateView(style: .loading)
                            .frame(height: 220)
                    } else if videos.isEmpty {
                        ContentUnavailableView {
                            Label("本期暂无内容", systemImage: "calendar")
                        } description: {
                            Text("换一期试试。")
                        }
                    } else {
                        VideoPosterGrid(
                            videos: videos,
                            onSelect: { card in
                                environment.playerRequest = PlayerRequest(card: card)
                            },
                            onAppear: { _ in }
                        )
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private var seriesPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(series) { item in
                    Button {
                        guard selectedNumber != item.number else { return }
                        selectedNumber = item.number
                        Task { await loadVideos(number: item.number) }
                    } label: {
                        Text(item.subject)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                selectedNumber == item.number
                                    ? Glass.pink.opacity(0.28)
                                    : Color.white.opacity(0.08),
                                in: .capsule
                            )
                            .overlay {
                                if selectedNumber == item.number {
                                    Capsule().stroke(Glass.pink.opacity(0.6), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadSeries() async {
        phase = .loading
        do {
            series = try await environment.client.popularSeriesList()
            guard let first = series.first else {
                phase = .loaded
                return
            }
            selectedNumber = first.number
            videos = try await environment.client.popularSeriesVideos(number: first.number)
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func loadVideos(number: Int) async {
        isLoadingVideos = true
        do {
            videos = try await environment.client.popularSeriesVideos(number: number)
        } catch {
            videos = []
        }
        isLoadingVideos = false
    }
}
