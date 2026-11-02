import Foundation

/// 主 App 与 Widget Extension 共享的「最近播放」快照。
///
/// 通过 App Group 的 UserDefaults 传递；主 App 在保存播放历史时写入并刷新 Widget，
/// Widget 只读取，不依赖网络。
struct SharedRecentPlayback: Codable, Sendable, Equatable {
    var title: String
    var coverURLString: String
    var bvid: String
    var cid: Int
    var progress: Double
    var duration: Double
    var updatedAt: Date

    static let appGroup = "group.com.zimingadr.piliplus"
    static let storageKey = "widget.recentPlayback"

    var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(progress / duration, 0), 1)
    }

    var deepLink: URL? {
        var components = URLComponents()
        components.scheme = "piliplus"
        components.host = "video"
        components.queryItems = [
            URLQueryItem(name: "bvid", value: bvid),
            URLQueryItem(name: "cid", value: String(cid)),
        ]
        return components.url
    }

    static func load() -> SharedRecentPlayback? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SharedRecentPlayback.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup),
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }

    static var placeholder: SharedRecentPlayback {
        SharedRecentPlayback(
            title: "继续观看最近的视频",
            coverURLString: "",
            bvid: "BV1xx411c7mD",
            cid: 0,
            progress: 42,
            duration: 120,
            updatedAt: .now
        )
    }
}
