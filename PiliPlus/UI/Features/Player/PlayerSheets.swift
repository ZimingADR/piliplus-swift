import SwiftUI

/// 分P / 选集面板。
struct EpisodeSheet: View {
    let controller: PlaybackController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(controller.pages.enumerated()), id: \.element.id) { index, page in
                    Button {
                        controller.selectPage(index: index)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text("P\(page.page)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(index == controller.currentPageIndex ? Theme.accent : .secondary)
                                .frame(width: 34, alignment: .leading)
                            Text(page.part?.isEmpty == false ? page.part! : "第 \(page.page) P")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if index == controller.currentPageIndex {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                            }
                            Text(page.durationText)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("选集（\(controller.pages.count) P）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 播放器内的弹幕参数面板，修改即写入全局设置。
struct DanmakuSettingsSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var newBlockedKeyword = ""

    var body: some View {
        @Bindable var settings = environment.settings

        NavigationStack {
            Form {
                Section {
                    Toggle("显示弹幕", isOn: $settings.danmakuEnabled)
                }

                Section("样式") {
                    slider(
                        title: "字号",
                        value: $settings.danmakuFontScale,
                        range: 0.6 ... 1.6,
                        step: 0.05,
                        display: "\(Int(settings.danmakuFontScale * 100))%"
                    )
                    slider(
                        title: "不透明度",
                        value: $settings.danmakuOpacity,
                        range: 0.2 ... 1.0,
                        step: 0.05,
                        display: "\(Int(settings.danmakuOpacity * 100))%"
                    )
                    slider(
                        title: "速度",
                        value: $settings.danmakuSpeed,
                        range: 0.5 ... 2.0,
                        step: 0.1,
                        display: String(format: "%.1fx", settings.danmakuSpeed)
                    )
                    slider(
                        title: "显示区域",
                        value: $settings.danmakuArea,
                        range: 0.25 ... 1.0,
                        step: 0.05,
                        display: "\(Int(settings.danmakuArea * 100))%"
                    )
                }

                Section("屏蔽词") {
                    ForEach(settings.danmakuBlockedKeywords, id: \.self) { keyword in
                        HStack {
                            Text(keyword)
                            Spacer()
                            Button {
                                settings.danmakuBlockedKeywords.removeAll { $0 == keyword }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("添加屏蔽关键词", text: $newBlockedKeyword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("添加") {
                            addBlockedKeyword()
                        }
                        .disabled(newBlockedKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section {
                    Button("恢复默认") {
                        settings.resetDanmakuDefaults()
                    }
                }
            }
            .navigationTitle("弹幕设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func addBlockedKeyword() {
        let keyword = newBlockedKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        if !environment.settings.danmakuBlockedKeywords.contains(keyword) {
            environment.settings.danmakuBlockedKeywords.append(keyword)
        }
        newBlockedKeyword = ""
    }

    private func slider(
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
            }
            Slider(value: value, in: range, step: step)
                .tint(Theme.accent)
        }
        .padding(.vertical, 2)
    }
}
