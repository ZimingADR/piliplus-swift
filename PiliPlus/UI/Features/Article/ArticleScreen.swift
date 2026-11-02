import SwiftUI
import WebKit

/// 专栏阅读页：原生头部 + WKWebView 正文。
struct ArticleScreen: View {
    let cvid: Int

    @Environment(AppEnvironment.self) private var environment
    @State private var detail: ArticleDetail?
    @State private var phase: Phase = .idle

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        ZStack {
            LiquidBackground()
            content
        }
        .navigationTitle(detail?.title ?? "专栏")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            LoadingStateView(style: .loading)
        case .failed(let message):
            LoadingStateView(style: .failure(message)) {
                Task { await load() }
            }
        case .loaded:
            if let detail {
                VStack(spacing: 0) {
                    header(detail)
                    Divider().opacity(0.4)
                    if detail.contentHTML.isEmpty {
                        ScrollView {
                            Text(detail.fallbackText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(20)
                        }
                    } else {
                        ArticleWebView(html: Self.htmlDocument(for: detail))
                    }
                }
            }
        }
    }

    private func header(_ detail: ArticleDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(detail.title)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                AvatarImage(url: detail.authorFaceURL, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(detail.authorName.isEmpty ? "B 站专栏作者" : detail.authorName)
                        .font(.caption.weight(.medium))
                    HStack(spacing: 8) {
                        if let date = detail.publishDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                        }
                        if detail.viewCount > 0 {
                            Text("\(VideoCard.formatCount(detail.viewCount)) 阅读")
                        }
                        if detail.likeCount > 0 {
                            Text("\(VideoCard.formatCount(detail.likeCount)) 点赞")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func load() async {
        guard detail == nil else { return }
        phase = .loading
        do {
            detail = try await environment.client.articleDetail(cvid: cvid)
            phase = .loaded
        } catch {
            phase = .failed((error as? any LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private static func htmlDocument(for detail: ArticleDetail) -> String {
        let body = detail.contentHTML
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        :root { color-scheme: light dark; }
        body {
            margin: 16px;
            background: transparent;
            color: #1c1c1e;
            font: -apple-system-body;
            font-size: 17px;
            line-height: 1.75;
            word-wrap: break-word;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #f2f2f7; }
        }
        img, video, iframe { max-width: 100%; height: auto; border-radius: 12px; }
        a { color: #fb7299; text-decoration: none; }
        pre, code {
            background: rgba(127, 127, 127, 0.16);
            border-radius: 8px;
            padding: 2px 6px;
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        }
        pre { padding: 12px; overflow-x: auto; }
        blockquote {
            margin: 12px 0;
            padding-left: 12px;
            border-left: 3px solid #fb7299;
            color: rgba(127, 127, 127, 0.95);
        }
        h1, h2, h3 { line-height: 1.35; }
        table { width: 100%; border-collapse: collapse; }
        td, th { border: 1px solid rgba(127, 127, 127, 0.3); padding: 6px; }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }
}

/// WKWebView 桥接（透明背景、按内容自适应宽度）。
struct ArticleWebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator(html: html)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.bilibili.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.html != html else { return }
        context.coordinator.html = html
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.bilibili.com"))
    }

    final class Coordinator {
        var html: String

        init(html: String) {
            self.html = html
        }
    }
}
