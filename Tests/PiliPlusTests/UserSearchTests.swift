import Foundation
import Testing

@testable import PiliPlus

@Suite("UserSearch")
struct UserSearchTests {
    @Test("用户搜索结果解码")
    func decodesUsers() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "result": [
              {
                "mid": 123,
                "uname": "<em>测试</em>UP",
                "upic": "//i0.hdslb.com/face.jpg",
                "usign": "签名",
                "level": 5,
                "fans": 10000,
                "videos": 42
              }
            ],
            "numResults": 1
          }
        }
        """

        let response = try JSONDecoder().decode(
            UserSearchResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        let item = try #require(payload.result?.first)
        #expect(item.mid?.value == 123)
        #expect(item.uname == "<em>测试</em>UP")
        #expect(item.level?.value == 5)
        #expect(item.fans?.value == 10000)
        #expect(payload.numResults?.value == 1)
    }
}
