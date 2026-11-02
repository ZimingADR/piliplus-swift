import SwiftUI
import WidgetKit

struct RecentEntry: TimelineEntry {
    let date: Date
    let recent: SharedRecentPlayback?
}

struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: .now, recent: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        completion(RecentEntry(date: .now, recent: SharedRecentPlayback.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        let entry = RecentEntry(date: .now, recent: SharedRecentPlayback.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct RecentWidgetView: View {
    let entry: RecentEntry

    private var link: URL? {
        entry.recent?.deepLink ?? URL(string: "piliplus://history")
    }

    var body: some View {
        Group {
            if let recent = entry.recent {
                content(recent)
            } else {
                emptyState
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.45, blue: 0.60),
                    Color(red: 0.66, green: 0.40, blue: 0.96),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(link)
    }

    private func content(_ recent: SharedRecentPlayback) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("PiliPlus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
                Image(systemName: "play.rectangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(recent.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            ProgressView(value: recent.fraction)
                .tint(.white)
                .background(.white.opacity(0.25))

            Text("继续观看 · 已看 \(Int(recent.fraction * 100))%")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PiliPlus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer(minLength: 0)

            Text("打开 PiliPlus")
                .font(.headline)
                .foregroundStyle(.white)
            Text("看过的视频会出现在这里")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(2)
    }
}

struct PiliPlusRecentWidget: Widget {
    let kind = "PiliPlusRecentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentProvider()) { entry in
            RecentWidgetView(entry: entry)
        }
        .configurationDisplayName("继续观看")
        .description("显示最近播放的视频，点击直接续播。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PiliPlusWidgetBundle: WidgetBundle {
    var body: some Widget {
        PiliPlusRecentWidget()
    }
}
