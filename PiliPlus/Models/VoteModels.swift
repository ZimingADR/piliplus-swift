import Foundation

struct VoteCreatePayload: Encodable, Sendable {
    struct Option: Encodable, Sendable {
        let optDesc: String
        let imgURL: String

        enum CodingKeys: String, CodingKey {
            case optDesc = "opt_desc"
            case imgURL = "img_url"
        }
    }

    let title: String
    let desc: String
    let type: Int
    let choiceCnt: Int
    let duration: Int
    let options: [Option]

    enum CodingKeys: String, CodingKey {
        case title, desc, type, duration, options
        case choiceCnt = "choice_cnt"
    }

    init(
        title: String,
        description: String,
        choiceCount: Int,
        durationDays: Int,
        options: [String]
    ) {
        self.title = title
        desc = description
        type = 0
        choiceCnt = choiceCount
        duration = durationDays * 86_400
        self.options = options.map { Option(optDesc: $0, imgURL: "") }
    }

    var jsonString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct VoteCreateResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let voteID: FlexInt?

        enum CodingKeys: String, CodingKey {
            case voteID = "vote_id"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}
