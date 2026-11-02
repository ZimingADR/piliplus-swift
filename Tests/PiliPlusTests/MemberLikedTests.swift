import Foundation
import Testing

@testable import PiliPlus

@Suite("MemberLiked")
struct MemberLikedTests {
    @Test("空间点赞视频解码")
    func decodesLiked() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "count": 21,
            "item": [
              {
                "title": "<em>点赞</em>视频",
                "cover": "//i0.hdslb.com/like.jpg",
                "param": "BV1xx411c7mD",
                "duration": 125,
                "play": 1000,
                "danmaku": 20,
                "ctime": 1700000000
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            SpaceLikeArcResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.count?.value == 21)
        let item = try #require(payload.item?.first)
        #expect(item.param == "BV1xx411c7mD")
        #expect(item.duration?.value == 125)
        #expect(item.play?.value == 1000)
    }
}
