import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case dynamics
    case discover
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .dynamics: "动态"
        case .discover: "发现"
        case .mine: "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .dynamics: "square.stack"
        case .discover: "square.grid.2x2"
        case .mine: "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: "house.fill"
        case .dynamics: "square.stack.fill"
        case .discover: "square.grid.2x2.fill"
        case .mine: "person.fill"
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
