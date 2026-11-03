import Foundation
import Testing

@testable import PiliPlus

@Suite("MemberAudio")
struct MemberAudioTests {
    @Test("空间音频解码")
    func decodesAudio() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "totalSize": 21,
            "data": [
              {
                "id": 1,
                "uid": 100,
                "title": "<em>歌曲</em>标题",
                "cover": "//i0.hdslb.com/audio.jpg",
                "aid": 123,
                "bvid": "BV1xx411c7mD",
                "cid": 456,
                "ctime": 1700000000,
                "statistic": { "play": 1000, "comment": 20 }
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            SpaceAudioResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.totalSize?.value == 21)
        let item = try #require(payload.data?.first)
        #expect(item.bvid == "BV1xx411c7mD")
        #expect(item.cid?.value == 456)
        #expect(item.statistic?.play?.value == 1000)
    }
}
