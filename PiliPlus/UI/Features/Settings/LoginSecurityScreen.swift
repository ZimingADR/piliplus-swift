import SwiftUI

/// 账号安全：登录设备与登录历史。
struct LoginSecurityScreen: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var devices: [LoginDevice] = []
    @State private var logs: [LoginLogEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showsLogin = false

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle("账号安全")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showsLogin) { LoginScreen() }
    }

    @ViewBuilder
    private var content: some View {
        if !environment.account.isLoggedIn {
            ContentUnavailableView {
                Label("登录后查看账号安全", systemImage: "lock.shield")
            } description: {
                Text("登录设备与历史需要账号凭据。")
            } actions: {
                Button("扫码登录") { showsLogin = true }
                    .buttonStyle(GlassButtonStyle(tint: Glass.pink))
            }
        } else if isLoading {
            LoadingStateView(style: .loading)
        } else if let errorMessage {
            LoadingStateView(style: .failure(errorMessage)) {
                Task { await load() }
            }
        } else {
            List {
                Section("登录设备") {
                    if devices.isEmpty {
                        Text("暂无设备信息")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(devices) { device in
                        deviceRow(device)
                    }
                }

                Section("登录历史") {
                    if logs.isEmpty {
                        Text("暂无登录记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(logs.prefix(30)) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.ip)
                                    .font(.caption.monospaced())
                                Spacer()
                                Text(entry.timeAt)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !entry.geo.isEmpty {
                                Text(entry.geo)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func deviceRow(_ device: LoginDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: device.isCurrent ? "iphone.gen3" : "laptopcomputer")
                .foregroundStyle(device.isCurrent ? Glass.pink : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.caption.weight(.semibold))
                    if device.isCurrent {
                        Text("当前设备")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Glass.pink)
                    }
                }
                HStack(spacing: 6) {
                    if !device.source.isEmpty {
                        Text(device.source)
                    }
                    if !device.lastLoginAt.isEmpty {
                        Text(device.lastLoginAt)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        guard environment.account.isLoggedIn else {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            devices = try await environment.client.loginDevices()
        } catch {
            devices = []
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        do {
            logs = try await environment.client.loginLog()
        } catch {
            logs = []
        }

        isLoading = false
    }
}
