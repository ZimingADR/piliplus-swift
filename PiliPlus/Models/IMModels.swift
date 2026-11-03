import Foundation

struct IMSession: Identifiable, Hashable, Sendable {
    let talkerID: Int
    var name: String
    var faceURL: URL?
    let lastMessage: String
    let timestamp: Int
    let unread: Int

    var id: Int { talkerID }
}

struct IMSessionsResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct LastMessage: Decodable, Sendable {
            let text: String?

            init(from decoder: any Decoder) throws {
                if let single = try? decoder.singleValueContainer(),
                   let raw = try? single.decode(String.self) {
                    text = Self.extract(from: raw)
                    return
                }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                text = try container.decodeIfPresent(String.self, forKey: .content)
            }

            enum CodingKeys: String, CodingKey {
                case content
            }

            static func extract(from raw: String) -> String {
                guard let data = raw.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = object["content"] as? String else {
                    return raw
                }
                return content
            }
        }

        struct Item: Decodable, Sendable {
            let talkerID: FlexInt?
            let atTime: FlexInt?
            let unreadCount: FlexInt?
            let lastMsg: LastMessage?

            enum CodingKeys: String, CodingKey {
                case talkerID = "talker_id"
                case atTime = "at_time"
                case unreadCount = "unread_count"
                case lastMsg = "last_msg"
            }
        }

        let sessionList: [Item]?

        enum CodingKeys: String, CodingKey {
            case sessionList = "session_list"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct IMMessage: Identifiable, Hashable, Sendable {
    let id: String
    let senderUID: Int
    let timestamp: Int
    let text: String
}

struct IMMessagesResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let msgKey: String?
            let senderUID: FlexInt?
            let timestamp: FlexInt?
            let content: String?
            let msgType: FlexInt?

            enum CodingKeys: String, CodingKey {
                case timestamp, content
                case msgKey = "msg_key"
                case senderUID = "sender_uid"
                case msgType = "msg_type"
            }
        }

        let messages: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct UserCardResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Card: Decodable, Sendable {
            let name: String?
            let face: String?
        }

        let card: Card?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
