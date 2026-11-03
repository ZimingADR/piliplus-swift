import Foundation
import Testing

@testable import PiliPlus

@Suite("ArticleCollection")
struct ArticleCollectionTests {
    @Test("专栏合集解码")
    func decodesCollection() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "list": {
              "id": 10,
              "name": "合集名称",
              "image_url": "//i0.hdslb.com/collection.jpg",
              "read": 1000,
              "articles_count": 3
            },
            "articles": [
              {
                "id": 100,
                "title": "<em>文章</em>标题",
                "summary": "摘要",
                "image_urls": ["//i0.hdslb.com/a.jpg"],
                "stats": { "view": 50 }
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            ArticleCollectionResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.list?.id?.value == 10)
        #expect(payload.list?.name == "合集名称")
        #expect(payload.list?.articlesCount?.value == 3)

        let item = try #require(payload.articles?.first)
        #expect(item.id?.value == 100)
        #expect(item.summary == "摘要")
        #expect(item.stats?.view?.value == 50)
    }
}
