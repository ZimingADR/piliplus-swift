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
}
