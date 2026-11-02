import SwiftUI

/// 关于页：版本、Group 1 模块清单、技术栈与开源声明。
struct AboutScreen: View {
    private let modules: [(String, String)] = [
        ("main", "App 生命周期与全局依赖注入"),
        ("home", "iPhone 悬浮 TabBar / iPad 双栏"),
        ("rcmd", "推荐流与无限分页"),
        ("video", "MPVKit 播放内核与手势"),
        ("danmaku", "CoreAnimation 弹幕"),
        ("audio_normalization", "BewlyCat 三级音量平衡"),
        ("search / trending / result / panel", "搜索全链路"),
        ("history / history_search", "断点续播与历史过滤"),
        ("setting / loudness_setting / about", "偏好、音量平衡与关于"),
    ]

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    icon
                    Text("PiliPlus")
                        .font(.title2.weight(.semibold))
                    Text("纯 Swift 原生 B 站客户端 · Group 1")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(AppInfo.versionText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)

            Section("Group 1 · 核心播放与发现") {
                ForEach(modules, id: \.0) { module in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.0)
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.accent)
                        Text(module.1)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("技术栈") {
                row("界面", "SwiftUI · Observation")
                row("播放", "MPVKit / libmpv + Vulkan(MoltenVK)")
                row("并发", "Swift 6 · 严格并发检查")
                row("存储", "SwiftData（播放历史）+ UserDefaults（偏好）")
                row("网络", "URLSession + Wbi 签名")
                row("弹幕", "CoreAnimation")
            }

            Section("链接") {
                Link(destination: URL(string: "https://github.com/ZimingADR/piliplus-swift")!) {
                    Label("GitHub 仓库", systemImage: "link")
                }
                Link(destination: URL(string: "https://github.com/ZimingADR/PiliNara")!) {
                    Label("Flutter 参考实现 PiliPlus", systemImage: "arrow.up.forward.square")
                }
            }

            Section {
                Text("""
                本项目为第三方客户端，与哔哩哔哩无任何关联。所有视频、弹幕与图片内容版权归 \
                哔哩哔哩及原始作者所有，App 仅做播放展示，不存储、不分发任何内容。\
                仅供学习与技术交流，请勿用于商业用途。
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.accent, Theme.accent.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 88, height: 88)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: 2)
            }
            .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 6)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
