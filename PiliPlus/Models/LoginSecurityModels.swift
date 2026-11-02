import Foundation

struct LoginDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let isCurrent: Bool
    let lastLoginAt: String
    let source: String
}

struct LoginDevicesResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let deviceName: String?
            let isCurrentDevice: Bool?
            let latestLoginAt: String?
            let source: String?

            enum CodingKeys: String, CodingKey {
                case deviceName = "device_name"
                case isCurrentDevice = "is_current_device"
                case latestLoginAt = "latest_login_at"
                case source
            }
        }

        let devices: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct LoginLogEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let ip: String
    let timeAt: String
    let geo: String
}

struct LoginLogResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let ip: String?
            let timeAt: String?
            let geo: String?

            enum CodingKeys: String, CodingKey {
                case ip, geo
                case timeAt = "time_at"
            }
        }

        let list: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}
