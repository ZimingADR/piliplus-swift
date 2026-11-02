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
    let pgcSeason: PGCSeason?
    let pgcEpisode: PGCEpisode?
    let offlineItem: DownloadItem?

    init(card: VideoCard) {
        bvid = card.bvid
        aid = card.aid
        cid = card.cid
        self.card = card
        pgcSeason = nil
        pgcEpisode = nil
        offlineItem = nil
    }

    init(bvid: String, aid: Int?, cid: Int?) {
        self.bvid = bvid
        self.aid = aid
        self.cid = cid
        card = nil
        pgcSeason = nil
        pgcEpisode = nil
        offlineItem = nil
    }

    init(pgcSeason: PGCSeason, episode: PGCEpisode) {
        bvid = episode.bvid
        aid = episode.aid
        cid = episode.cid
        card = nil
        self.pgcSeason = pgcSeason
        pgcEpisode = episode
        offlineItem = nil
    }

    init(downloaded item: DownloadItem) {
        bvid = item.bvid
        aid = item.aid
        cid = item.cid
        card = nil
        pgcSeason = nil
        pgcEpisode = nil
        offlineItem = item
    }

    static func == (lhs: PlayerRequest, rhs: PlayerRequest) -> Bool {
        lhs.id == rhs.id
    }
}
