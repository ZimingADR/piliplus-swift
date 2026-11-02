import Foundation

extension BiliClient {
    /// 番剧长评（游标分页）。
    func pgcReviews(
        mediaID: Int,
        cursor: String = ""
    ) async throws -> ([PGCReviewItem], String, Int) {
        var query = [
            "media_id": String(mediaID),
            "ps": "20",
            "sort": "0",
            "web_location": "666.19",
        ]
        if !cursor.isEmpty {
            query["cursor"] = cursor
        }

        let payload: PGCReviewsResponse.Payload = try await object(
            PGCReviewsResponse.Payload.self,
            path: "/pgc/review/long/list",
            query: query,
            signed: false
        )

        let items: [PGCReviewItem] = (payload.list ?? []).compactMap { item in
            guard let reviewID = item.reviewID?.value else { return nil }
            return PGCReviewItem(
                id: reviewID,
                title: (item.title ?? "").removingHTMLTags,
                content: (item.content ?? "").removingHTMLTags,
                authorName: item.author?.uname ?? "用户",
                avatarURL: RecommendFeedResponse.Item.httpsURL(item.author?.avatar),
                score: max(0, (item.score?.value ?? 0) / 2),
                likes: item.stat?.likes?.value ?? 0,
                timeText: item.pushTimeStr ?? ""
            )
        }

        return (items, payload.next ?? "", payload.count?.value ?? payload.total?.value ?? items.count)
    }
}
