import Foundation

/// UP 主合集（合辑 season / 系列 series）。
struct MemberCollection: Identifiable, Hashable, Sendable {
    let number: Int
    let title: String
    let coverURL: URL?
    let count: Int
    let isSeason: Bool

    var id: String { "\(isSeason ? "s" : "r")-\(number)" }
}

struct SpaceCollectionsResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Page: Decodable, Sendable {
            let total: FlexInt?
        }

        struct Meta: Decodable, Sendable {
            let cover: String?
            let name: String?
            let total: FlexInt?
            let seasonID: FlexInt?
            let seriesID: FlexInt?

            enum CodingKeys: String, CodingKey {
                case cover, name, total
                case seasonID = "season_id"
                case seriesID = "series_id"
            }
        }

        struct Item: Decodable, Sendable {
            let meta: Meta?
        }

        struct ItemsLists: Decodable, Sendable {
            let page: Page?
            let seasonsList: [Item]?
            let seriesList: [Item]?

            enum CodingKeys: String, CodingKey {
                case page
                case seasonsList = "seasons_list"
                case seriesList = "series_list"
            }
        }

        let itemsLists: ItemsLists?

        enum CodingKeys: String, CodingKey {
            case itemsLists = "items_lists"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}
