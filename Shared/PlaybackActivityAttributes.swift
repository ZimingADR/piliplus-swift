import ActivityKit
import Foundation

/// 播放实时活动（灵动岛 / 锁屏）的属性与状态，App 与 Widget 共用。
struct PlaybackActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var elapsed: Double
        var duration: Double
        var title: String
        var ownerName: String
        var coverURLString: String

        var fraction: Double {
            guard duration > 0 else { return 0 }
            return min(max(elapsed / duration, 0), 1)
        }

        var percentText: String {
            "\(Int(fraction * 100))%"
        }
    }

    var bvid: String
    var cid: Int

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
}
