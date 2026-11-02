import Foundation
import Observation

/// 轻量运行日志：环形缓冲，最多保留 300 条，供设置页排查问题。
@MainActor
@Observable
final class LogStore {
    struct Entry: Identifiable, Sendable {
        enum Level: String, Sendable {
            case info
            case warning
            case error
        }

        let id = UUID()
        let date: Date
        let level: Level
        let message: String
    }

    static let shared = LogStore()

    private(set) var entries: [Entry] = []
    private let capacity = 300

    func log(_ message: String, level: Entry.Level = .info) {
        entries.append(Entry(date: .now, level: level, message: message))
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
