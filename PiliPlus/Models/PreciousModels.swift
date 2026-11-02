import Foundation

/// 「入站必刷」接口模型。
struct PreciousResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Owner: Decodable, Sendable {
            let name: String?
            let face: String?
        }

        struct Stat: Decodable, Sendable {
            let view: FlexInt?
            let danmaku: FlexInt?
        }

        struct Item: Decodable, Sendable {
            let aid: FlexInt?
            let bvid: String?
            let title: String?
            let pic: String?
            let duration: FlexInt?
            let owner: Owner?
            let stat: Stat?
        }

        struct Page: Decodable, Sendable {
            let pn: FlexInt?
            let ps: FlexInt?
            let count: FlexInt?
        }

        let list: [Item]?
        let page: Page?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
