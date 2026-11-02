import SwiftUI

/// iPhone 底部悬浮玻璃 TabBar。
///
/// 不使用系统 `TabView` 的 bar：Group 1 需要可悬浮在内容之上的 Liquid Glass
/// 胶囊；系统 TabBar 的隐藏与内容避让都在 `RootView` 中处理。
struct GlassTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                item(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityElement(children: .contain)
    }

    private func item(for tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .frame(height: 20)
                Text(tab.title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.accent.opacity(0.14))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
