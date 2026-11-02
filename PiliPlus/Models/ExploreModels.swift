import Foundation

// MARK: - 热门 / 排行榜

struct VideoListResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let list: [RecommendFeedResponse.Item]?
        let noMore: Bool?
        let note: String?

        enum CodingKeys: String, CodingKey {
            case list, note
            case noMore = "no_more"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

// MARK: - 稍后再看

struct LaterResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let count: Int?
        let list: [Item]?
    }

    struct Item: Decodable, Sendable {
        let aid: Int?
        let bvid: String?
        let cid: Int?
        let pic: String?
        let title: String?
        let duration: FlexInt?
        let progress: FlexInt?
        let pubdate: FlexInt?
        let owner: Owner?
        let stat: Stat?

        struct Owner: Decodable, Sendable {
            let mid: Int?
            let name: String?
            let face: String?
        }

        struct Stat: Decodable, Sendable {
            let view: FlexInt?
            let danmaku: FlexInt?
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct LaterVideo: Identifiable, Sendable {
    let card: VideoCard
    /// 已播放秒数；0 表示未开始，-1 表示已看完。
    let progress: Int

    var id: String { card.id }

    var progressFraction: Double {
        guard progress > 0, card.duration > 0 else { return 0 }
        return min(Double(progress) / Double(card.duration), 1)
    }
}

// MARK: - UP 主空间

struct MemberInfoResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct VIP: Decodable, Sendable {
            let status: FlexInt?
            let type: FlexInt?
        }

        let mid: Int?
        let name: String?
        let face: String?
        let sign: String?
        let level: FlexInt?
        let vip: VIP?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct MemberArchiveResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct List: Decodable, Sendable {
            let vlist: [Item]?
        }

        struct Page: Decodable, Sendable {
            let pn: FlexInt?
            let ps: FlexInt?
            let count: FlexInt?
        }

        let list: List?
        let page: Page?
    }

    struct Item: Decodable, Sendable {
        let aid: Int?
        let bvid: String?
        let cid: Int?
        let pic: String?
        let title: String?
        let created: FlexInt?
        let length: String?
        let play: FlexInt?
        let description: String?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct MemberProfile: Sendable, Equatable {
    let mid: Int
    let name: String
    let faceURL: URL?
    let sign: String
    let level: Int
    let isVip: Bool
    let following: Int
    let follower: Int
}

struct MemberVideoPage: Sendable {
    let videos: [VideoCard]
    let page: Int
    let totalPages: Int
    let totalCount: Int
}
