import Foundation
import Testing

@testable import PiliPlus

@Suite("Precious")
struct PreciousTests {
    @Test("入站必刷分页解码")
    func decodesPrecious() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "list": [
              {
                "aid": 123,
                "bvid": "BV1xx411c7mD",
                "title": "<em>经典</em>视频",
                "pic": "//i0.hdslb.com/cover.jpg",
                "duration": 125,
                "owner": { "name": "UP", "face": "//i0.hdslb.com/face.jpg" },
                "stat": { "view": 1000, "danmaku": 20 }
              }
            ],
            "page": { "pn": 1, "ps": 30, "count": 31 }
          }
        }
        """

        let response = try JSONDecoder().decode(
            PreciousResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.list?.count == 1)
        #expect(payload.page?.count?.value == 31)

        let item = try #require(payload.list?.first)
        #expect(item.bvid == "BV1xx411c7mD")
        #expect(item.duration?.value == 125)
        #expect(item.owner?.name == "UP")
        #expect(item.stat?.view?.value == 1000)
    }
}
