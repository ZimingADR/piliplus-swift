import Foundation

struct SpaceLikeArcResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let title: String?
            let cover: String?
            let param: String?
            let duration: FlexInt?
            let play: FlexInt?
            let danmaku: FlexInt?
            let ctime: FlexInt?
        }

        let count: FlexInt?
        let item: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
