import SwiftUI

/// 带占位骨架的远程图片。
///
/// Group 1 的封面图都来自 B 站 CDN，数量大、尺寸稳定，直接使用 `URLCache`
/// （`URLSession.biliShared` 配置了 128MB 磁盘缓存）即可，无需自建图片缓存。
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(
            url: url,
            transaction: Transaction(animation: .easeOut(duration: 0.2))
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            case .failure:
                placeholder(systemImage: "photo")
            case .empty:
                placeholder(systemImage: nil)
            @unknown default:
                placeholder(systemImage: "photo")
            }
        }
        .background(Color(.tertiarySystemFill))
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Color(.tertiarySystemFill)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

/// 头像（圆形）。
struct AvatarImage: View {
    let url: URL?
    var size: CGFloat = 28

    var body: some View {
        RemoteImage(url: url)
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay {
                Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            }
    }
}
