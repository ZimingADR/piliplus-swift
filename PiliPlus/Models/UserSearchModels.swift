import Foundation

/// 用户搜索结果。
struct UserSearchItem: Identifiable, Hashable, Sendable {
    let mid: Int
    let name: String
    let faceURL: URL?
    let sign: String
    let level: Int
    let fans: Int
    let videoCount: Int

    var id: Int { mid }
}

struct UserSearchResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let mid: FlexInt?
            let uname: String?
            let upic: String?
            let usign: String?
            let level: FlexInt?
            let fans: FlexInt?
            let videos: FlexInt?
        }

        let result: [Item]?
        let numResults: FlexInt?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
