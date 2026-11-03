import Foundation

/// 动态图片（上传后得到，用于 dyn_req 的 `pics`）。
struct DynamicPicture: Encodable, Sendable, Hashable {
    let imgSrc: String
    let imgWidth: Int
    let imgHeight: Int
    let imgSize: Double

    enum CodingKeys: String, CodingKey {
        case imgSrc = "img_src"
        case imgWidth = "img_width"
        case imgHeight = "img_height"
        case imgSize = "img_size"
    }
}

/// BFS 图片上传响应。
struct DynamicImageUpload: Decodable, Sendable {
    let imageURL: String?
    let imageWidth: FlexInt?
    let imageHeight: FlexInt?
    let imgSize: FlexDouble?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case imgSize = "img_size"
    }

    var picture: DynamicPicture? {
        guard let imageURL, !imageURL.isEmpty else { return nil }
        return DynamicPicture(
            imgSrc: imageURL,
            imgWidth: imageWidth?.value ?? 0,
            imgHeight: imageHeight?.value ?? 0,
            imgSize: imgSize?.value ?? 0
        )
    }
}

/// 发布动态的 `dyn_req` 请求体（纯文字或图文）。
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
    let pics: [DynamicPicture]?

    init(text: String, pictures: [DynamicPicture] = []) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        content = Content(
            contents: trimmed.isEmpty
                ? []
                : [Paragraph(rawText: trimmed, type: 1, bizID: "")]
        )
        pics = pictures.isEmpty ? nil : pictures
        scene = pictures.isEmpty ? 1 : 2
    }

    var jsonString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
