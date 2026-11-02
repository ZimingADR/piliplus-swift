import Foundation

/// 应用内深链路由（供 App Intents、小组件与外部 URL 调用）。
enum DeepLinkRoute: Equatable {
    case home
    case history
    case search(keyword: String)
    case video(bvid: String, cid: Int?)

    static func parse(_ url: URL) -> DeepLinkRoute? {
        guard url.scheme?.lowercased() == "piliplus" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch url.host?.lowercased() {
        case "home":
            return .home
        case "history":
            return .history
        case "search":
            return .search(keyword: value("keyword") ?? "")
        case "video":
            guard let bvid = value("bvid"), !bvid.isEmpty else { return nil }
            return .video(bvid: bvid, cid: Int(value("cid") ?? ""))
        default:
            return nil
        }
    }

    /// 生成分享/小组件使用的深链。
    static func url(for route: DeepLinkRoute) -> URL? {
        var components = URLComponents()
        components.scheme = "piliplus"
        switch route {
        case .home:
            components.host = "home"
        case .history:
            components.host = "history"
        case .search(let keyword):
            components.host = "search"
            components.queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        case .video(let bvid, let cid):
            components.host = "video"
            var items = [URLQueryItem(name: "bvid", value: bvid)]
            if let cid {
                items.append(URLQueryItem(name: "cid", value: String(cid)))
            }
            components.queryItems = items
        }
        return components.url
    }
}
