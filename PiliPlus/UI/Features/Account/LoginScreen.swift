import CoreImage.CIFilterBuiltins
import SwiftUI

/// 二维码渲染（纯 CoreImage，无第三方依赖）。
struct QRCodeImage: View {
    let content: String

    var body: some View {
        Group {
            if let image = Self.makeImage(from: content) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .accessibilityLabel("登录二维码")
    }

    private static func makeImage(from content: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// 扫码登录页。
struct LoginScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var session: QRLoginSession?
    @State private var status: QRLoginPollResult.State = .waiting
    @State private var statusMessage = "正在获取二维码…"
    @State private var isExpired = false
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    QRCodeImage(content: session?.url ?? "")
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .liquidGlass(cornerRadius: 28)
                        .overlay {
                            if status == .expired || isExpired {
                                expiredOverlay
                            }
                        }

                    statusView

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await loadQRCode() }
                    } label: {
                        Label("刷新二维码", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle())

                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .liquidScreen()
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task { await loadQRCode() }
        .onDisappear { pollTask?.cancel() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Glass.pink)
            Text("登录 B 站账号")
                .font(.title3.weight(.semibold))
            Text("登录后可同步收藏、关注、稍后再看，并解锁大会员清晰度。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var statusView: some View {
        HStack(spacing: 8) {
            switch status {
            case .waiting:
                ProgressView().controlSize(.small)
            case .scanned:
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundStyle(Glass.blue)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .expired:
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.8) }
    }

    private var expiredOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("二维码已失效")
                    .font(.subheadline.weight(.medium))
                Button("重新获取") {
                    Task { await loadQRCode() }
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("使用哔哩哔哩 App 扫描二维码")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("登录信息仅保存在本机 Keychain，不会上传到任何第三方服务器。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private func loadQRCode() async {
        pollTask?.cancel()
        errorMessage = nil
        isExpired = false
        status = .waiting
        statusMessage = "正在获取二维码…"
        session = nil

        do {
            let session = try await environment.client.qrLoginSession()
            self.session = session
            statusMessage = "等待扫码"
            startPolling(key: session.key)
        } catch {
            status = .failed
            statusMessage = "二维码获取失败"
            errorMessage = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func startPolling(key: String) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                do {
                    let result = try await environment.client.qrLoginPoll(key: key)
                    status = result.state
                    statusMessage = result.message
                    switch result.state {
                    case .succeeded:
                        guard let cookie = result.cookie else {
                            status = .failed
                            statusMessage = "登录成功但未获取到 Cookie"
                            return
                        }
                        await environment.account.signIn(cookie: cookie)
                        dismiss()
                        return
                    case .expired, .failed:
                        isExpired = result.state == .expired
                        return
                    case .waiting, .scanned:
                        continue
                    }
                } catch {
                    if Cancellation.isCancellation(error) { return }
                    statusMessage = "网络异常，重试中…"
                }
            }
        }
    }
}
