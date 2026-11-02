import Foundation

/// 番剧（PGC）接口：索引、季详情与播放地址。
extension BiliClient {
    func pgcSeason(seasonID: Int) async throws -> PGCSeason {
        let payload: PGCSeasonResponse.Payload = try await object(
            PGCSeasonResponse.Payload.self,
            path: "/pgc/view/web/season",
            query: ["season_id": String(seasonID)],
            signed: false
        )
        guard let season = payload.domainModel() else {
            throw BiliAPIError(code: -10, message: "番剧信息为空")
        }
        return season
    }

    func pgcIndex(
        page: Int,
        seasonType: Int = 1,
        year: String = "-1",
        area: String = "-1"
    ) async throws -> PGCIndexPage {
        let payload: PGCIndexResponse.Payload = try await object(
            PGCIndexResponse.Payload.self,
            path: "/pgc/season/index/result",
            query: [
                "st": "1",
                "order": "3",
                "season_type": String(seasonType),
                "page": String(max(1, page)),
                "pagesize": "20",
                "type": "1",
                "area": area,
                "year": year,
                "style": "-1",
            ],
            signed: false
        )
        return payload.domainPage
    }

    /// 番剧播放地址：优先 web v2，失败回退旧版 web playurl。
    func pgcPlayURL(
        episode: PGCEpisode,
        seasonID: Int,
        quality: Int
    ) async throws -> PlayURLResult {
        var query: [String: String] = [
            "ep_id": String(episode.id),
            "season_id": String(seasonID),
            "qn": String(quality),
            "fnval": "4048",
            "fnver": "0",
            "fourk": "1",
        ]
        if let cid = episode.cid, cid > 0 {
            query["cid"] = String(cid)
        }
        if !episode.bvid.isEmpty {
            query["bvid"] = episode.bvid
        }

        do {
            let payload: PlayURLResponse.Payload = try await object(
                PlayURLResponse.Payload.self,
                path: "/pgc/player/web/v2/playurl",
                query: query,
                signed: false
            )
            if let result = payload.result() {
                return result
            }
        } catch {
            // 落到旧版接口。
        }

        let payload: PlayURLResponse.Payload = try await object(
            PlayURLResponse.Payload.self,
            path: "/pgc/player/web/playurl",
            query: query,
            signed: false
        )
        guard let result = payload.result() else {
            throw BiliAPIError(code: -12, message: "番剧播放地址为空")
        }
        return result
    }
}
