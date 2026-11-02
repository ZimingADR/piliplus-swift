import SwiftUI
import UIKit

/// 运行日志：网络失败与关键错误，便于无 Xcode 环境下排查。
struct LogsScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var copied = false

    var body: some View {
        @Bindable var logs = environment.logs

        List {
            if logs.entries.isEmpty {
                ContentUnavailableView {
                    Label("暂无日志", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("网络请求失败或播放异常时会记录在这里。")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(logs.entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.level.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(entry.level.tint)
                            Spacer(minLength: 0)
                            Text(entry.date.formatted(date: .omitted, time: .standard))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        Text(entry.message)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { LiquidBackground() }
        .navigationTitle("运行日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = logs.entries
                            .map { "\($0.date.formatted()) [\($0.level.rawValue)] \($0.message)" }
                            .joined(separator: "\n")
                        copied = true
                    } label: {
                        Label("复制全部", systemImage: "doc.on.doc")
                    }
                    .disabled(logs.entries.isEmpty)

                    Button(role: .destructive) {
                        logs.clear()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    .disabled(logs.entries.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("已复制", isPresented: $copied) {
            Button("好", role: .cancel) {}
        }
    }
}

private extension LogStore.Entry.Level {
    var title: String {
        switch self {
        case .info: "信息"
        case .warning: "警告"
        case .error: "错误"
        }
    }

    var tint: Color {
        switch self {
        case .info: .secondary
        case .warning: .orange
        case .error: .red
        }
    }
}
