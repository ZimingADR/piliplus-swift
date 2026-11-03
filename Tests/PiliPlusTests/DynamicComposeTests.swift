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

    @Test("图文动态编码 pics 与 scene=2")
    func encodesPictures() throws {
        let picture = DynamicPicture(
            imgSrc: "https://i0.hdslb.com/bfs/new_dyn/a.jpg",
            imgWidth: 1200,
            imgHeight: 800,
            imgSize: 120_000
        )
        let json = try #require(
            DynamicComposePayload(text: "", pictures: [picture]).jsonString
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )

        #expect(object["scene"] as? Int == 2)

        let pics = try #require(object["pics"] as? [[String: Any]])
        #expect(pics.count == 1)
        #expect(pics[0]["img_src"] as? String == picture.imgSrc)
        #expect(pics[0]["img_width"] as? Int == 1200)
        #expect(pics[0]["img_height"] as? Int == 800)

        let content = try #require(object["content"] as? [String: Any])
        let contents = try #require(content["contents"] as? [[String: Any]])
        #expect(contents.isEmpty)
    }
}
