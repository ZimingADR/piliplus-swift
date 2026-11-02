import SwiftUI

/// WebDAV 备份与恢复（播放历史 + 设置）。
struct WebDAVSyncScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showsRestoreConfirmation = false

    var body: some View {
        @Bindable var webdav = environment.webdav

        Form {
            Section {
                TextField("https://dav.example.com/dav", text: $webdav.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("用户名", text: $webdav.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("密码", text: $webdav.password)
            } header: {
                Text("服务器")
            } footer: {
                Text("填写 WebDAV 根目录或子目录地址，建议使用 HTTPS。凭据仅保存在本机 Keychain。")
            }

            Section("操作") {
                Button {
                    Task { await webdav.testConnection() }
                } label: {
                    Label("测试连接", systemImage: "network")
                }
                .disabled(webdav.isWorking)

                Button {
                    Task { await webdav.upload() }
                } label: {
                    Label("上传备份", systemImage: "arrow.up.circle")
                }
                .disabled(webdav.isWorking)

                Button {
                    showsRestoreConfirmation = true
                } label: {
                    Label("下载并恢复", systemImage: "arrow.down.circle")
                }
                .disabled(webdav.isWorking)
            }

            Section("状态") {
                statusRow(webdav)

                if let lastBackupAt = webdav.lastBackupAt {
                    HStack {
                        Text("上次备份")
                        Spacer()
                        Text(lastBackupAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }

            Section {
                Text("备份文件：\(WebDAVSyncService.fileName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("恢复会覆盖本机播放历史与对应设置，请确认已在其他设备完成备份。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background { LiquidBackground() }
        .navigationTitle("WebDAV 同步")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "恢复备份将覆盖本机历史与设置，确定继续？",
            isPresented: $showsRestoreConfirmation
        ) {
            Button("下载并覆盖", role: .destructive) {
                Task { await webdav.restore() }
            }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func statusRow(_ webdav: WebDAVSyncService) -> some View {
        switch webdav.status {
        case .idle:
            Text("尚未执行同步")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .working(let message):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(message)
                    .font(.caption)
            }
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
