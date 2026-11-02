import Foundation
import Testing

@testable import PiliPlus

@Suite("LiveSearch")
struct LiveSearchTests {
    @Test("直播搜索结果解码")
    func decodesSearch() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "result": [
              {
                "roomid": 12345,
                "uname": "主播",
                "title": "<em>测试</em>直播间",
                "cover": "//i0.hdslb.com/live.jpg",
                "online": 1200,
                "area_v2_name": "虚拟主播"
              }
            ],
            "numResults": 1
          }
        }
        """

        let response = try JSONDecoder().decode(
            LiveSearchResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        let item = try #require(payload.result?.first)
        #expect(item.roomID?.value == 12345)
        #expect(item.uname == "主播")
        #expect(item.online?.value == 1200)
        #expect(item.areaName == "虚拟主播")
        #expect(payload.numResults?.value == 1)
    }
}
