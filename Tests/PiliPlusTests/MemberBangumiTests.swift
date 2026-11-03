import Foundation
import Testing

@testable import PiliPlus

@Suite("MemberBangumi")
struct MemberBangumiTests {
    @Test("空间追番解码")
    func decodesBangumi() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "total": 1,
            "list": [
              {
                "season_id": 12345,
                "title": "<em>番剧</em>标题",
                "cover": "//i0.hdslb.com/bangumi.jpg",
                "new_ep": { "index_show": "更新至第 3 话" },
                "badge": "会员"
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            SpaceBangumiResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.total?.value == 1)
        let item = try #require(payload.list?.first)
        #expect(item.seasonID?.value == 12345)
        #expect(item.newEp?.indexShow == "更新至第 3 话")
        #expect(item.badge == "会员")
    }
}
