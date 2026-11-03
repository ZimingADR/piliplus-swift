import Foundation

/// 排行榜周期。
enum RankPeriod: String, CaseIterable, Identifiable, Sendable {
    case all
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "三日榜"
        case .day: "日榜"
        case .week: "周榜"
        case .month: "月榜"
        }
    }
}

/// 排行榜分区（rid）。
struct RankRegion: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String

    static let all: [RankRegion] = [
        RankRegion(id: 0, title: "全站"),
        RankRegion(id: 1, title: "动画"),
        RankRegion(id: 3, title: "音乐"),
        RankRegion(id: 4, title: "游戏"),
        RankRegion(id: 5, title: "娱乐"),
        RankRegion(id: 36, title: "知识"),
        RankRegion(id: 119, title: "鬼畜"),
        RankRegion(id: 129, title: "舞蹈"),
        RankRegion(id: 155, title: "时尚"),
        RankRegion(id: 160, title: "生活"),
        RankRegion(id: 181, title: "影视"),
        RankRegion(id: 188, title: "科技"),
    ]
}
