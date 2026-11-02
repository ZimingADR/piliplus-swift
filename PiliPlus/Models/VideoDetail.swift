import Foundation

/// 视频详情（`/x/web-interface/wbi/view`）。
struct VideoDetail: Decodable, Sendable {
    struct Owner: Decodable, Sendable {
        let mid: Int?
        let name: String?
        let face: String?
    }

    struct Stat: Decodable, Sendable {
        let view: FlexInt?
        let danmaku: FlexInt?
        let reply: FlexInt?
        let favorite: FlexInt?
        let coin: FlexInt?
        let share: FlexInt?
        let like: FlexInt?
    }

    struct Page: Decodable, Sendable, Identifiable {
        let cid: Int
        let page: Int
        let part: String?
        let duration: FlexInt?

        var id: Int { cid }

        var title: String {
            let name = (part ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "P\(page)" : "P\(page) · \(name)"
        }

        var durationText: String {
            VideoCard.formatDuration(duration?.value ?? 0)
        }
    }

    let bvid: String
    let aid: Int
    let cid: Int?
    let title: String
    let pic: String?
    let desc: String?
    let duration: FlexInt?
    let pubdate: Int?
    let tname: String?
    let owner: Owner?
    let stat: Stat?
    let pages: [Page]?

    var coverURL: URL? {
        RecommendFeedResponse.Item.httpsURL(pic)
    }

    var displayPages: [Page] {
        (pages ?? []).sorted { $0.page < $1.page }
    }

    var publishedAt: Date? {
        pubdate.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    var durationSeconds: Double {
        if let duration = duration?.value, duration > 0 {
            return Double(duration)
        }
        return displayPages.reduce(0) { $0 + Double($1.duration?.value ?? 0) }
    }
}

/// `/x/web-interface/nav`（未登录也会返回 `wbi_img`，用于刷新签名密钥）。
struct NavResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct WbiImage: Decodable, Sendable {
            let imgUrl: String?
            let subUrl: String?

            enum CodingKeys: String, CodingKey {
                case imgUrl = "img_url"
                case subUrl = "sub_url"
            }
        }

        let wbiImg: WbiImage?

        enum CodingKeys: String, CodingKey {
            case wbiImg = "wbi_img"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}
