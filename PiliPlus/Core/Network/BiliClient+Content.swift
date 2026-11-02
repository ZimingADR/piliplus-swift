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

// MARK: - 收藏夹

extension BiliClient {
    func favoriteFolders(mid: Int) async throws -> [FavoriteFolder] {
        let payload: FavoriteFoldersResponse.Payload = try await object(
            FavoriteFoldersResponse.Payload.self,
            path: "/x/v3/fav/folder/created/list-all",
            query: ["up_mid": String(mid)],
            signed: false
        )
        return (payload.list ?? []).compactMap { item in
            guard let id = item.id else { return nil }
            return FavoriteFolder(
                id: id,
                title: item.title ?? "收藏夹",
                mediaCount: item.mediaCount?.value ?? 0,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.cover)
            )
        }
    }

    func favoritePage(mediaID: Int, page: Int) async throws -> FavoritePage {
        let payload: FavoriteResourceResponse.Payload = try await object(
            FavoriteResourceResponse.Payload.self,
            path: "/x/v3/fav/resource/list",
            query: [
                "media_id": String(mediaID),
                "pn": String(max(1, page)),
                "ps": "20",
                "platform": "web",
                "order": "mtime",
                "type": "0",
                "tid": "0",
            ],
            signed: false
        )

        let videos: [VideoCard] = (payload.medias ?? []).compactMap { media in
            guard let bvid = media.bvid, !bvid.isEmpty, media.type?.value == 2 else { return nil }
            return VideoCard(
                bvid: bvid,
                aid: media.id?.value,
                cid: nil,
                title: (media.title ?? "已失效视频").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(media.cover),
                ownerName: media.upper?.name ?? "未知 UP 主",
                ownerFaceURL: nil,
                duration: media.duration?.value ?? 0,
                viewCount: media.cntInfo?.play?.value ?? 0,
                danmakuCount: media.cntInfo?.danmaku?.value ?? 0,
                publishedAt: nil
            )
        }

        return FavoritePage(
            folderTitle: payload.info?.title ?? "收藏夹",
            videos: videos,
            page: page,
            hasMore: payload.hasMore ?? false,
            total: payload.info?.mediaCount?.value ?? 0
        )
    }
}

// MARK: - 关注

extension BiliClient {
    func followings(mid: Int, page: Int) async throws -> FollowPage {
        let payload: FollowingsResponse.Payload = try await object(
            FollowingsResponse.Payload.self,
            path: "/x/relation/followings",
            query: [
                "vmid": String(mid),
                "pn": String(max(1, page)),
                "ps": "20",
                "order": "desc",
                "order_type": "attention",
            ],
            signed: false
        )

        let users = (payload.list ?? []).compactMap { item -> FollowUser? in
            guard let mid = item.mid else { return nil }
            return FollowUser(
                mid: mid,
                name: item.uname ?? "用户",
                faceURL: RecommendFeedResponse.Item.httpsURL(item.face),
                sign: item.sign ?? "",
                isVip: (item.vip?.status?.value ?? 0) > 0
            )
        }

        return FollowPage(users: users, page: page, total: payload.total?.value ?? 0)
    }
}

// MARK: - 评论

extension BiliClient {
    func comments(aid: Int, offset: String = "") async throws -> CommentPage {
        let pagination = offset.isEmpty
            ? "{\"offset\":\"\"}"
            : "{\"offset\":\"\(offset)\"}"

        let payload: CommentsResponse.Payload = try await object(
            CommentsResponse.Payload.self,
            path: "/x/v2/reply/wbi/main",
            query: [
                "oid": String(aid),
                "type": "1",
                "mode": "3",
                "plat": "1",
                "web_location": "1315871",
                "pagination_str": pagination,
            ],
            signed: true
        )

        let uploaderMid = payload.upper?.mid
        var comments: [VideoComment] = []

        if offset.isEmpty {
            comments.append(
                contentsOf: (payload.topReplies ?? [])
                    .compactMap { $0.videoComment(uploaderMid: uploaderMid) }
            )
        }
        comments.append(
            contentsOf: (payload.replies ?? [])
                .compactMap { $0.videoComment(uploaderMid: uploaderMid) }
        )

        var seen = Set<Int64>()
        comments = comments.filter { seen.insert($0.id).inserted }

        return CommentPage(
            comments: comments,
            nextOffset: payload.cursor?.paginationReply?.nextOffset ?? "",
            isEnd: payload.cursor?.isEnd ?? true,
            total: payload.cursor?.allCount?.value ?? comments.count
        )
    }

    /// 楼中楼（子回复）分页。
    func commentReplies(
        oid: Int,
        root: Int64,
        page: Int
    ) async throws -> CommentPage {
        let payload: ReplyRepliesResponse.Payload = try await object(
            ReplyRepliesResponse.Payload.self,
            path: "/x/v2/reply/reply",
            query: [
                "oid": String(oid),
                "type": "1",
                "root": String(root),
                "pn": String(max(1, page)),
                "ps": "20",
                "web_location": "1315871",
            ],
            signed: false
        )

        let upper = payload.upper?.mid
        let replies = (payload.replies ?? [])
            .compactMap { $0.videoComment(uploaderMid: upper) }
        let pageSize = payload.page?.ps?.value ?? 20
        let total = payload.page?.count?.value ?? replies.count
        let currentPage = payload.page?.pn?.value ?? page

        return CommentPage(
            comments: replies,
            nextOffset: String(currentPage + 1),
            isEnd: currentPage * pageSize >= total,
            total: total
        )
    }

    /// 点赞 / 取消点赞评论。
    func likeComment(oid: Int, rpid: Int64, like: Bool) async throws {
        guard let csrf = csrfToken() else {
            throw BiliAPIError(code: -101, message: "请先登录")
        }
        let data = try await postForm(
            "/x/v2/reply/action",
            form: [
                "oid": String(oid),
                "type": "1",
                "rpid": String(rpid),
                "action": like ? "1" : "0",
                "csrf": csrf,
            ]
        )
        let response = try JSONDecoder().decode(ActionResponse.self, from: data)
        guard response.code == 0 else {
            throw BiliAPIError(code: response.code, message: response.message ?? "操作失败")
        }
    }
}
