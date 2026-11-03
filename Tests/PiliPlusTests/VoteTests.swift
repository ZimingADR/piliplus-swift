import Foundation
import Testing

@testable import PiliPlus

@Suite("Vote")
struct VoteTests {
    @Test("投票请求体编码")
    func encodesVote() throws {
        let payload = VoteCreatePayload(
            title: "测试投票",
            description: "说明",
            choiceCount: 2,
            durationDays: 7,
            options: ["A", "B", "C"]
        )
        let json = try #require(payload.jsonString)
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )

        #expect(object["title"] as? String == "测试投票")
        #expect(object["type"] as? Int == 0)
        #expect(object["choice_cnt"] as? Int == 2)
        #expect(object["duration"] as? Int == 7 * 86_400)

        let options = try #require(object["options"] as? [[String: Any]])
        #expect(options.count == 3)
        #expect(options[0]["opt_desc"] as? String == "A")
        #expect(options[0]["img_url"] as? String == "")
    }

    @Test("投票创建响应解码")
    func decodesResponse() throws {
        let json = """
        { "code": 0, "data": { "vote_id": 12345 } }
        """
        let response = try JSONDecoder().decode(
            VoteCreateResponse.self,
            from: Data(json.utf8)
        )
        #expect(response.data?.voteID?.value == 12345)
    }
}
