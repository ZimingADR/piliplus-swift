import Foundation

extension BiliClient {
    /// 搜索 UP 主（Web WBI 搜索，search_type=bili_user）。
    func searchUsers(keyword: String, page: Int = 1) async throws -> [UserSearchItem] {
        let payload: UserSearchResponse.Payload = try await object(
            UserSearchResponse.Payload.self,
            path: "/x/web-interface/wbi/search/type",
            query: [
                "search_type": "bili_user",
                "keyword": keyword,
                "page": String(max(1, page)),
                "page_size": "20",
            ],
            signed: true
        )

        return (payload.result ?? []).compactMap { item in
            guard let mid = item.mid?.value, mid > 0 else { return nil }
            return UserSearchItem(
                mid: mid,
                name: (item.uname ?? "用户").removingHTMLTags,
                faceURL: RecommendFeedResponse.Item.httpsURL(item.upic),
                sign: (item.usign ?? "").removingHTMLTags,
                level: item.level?.value ?? 0,
                fans: item.fans?.value ?? 0,
                videoCount: item.videos?.value ?? 0
            )
        }
    }
}
