import Foundation
import Testing

@testable import PiliPlus

@Suite("LiveFollow")
struct LiveFollowTests {
    @Test("关注开播解码")
    func decodesFollow() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "totalPage": 2,
            "count": 2,
            "live_count": 1,
            "list": [
              {
                "roomid": 123,
                "live_status": 1,
                "uname": "主播A",
                "title": "直播标题",
                "area_name": "虚拟主播",
                "text_small": "1.2 万人气",
                "room_cover": "//i0.hdslb.com/live.jpg"
              },
              {
                "roomid": 456,
                "live_status": 0,
                "uname": "主播B",
                "title": "未开播",
                "area_name": "游戏",
                "text_small": "",
                "room_cover": ""
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            LiveFollowResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.totalPage?.value == 2)
        #expect(payload.liveCount?.value == 1)

        let items = try #require(payload.list)
        #expect(items.count == 2)
        #expect(items[0].liveStatus?.value == 1)
        #expect(items[0].roomID?.value == 123)
        #expect(items[0].textSmall == "1.2 万人气")
        #expect(items[1].liveStatus?.value == 0)
    }
}
