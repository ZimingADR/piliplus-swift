import SwiftUI

/// 与单个用户的私信对话。
struct IMChatScreen: View {
    let talkerID: Int
    let name: String

    @Environment(AppEnvironment.self) private var environment

    @State private var messages: [IMMessage] = []
    @State private var input = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            LiquidBackground()
            VStack(spacing: 0) {
                content
                composer
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            LoadingStateView(style: .loading)
        } else if messages.isEmpty {
            ContentUnavailableView {
                Label("还没有消息", systemImage: "bubble.left")
            } description: {
                Text("打个招呼吧。")
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            bubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .task {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func bubble(_ message: IMMessage) -> some View {
        let isMine = message.senderUID == environment.account.profile?.mid
        return HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(isMine ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isMine ? Glass.pink : Color.white.opacity(0.12),
                        in: .rect(cornerRadius: 14, style: .continuous)
                    )
                Text(Date(timeIntervalSince1970: TimeInterval(message.timestamp)).formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !isMine { Spacer(minLength: 40) }
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
                TextField("发消息…", text: $input, axis: .vertical)
                    .lineLimit(1 ... 3)
                    .focused($isFocused)
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
    }

    private func load() async {
        isLoading = true
        do {
            let list = try await environment.client.imMessages(talkerID: talkerID)
            messages = list.sorted { $0.timestamp < $1.timestamp }
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let selfUID = environment.account.profile?.mid else {
            errorMessage = "请先登录"
            return
        }

        isSending = true
        errorMessage = nil
        let pending = IMMessage(
            id: "local-\(UUID().uuidString)",
            senderUID: selfUID,
            timestamp: Int(Date.now.timeIntervalSince1970),
            text: text
        )
        messages.append(pending)
        input = ""
        isFocused = false

        do {
            try await environment.client.sendIMMessage(
                talkerID: talkerID,
                selfUID: selfUID,
                text: text
            )
            await load()
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSending = false
    }
}
