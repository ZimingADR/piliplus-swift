import Foundation
import Testing

@testable import PiliPlus

@Suite("MemberArticles")
struct MemberArticlesTests {
    @Test("空间专栏分页解码")
    func decodesArticles() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "articles": [
              {
                "id": 123456,
                "title": "<em>专栏</em>标题",
                "cover": "//i0.hdslb.com/article.jpg",
                "publish_time": 1700000000,
                "stats": { "view": 500 }
              }
            ],
            "page": { "pn": 1, "ps": 20, "count": 21 }
          }
        }
        """

        let response = try JSONDecoder().decode(
            SpaceArticlesResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        let item = try #require(payload.articles?.first)
        #expect(item.id?.value == 123456)
        #expect(item.title == "<em>专栏</em>标题")
        #expect(item.publishTime?.value == 1_700_000_000)
        #expect(item.stats?.view?.value == 500)
        #expect(payload.page?.count?.value == 21)
    }
}
