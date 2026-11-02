import ActivityKit
import SwiftUI
import WidgetKit

/// 锁屏 / 灵动岛播放卡片。
struct PlaybackLockScreenView: View {
    let context: ActivityViewContext<PlaybackActivityAttributes>

    private var state: PlaybackActivityAttributes.ContentState { context.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GlassWidget.pink)

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(state.ownerName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(state.percentText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: state.fraction)
                .tint(GlassWidget.pink)

            HStack {
                Text(Self.format(state.elapsed))
                Spacer()
                Text(Self.format(state.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .widgetURL(context.attributes.deepLink)
    }

    private static func format(_ seconds: Double) -> String {
        VideoCardFormatting.formatDuration(Int(max(seconds, 0)))
    }
}

/// Widget 扩展内复用的小型格式化工具（避免引用 App 内部类型）。
enum VideoCardFormatting {
    static func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "00:00" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

enum GlassWidget {
    static let pink = Color(red: 0.98, green: 0.45, blue: 0.60)
}

struct PlaybackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaybackActivityAttributes.self) { context in
            PlaybackLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                        .foregroundStyle(GlassWidget.pink)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(state.ownerName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: state.fraction)
                        .tint(GlassWidget.pink)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundStyle(GlassWidget.pink)
            } compactTrailing: {
                Text(state.percentText)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "play.fill")
                    .foregroundStyle(GlassWidget.pink)
            }
        }
    }
}
