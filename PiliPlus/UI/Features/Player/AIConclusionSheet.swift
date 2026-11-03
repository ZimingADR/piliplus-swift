import SwiftUI

/// 视频 AI 总结：全文摘要 + 分段提纲，可跳转到对应时间点。
struct AIConclusionSheet: View {
    let bvid: String
    let cid: Int
    let upMid: Int?
    var onSeek: (Double) -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var payload: AIConclusionResponse.Payload?
    @State private var phase: Phase = .loading

    private enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                content
            }
            .navigationTitle("AI 总结")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load() }
            }
        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let summary = payload?.modelResult?.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("摘要", systemImage: "sparkles")
                                .font(.headline)
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(cornerRadius: 18, elevation: 0.6)
                    }

                    ForEach(Array((payload?.modelResult?.outline ?? []).enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 8) {
                            if let title = section.title, !title.isEmpty {
                                Text(title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            ForEach(Array((section.partOutline ?? []).enumerated()), id: \.offset) { _, part in
                                Button {
                                    onSeek(Double(part.timestamp?.value ?? 0))
                                    dismiss()
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(VideoCard.formatDuration(part.timestamp?.value ?? 0))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(Glass.pink)
                                        Text(part.content ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(cornerRadius: 16, elevation: 0.5)
                    }

                    if payload?.modelResult?.summary?.isEmpty != false,
                       (payload?.modelResult?.outline ?? []).isEmpty {
                        ContentUnavailableView {
                            Label("暂无总结", systemImage: "sparkles")
                        } description: {
                            Text("该视频暂时没有 AI 总结。")
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private func load() async {
        phase = .loading
        do {
            payload = try await environment.client.aiConclusion(
                bvid: bvid,
                cid: cid,
                upMid: upMid
            )
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
