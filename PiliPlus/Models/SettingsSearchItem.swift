import Foundation

/// 设置搜索条目（标题 + 关键词，命中后直接展示对应控件或入口）。
enum SettingsSearchItem: String, CaseIterable, Identifiable, Sendable {
    case danmaku
    case backgroundPlayback
    case pictureInPicture
    case resumePlayback
    case sponsorBlock
    case audioOnly
    case loudness
    case webdav
    case logs
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .danmaku: "弹幕显示"
        case .backgroundPlayback: "后台播放"
        case .pictureInPicture: "自动画中画"
        case .resumePlayback: "断点续播"
        case .sponsorBlock: "自动跳过赞助片段"
        case .audioOnly: "仅音频模式"
        case .loudness: "智能音量平衡"
        case .webdav: "WebDAV 同步"
        case .logs: "运行日志"
        case .about: "关于 PiliPlus"
        }
    }

    var keywords: [String] {
        switch self {
        case .danmaku: ["弹幕", "danmaku", "字幕"]
        case .backgroundPlayback: ["后台", "播放", "background"]
        case .pictureInPicture: ["画中画", "pip", "小窗"]
        case .resumePlayback: ["续播", "断点", "历史"]
        case .sponsorBlock: ["赞助", "广告", "sponsor", "跳过"]
        case .audioOnly: ["音频", "听视频", "audio"]
        case .loudness: ["音量", "响度", "lufs", "平衡"]
        case .webdav: ["备份", "同步", "恢复", "webdav"]
        case .logs: ["日志", "诊断", "错误", "log"]
        case .about: ["关于", "版本", "开源", "about"]
        }
    }

    var icon: String {
        switch self {
        case .danmaku: "text.bubble"
        case .backgroundPlayback: "play.circle"
        case .pictureInPicture: "pip"
        case .resumePlayback: "clock.arrow.circlepath"
        case .sponsorBlock: "forward.fill"
        case .audioOnly: "headphones"
        case .loudness: "waveform"
        case .webdav: "arrow.triangle.2.circlepath.icloud"
        case .logs: "doc.text.magnifyingglass"
        case .about: "info.circle"
        }
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(trimmed) { return true }
        return keywords.contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}
