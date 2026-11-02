import Foundation

/// 探索类接口：热门、排行榜、稍后再看、UP 主空间。
///
/// 这些接口都返回 `list` 结构，统一转换为 `VideoCard`，直接复用首页与搜索的卡片组件。
extension BiliClient {
    func hotVideos(page: Int, size: Int = 20) async throws -> [VideoCard] {
        let payload: VideoListResponse.Payload = try await object(
            VideoListResponse.Payload.self,
            path: "/x/web-interface/popular",
            query: [
                "pn": String(max(1, page)),
                "ps": String(max(1, min(size, 50))),
            ],
            signed: false
        )
        return (payload.list ?? []).compactMap { $0.videoCard() }
    }

    func rankedVideos(regionID: Int = 0) async throws -> [VideoCard] {
        let payload: VideoListResponse.Payload = try await object(
            VideoListResponse.Payload.self,
            path: "/x/web-interface/ranking/v2",
            query: [
                "rid": String(regionID),
                "type": "all",
            ],
            signed: false
        )
        return (payload.list ?? []).compactMap { $0.videoCard() }
    }

    /// 稍后再看（需要登录 Cookie）。
    func watchLater() async throws -> [LaterVideo] {
        let payload: LaterResponse.Payload = try await object(
            LaterResponse.Payload.self,
            path: "/x/v2/history/toview/web",
            query: [:],
            signed: false
        )
        return (payload.list ?? []).compactMap { item in
            guard let bvid = item.bvid, !bvid.isEmpty else { return nil }
            let card = VideoCard(
                bvid: bvid,
                aid: item.aid,
                cid: item.cid,
                title: (item.title ?? "无标题").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.pic),
                ownerName: item.owner?.name ?? "未知 UP 主",
                ownerFaceURL: RecommendFeedResponse.Item.httpsURL(item.owner?.face),
                duration: item.duration?.value ?? 0,
                viewCount: item.stat?.view?.value ?? 0,
                danmakuCount: item.stat?.danmaku?.value ?? 0,
                publishedAt: item.pubdate.map { Date(timeIntervalSince1970: TimeInterval($0.value)) }
            )
            return LaterVideo(card: card, progress: item.progress?.value ?? 0)
        }
    }

    /// UP 主资料（需要 Wbi 签名）。
    func memberInfo(mid: Int) async throws -> MemberProfile {
        let payload: MemberInfoResponse.Payload = try await object(
            MemberInfoResponse.Payload.self,
            path: "/x/space/wbi/acc/info",
            query: [
                "mid": String(mid),
                "platform": "web",
                "web_location": "1550101",
            ],
            signed: true
        )

        let stats = try? await relationStats(mid: mid)
        return MemberProfile(
            mid: payload.mid ?? mid,
            name: payload.name ?? "UP 主",
            faceURL: RecommendFeedResponse.Item.httpsURL(payload.face),
            sign: payload.sign ?? "",
            level: payload.level?.value ?? 0,
            isVip: (payload.vip?.status?.value ?? 0) > 0,
            following: stats?.following?.value ?? 0,
            follower: stats?.follower?.value ?? 0
        )
    }

    /// UP 主投稿列表。
    func memberVideos(
        mid: Int,
        page: Int,
        order: String = "pubdate"
    ) async throws -> MemberVideoPage {
        let payload: MemberArchiveResponse.Payload = try await object(
            MemberArchiveResponse.Payload.self,
            path: "/x/space/wbi/arc/search",
            query: [
                "mid": String(mid),
                "pn": String(max(1, page)),
                "ps": "30",
                "order": order,
                "tid": "0",
                "keyword": "",
                "platform": "web",
                "web_location": "1550101",
            ],
            signed: true
        )

        let pageSize = payload.page?.ps?.value ?? 30
        let total = payload.page?.count?.value ?? 0
        let totalPages = max(1, Int((Double(total) / Double(max(pageSize, 1))).rounded(.up)))

        let videos: [VideoCard] = (payload.list?.vlist ?? []).compactMap { item in
            guard let bvid = item.bvid, !bvid.isEmpty else { return nil }
            return VideoCard(
                bvid: bvid,
                aid: item.aid,
                cid: item.cid,
                title: (item.title ?? "无标题").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.pic),
                ownerName: "",
                ownerFaceURL: nil,
                duration: SearchTypeResponse.Item.parseDuration(item.length),
                viewCount: item.play?.value ?? 0,
                danmakuCount: 0,
                publishedAt: item.created.map { Date(timeIntervalSince1970: TimeInterval($0.value)) }
            )
        }

        return MemberVideoPage(
            videos: videos,
            page: payload.page?.pn?.value ?? page,
            totalPages: totalPages,
            totalCount: total
        )
    }
}
