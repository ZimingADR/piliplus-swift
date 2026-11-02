import Foundation
import Observation
import SwiftData
import SwiftUI

/// 全局依赖容器。
///
/// Group 1 的依赖非常克制：一个匿名网络客户端、一个设置存储、一个 SwiftData
/// 播放历史仓储、一个系统音频协调器。所有类型都是 `@MainActor`，避免在
/// SwiftUI 视图里做跨 actor 的状态同步。
@MainActor
@Observable
final class AppEnvironment {
    let client: BiliClient
    let settings: SettingsStore
    let history: PlaybackHistoryStore
    let audioSession: AudioSessionCoordinator
    let modelContainer: ModelContainer

    /// 由任意列表发起、`RootView` 统一呈现的全屏播放请求。
    var playerRequest: PlayerRequest?

    init(
        modelContainer: ModelContainer,
        client: BiliClient = .shared,
        settings: SettingsStore = SettingsStore(),
        audioSession: AudioSessionCoordinator = AudioSessionCoordinator()
    ) {
        self.modelContainer = modelContainer
        self.client = client
        self.settings = settings
        self.audioSession = audioSession
        self.history = PlaybackHistoryStore(context: modelContainer.mainContext)
    }

    static func live() -> AppEnvironment {
        let schema = Schema([PlaybackRecord.self])
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration("PiliPlus", schema: schema)
            )
        } catch {
            // 数据库损坏时退回内存存储，保证 App 仍可启动（Group 1 的崩溃防护要求）。
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: fallback)
        }
        return AppEnvironment(modelContainer: container)
    }

    /// SwiftUI 预览 / 单元测试使用的内存环境。
    static func preview() -> AppEnvironment {
        let schema = Schema([PlaybackRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        let defaults = UserDefaults(suiteName: "preview") ?? .standard
        defaults.removePersistentDomain(forName: "preview")
        return AppEnvironment(
            modelContainer: container,
            settings: SettingsStore(defaults: defaults)
        )
    }
}
