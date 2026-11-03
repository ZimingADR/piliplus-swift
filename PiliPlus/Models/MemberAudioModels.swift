import Foundation

struct SpaceAudioResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Statistic: Decodable, Sendable {
            let play: FlexInt?
            let comment: FlexInt?
        }

        struct Item: Decodable, Sendable {
            let id: FlexInt?
            let uid: FlexInt?
            let title: String?
            let cover: String?
            let aid: FlexInt?
            let bvid: String?
            let cid: FlexInt?
            let ctime: FlexInt?
            let statistic: Statistic?
        }

        let totalSize: FlexInt?
        let data: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
