import SwiftUI

/// DLNA 投屏：局域网设备发现（当前只做发现与展示）。
struct DLNAScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var devices: [DLNADevice] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var errorMessage: String?

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
                    ForEach(devices) { device in
                        deviceRow(device)
                    }

                    Text("设备发现已完成。视频投屏代理将在后续版本接入。")
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
        }
        .padding(12)
        .liquidGlass(cornerRadius: 16, elevation: 0.6)
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
