import SwiftUI

/// 发起投票（创建后由 B 站生成投票动态）。
struct VoteComposeSheet: View {
    var onCreated: () -> Void = {}

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var desc = ""
    @State private var options: [String] = ["", ""]
    @State private var choiceCount = 1
    @State private var durationDays = 7
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showsLogin = false

    private let durationOptions = [1, 3, 7, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("投票标题", text: $title, axis: .vertical)
                        .lineLimit(1 ... 2)
                }

                Section("说明（可选）") {
                    TextField("投票说明", text: $desc, axis: .vertical)
                        .lineLimit(2 ... 4)
                }

                Section("选项") {
                    ForEach(options.indices, id: \.self) { index in
                        HStack {
                            TextField("选项 \(index + 1)", text: $options[index])
                                .textInputAutocapitalization(.never)
                            if options.count > 2 {
                                Button {
                                    options.remove(at: index)
                                    choiceCount = min(choiceCount, options.count)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if options.count < 8 {
                        Button {
                            options.append("")
                        } label: {
                            Label("添加选项", systemImage: "plus.circle")
                        }
                    }
                }

                Section {
                    Stepper("最多可选 \(choiceCount) 项", value: $choiceCount, in: 1 ... max(options.count, 1))
                    Picker("有效期", selection: $durationDays) {
                        ForEach(durationOptions, id: \.self) { days in
                            Text("\(days) 天").tag(days)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await publish() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView().controlSize(.small)
                            }
                            Text("发起投票")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isSending || !canPublish)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { LiquidBackground() }
            .navigationTitle("发起投票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    private var canPublish: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let validOptions = options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return !trimmedTitle.isEmpty && validOptions.count >= 2
    }

    private func publish() async {
        guard canPublish else { return }
        guard environment.account.isLoggedIn else {
            showsLogin = true
            return
        }

        let validOptions = options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        isSending = true
        errorMessage = nil
        do {
            _ = try await environment.client.createVote(
                VoteCreatePayload(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: desc.trimmingCharacters(in: .whitespacesAndNewlines),
                    choiceCount: min(choiceCount, validOptions.count),
                    durationDays: durationDays,
                    options: validOptions
                )
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isSending = false
    }
}
