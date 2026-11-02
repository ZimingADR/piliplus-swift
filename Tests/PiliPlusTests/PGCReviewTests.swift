import Foundation
import Testing

@testable import PiliPlus

@Suite("PGCReviews")
struct PGCReviewTests {
    @Test("番剧长评解码")
    func decodesReviews() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "list": [
              {
                "review_id": 100,
                "title": "<em>长评</em>标题",
                "content": "正文内容",
                "score": 8,
                "author": {
                  "uname": "作者",
                  "avatar": "//i0.hdslb.com/face.jpg",
                  "mid": 1
                },
                "stat": { "likes": 12 },
                "push_time_str": "2026-01-01"
              }
            ],
            "next": "abc",
            "count": 21
          }
        }
        """

        let response = try JSONDecoder().decode(
            PGCReviewsResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.next == "abc")
        #expect(payload.count?.value == 21)

        let item = try #require(payload.list?.first)
        #expect(item.reviewID?.value == 100)
        #expect(item.score?.value == 8)
        #expect(item.author?.uname == "作者")
        #expect(item.stat?.likes?.value == 12)
        #expect(item.pushTimeStr == "2026-01-01")
    }
}
