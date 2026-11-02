import Foundation
import Testing

@testable import PiliPlus

@Suite("Weekly")
struct WeeklyTests {
    @Test("每周必看系列列表解码")
    func decodesSeriesList() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "list": [
              { "number": 2, "subject": "第二期" },
              { "number": 1, "subject": "第一期" }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            PopularSeriesListResponse.self,
            from: Data(json.utf8)
        )
        let items = try #require(response.data?.list)
        #expect(items.count == 2)
        #expect(items[0].number?.value == 2)
        #expect(items[0].subject == "第二期")
    }

    @Test("每周必看当期视频解码")
    func decodesSeriesVideos() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "number": 2,
            "subject": "第二期",
            "list": [
              {
                "aid": 1,
                "bvid": "BV1xx411c7mD",
                "title": "精选视频",
                "pic": "//i0.hdslb.com/cover.jpg",
                "duration": 60,
                "owner": { "name": "UP", "face": "" },
                "stat": { "view": 10, "danmaku": 2 }
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            PopularSeriesResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.number?.value == 2)
        #expect(payload.subject == "第二期")
        #expect(payload.list?.count == 1)
        #expect(payload.list?.first?.bvid == "BV1xx411c7mD")
    }
}
