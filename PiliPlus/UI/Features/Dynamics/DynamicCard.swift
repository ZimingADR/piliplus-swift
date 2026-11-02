import SwiftUI

/// 动态卡片：作者、正文、媒体与互动计数。
struct DynamicCard: View {
    let item: DynamicItem
    var expandsText: Bool = false

    var onOpenVideo: (VideoCard) -> Void
    var onOpenArticle: (Int) -> Void
    var onOpenDetail: (DynamicItem) -> Void
    var onLike: ((Bool) -> Void)? = nil
    var onRepost: (() -> Void)? = nil

    @State private var isLiked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !item.text.isEmpty {
                Text(item.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(expandsText ? nil : 6)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture { onOpenDetail(item) }
            }

            media
            stats
        }
        .padding(14)
        .liquidGlass(cornerRadius: 22, elevation: 0.7)
    }

    private var header: some View {
        Button {
            onOpenDetail(item)
        } label: {
            HStack(spacing: 10) {
                AvatarImage(url: item.authorFaceURL, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.authorName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let publishedAt = item.publishedAt {
                        Text(Self.relativeTime(publishedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var media: some View {
        switch item.kind {
        case .video:
            if let card = item.video {
                Button {
                    onOpenVideo(card)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        RemoteImage(url: card.coverURL)
                            .frame(width: 132, height: 132 / Theme.coverAspect)
                            .clipShape(.rect(cornerRadius: 10, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Text(card.durationText)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
                                    .padding(4)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                            Text(card.ownerName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            Label(card.viewText + " 播放", systemImage: "play.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

        case .images:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(Array(item.imageURLs.prefix(9).enumerated()), id: \.offset) { _, url in
                    RemoteImage(url: url)
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                        .onTapGesture { onOpenDetail(item) }
                }
            }

        case .article:
            if let cvid = item.articleID {
                Button {
                    onOpenArticle(cvid)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            GlassChip(title: "专栏", systemImage: "doc.text", tint: Glass.blue)
                            Text(item.articleTitle ?? "专栏文章")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        RemoteImage(url: item.articleCoverURL)
                            .frame(width: 84, height: 84)
                            .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 14, style: .continuous))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

        case .text:
            EmptyView()
        }
    }

    private var stats: some View {
        HStack(spacing: 20) {
            Button {
                onRepost?()
            } label: {
                statItem(icon: "arrowshape.turn.up.right", value: item.forwardCount)
            }
            .buttonStyle(.plain)
            .disabled(onRepost == nil)

            Button {
                onOpenDetail(item)
            } label: {
                statItem(icon: "text.bubble", value: item.commentCount)
            }
            .buttonStyle(.plain)

            Button {
                isLiked.toggle()
                onLike?(isLiked)
            } label: {
                statItem(
                    icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    value: max(0, item.likeCount + (isLiked ? 1 : 0)),
                    highlighted: isLiked
                )
            }
            .buttonStyle(.plain)
            .disabled(onLike == nil)

            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    private func statItem(icon: String, value: Int, highlighted: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value > 0 ? VideoCard.formatCount(value) : " ")
                .monospacedDigit()
        }
        .foregroundStyle(highlighted ? Glass.pink : Color.secondary)
    }

    private static func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<60: return "刚刚"
        case ..<3_600: return "\(Int(seconds / 60)) 分钟前"
        case ..<86_400: return "\(Int(seconds / 3_600)) 小时前"
        case ..<2_592_000: return "\(Int(seconds / 86_400)) 天前"
        default: return date.formatted(date: .numeric, time: .omitted)
        }
    }
}
