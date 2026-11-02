import Foundation
import Testing

@testable import PiliPlus

@Suite("DynamicCompose")
struct DynamicComposeTests {
    @Test("dyn_req 编码为纯文字动态")
    func encodesPayload() throws {
        let json = try #require(DynamicComposePayload(text: "你好 #测试#").jsonString)
        let data = Data(json.utf8)

        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(object["scene"] as? Int == 1)

        let content = try #require(object["content"] as? [String: Any])
        let contents = try #require(content["contents"] as? [[String: Any]])
        let paragraph = try #require(contents.first)
        #expect(paragraph["raw_text"] as? String == "你好 #测试#")
        #expect(paragraph["type"] as? Int == 1)
        #expect(paragraph["biz_id"] as? String == "")
    }

    @Test("空字符串仍能编码（由 UI 拦截）")
    func encodesEmptyText() throws {
        let json = try #require(DynamicComposePayload(text: "").jsonString)
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        #expect(object["scene"] as? Int == 1)
    }
}
