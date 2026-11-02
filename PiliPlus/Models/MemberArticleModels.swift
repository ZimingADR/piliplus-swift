import Foundation

/// UP 主专栏条目。
struct MemberArticle: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let coverURL: URL?
    let publishedAt: Date?
    let viewCount: Int
}

struct SpaceArticlesResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Stats: Decodable, Sendable {
            let view: FlexInt?
        }

        struct Item: Decodable, Sendable {
            let id: FlexInt?
            let title: String?
            let cover: String?
            let publishTime: FlexInt?
            let stats: Stats?

            enum CodingKeys: String, CodingKey {
                case id, title, cover, stats
                case publishTime = "publish_time"
            }
        }

        struct Page: Decodable, Sendable {
            let count: FlexInt?
            let pn: FlexInt?
            let ps: FlexInt?
        }

        let articles: [Item]?
        let page: Page?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
