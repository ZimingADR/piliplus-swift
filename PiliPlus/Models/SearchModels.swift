import Foundation

struct SearchPage: Sendable {
    let videos: [VideoCard]
    let page: Int
    let totalPages: Int
    let totalResults: Int

    var hasMore: Bool {
        page < totalPages && !videos.isEmpty
    }
}

enum SearchOrder: String, CaseIterable, Identifiable, Sendable {
    case relevance = "totalrank"
    case newest = "pubdate"
    case views = "click"
    case danmaku = "dm"
    case favorites = "stow"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relevance: "综合排序"
        case .newest: "最新发布"
        case .views: "最多播放"
        case .danmaku: "最多弹幕"
        case .favorites: "最多收藏"
        }
    }
}

/// 全站热搜 / 搜索发现。
struct TrendingKeyword: Identifiable, Hashable, Sendable {
    let keyword: String
    let displayName: String
    let heat: Int
    let iconURL: URL?

    var id: String { keyword }
}

struct TrendingResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let keyword: String?
            let showName: String?
            let icon: String?
            let heatScore: FlexInt?

            enum CodingKeys: String, CodingKey {
                case keyword, icon
                case showName = "show_name"
                case heatScore = "heat_score"
            }
        }

        struct Trending: Decodable, Sendable {
            let list: [Item]?
        }

        let list: [Item]?
        let trending: Trending?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension TrendingResponse {
    /// 优先使用 `data.list`，部分版本把列表放在 `data.trending.list`。
    var keywords: [TrendingKeyword] {
        let items = data?.list ?? data?.trending?.list ?? []
        return items.compactMap { item in
            guard let keyword = item.keyword, !keyword.isEmpty else { return nil }
            return TrendingKeyword(
                keyword: keyword,
                displayName: item.showName?.isEmpty == false ? item.showName! : keyword,
                heat: item.heatScore?.value ?? 0,
                iconURL: RecommendFeedResponse.Item.httpsURL(item.icon)
            )
        }
    }
}

/// 旧版热搜接口（`s.search.bilibili.com/main/hotword`）。
struct HotwordResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let keyword: String?
        let showName: String?
        let icon: String?
    }

    let code: Int
    let list: [Item]?
}

extension HotwordResponse {
    var keywords: [TrendingKeyword] {
        (list ?? []).compactMap { item in
            guard let keyword = item.keyword, !keyword.isEmpty else { return nil }
            return TrendingKeyword(
                keyword: keyword,
                displayName: item.showName?.isEmpty == false ? item.showName! : keyword,
                heat: 0,
                iconURL: RecommendFeedResponse.Item.httpsURL(item.icon)
            )
        }
    }
}

/// 输入联想。
struct SuggestResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Result: Decodable, Sendable {
            struct Tag: Decodable, Sendable {
                let value: String?
                let name: String?
            }

            let tag: [Tag]?
        }

        let result: Result?
    }

    let code: Int
    let data: Payload?
}

extension SuggestResponse.Payload {
    var suggestions: [String] {
        (result?.tag ?? []).compactMap { tag in
            let value = tag.value ?? tag.name
            guard let value, !value.isEmpty else { return nil }
            return value
        }
    }
}
