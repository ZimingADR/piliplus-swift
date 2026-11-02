import Foundation
import Observation

/// 搜索页状态：热搜、输入联想、结果分页与排序。
@MainActor
@Observable
final class SearchModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var trending: [TrendingKeyword] = []
    private(set) var suggestions: [String] = []
    private(set) var results: [VideoCard] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false
    private(set) var totalResults = 0

    var order: SearchOrder = .relevance

    @ObservationIgnored private var page = 0
    @ObservationIgnored private var totalPages = 0
    @ObservationIgnored private var currentQuery = ""
    @ObservationIgnored private var didLoadTrending = false
    @ObservationIgnored private let client: BiliClient

    init(client: BiliClient) {
        self.client = client
    }

    func loadTrendingIfNeeded() async {
        guard !didLoadTrending else { return }
        didLoadTrending = true
        do {
            trending = try await client.trendingKeywords(limit: 30)
        } catch {
            // 热搜失败不阻塞搜索。
            trending = []
        }
    }

    func loadSuggestions(for term: String) async {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }
        do {
            let values = try await client.suggestions(term: trimmed)
            guard !Task.isCancelled else { return }
            suggestions = Array(values.prefix(8))
        } catch {
            suggestions = []
        }
    }

    func submit(_ term: String) async {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentQuery = trimmed
        page = 0
        totalPages = 0
        results = []
        phase = .loading
        await loadPage(reset: true)
    }

    func selectSuggestion(_ suggestion: String) {
        suggestions = []
        Task { await submit(suggestion) }
    }

    func changeOrder(_ newOrder: SearchOrder) async {
        guard newOrder != order else { return }
        order = newOrder
        guard !currentQuery.isEmpty else { return }
        await submit(currentQuery)
    }

    func loadMoreIfNeeded(current card: VideoCard) async {
        guard phase == .loaded, !isLoadingMore, page < totalPages else { return }
        guard results.suffix(4).contains(where: { $0.id == card.id }) else { return }
        await loadPage(reset: false)
    }

    func clearResults() {
        results = []
        suggestions = []
        phase = .idle
        totalResults = 0
    }

    private func loadPage(reset: Bool) async {
        if reset {
            page = 1
            isLoadingMore = false
        } else {
            isLoadingMore = true
            page += 1
        }

        do {
            let result = try await client.searchVideos(
                keyword: currentQuery,
                page: page,
                order: order
            )
            totalPages = result.totalPages
            totalResults = result.totalResults
            if reset {
                results = result.videos
            } else {
                let existing = Set(results.map(\.id))
                results.append(contentsOf: result.videos.filter { !existing.contains($0.id) })
            }
            phase = result.videos.isEmpty && reset ? .failed("没有找到相关视频") : .loaded
        } catch is CancellationError {
            return
        } catch {
            if !reset { page -= 1 }
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
        isLoadingMore = false
    }
}
