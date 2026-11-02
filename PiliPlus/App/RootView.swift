import SwiftUI

/// 临时脚手架视图。
///
/// 该文件会在 Group 1 的 `home` / `main` 模块落地后被正式的
/// `RootView`（悬浮 Liquid Glass TabBar + iPad 双栏）替换。
struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text("PiliPlus")
                .font(.largeTitle.bold())
            Text("Group 1 · 核心播放与发现体验")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
