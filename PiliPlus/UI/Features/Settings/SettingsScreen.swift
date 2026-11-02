import SwiftUI

/// 设置页：播放偏好、弹幕参数、音量平衡入口、外观与关于。
struct SettingsScreen: View {
    @Environment(AppEnvironment.self) private var environment

    private let qualityOptions = [
        BiliQuality.quality360p,
        BiliQuality.quality480p,
        BiliQuality.quality720p,
        BiliQuality.quality1080p,
        BiliQuality.quality1080pPlus,
        BiliQuality.quality1080p60,
        BiliQuality.quality4K,
        BiliQuality.quality8K,
    ]

    var body: some View {
        @Bindable var settings = environment.settings

        List {
            Section {
                NavigationLink {
                    SettingsSearchScreen()
                } label: {
                    Label("搜索设置", systemImage: "magnifyingglass")
                }
            }

            Section("播放") {
                Picker("默认清晰度", selection: $settings.defaultQuality) {
                    ForEach(qualityOptions, id: \.self) { quality in
                        Text(BiliQuality.title(for: quality)).tag(quality)
                    }
                }
                Picker("解码偏好", selection: $settings.codecPreference) {
                    ForEach(VideoCodecPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                Toggle("后台播放", isOn: $settings.backgroundPlaybackEnabled)
                Toggle("自动画中画", isOn: $settings.pictureInPictureEnabled)
                Toggle("断点续播", isOn: $settings.resumePlaybackEnabled)
                Toggle("自动跳过赞助片段", isOn: $settings.sponsorBlockEnabled)
            }

            Section {
                Toggle("显示弹幕", isOn: $settings.danmakuEnabled)
                sliderRow(
                    title: "字号",
                    value: $settings.danmakuFontScale,
                    range: 0.6 ... 1.6,
                    step: 0.05,
                    display: "\(Int(settings.danmakuFontScale * 100))%"
                )
                sliderRow(
                    title: "不透明度",
                    value: $settings.danmakuOpacity,
                    range: 0.2 ... 1.0,
                    step: 0.05,
                    display: "\(Int(settings.danmakuOpacity * 100))%"
                )
                sliderRow(
                    title: "速度",
                    value: $settings.danmakuSpeed,
                    range: 0.5 ... 2.0,
                    step: 0.1,
                    display: String(format: "%.1fx", settings.danmakuSpeed)
                )
                sliderRow(
                    title: "显示区域",
                    value: $settings.danmakuArea,
                    range: 0.25 ... 1.0,
                    step: 0.05,
                    display: "\(Int(settings.danmakuArea * 100))%"
                )
                Button("恢复默认弹幕参数") {
                    settings.resetDanmakuDefaults()
                }
            } header: {
                Text("弹幕")
            } footer: {
                Text("弹幕由 CoreAnimation 渲染，字号与速度实时生效，显示区域控制弹幕最多占用的画面高度。")
            }

            Section("音量平衡") {
                NavigationLink {
                    LoudnessSettingsScreen()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("智能音量平衡")
                        Text(settings.audioNormalizationSummary.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("同步与备份") {
                NavigationLink {
                    WebDAVSyncScreen()
                } label: {
                    Label("WebDAV 同步", systemImage: "arrow.triangle.2.circlepath.icloud")
                }
            }

            Section("诊断") {
                NavigationLink {
                    LogsScreen()
                } label: {
                    Label("运行日志", systemImage: "doc.text.magnifyingglass")
                }
            }

            Section("外观") {
                Picker("主题", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("关于") {
                NavigationLink {
                    AboutScreen()
                } label: {
                    Label("关于 PiliPlus", systemImage: "info.circle")
                }
            }

            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(AppInfo.versionText)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("播放内核")
                    Spacer()
                    Text("libmpv \(MPVRuntime.clientAPIVersion)")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("PiliPlus 是第三方客户端，仅供学习与技术交流使用。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background { LiquidBackground() }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(display)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Slider(value: value, in: range, step: step)
                .tint(Theme.accent)
        }
        .padding(.vertical, 2)
    }
}

enum AppInfo {
    static var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
