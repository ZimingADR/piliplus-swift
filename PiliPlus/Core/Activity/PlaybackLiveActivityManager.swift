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
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(_ state: PlaybackActivityAttributes.ContentState) {
        guard let activity else { return }
        self.activity = nil
        activityID = nil
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}
