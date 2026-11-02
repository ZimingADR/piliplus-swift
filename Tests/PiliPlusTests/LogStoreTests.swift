import Foundation
import Testing

@testable import PiliPlus

@Suite("LogStore")
struct LogStoreTests {
    @Test("环形缓冲裁剪到 300 条")
    @MainActor
    func ringBuffer() {
        let store = LogStore()
        for index in 0 ..< 310 {
            store.log("message-\(index)")
        }

        #expect(store.entries.count == 300)
        #expect(store.entries.first?.message == "message-10")
        #expect(store.entries.last?.message == "message-309")
    }

    @Test("清空日志")
    @MainActor
    func clear() {
        let store = LogStore()
        store.log("a", level: .warning)
        store.log("b", level: .error)
        #expect(store.entries.count == 2)
        #expect(store.entries.last?.level == .error)

        store.clear()
        #expect(store.entries.isEmpty)
    }
}
