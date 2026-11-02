import Foundation

extension BiliClient {
    /// 入站必刷（分页）。
    func preciousVideos(page: Int) async throws -> ([VideoCard], Bool) {
        let payload: PreciousResponse.Payload = try await object(
            PreciousResponse.Payload.self,
            path: "/x/web-interface/popular/precious",
            query: [
                "page_size": "30",
                "page": String(max(1, page)),
            ],
            signed: false
        )

        let cards: [VideoCard] = (payload.list ?? []).compactMap { item in
            guard let bvid = item.bvid, !bvid.isEmpty else { return nil }
            return VideoCard(
                bvid: bvid,
                aid: item.aid?.value,
                cid: nil,
                title: (item.title ?? "视频").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.pic),
                ownerName: item.owner?.name ?? "UP 主",
                ownerFaceURL: RecommendFeedResponse.Item.httpsURL(item.owner?.face),
                duration: item.duration?.value ?? 0,
                viewCount: item.stat?.view?.value ?? 0,
                danmakuCount: item.stat?.danmaku?.value ?? 0,
                publishedAt: nil
            )
        }

        let pageSize = payload.page?.ps?.value ?? 30
        let total = payload.page?.count?.value ?? cards.count
        let current = payload.page?.pn?.value ?? page
        return (cards, current * pageSize < total)
    }
}
