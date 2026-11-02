import Foundation

/// 每周必看系列。
struct PopularSeries: Identifiable, Hashable, Sendable {
    let number: Int
    let subject: String

    var id: Int { number }
}

struct PopularSeriesListResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let number: FlexInt?
            let subject: String?
        }

        let list: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct PopularSeriesResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let list: [PreciousResponse.Payload.Item]?
        let subject: String?
        let number: FlexInt?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
