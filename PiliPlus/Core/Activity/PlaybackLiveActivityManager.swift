import ActivityKit
import Foundation
import Observation

/// 管理播放实时活动：开始、节流更新、结束。
@MainActor
@Observable
final class PlaybackLiveActivityManager {
    private(set) var activityID: String?

    @ObservationIgnored private var activity: Activity<PlaybackActivityAttributes>?

    var isActive: Bool { activity != nil }

    func start(
        bvid: String,
        cid: Int,
        state: PlaybackActivityAttributes.ContentState
    ) {
        guard activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PlaybackActivityAttributes(bvid: bvid, cid: cid)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            activityID = activity?.id
        } catch {
            activity = nil
            activityID = nil
        }
    }

    func update(_ state: PlaybackActivityAttributes.ContentState) {
        guard let activity else { return }
        let handle = ActivityHandle(activity: activity)
        Task {
            await handle.activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(_ state: PlaybackActivityAttributes.ContentState) {
        guard let activity else { return }
        self.activity = nil
        activityID = nil
        let handle = ActivityHandle(activity: activity)
        Task {
            await handle.activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}

/// `Activity` 本身没有标注 Sendable，但 ActivityKit 的更新/结束接口是线程安全的；
/// 用显式包装跨越 Task 边界，避免把 App 的 MainActor 状态一并发送出去。
private struct ActivityHandle: @unchecked Sendable {
    let activity: Activity<PlaybackActivityAttributes>
}
