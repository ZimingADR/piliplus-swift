import Foundation
import Observation
import SwiftData

/// 一条播放历史记录。`videoKey` 取 bvid，保证同一条视频只有一条记录。
@Model
final class PlaybackRecord {
    @Attribute(.unique) var videoKey: String
    var bvid: String
    var aid: Int
    var cid: Int
    var title: String
    var coverURLString: String
    var ownerName: String
    var duration: Double
    var position: Double
    var pageIndex: Int
    var pageTitle: String
    var updatedAt: Date

    init(
        bvid: String,
        aid: Int,
        cid: Int,
        title: String,
        coverURLString: String,
        ownerName: String,
        duration: Double,
        position: Double,
        pageIndex: Int,
        pageTitle: String,
        updatedAt: Date = .now
    ) {
        self.videoKey = bvid.isEmpty ? "av\(aid)" : bvid
        self.bvid = bvid
        self.aid = aid
        self.cid = cid
        self.title = title
        self.coverURLString = coverURLString
        self.ownerName = ownerName
        self.duration = duration
        self.position = position
        self.pageIndex = pageIndex
        self.pageTitle = pageTitle
        self.updatedAt = updatedAt
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    var coverURL: URL? {
        RecommendFeedResponse.Item.httpsURL(coverURLString)
    }

    var resumeText: String {
        guard position > 1, duration > 0 else { return "尚未播放" }
        return "已看到 \(VideoCard.formatDuration(Int(position))) / \(VideoCard.formatDuration(Int(duration)))"
    }
}

/// 播放进度快照，用于从播放器向存储层传递数据。
struct PlaybackSnapshot: Sendable, Equatable {
    let bvid: String
    let aid: Int
    let cid: Int
    let title: String
    let coverURLString: String
    let ownerName: String
    let duration: Double
    let position: Double
    let pageIndex: Int
    let pageTitle: String
}

/// 播放历史仓储。
///
/// 视图层用 `@Query` 直接渲染列表，写入 / 断点查询走这里，避免在多个视图里
/// 重复实现 upsert 逻辑。
@MainActor
@Observable
final class PlaybackHistoryStore {
    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func record(bvid: String, aid: Int? = nil) -> PlaybackRecord? {
        let key = bvid.isEmpty ? "av\(aid ?? 0)" : bvid
        var descriptor = FetchDescriptor<PlaybackRecord>(
            predicate: #Predicate { $0.videoKey == key }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func upsert(_ snapshot: PlaybackSnapshot) {
        let existing = record(bvid: snapshot.bvid, aid: snapshot.aid)
        if let existing {
            existing.aid = snapshot.aid
            existing.cid = snapshot.cid
            existing.title = snapshot.title
            existing.coverURLString = snapshot.coverURLString
            existing.ownerName = snapshot.ownerName
            existing.duration = snapshot.duration
            existing.position = snapshot.position
            existing.pageIndex = snapshot.pageIndex
            existing.pageTitle = snapshot.pageTitle
            existing.updatedAt = .now
        } else {
            let record = PlaybackRecord(
                bvid: snapshot.bvid,
                aid: snapshot.aid,
                cid: snapshot.cid,
                title: snapshot.title,
                coverURLString: snapshot.coverURLString,
                ownerName: snapshot.ownerName,
                duration: snapshot.duration,
                position: snapshot.position,
                pageIndex: snapshot.pageIndex,
                pageTitle: snapshot.pageTitle
            )
            context.insert(record)
        }
        save()

        WidgetSnapshotWriter.update(
            title: snapshot.title,
            coverURLString: snapshot.coverURLString,
            bvid: snapshot.bvid,
            cid: snapshot.cid,
            position: snapshot.position,
            duration: snapshot.duration
        )
    }

    func remove(_ record: PlaybackRecord) {
        context.delete(record)
        save()
    }

    func removeAll() {
        let records = (try? context.fetch(FetchDescriptor<PlaybackRecord>())) ?? []
        for record in records {
            context.delete(record)
        }
        save()
    }

    /// 全量导出（用于 WebDAV 备份）。
    func allRecords() -> [PlaybackRecord] {
        let descriptor = FetchDescriptor<PlaybackRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 全量替换（用于 WebDAV 恢复）。
    func importAll(_ records: [PlaybackRecord]) {
        for record in allRecords() {
            context.delete(record)
        }
        for record in records {
            context.insert(record)
        }
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // 历史记录失败不应打断播放，交由上层日志观察。
            #if DEBUG
            print("[History] 保存播放历史失败：\(error)")
            #endif
        }
    }
}
