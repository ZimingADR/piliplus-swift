import SwiftUI

/// 楼中楼（子回复）列表与回复输入。
struct RepliesSheet: View {
    let oid: Int
    var type: Int = 1
    let root: VideoComment

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var replies: [VideoComment] = []
    @State private var page = 1
    @State private var isEnd = false
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
                    header
                    content
                    composer
                }
            }
            .navigationTitle("回复")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AvatarImage(url: root.avatarURL, size: 26)
                Text(root.userName)
                    .font(.caption.weight(.semibold))
                if root.isUp {
                    Text("UP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Glass.pink, in: .rect(cornerRadius: 3))
                }
                Spacer(minLength: 0)
            }
            Text(root.message)
                .font(.subheadline)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load(reset: true) }
            }
        case .loaded:
            if replies.isEmpty {
                ContentUnavailableView {
                    Label("还没有回复", systemImage: "text.bubble")
                } description: {
                    Text("来回复第一条吧。")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(replies) { reply in
                            CommentRow(
                                comment: reply,
                                onLike: { liked in
                                    Task {
                                        try? await environment.client.likeComment(
                                            oid: oid,
                                            rpid: reply.id,
                                            like: liked,
                                            type: type
                                        )
                                    }
                                }
                            )
                            .onAppear {
                                if reply.id == replies.last?.id, !isEnd, !isLoadingMore {
                                    Task { await loadMore() }
                                }
                            }
                            Divider().opacity(0.3)
                        }
                        if !isEnd {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 10)
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
                TextField("回复 \(root.userName)", text: $input, axis: .vertical)
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
            page = 1
        }

        do {
            let result = try await environment.client.commentReplies(
                oid: oid,
                root: root.id,
                page: page,
                type: type
            )
            if reset {
                replies = result.comments
            } else {
                let existing = Set(replies.map(\.id))
                replies.append(contentsOf: result.comments.filter { !existing.contains($0.id) })
            }
            isEnd = result.isEnd
            phase = .loaded
        } catch {
            if reset {
                phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
        isLoadingMore = false
    }

    private func loadMore() async {
        guard !isEnd, !isLoadingMore else { return }
        isLoadingMore = true
        page += 1
        await load(reset: false)
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
            try await environment.client.addReply(
                oid: oid,
                type: type,
                message: message,
                root: root.id,
                parent: root.id
            )
            input = ""
            isComposerFocused = false
            await load(reset: true)
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSending = false
    }
}
