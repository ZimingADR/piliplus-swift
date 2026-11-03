import SwiftUI

/// 音乐模式：大封面、标题、进度与播放控制。
struct MusicModeSheet: View {
    let controller: PlaybackController

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.10, blue: 0.22),
                        Color(red: 0.05, green: 0.05, blue: 0.09),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer(minLength: 8)

                    RemoteImage(url: controller.coverURL)
                        .frame(width: 288, height: 288 * 9 / 16)
                        .clipShape(.rect(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)

                    VStack(spacing: 6) {
                        Text(controller.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(controller.ownerName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { controller.currentTime },
                                set: { controller.seek(to: $0) }
                            ),
                            in: 0 ... max(controller.duration, 1)
                        )
                        .tint(Glass.pink)

                        HStack {
                            Text(VideoCard.formatDuration(Int(controller.currentTime)))
                            Spacer()
                            Text(VideoCard.formatDuration(Int(controller.duration)))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 28)

                    HStack(spacing: 44) {
                        Button {
                            controller.seek(by: -15)
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        Button {
                            controller.togglePlayPause()
                        } label: {
                            Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 58))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            controller.seek(by: 15)
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.white.opacity(0.9))

                    Label("音乐模式 · 后台播放", systemImage: "music.note")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer(minLength: 8)
                }
            }
            .navigationTitle("音乐模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
