import SwiftUI

/// 推荐流 / 搜索结果共用的视频卡片。
///
/// 视觉层级：封面（16:9）→ 标题（最多两行）→ UP 主与播放量。
/// 不使用渐变蒙版和自定义描边，保持信息密度与原生列表一致的呼吸感。
struct VideoCardTile: View {
    let card: VideoCard
    var showsOwnerFace: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover

            Text(card.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            HStack(spacing: 4) {
                if showsOwnerFace {
                    AvatarImage(url: card.ownerFaceURL, size: 18)
                }
                Text(card.ownerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Label(card.viewText, systemImage: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .labelStyle(.titleAndIcon)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title)，\(card.ownerName)，时长 \(card.durationText)，播放 \(card.viewText)")
    }

    private var cover: some View {
        RemoteImage(url: card.coverURL)
            .aspectRatio(Theme.coverAspect, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
            .overlay(alignment: .bottomTrailing) {
                Text(card.durationText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
                    .padding(6)
            }
            .overlay(alignment: .topLeading) {
                if card.danmakuCount > 0 {
                    Label(VideoCard.formatCount(card.danmakuCount), systemImage: "text.bubble.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.45), in: .capsule)
                        .padding(6)
                }
            }
    }
}

/// 历史 / 搜索结果里的横向列表行。
struct VideoRow: View {
    let title: String
    let coverURL: URL?
    let ownerName: String
    let bottomText: String
    var progress: Double?
    var durationText: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: coverURL)
                .frame(width: 140, height: 140 / Theme.coverAspect)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    if let durationText {
                        Text(durationText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.black.opacity(0.55), in: .rect(cornerRadius: 3))
                            .padding(4)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let progress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Color.black.opacity(0.35)
                                Theme.accent.opacity(0.95)
                                    .frame(width: max(2, proxy.size.width * progress))
                            }
                        }
                        .frame(height: 3)
                        .clipShape(.rect(cornerRadius: 2))
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(ownerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(bottomText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
