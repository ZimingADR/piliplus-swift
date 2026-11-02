import AppIntents
import Foundation

/// Siri / 聚焦 / 快捷指令入口。
///
/// Intent 本身不直接操作 UI，而是通过 `piliplus://` 深链交给 App 处理，
/// 这样 Intents、小组件与分享链接共用一套路由。

struct OpenRecommendIntent: AppIntent {
    static let title: LocalizedStringResource = "打开推荐"
    static let description = IntentDescription("打开 PiliPlus 首页推荐")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        let url = DeepLinkRoute.url(for: .home)!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct OpenHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "打开播放历史"
    static let description = IntentDescription("打开 PiliPlus 的播放历史")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        let url = DeepLinkRoute.url(for: .history)!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct SearchVideosIntent: AppIntent {
    static let title: LocalizedStringResource = "搜索视频"
    static let description = IntentDescription("在 PiliPlus 中搜索视频")
    static let openAppWhenRun = true

    @Parameter(title: "关键词")
    var keyword: String

    init() {}

    init(keyword: String) {
        self.keyword = keyword
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        let url = DeepLinkRoute.url(for: .search(keyword: keyword))!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct PiliPlusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRecommendIntent(),
            phrases: [
                "打开 \(.applicationName)",
                "用 \(.applicationName) 看推荐",
            ],
            shortTitle: "打开推荐",
            systemImageName: "play.rectangle.fill"
        )

        AppShortcut(
            intent: OpenHistoryIntent(),
            phrases: [
                "用 \(.applicationName) 看播放历史",
                "打开 \(.applicationName) 的播放历史",
            ],
            shortTitle: "播放历史",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
