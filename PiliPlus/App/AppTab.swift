import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case search
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "推荐"
        case .search: "搜索"
        case .history: "历史"
        case .settings: "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: "house.fill"
        case .search: "magnifyingglass"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape.fill"
        }
    }
}

/// 一次播放请求。由任意列表发起，`RootView` 统一用全屏 cover 呈现。
struct PlayerRequest: Identifiable, Equatable {
    let id = UUID()
    let bvid: String
    let aid: Int?
    let cid: Int?
    let card: VideoCard?

    init(card: VideoCard) {
        bvid = card.bvid
        aid = card.aid
        cid = card.cid
        self.card = card
    }

    init(bvid: String, aid: Int?, cid: Int?) {
        self.bvid = bvid
        self.aid = aid
        self.cid = cid
        card = nil
    }

    static func == (lhs: PlayerRequest, rhs: PlayerRequest) -> Bool {
        lhs.id == rhs.id
    }
}
