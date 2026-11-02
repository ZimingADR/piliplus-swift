import Foundation
import Observation

/// 热门 / 排行榜列表模型。
@MainActor
@Observable
final class VideoFeedModel {
    enum Kind: String, Sendable {
        case hot
        case rank

        var title: String {
            switch self {
            case .hot: "热门"
            case .rank: "排行榜"
            }
        }
    }

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let kind: Kind
    private(set) var videos: [VideoCard] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false

    @ObservationIgnored private let client: BiliClient
    @ObservationIgnored private var page = 0
    @ObservationIgnored private var reachedEnd = false

    init(kind: Kind, client: BiliClient) {
        self.kind = kind
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
        guard kind == .hot,
              phase == .loaded,
              !isLoadingMore,
              !reachedEnd else { return }
        guard videos.suffix(4).contains(where: { $0.id == card.id }) else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        if reset {
            page = 0
            reachedEnd = false
            phase = .loading
        } else {
            isLoadingMore = true
        }

        do {
            let items: [VideoCard]
            switch kind {
            case .hot:
                let next = page + 1
                items = try await client.hotVideos(page: next, size: 20)
                page = next
                reachedEnd = items.isEmpty
            case .rank:
                items = try await client.rankedVideos()
                reachedEnd = true
            }

            if reset {
                videos = items
            } else {
                let existing = Set(videos.map(\.id))
                videos.append(contentsOf: items.filter { !existing.contains($0.id) })
            }
            phase = .loaded
        } catch {
            if Cancellation.isCancellation(error) {
                isLoadingMore = false
                return
            }
            if reset {
                phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
        isLoadingMore = false
    }
}

/// 稍后再看列表模型。
@MainActor
@Observable
final class LaterModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case requiresLogin
    }

    private(set) var items: [LaterVideo] = []
    private(set) var phase: Phase = .idle

    @ObservationIgnored private let client: BiliClient
    @ObservationIgnored private let account: AccountStore

    init(client: BiliClient, account: AccountStore) {
        self.client = client
        self.account = account
    }

    func loadIfNeeded(force: Bool = false) async {
        if !force, phase == .loaded { return }
        guard account.isLoggedIn else {
            phase = .requiresLogin
            return
        }
        phase = .loading
        do {
            items = try await client.watchLater()
            phase = .loaded
        } catch {
            let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = message.contains("登录") ? .requiresLogin : .failed(message)
        }
    }
}

/// UP 主空间模型。
@MainActor
@Observable
final class MemberViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let mid: Int
    private(set) var profile: MemberProfile?
    private(set) var videos: [VideoCard] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false
    private(set) var order = "pubdate"
    private(set) var totalCount = 0

    @ObservationIgnored private var page = 0
    @ObservationIgnored private var totalPages = 1
    @ObservationIgnored private let client: BiliClient

    init(mid: Int, client: BiliClient) {
        self.mid = mid
        self.client = client
    }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await refresh()
    }

    func refresh() async {
        phase = .loading
        page = 0
        do {
            async let profileTask = client.memberInfo(mid: mid)
            async let videosTask = client.memberVideos(mid: mid, page: 1, order: order)
            let (profile, pageData) = try await (profileTask, videosTask)
            self.profile = profile
            videos = pageData.videos
            page = 1
            totalPages = pageData.totalPages
            totalCount = pageData.totalCount
            phase = .loaded
        } catch {
            if Cancellation.isCancellation(error) { return }
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func changeOrder(_ newOrder: String) async {
        guard newOrder != order else { return }
        order = newOrder
        await refresh()
    }

    func loadMoreIfNeeded(current card: VideoCard) async {
        guard phase == .loaded, !isLoadingMore, page < totalPages else { return }
        guard videos.suffix(4).contains(where: { $0.id == card.id }) else { return }
        isLoadingMore = true
        do {
            let next = page + 1
            let result = try await client.memberVideos(mid: mid, page: next, order: order)
            let existing = Set(videos.map(\.id))
            videos.append(contentsOf: result.videos.filter { !existing.contains($0.id) })
            page = next
        } catch {
            // 滚动加载失败静默重试。
        }
        isLoadingMore = false
    }
}
