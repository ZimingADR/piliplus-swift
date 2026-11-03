import Foundation
import Testing

@testable import PiliPlus

@Suite("AIConclusion")
struct AIConclusionTests {
    @Test("AI 总结解码")
    func decodesConclusion() throws {
        let json = """
        {
          "code": 0,
          "message": "0",
          "data": {
            "code": 0,
            "model_result": {
              "summary": "这是摘要",
              "outline": [
                {
                  "title": "第一部分",
                  "part_outline": [
                    { "timestamp": 120, "content": "内容一" }
                  ]
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            AIConclusionResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        #expect(payload.code?.value == 0)
        #expect(payload.modelResult?.summary == "这是摘要")

        let outline = try #require(payload.modelResult?.outline?.first)
        #expect(outline.title == "第一部分")
        #expect(outline.partOutline?.first?.timestamp?.value == 120)
        #expect(outline.partOutline?.first?.content == "内容一")
    }
}
