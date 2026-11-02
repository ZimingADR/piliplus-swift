import Foundation

/// SponsorBlock 跳过片段。
struct SponsorSegment: Identifiable, Sendable, Hashable {
    let id: String
    let category: String
    let start: Double
    let end: Double

    var categoryTitle: String {
        switch category {
        case "sponsor": "赞助广告"
        case "selfpromo": "自我推广"
        case "interaction": "求三连"
        case "intro": "片头"
        case "outro": "片尾"
        case "preview": "预览"
        case "music_offtopic": "非音乐片段"
        default: "片段"
        }
    }
}

/// SponsorBlock 客户端（sponsor.ajay.app）。
enum SponsorBlockService {
    private static let categories = [
        "sponsor", "selfpromo", "interaction",
        "intro", "outro", "preview", "music_offtopic",
    ]

    static func segments(bvid: String) async throws -> [SponsorSegment] {
        guard !bvid.isEmpty,
              var components = URLComponents(string: "https://sponsor.ajay.app/api/skipSegments") else {
            return []
        }
        let categoryJSON = "[" + categories.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        components.queryItems = [
            URLQueryItem(name: "videoID", value: bvid),
            URLQueryItem(name: "categories", value: categoryJSON),
            URLQueryItem(name: "actionType", value: "skip"),
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("PiliPlus/0.3 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            // 无片段时接口返回 404。
            return []
        }
        return parse(data)
    }

    /// 供单元测试使用的纯解析函数。
    static func parse(_ data: Data) -> [SponsorSegment] {
        struct Entry: Decodable {
            struct Segment: Decodable {
                let UUID: String?
                let segment: [Double]?
                let category: String?
            }

            let segments: [Segment]?
        }

        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }

        return entries
            .flatMap { $0.segments ?? [] }
            .compactMap { segment in
                guard let range = segment.segment,
                      range.count >= 2,
                      range[1] > range[0] else { return nil }
                let id = segment.UUID ?? "\(segment.category ?? "segment")-\(range[0])"
                return SponsorSegment(
                    id: id,
                    category: segment.category ?? "sponsor",
                    start: range[0],
                    end: range[1]
                )
            }
            .sorted { $0.start < $1.start }
    }
}
