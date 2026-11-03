import Foundation

extension BiliClient {
    /// UP 主专栏列表：优先 WBI 接口，失败回退旧接口。
    func memberArticles(mid: Int, page: Int) async throws -> ([MemberArticle], Bool) {
        let query = [
            "mid": String(mid),
            "pn": String(max(1, page)),
            "ps": "20",
            "sort": "publish_time",
        ]

        let payload: SpaceArticlesResponse.Payload
        do {
            payload = try await object(
                SpaceArticlesResponse.Payload.self,
                path: "/x/space/wbi/article",
                query: query,
                signed: true
            )
        } catch {
            payload = try await object(
                SpaceArticlesResponse.Payload.self,
                path: "/x/space/article",
                query: query,
                signed: false
            )
        }

        let articles: [MemberArticle] = (payload.articles ?? []).compactMap { item in
            guard let id = item.id?.value else { return nil }
            return MemberArticle(
                id: id,
                title: (item.title ?? "无标题").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.cover),
                publishedAt: item.publishTime.map {
                    Date(timeIntervalSince1970: TimeInterval($0.value))
                },
                viewCount: item.stats?.view?.value ?? 0
            )
        }

        let pageSize = payload.page?.ps?.value ?? 20
        let total = payload.page?.count?.value ?? articles.count
        let current = payload.page?.pn?.value ?? page
        return (articles, current * pageSize < total)
    }

    /// UP 主合集/系列列表。
    func memberCollections(mid: Int, page: Int) async throws -> ([MemberCollection], Bool) {
        let payload: SpaceCollectionsResponse.Payload = try await object(
            SpaceCollectionsResponse.Payload.self,
            path: "/x/polymer/web-space/seasons_series_list",
            query: [
                "mid": String(mid),
                "page_num": String(max(1, page)),
                "page_size": "20",
            ],
            signed: false
        )

        guard let lists = payload.itemsLists else { return ([], false) }

        var collections: [MemberCollection] = []

        for item in lists.seasonsList ?? [] {
            guard let meta = item.meta, let number = meta.seasonID?.value else { continue }
            collections.append(
                MemberCollection(
                    number: number,
                    title: (meta.name ?? "合集").removingHTMLTags,
                    coverURL: RecommendFeedResponse.Item.httpsURL(meta.cover),
                    count: meta.total?.value ?? 0,
                    isSeason: true
                )
            )
        }

        for item in lists.seriesList ?? [] {
            guard let meta = item.meta, let number = meta.seriesID?.value else { continue }
            collections.append(
                MemberCollection(
                    number: number,
                    title: (meta.name ?? "系列").removingHTMLTags,
                    coverURL: RecommendFeedResponse.Item.httpsURL(meta.cover),
                    count: meta.total?.value ?? 0,
                    isSeason: false
                )
            )
        }

        let total = lists.page?.total?.value ?? collections.count
        return (collections, page * 20 < total)
    }

    /// UP 主最近点赞的视频。
    func memberLikedVideos(mid: Int, page: Int) async throws -> ([VideoCard], Bool) {
        let payload: SpaceLikeArcResponse.Payload = try await object(
            SpaceLikeArcResponse.Payload.self,
            path: "/x/v2/space/likearc",
            query: [
                "pn": String(max(1, page)),
                "ps": "20",
                "vmid": String(mid),
            ],
            signed: false
        )

        let cards: [VideoCard] = (payload.item ?? []).compactMap { item in
            let param = item.param ?? ""
            let bvid = param.hasPrefix("BV") ? param : ""
            let aid = bvid.isEmpty ? Int(param) : nil
            guard !bvid.isEmpty || aid != nil else { return nil }

            return VideoCard(
                bvid: bvid,
                aid: aid,
                cid: nil,
                title: (item.title ?? "视频").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.cover),
                ownerName: "",
                ownerFaceURL: nil,
                duration: item.duration?.value ?? 0,
                viewCount: item.play?.value ?? 0,
                danmakuCount: item.danmaku?.value ?? 0,
                publishedAt: item.ctime.map {
                    Date(timeIntervalSince1970: TimeInterval($0.value))
                }
            )
        }

        let total = payload.count?.value ?? cards.count
        return (cards, page * 20 < total)
    }

    /// UP 主音频（歌曲）列表。
    func memberAudios(mid: Int, page: Int) async throws -> ([VideoCard], Bool) {
        let payload: SpaceAudioResponse.Payload = try await object(
            SpaceAudioResponse.Payload.self,
            path: "/audio/music-service/web/song/upper",
            query: [
                "mid": String(mid),
                "pn": String(max(1, page)),
                "ps": "20",
            ],
            signed: false
        )

        let cards: [VideoCard] = (payload.data ?? []).compactMap { item in
            guard let bvid = item.bvid, !bvid.isEmpty else { return nil }
            return VideoCard(
                bvid: bvid,
                aid: item.aid?.value,
                cid: item.cid?.value,
                title: (item.title ?? "音频").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.cover),
                ownerName: "音频",
                ownerFaceURL: nil,
                duration: 0,
                viewCount: item.statistic?.play?.value ?? 0,
                danmakuCount: item.statistic?.comment?.value ?? 0,
                publishedAt: item.ctime.map {
                    Date(timeIntervalSince1970: TimeInterval($0.value))
                }
            )
        }

        let total = payload.totalSize?.value ?? cards.count
        return (cards, page * 20 < total)
    }

    /// UP 主追番（type=1 番剧）。
    func memberBangumi(mid: Int, page: Int) async throws -> ([MemberBangumi], Bool) {
        let payload: SpaceBangumiResponse.Payload = try await object(
            SpaceBangumiResponse.Payload.self,
            path: "/x/space/bangumi/follow/list",
            query: [
                "type": "1",
                "follow_status": "0",
                "vmid": String(mid),
                "pn": String(max(1, page)),
                "ps": "15",
            ],
            signed: false
        )

        let items: [MemberBangumi] = (payload.list ?? []).compactMap { item in
            guard let seasonID = item.seasonID?.value, seasonID > 0 else { return nil }
            return MemberBangumi(
                seasonID: seasonID,
                title: (item.title ?? "番剧").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.cover),
                newEp: item.newEp?.indexShow ?? "",
                badge: item.badge
            )
        }

        let total = payload.total?.value ?? items.count
        return (items, page * 15 < total)
    }
}
