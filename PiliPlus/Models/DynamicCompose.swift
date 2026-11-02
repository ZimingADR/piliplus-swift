import Foundation

/// 发布图文动态的 `dyn_req` 请求体（纯文字，type=1）。
struct DynamicComposePayload: Encodable, Sendable {
    struct Paragraph: Encodable, Sendable {
        let rawText: String
        let type: Int
        let bizID: String

        enum CodingKeys: String, CodingKey {
            case rawText = "raw_text"
            case type
            case bizID = "biz_id"
        }
    }

    struct Content: Encodable, Sendable {
        let contents: [Paragraph]
    }

    let content: Content
    let scene: Int

    init(text: String) {
        content = Content(contents: [Paragraph(rawText: text, type: 1, bizID: "")])
        scene = 1
    }

    var jsonString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
