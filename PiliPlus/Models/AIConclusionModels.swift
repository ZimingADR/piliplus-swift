import Foundation

struct AIConclusionResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Part: Decodable, Sendable {
            let timestamp: FlexInt?
            let content: String?
        }

        struct Outline: Decodable, Sendable {
            let title: String?
            let partOutline: [Part]?

            enum CodingKeys: String, CodingKey {
                case title
                case partOutline = "part_outline"
            }
        }

        struct ModelResult: Decodable, Sendable {
            let summary: String?
            let outline: [Outline]?
        }

        let code: FlexInt?
        let modelResult: ModelResult?

        enum CodingKeys: String, CodingKey {
            case code
            case modelResult = "model_result"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}
