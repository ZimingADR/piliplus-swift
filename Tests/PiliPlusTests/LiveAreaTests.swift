import Foundation
import Testing

@testable import PiliPlus

@Suite("LiveArea")
struct LiveAreaTests {
    @Test("直播分区解码")
    func decodesArea() throws {
        let json = """
        { "id": 9, "name": "虚拟主播", "parent_id": 0 }
        """
        let area = try JSONDecoder().decode(LiveArea.self, from: Data(json.utf8))
        #expect(area.id == 9)
        #expect(area.name == "虚拟主播")
        #expect(area.parentID == 0)
    }

    @Test("分区直播间列表复用 LiveListResponse")
    func decodesAreaRooms() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "count": 1,
            "list": [
              {
                "roomid": 555,
                "uid": 1,
                "uname": "主播",
                "face": "",
                "cover": "//i0.hdslb.com/live.jpg",
                "title": "分区直播",
                "area_name": "虚拟主播",
                "watched_show": { "text_large": "1.2 万人看过" }
              }
            ]
          }
        }
        """
        let response = try JSONDecoder().decode(
            LiveListResponse.self,
            from: Data(json.utf8)
        )
        let rooms = response.data?.rooms ?? []
        #expect(rooms.count == 1)
        #expect(rooms.first?.id == 555)
        #expect(rooms.first?.uname == "主播")
        #expect(rooms.first?.areaName == "虚拟主播")
    }
}
