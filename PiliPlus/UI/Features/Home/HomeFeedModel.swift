import Observation
import SwiftUI

/// 首页推荐流状态。
@MainActor
@Observable
final class HomeFeedModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var videos: [VideoCard] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false

    @ObservationIgnored private var freshIndex = 0
    @ObservationIgnored private var seenIDs = Set<String>()
    @ObservationIgnored private let client: BiliClient

    init(client: BiliClient) {
        self.client = client
    }

    func loadInitialIfNeeded() async {
        guard phase == .idle else { return }
        await load(reset: true)
    }

    func refresh() async {
        await load(reset: true)
    }

    func loadMoreIfNeeded(current card: VideoCard) async {
        guard phase == .loaded, !isLoadingMore else { return }
        guard videos.suffix(4).contains(where: { $0.id == card.id }) else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        if reset {
            freshIndex = 0
            seenIDs = []
            phase = .loading
        } else {
            isLoadingMore = true
        }

        do {
            var attempts = 0
            while attempts < 3 {
                let page = try await client.recommend(freshIndex: freshIndex, pageSize: 12)
                freshIndex += 1
                let newItems = page.filter { seenIDs.insert($0.id).inserted }

                if !newItems.isEmpty {
                    if reset {
                        videos = newItems
                    } else {
                        videos.append(contentsOf: newItems)
                    }
                    break
                }

                attempts += 1
                // 首页刷新时即使返回空也停止；翻页则最多补拉 3 次，避免“上拉无反应”。
                if reset { break }
            }
            phase = .loaded
        } catch is CancellationError {
            isLoadingMore = false
            return
        } catch {
            phase = .failed(Self.message(for: error))
        }
        isLoadingMore = false
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
