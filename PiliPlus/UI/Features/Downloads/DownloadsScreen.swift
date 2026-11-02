import SwiftUI

/// 离线下载列表。
struct DownloadsScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selectedItem: DownloadItem?

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("离线下载")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            environment.downloads.load()
        }
        .navigationDestination(item: $selectedItem) { item in
            DownloadedDetailScreen(item: item)
        }
    }

    @ViewBuilder
    private var content: some View {
        if environment.downloads.items.isEmpty {
            ContentUnavailableView {
                Label("还没有离线视频", systemImage: "arrow.down.circle")
            } description: {
                Text("在播放器「更多」菜单中点击「离线下载」，即可保存 DASH 双轨到本机。")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(environment.downloads.items) { item in
                        Button {
                            play(item)
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                environment.downloads.delete(item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private func row(_ item: DownloadItem) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: item.coverURL)
                .frame(width: 120, height: 120 / Theme.coverAspect)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Text(item.durationText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
                        .padding(4)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Text(item.ownerName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Label(item.sizeText, systemImage: "internaldrive")
                    Text("\(item.quality)P")
                    Spacer(minLength: 0)
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Glass.pink)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 18, elevation: 0.6)
    }

    private func play(_ item: DownloadItem) {
        environment.playerRequest = PlayerRequest(downloaded: item)
    }
}

/// 单个离线视频详情：可直接播放、查看文件信息与删除。
struct DownloadedDetailScreen: View {
    let item: DownloadItem
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LiquidBackground()
            ScrollView {
                VStack(spacing: 16) {
                    RemoteImage(url: item.coverURL)
                        .aspectRatio(Theme.coverAspect, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.ownerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Label(item.durationText, systemImage: "clock")
                            Label(item.sizeText, systemImage: "internaldrive")
                            Label("\(item.quality)P", systemImage: "4k.tv")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        environment.playerRequest = PlayerRequest(downloaded: item)
                    } label: {
                        Label("离线播放", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))

                    Button(role: .destructive) {
                        environment.downloads.delete(item)
                        dismiss()
                    } label: {
                        Label("删除下载", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle(tint: .red))
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("离线视频")
        .navigationBarTitleDisplayMode(.inline)
    }
}
