import SwiftUI

/// DLNA 投屏：局域网设备发现（当前只做发现与展示）。
struct DLNAScreen: View {
    var mediaTitle: String = ""
    var loadCastURL: (() async -> URL?)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var devices: [DLNADevice] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var errorMessage: String?
    @State private var castingDeviceID: String?
    @State private var castMessage: String?
    @State private var castError: String?
    @State private var proxy: DLNAProxy?

    private let discovery = DLNADiscovery()

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                content
            }
            .navigationTitle("投屏到设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await scan() }
                    } label: {
                        if isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isScanning)
                    .accessibilityLabel("重新扫描")
                }
            }
            .task { await scan() }
            .onDisappear { proxy?.stop() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        if isScanning {
            VStack(spacing: 10) {
                ProgressView()
                Text("正在搜索局域网内的投屏设备…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage {
            LoadingStateView(style: .failure(errorMessage)) {
                Task { await scan() }
            }
        } else if devices.isEmpty {
            ContentUnavailableView {
                Label("没有找到设备", systemImage: "airplayvideo")
            } description: {
                Text("请确认手机与电视/音箱在同一 Wi-Fi，并已开启 DLNA 投屏。")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let castMessage {
                        Label(castMessage, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let castError {
                        Label(castError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    ForEach(devices) { device in
                        deviceRow(device)
                    }

                    Text("投屏使用设备的 AVTransport 服务；若设备无法直接访问 B 站 CDN，可等待后续版本的内置代理。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private func deviceRow(_ device: DLNADevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "appletv.fill")
                .font(.title3)
                .foregroundStyle(Glass.pink)
                .frame(width: 40, height: 40)
                .background(Glass.pink.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !device.modelName.isEmpty {
                        Text(device.modelName)
                    }
                    if !device.deviceType.isEmpty {
                        Text(device.deviceType.components(separatedBy: ":").last ?? "")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            if device.controlURL != nil, loadCastURL != nil {
                Button {
                    Task { await cast(device) }
                } label: {
                    if castingDeviceID == device.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("投屏")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(GlassButtonStyle(tint: Glass.pink, cornerRadius: 12))
                .disabled(castingDeviceID != nil)
            } else {
                Text("不支持")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
    }

    private func cast(_ device: DLNADevice) async {
        guard let loadCastURL else { return }
        castingDeviceID = device.id
        castMessage = nil
        castError = nil
        do {
            guard let remoteURL = await loadCastURL() else {
                throw DLNACastService.CastError.unsupported
            }

            let proxy = DLNAProxy()
            let localURL = try await proxy.start(upstream: remoteURL)
            self.proxy?.stop()
            self.proxy = proxy

            try await DLNACastService.cast(
                device: device,
                videoURL: localURL,
                title: mediaTitle.isEmpty ? "PiliPlus" : mediaTitle
            )
            castMessage = "已通过本机代理发送到 \(device.name)"
        } catch {
            proxy?.stop()
            proxy = nil
            castError = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        castingDeviceID = nil
    }

    private func scan() async {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil
        devices = await discovery.discover()
        hasScanned = true
        isScanning = false
    }
}
