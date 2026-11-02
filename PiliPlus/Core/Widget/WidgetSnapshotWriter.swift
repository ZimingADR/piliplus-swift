import Foundation
import WidgetKit

/// 把最近播放写入 App Group 并刷新桌面小组件。
enum WidgetSnapshotWriter {
    static func update(
        title: String,
        coverURLString: String,
        bvid: String,
        cid: Int,
        position: Double,
        duration: Double
    ) {
        guard !bvid.isEmpty, !title.isEmpty else { return }

        SharedRecentPlayback(
            title: title,
            coverURLString: coverURLString,
            bvid: bvid,
            cid: cid,
            progress: position,
            duration: duration,
            updatedAt: .now
        )
        .save()

        WidgetCenter.shared.reloadTimelines(ofKind: "PiliPlusRecentWidget")
    }
}
