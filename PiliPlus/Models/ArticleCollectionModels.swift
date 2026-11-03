import Foundation

struct ArticleCollection: Sendable {
    let id: Int
    let name: String
    let imageURL: URL?
    let read: Int
    let articleCount: Int
}

struct ArticleCollectionItem: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let summary: String
    let coverURL: URL?
    let viewCount: Int
}

struct ArticleCollectionResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Info: Decodable, Sendable {
            let id: FlexInt?
            let name: String?
            let imageURL: String?
            let read: FlexInt?
            let articlesCount: FlexInt?

            enum CodingKeys: String, CodingKey {
                case id, name, read
                case imageURL = "image_url"
                case articlesCount = "articles_count"
            }
        }

        struct Stats: Decodable, Sendable {
            let view: FlexInt?
        }

        struct Item: Decodable, Sendable {
            let id: FlexInt?
            let title: String?
            let summary: String?
            let imageURLs: [String]?
            let stats: Stats?

            enum CodingKeys: String, CodingKey {
                case id, title, summary, stats
                case imageURLs = "image_urls"
            }
        }

        let list: Info?
        let articles: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
