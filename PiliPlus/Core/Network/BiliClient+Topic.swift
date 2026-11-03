import Foundation

extension BiliClient {
    /// 话题详情。
    func topicTop(topicID: Int) async throws -> TopicInfo? {
        let payload: TopicTopResponse.Payload = try await object(
            TopicTopResponse.Payload.self,
            path: "/x/topic/web/details/top",
            query: [
                "topic_id": String(topicID),
                "source": "Web",
            ],
            signed: false
        )
        return payload.topDetails?.topicItem?.topicInfo
    }

    /// 话题动态流。
    func topicFeed(
        topicID: Int,
        offset: String = ""
    ) async throws -> (items: [DynamicItem], offset: String, hasMore: Bool) {
        var query = [
            "topic_id": String(topicID),
            "sort_by": "3",
            "page_size": "20",
            "source": "Web",
        ]
        if !offset.isEmpty {
            query["offset"] = offset
        }

        let payload: TopicFeedResponse.Payload = try await object(
            TopicFeedResponse.Payload.self,
            path: "/x/polymer/web-dynamic/v1/feed/topic",
            query: query,
            signed: false
        )

        guard let cardList = payload.topicCardList else {
            return ([], "", false)
        }

        let items: [DynamicItem] = (cardList.items ?? []).compactMap {
            $0.dynamicCardItem?.domainModel()
        }

        return (
            items,
            cardList.offset ?? "",
            (cardList.hasMore?.value ?? 0) != 0
        )
    }

    /// 搜索话题。
    func searchTopics(keyword: String, page: Int = 1) async throws -> [TopicInfo] {
        let payload: TopicSearchResponse.Payload = try await object(
            TopicSearchResponse.Payload.self,
            path: "/x/topic/pub/search",
            query: [
                "keywords": keyword,
                "page_num": String(max(1, page)),
                "page_size": "20",
            ],
            signed: false
        )

        return (payload.topicItems ?? []).compactMap(\.topicInfo)
    }
}
