import Foundation

/// 当前登录账号的公开信息。
struct AccountProfile: Sendable, Equatable {
    let mid: Int
    let name: String
    let faceURL: URL?
    let level: Int
    let coins: Int
    let isVip: Bool
    let following: Int
    let follower: Int

    var levelText: String { "LV\(level)" }

    var coinsText: String {
        coins >= 10_000 ? String(format: "%.1f万", Double(coins) / 10_000) : "\(coins)"
    }
}

/// `/x/relation/stat` 的关注 / 粉丝数。
struct RelationStats: Decodable, Sendable {
    let mid: Int?
    let following: FlexInt?
    let follower: FlexInt?
}

/// 二维码登录会话。
struct QRLoginSession: Sendable, Equatable {
    let url: String
    let key: String
}

/// 二维码轮询结果。
struct QRLoginPollResult: Sendable, Equatable {
    enum State: Sendable, Equatable {
        case waiting
        case scanned
        case succeeded
        case expired
        case failed
    }

    let state: State
    let message: String
    let cookie: String?
}

struct QRGenerateResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let url: String
        let qrcodeKey: String

        enum CodingKeys: String, CodingKey {
            case url
            case qrcodeKey = "qrcode_key"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct QRPollResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let url: String?
        let refreshToken: String?
        let timestamp: Int?
        let code: Int
        let message: String?

        enum CodingKeys: String, CodingKey {
            case url, timestamp, code, message
            case refreshToken = "refresh_token"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}
