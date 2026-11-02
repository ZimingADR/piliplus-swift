import SwiftUI

/// 设置搜索：按标题/关键词过滤，开关类设置可直接修改，入口类设置可跳转。
struct SettingsSearchScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var query = ""

    var body: some View {
        @Bindable var settings = environment.settings

        List {
            ForEach(filteredItems) { item in
                switch item {
                case .danmaku:
                    Toggle(isOn: $settings.danmakuEnabled) {
                        Label(item.title, systemImage: item.icon)
                    }
                case .backgroundPlayback:
                    Toggle(isOn: $settings.backgroundPlaybackEnabled) {
                        Label(item.title, systemImage: item.icon)
                    }
                case .pictureInPicture:
                    Toggle(isOn: $settings.pictureInPictureEnabled) {
                        Label(item.title, systemImage: item.icon)
                    }
                case .resumePlayback:
                    Toggle(isOn: $settings.resumePlaybackEnabled) {
                        Label(item.title, systemImage: item.icon)
                    }
                case .sponsorBlock:
                    Toggle(isOn: $settings.sponsorBlockEnabled) {
                        Label(item.title, systemImage: item.icon)
                    }
                case .audioOnly:
                    Toggle(isOn: $settings.audioOnlyEnabled) {
                        Label(item.title, systemImage: item.icon)
                    }
                case .loudness:
                    NavigationLink {
                        LoudnessSettingsScreen()
                    } label: {
                        Label(item.title, systemImage: item.icon)
                    }
                case .webdav:
                    NavigationLink {
                        WebDAVSyncScreen()
                    } label: {
                        Label(item.title, systemImage: item.icon)
                    }
                case .logs:
                    NavigationLink {
                        LogsScreen()
                    } label: {
                        Label(item.title, systemImage: item.icon)
                    }
                case .about:
                    NavigationLink {
                        AboutScreen()
                    } label: {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { LiquidBackground() }
        .navigationTitle("搜索设置")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索设置项")
        .overlay {
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("没有匹配的设置", systemImage: "magnifyingglass")
                } description: {
                    Text("试试「弹幕」「备份」「日志」等关键词。")
                }
            }
        }
    }

    private var filteredItems: [SettingsSearchItem] {
        SettingsSearchItem.allCases.filter { $0.matches(query) }
    }
}
