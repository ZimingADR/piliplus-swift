import Foundation
import Testing

@testable import PiliPlus

@Suite("MemberCollections")
struct MemberCollectionTests {
    @Test("空间合集/系列解码")
    func decodesCollections() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "items_lists": {
              "page": { "total": 2 },
              "seasons_list": [
                {
                  "meta": {
                    "cover": "//i0.hdslb.com/season.jpg",
                    "name": "<em>合集</em>名称",
                    "total": 12,
                    "season_id": 100
                  }
                }
              ],
              "series_list": [
                {
                  "meta": {
                    "cover": "//i0.hdslb.com/series.jpg",
                    "name": "系列名称",
                    "total": 5,
                    "series_id": 200
                  }
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            SpaceCollectionsResponse.self,
            from: Data(json.utf8)
        )
        let lists = try #require(response.data?.itemsLists)
        #expect(lists.page?.total?.value == 2)
        #expect(lists.seasonsList?.count == 1)
        #expect(lists.seasonsList?.first?.meta?.seasonID?.value == 100)
        #expect(lists.seriesList?.first?.meta?.seriesID?.value == 200)
        #expect(lists.seasonsList?.first?.meta?.total?.value == 12)
    }
}
