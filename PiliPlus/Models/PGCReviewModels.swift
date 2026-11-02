import Foundation

/// 番剧长评。
struct PGCReviewItem: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let content: String
    let authorName: String
    let avatarURL: URL?
    let score: Int
    let likes: Int
    let timeText: String
}

struct PGCReviewsResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Author: Decodable, Sendable {
            let uname: String?
            let avatar: String?
            let mid: FlexInt?
        }

        struct Stat: Decodable, Sendable {
            let likes: FlexInt?
        }

        struct Item: Decodable, Sendable {
            let reviewID: FlexInt?
            let title: String?
            let content: String?
            let score: FlexInt?
            let author: Author?
            let stat: Stat?
            let pushTimeStr: String?

            enum CodingKeys: String, CodingKey {
                case title, content, score, author, stat
                case reviewID = "review_id"
                case pushTimeStr = "push_time_str"
            }
        }

        let list: [Item]?
        let next: String?
        let count: FlexInt?
        let total: FlexInt?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
