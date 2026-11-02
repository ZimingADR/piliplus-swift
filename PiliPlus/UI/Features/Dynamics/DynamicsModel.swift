import Foundation
import Observation

/// 动态信息流模型。
@MainActor
@Observable
final class DynamicsModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case requiresLogin
    }

    private(set) var items: [DynamicItem] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false

    @ObservationIgnored private let client: BiliClient
    @ObservationIgnored private let account: AccountStore
    @ObservationIgnored private var offset = ""
    @ObservationIgnored private var hasMore = true

    init(client: BiliClient, account: AccountStore) {
        self.client = client
        self.account = account
    }

    func loadInitial(force: Bool = false) async {
        if !force, phase == .loaded { return }
        guard account.isLoggedIn else {
            phase = .requiresLogin
            return
        }

        phase = .loading
        offset = ""
        hasMore = true
        do {
            let page = try await client.dynamicsFeed(offset: nil)
            items = page.items
            offset = page.offset
            hasMore = page.hasMore
            phase = .loaded
        } catch {
            if Cancellation.isCancellation(error) { return }
            let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = message.contains("登录") ? .requiresLogin : .failed(message)
        }
    }

    func loadMoreIfNeeded(current item: DynamicItem) async {
        guard phase == .loaded, !isLoadingMore, hasMore else { return }
        guard items.suffix(3).contains(where: { $0.id == item.id }) else { return }

        isLoadingMore = true
        do {
            let page = try await client.dynamicsFeed(offset: offset)
            let existing = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            offset = page.offset
            hasMore = page.hasMore
        } catch {
            // 滚动加载失败时停止本次追加，等待下次触发。
        }
        isLoadingMore = false
    }
}
