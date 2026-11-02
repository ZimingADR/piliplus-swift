import Foundation

extension BiliClient {
    /// 直播搜索（Web WBI 搜索，search_type=live）。
    func searchLive(keyword: String, page: Int = 1) async throws -> [LiveRoom] {
        let payload: LiveSearchResponse.Payload = try await object(
            LiveSearchResponse.Payload.self,
            path: "/x/web-interface/wbi/search/type",
            query: [
                "search_type": "live",
                "keyword": keyword,
                "page": String(max(1, page)),
                "page_size": "20",
            ],
            signed: true
        )

        return (payload.result ?? []).compactMap { item in
            guard let roomID = item.roomID?.value, roomID > 0 else { return nil }
            let online = item.online?.value ?? 0
            return LiveRoom(
                id: roomID,
                title: (item.title ?? "直播间").removingHTMLTags,
                uname: item.uname ?? "主播",
                coverURL: RecommendFeedResponse.Item.httpsURL(item.cover),
                faceURL: nil,
                areaName: item.areaName ?? "直播",
                watchedText: online > 0 ? "\(VideoCard.formatCount(online)) 人气" : ""
            )
        }
    }
}
