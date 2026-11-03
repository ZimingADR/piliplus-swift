import Foundation

struct MemberBangumi: Identifiable, Hashable, Sendable {
    let seasonID: Int
    let title: String
    let coverURL: URL?
    let newEp: String
    let badge: String?

    var id: Int { seasonID }
}

struct SpaceBangumiResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct NewEp: Decodable, Sendable {
            let indexShow: String?

            enum CodingKeys: String, CodingKey {
                case indexShow = "index_show"
            }
        }

        struct Item: Decodable, Sendable {
            let seasonID: FlexInt?
            let title: String?
            let cover: String?
            let newEp: NewEp?
            let badge: String?

            enum CodingKeys: String, CodingKey {
                case title, cover, badge
                case seasonID = "season_id"
                case newEp = "new_ep"
            }
        }

        let list: [Item]?
        let total: FlexInt?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
