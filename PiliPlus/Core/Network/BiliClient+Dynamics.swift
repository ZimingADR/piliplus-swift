import Foundation

extension BiliClient {
    /// 网页动态接口的 feature 开关，与 Flutter 版 `Constants.dynFeatures` 对齐。
    static let dynamicFeatures = "itemOpusStyle,listOnlyfans,opusBigCover,onlyfansVote,"
        + "decorationCard,onlyfansAssetsV2,forwardListHidden,ugcDelete,onlyfansQaCard,"
        + "commentsNewVersion,avatarAutoTheme,sunflowerStyle,cardsEnhance,"
        + "eva3CardOpus,eva3CardVideo,eva3CardComment,eva3CardVote,eva3CardUser"

    /// 关注动态 / 综合动态（需要登录）。
    func dynamicsFeed(offset: String? = nil) async throws -> DynamicsPage {
        var query = [
            "type": "all",
            "features": Self.dynamicFeatures,
        ]
        if let offset, !offset.isEmpty {
            query["offset"] = offset
        }

        let payload: DynamicsFeedResponse.Payload = try await object(
            DynamicsFeedResponse.Payload.self,
            path: "/x/polymer/web-dynamic/v1/feed/all",
            query: query,
            signed: false
        )
        return payload.domainPage
    }

    /// UP 主动态（公开，无需登录）。
    func memberDynamics(mid: Int, offset: String? = nil) async throws -> DynamicsPage {
        var query = [
            "host_mid": String(mid),
            "features": Self.dynamicFeatures,
        ]
        if let offset, !offset.isEmpty {
            query["offset"] = offset
        }

        let payload: DynamicsFeedResponse.Payload = try await object(
            DynamicsFeedResponse.Payload.self,
            path: "/x/polymer/web-dynamic/v1/feed/all",
            query: query,
            signed: false
        )
        return payload.domainPage
    }

    func dynamicDetail(id: String) async throws -> DynamicItem? {
        let payload: DynamicDetailPayload.Payload = try await object(
            DynamicDetailPayload.Payload.self,
            path: "/x/polymer/web-dynamic/v1/detail",
            query: [
                "rid": id,
                "features": Self.dynamicFeatures,
            ],
            signed: false
        )
        return payload.item?.domainModel()
    }

    /// 专栏正文（`/x/article/view`，需要 Wbi 签名）。
    func articleDetail(cvid: Int) async throws -> ArticleDetail {
        let payload: ArticleViewResponse.Payload = try await object(
            ArticleViewResponse.Payload.self,
            path: "/x/article/view",
            query: [
                "id": String(cvid),
                "gaia_source": "main_web",
                "web_location": "333.976",
            ],
            signed: true
        )

        return ArticleDetail(
            id: payload.id?.value ?? cvid,
            title: payload.title ?? "专栏",
            authorName: payload.author?.name ?? "",
            authorFaceURL: Self.httpsURL(payload.author?.face),
            publishDate: payload.publishTime.map {
                Date(timeIntervalSince1970: TimeInterval($0.value))
            },
            contentHTML: payload.content ?? "",
            coverURL: Self.httpsURL(payload.bannerURL),
            viewCount: payload.stats?.view?.value ?? 0,
            likeCount: payload.stats?.like?.value ?? 0
        )
    }

    private static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        return URL(string: raw.hasPrefix("//") ? "https:" + raw : raw)
    }
}

/// `/x/polymer/web-dynamic/v1/detail` 的响应载荷（`data.item` 单条）。
struct DynamicDetailPayload: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let item: DynamicsFeedResponse.Item?
    }
}
