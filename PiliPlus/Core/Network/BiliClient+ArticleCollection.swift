import Foundation

extension BiliClient {
    /// 专栏合集（从任意专栏加载所属合集）。
    func articleCollection(cvid: Int) async throws -> (ArticleCollection?, [ArticleCollectionItem]) {
        let payload: ArticleCollectionResponse.Payload = try await object(
            ArticleCollectionResponse.Payload.self,
            path: "/x/article/list/web/articles",
            query: [
                "id": String(cvid),
                "web_location": "333.1400",
            ],
            signed: false
        )

        let info = payload.list.flatMap { list -> ArticleCollection? in
            guard let id = list.id?.value else { return nil }
            return ArticleCollection(
                id: id,
                name: (list.name ?? "专栏合集").removingHTMLTags,
                imageURL: RecommendFeedResponse.Item.httpsURL(list.imageURL),
                read: list.read?.value ?? 0,
                articleCount: list.articlesCount?.value ?? 0
            )
        }

        let items: [ArticleCollectionItem] = (payload.articles ?? []).compactMap { item in
            guard let id = item.id?.value else { return nil }
            return ArticleCollectionItem(
                id: id,
                title: (item.title ?? "文章").removingHTMLTags,
                summary: (item.summary ?? "").removingHTMLTags,
                coverURL: RecommendFeedResponse.Item.httpsURL(item.imageURLs?.first),
                viewCount: item.stats?.view?.value ?? 0
            )
        }

        return (info, items)
    }
}
