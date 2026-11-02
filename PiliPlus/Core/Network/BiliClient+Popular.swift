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

        let cards: [VideoCard] = (payload.list ?? []).compactMap(makeCard)

        let pageSize = payload.page?.ps?.value ?? 30
        let total = payload.page?.count?.value ?? cards.count
        let current = payload.page?.pn?.value ?? page
        return (cards, current * pageSize < total)
    }

    /// 每周必看系列列表（最新在前）。
    func popularSeriesList() async throws -> [PopularSeries] {
        let payload: PopularSeriesListResponse.Payload = try await object(
            PopularSeriesListResponse.Payload.self,
            path: "/x/web-interface/popular/series/list",
            query: [:],
            signed: false
        )

        return (payload.list ?? []).compactMap { item in
            guard let number = item.number?.value else { return nil }
            return PopularSeries(
                number: number,
                subject: item.subject ?? "第 \(number) 期"
            )
        }
    }

    /// 某一期每周必看的视频列表。
    func popularSeriesVideos(number: Int) async throws -> [VideoCard] {
        let payload: PopularSeriesResponse.Payload = try await object(
            PopularSeriesResponse.Payload.self,
            path: "/x/web-interface/popular/series/one",
            query: ["number": String(max(1, number))],
            signed: false
        )

        return (payload.list ?? []).compactMap(makeCard)
    }

    private func makeCard(from item: PreciousResponse.Payload.Item) -> VideoCard? {
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
}
