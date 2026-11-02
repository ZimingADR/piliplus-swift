import Foundation

/// 首页推荐流 / 搜索结果共用的视频卡片模型。
struct VideoCard: Identifiable, Hashable, Sendable {
    let bvid: String
    let aid: Int?
    let cid: Int?
    let title: String
    let coverURL: URL?
    let ownerName: String
    let ownerFaceURL: URL?
    /// 视频时长，单位秒。
    let duration: Int
    let viewCount: Int
    let danmakuCount: Int
    let publishedAt: Date?

    var id: String {
        bvid.isEmpty ? "av\(aid ?? 0)" : bvid
    }

    var durationText: String {
        Self.formatDuration(duration)
    }

    var viewText: String {
        Self.formatCount(viewCount)
    }

    static func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "--:--" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func formatCount(_ count: Int) -> String {
        if count < 0 {
            return "0"
        }
        if count < 10_000 {
            return "\(count)"
        }
        if count < 100_000_000 {
            let value = Double(count) / 10_000
            return value >= 10
                ? String(format: "%.0f万", value)
                : String(format: "%.1f万", value)
        }
        return String(format: "%.1f亿", Double(count) / 100_000_000)
    }
}

// MARK: - 推荐流

struct RecommendFeedResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let item: [Item]?
    }

    struct Item: Decodable, Sendable {
        let bvid: String?
        let cid: Int?
        let goto: String?
        let pic: String?
        let title: String?
        let duration: FlexInt?
        let pubdate: Int?
        let owner: Owner?
        let stat: Stat?

        struct Owner: Decodable, Sendable {
            let mid: Int?
            let name: String?
            let face: String?
        }

        struct Stat: Decodable, Sendable {
            let view: FlexInt?
            let danmaku: FlexInt?
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension RecommendFeedResponse.Item {
    /// 过滤直播、广告、课程等非 `av` 卡片，并转换成 UI 模型。
    func videoCard() -> VideoCard? {
        guard let bvid, !bvid.isEmpty else { return nil }
        guard goto == nil || goto == "av" else { return nil }

        return VideoCard(
            bvid: bvid,
            aid: nil,
            cid: Self.normalizeCID(cid),
            title: (title ?? "无标题").removingHTMLTags,
            coverURL: Self.httpsURL(pic),
            ownerName: owner?.name ?? "未知 UP 主",
            ownerFaceURL: Self.httpsURL(owner?.face),
            duration: duration?.value ?? 0,
            viewCount: stat?.view?.value ?? 0,
            danmakuCount: stat?.danmaku?.value ?? 0,
            publishedAt: pubdate.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func normalizeCID(_ cid: Int?) -> Int? {
        guard let cid, cid > 0 else { return nil }
        return cid
    }

    static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        }
        return URL(string: raw)
    }
}

// MARK: - 搜索结果

struct SearchTypeResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let page: Int?
        let pagesize: Int?
        let numResults: FlexInt?
        let numPages: FlexInt?
        let result: [Item]?
    }

    struct Item: Decodable, Sendable {
        let type: String?
        let id: FlexInt?
        let bvid: String?
        let title: String?
        let author: String?
        let pic: String?
        let play: FlexInt?
        let danmaku: FlexInt?
        let duration: String?
        let pubdate: FlexInt?
        let senddate: FlexInt?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension SearchTypeResponse.Item {
    func videoCard() -> VideoCard? {
        if let type, type != "video" { return nil }
        let bvid = bvid ?? ""
        let aid = id?.value
        guard !bvid.isEmpty || (aid ?? 0) > 0 else { return nil }

        return VideoCard(
            bvid: bvid,
            aid: aid,
            cid: nil,
            title: (title ?? "无标题").removingHTMLTags,
            coverURL: RecommendFeedResponse.Item.httpsURL(pic),
            ownerName: author ?? "未知 UP 主",
            ownerFaceURL: nil,
            duration: Self.parseDuration(duration),
            viewCount: play?.value ?? 0,
            danmakuCount: danmaku?.value ?? 0,
            publishedAt: (pubdate ?? senddate).map { Date(timeIntervalSince1970: TimeInterval($0.value)) }
        )
    }

    /// 搜索结果里的时长是 `mm:ss` / `hh:mm:ss` 字符串。
    static func parseDuration(_ raw: String?) -> Int {
        guard let raw, !raw.isEmpty else { return 0 }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return 0
        }
    }
}

// MARK: - 通用解码工具

/// B 站接口里数字字段有时是 Int、有时是 String，这里统一做宽松解码。
struct FlexInt: Decodable, Sendable, Equatable {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else if let string = try? container.decode(String.self) {
            value = Int(string) ?? 0
        } else {
            value = 0
        }
    }
}

extension Optional where Wrapped == FlexInt {
    var intValue: Int? { self?.value }
}

extension String {
    /// 去掉搜索结果标题里的 `<em class="keyword">` 等高亮标签。
    var removingHTMLTags: String {
        guard contains("<") else { return self }
        return replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
    }
}
