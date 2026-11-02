import Foundation
import SwiftData
import Testing

@testable import PiliPlus

@Suite("PlaybackHistory")
@MainActor
struct PlaybackHistoryTests {
    private func makeStore() throws -> (PlaybackHistoryStore, ModelContainer) {
        let schema = Schema([PlaybackRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let store = PlaybackHistoryStore(context: container.mainContext)
        return (store, container)
    }

    private func snapshot(position: Double) -> PlaybackSnapshot {
        PlaybackSnapshot(
            bvid: "BV1xx411c7mD",
            aid: 1_234,
            cid: 5_678,
            title: "测试视频",
            coverURLString: "https://example.com/cover.jpg",
            ownerName: "测试 UP",
            duration: 600,
            position: position,
            pageIndex: 0,
            pageTitle: "P1"
        )
    }

    @Test("同一视频重复写入只保留一条记录并更新进度")
    func upsertKeepsSingleRecord() throws {
        let (store, container) = try makeStore()

        store.upsert(snapshot(position: 30))
        store.upsert(snapshot(position: 120))

        let records = try container.mainContext.fetch(FetchDescriptor<PlaybackRecord>())
        #expect(records.count == 1)
        #expect(records.first?.position == 120)
        #expect((records.first?.progress ?? 0) > 0)
    }

    @Test("按 bvid 查询断点，删除后为空")
    func fetchAndDelete() throws {
        let (store, container) = try makeStore()
        store.upsert(snapshot(position: 42))

        let record = try #require(store.record(bvid: "BV1xx411c7mD"))
        #expect(record.cid == 5_678)
        #expect(record.resumeText.contains("00:42"))

        store.remove(record)
        #expect(store.record(bvid: "BV1xx411c7mD") == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<PlaybackRecord>()).isEmpty)
    }

    @Test("清空历史")
    func removeAll() throws {
        let (store, container) = try makeStore()
        store.upsert(snapshot(position: 10))

        let other = PlaybackSnapshot(
            bvid: "BV1yy411c7mD",
            aid: 2_345,
            cid: 6_789,
            title: "另一个视频",
            coverURLString: "",
            ownerName: "UP",
            duration: 100,
            position: 20,
            pageIndex: 0,
            pageTitle: "P1"
        )
        store.upsert(other)

        store.removeAll()
        #expect(try container.mainContext.fetch(FetchDescriptor<PlaybackRecord>()).isEmpty)
    }
}
