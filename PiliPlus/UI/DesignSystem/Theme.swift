import SwiftUI

/// 全局设计令牌。
///
/// 约束：
/// - 间距只取 4/8/12/16/20/24/32 的栅格；
/// - 颜色一律用语义色，深浅色模式自动适配；
/// - 卡片圆角 10pt，与 iOS 系统分组样式一致。
enum Theme {
    static let accent = Color.accentColor
    static let screenPadding: CGFloat = 16
    static let cardRadius: CGFloat = 10
    static let sectionSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 12
    static let coverAspect: CGFloat = 16.0 / 9.0
}

// MARK: - 玻璃拟态

extension View {
    /// 悬浮玻璃面板：用于底部 TabBar、播放器控制条、搜索浮层。
    func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }

    func cardSurface(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        background(Color(.secondarySystemBackground), in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - 通用排版

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 状态视图

struct LoadingStateView: View {
    enum Style {
        case loading
        case empty(title: String, message: String, systemImage: String)
        case failure(message: String, retry: () -> Void)
    }

    let style: Style

    var body: some View {
        switch style {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)

        case .empty(let title, let message, let systemImage):
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(message)
            }
            .padding(.vertical, 32)

        case .failure(let message, let retry):
            ContentUnavailableView {
                Label("加载失败", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding(.vertical, 32)
        }
    }
}

// MARK: - 播放器辅助

extension View {
    func playerChrome() -> some View {
        foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassPanel(cornerRadius: 16)
    }
}
