import SwiftUI

/// 视频评论区（主楼 + 分页 + 发表评论）。
struct CommentsSheet: View {
    let aid: Int
    var videoTitle: String = ""

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [VideoComment] = []
    @State private var offset = ""
    @State private var isEnd = false
    @State private var total = 0
    @State private var phase: Phase = .idle
    @State private var isLoadingMore = false
    @State private var input = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showsLogin = false
    @FocusState private var isComposerFocused: Bool

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                VStack(spacing: 0) {
                    list
                    composer
                }
            }
            .navigationTitle(total > 0 ? "评论 \(total)" : "评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await load(reset: true) }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    @ViewBuilder
    private var list: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load(reset: true) }
            }
        case .loaded:
            if comments.isEmpty {
                ContentUnavailableView {
                    Label("还没有评论", systemImage: "text.bubble")
                } description: {
                    Text("来抢沙发吧。")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment)
                            Divider().opacity(0.35)
                        }
                        if !isEnd {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .onAppear {
                                    Task { await load(reset: false) }
                                }
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                TextField("发一条友善的评论", text: $input, axis: .vertical)
                    .lineLimit(1 ... 3)
                    .font(.subheadline)
                    .focused($isComposerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))

                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(GlassButtonStyle(tint: Glass.pink, cornerRadius: 16))
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.4)
        }
    }

    private func load(reset: Bool) async {
        if reset {
            phase = .loading
            offset = ""
        } else {
            guard !isLoadingMore, !isEnd else { return }
            isLoadingMore = true
        }

        do {
            let page = try await environment.client.comments(aid: aid, offset: offset)
            let next = page
            if reset {
                comments = next.comments
            } else {
                let existing = Set(comments.map(\.id))
                comments.append(contentsOf: next.comments.filter { !existing.contains($0.id) })
            }
            self.offset = next.nextOffset
            isEnd = next.isEnd
            total = next.total
            phase = .loaded
        } catch {
            if Cancellation.isCancellation(error) {
                isLoadingMore = false
                return
            }
            if reset {
                phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
        isLoadingMore = false
    }

    private func send() async {
        let message = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard environment.account.isLoggedIn else {
            showsLogin = true
            return
        }

        isSending = true
        errorMessage = nil
        do {
            try await environment.client.addReply(aid: aid, message: message)
            input = ""
            isComposerFocused = false
            await load(reset: true)
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSending = false
    }
}

struct CommentRow: View {
    let comment: VideoComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarImage(url: comment.avatarURL, size: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.userName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("LV\(comment.level)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Glass.blue)
                    if comment.isUp {
                        Text("UP")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Glass.pink, in: .rect(cornerRadius: 3))
                    }
                }

                Text(comment.message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 14) {
                    if let createdAt = comment.createdAt {
                        Text(Self.relativeTime(createdAt))
                    }
                    if comment.replyCount > 0 {
                        Label("\(comment.replyCount)", systemImage: "text.bubble")
                    }
                    Spacer(minLength: 0)
                    Label("\(comment.likeCount)", systemImage: "hand.thumbsup")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
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
