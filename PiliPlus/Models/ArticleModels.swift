import Foundation

struct ArticleDetail: Sendable {
    let id: Int
    let title: String
    let authorName: String
    let authorFaceURL: URL?
    let publishDate: Date?
    let contentHTML: String
    let coverURL: URL?
    let viewCount: Int
    let likeCount: Int

    var fallbackText: String {
        contentHTML.isEmpty ? "这篇专栏暂时无法获取正文，请稍后重试或前往网页端阅读。" : ""
    }
}

struct ArticleViewResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Author: Decodable, Sendable {
            let mid: Int?
            let name: String?
            let face: String?
        }

        struct Stats: Decodable, Sendable {
            let view: FlexInt?
            let like: FlexInt?
            let favorite: FlexInt?
            let coin: FlexInt?
        }

        let id: FlexInt?
        let title: String?
        let content: String?
        let publishTime: FlexInt?
        let author: Author?
        let stats: Stats?
        let bannerURL: String?

        enum CodingKeys: String, CodingKey {
            case id, title, content, author, stats
            case publishTime = "publish_time"
            case bannerURL = "banner_url"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}
