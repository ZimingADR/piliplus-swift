import SwiftUI

/// Liquid Glass 设计语言。
///
/// 目标是在 iOS 18 上稳定复刻 iOS 26 的玻璃质感：
/// - `.ultraThinMaterial` 提供真实背景模糊；
/// - 镜面高光描边模拟玻璃折射边缘；
/// - 低饱和度色调叠层保证亮/暗色模式下的可读性；
/// - 统一 24pt 连续圆角与悬浮阴影。
enum Glass {
    static let pink = Color(red: 0.984, green: 0.447, blue: 0.600)
    static let blue = Color(red: 0.337, green: 0.612, blue: 0.984)
    static let violet = Color(red: 0.561, green: 0.447, blue: 0.957)
    static let mint = Color(red: 0.298, green: 0.788, blue: 0.706)

    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 20
}

// MARK: - 背景

/// 全局玻璃背景：语义底色 + 两处低饱和光晕。
struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            glow(
                color: Glass.pink,
                size: 460,
                offset: CGSize(width: -150, height: -260),
                opacity: colorScheme == .dark ? 0.26 : 0.22
            )
            glow(
                color: colorScheme == .dark ? Glass.violet : Glass.blue,
                size: 420,
                offset: CGSize(width: 170, height: -140),
                opacity: colorScheme == .dark ? 0.30 : 0.16
            )
        }
        .ignoresSafeArea()
    }

    private func glow(color: Color, size: CGFloat, offset: CGSize, opacity: Double) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 120)
            .offset(offset)
            .blendMode(.plusLighter)
    }
}

// MARK: - 玻璃面板

struct GlassPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = Glass.cardRadius
    var tint: Color = .clear
    var elevation: Double = 1

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.fill(tint.opacity(colorScheme == .dark ? 0.20 : 0.12))
                    }
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.32 : 0.85),
                                .white.opacity(colorScheme == .dark ? 0.06 : 0.28),
                                .white.opacity(0.02),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(shape)
            .shadow(
                color: .black.opacity((colorScheme == .dark ? 0.42 : 0.10) * elevation),
                radius: 22 * elevation,
                y: 10 * elevation
            )
    }
}

extension View {
    /// 标准玻璃卡片。
    func liquidGlass(
        cornerRadius: CGFloat = Glass.cardRadius,
        tint: Color = .clear,
        elevation: Double = 1
    ) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius, tint: tint, elevation: elevation))
    }

    /// 屏幕级背景（含状态栏区域）。
    func liquidScreen() -> some View {
        background { LiquidBackground() }
    }

    /// 让 List / Form 透出玻璃背景。
    func liquidList() -> some View {
        scrollContentBackground(.hidden)
            .background { LiquidBackground() }
    }
}

// MARK: - 按钮

struct GlassButtonStyle: ButtonStyle {
    var tint: Color = .clear
    var cornerRadius: CGFloat = Glass.controlRadius

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.18))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.7), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.22), value: configuration.isPressed)
    }
}

struct GlassIconButton: View {
    let systemName: String
    var tint: Color = .primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: .circle)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 胶囊 / 标签

struct GlassChip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var tint: Color = Glass.pink

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(isSelected ? .white : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.ultraThinMaterial))
        }
        .overlay {
            Capsule().strokeBorder(.white.opacity(isSelected ? 0.35 : 0.25), lineWidth: 0.8)
        }
    }
}

/// 顶部玻璃分段控件，用于首页的 推荐 / 热门 / 排行 / 稍后。
struct GlassSegmentedControl<Value: Hashable>: View {
    let items: [Value]
    let title: (Value) -> String
    @Binding var selection: Value
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                Button {
                    withAnimation(.spring(duration: 0.32, bounce: 0.18)) {
                        selection = item
                    }
                } label: {
                    Text(title(item))
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Glass.pink.gradient)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                                    .shadow(color: Glass.pink.opacity(0.35), radius: 8, y: 3)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
        }
    }
}

// MARK: - 区块标题

struct LiquidSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

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
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Glass.pink)
            }
        }
    }
}
