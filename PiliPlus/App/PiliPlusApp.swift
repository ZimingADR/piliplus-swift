import SwiftUI

/// 应用入口。
///
/// Group 1 只需要一个无需登录即可使用的播放器，因此启动路径刻意保持极短：
/// 1. 构建 `AppEnvironment`（网络 / 设置 / 播放历史）；
/// 2. 注入 SwiftData `ModelContainer`；
/// 3. 交给 `RootView` 决定 iPhone 悬浮 TabBar 或 iPad 双栏布局。
@main
struct PiliPlusApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
