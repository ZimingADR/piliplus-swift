import Darwin
import Foundation
import Network

/// 局域网 IPv4（Wi-Fi）。
enum LocalNetworkAddress {
    static func wifiIPv4() -> String? {
        var result: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }
            guard String(cString: interface.ifa_name) == "en0" else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(address.pointee.sa_len)
            if getnameinfo(
                address,
                length,
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                result = String(cString: host)
            }
        }
        return result
    }
}

enum DLNAProxyHTTP {
    static func requestRange(_ request: String) -> String? {
        for line in request.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces)
                .caseInsensitiveCompare("Range") == .orderedSame {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    static func responseHead(status: Int, headers: [(String, String)]) -> Data {
        var lines = ["HTTP/1.1 \(status) \(status == 206 ? "Partial Content" : "OK")"]
        for (key, value) in headers {
            lines.append("\(key): \(value)")
        }
        lines.append("Connection: close")
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }
}

/// 把 B 站视频流转发到局域网，供 DLNA 电视访问（附带 Referer/UA，支持 Range）。
final class DLNAProxy: @unchecked Sendable {
    enum ProxyError: LocalizedError {
        case listenerFailed
        case noLocalAddress
        case badUpstream

        var errorDescription: String? {
            switch self {
            case .listenerFailed: "本地代理启动失败"
            case .noLocalAddress: "无法获取本机局域网 IP，请确认已连接 Wi-Fi"
            case .badUpstream: "视频地址无效"
            }
        }
    }

    private let queue = DispatchQueue(label: "piliplus.dlna.proxy")
    private let lock = NSLock()
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var upstream: URL?
    private(set) var port: UInt16 = 0

    var localURL: URL? {
        guard let ip = LocalNetworkAddress.wifiIPv4(), port > 0 else { return nil }
        return URL(string: "http://\(ip):\(port)/cast")
    }

    func start(upstream: URL) async throws -> URL {
        stop()
        lock.lock()
        self.upstream = upstream
        lock.unlock()

        guard let listener = try? NWListener(using: .tcp) else {
            throw ProxyError.listenerFailed
        }
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    box.resume(.success(listener.port?.rawValue ?? 0))
                case .failed(let error):
                    box.resume(.failure(error))
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }

        guard port > 0 else { throw ProxyError.listenerFailed }
        self.port = port
        guard let url = localURL else { throw ProxyError.noLocalAddress }
        return url
    }

    func stop() {
        listener?.cancel()
        listener = nil
        lock.lock()
        let active = connections
        connections.removeAll()
        lock.unlock()
        active.forEach { $0.cancel() }
        port = 0
    }

    private func handle(_ connection: NWConnection) {
        lock.lock()
        connections.append(connection)
        lock.unlock()

        connection.start(queue: queue)
        receiveRequest(connection, buffer: Data())
    }

    private func receiveRequest(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let header = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self)
                self.respond(connection, request: header)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receiveRequest(connection, buffer: buffer)
            }
        }
    }

    private func respond(_ connection: NWConnection, request: String) {
        lock.lock()
        let upstream = self.upstream
        lock.unlock()

        guard let upstream else {
            connection.send(
                content: DLNAProxyHTTP.responseHead(status: 404, headers: []),
                completion: .contentProcessed { _ in connection.cancel() }
            )
            return
        }

        let range = DLNAProxyHTTP.requestRange(request)

        Task { [weak self] in
            guard let self else { return }
            var urlRequest = URLRequest(url: upstream)
            urlRequest.timeoutInterval = 30
            urlRequest.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
            urlRequest.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
            if let range {
                urlRequest.setValue(range, forHTTPHeaderField: "Range")
            }

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw ProxyError.badUpstream
                }

                var headers: [(String, String)] = []
                for key in ["Content-Type", "Content-Length", "Content-Range", "Accept-Ranges"] {
                    if let value = http.value(forHTTPHeaderField: key) {
                        headers.append((key, value))
                    }
                }
                if http.value(forHTTPHeaderField: "Content-Type") == nil {
                    headers.append(("Content-Type", "video/mp4"))
                }
                headers.append(("Accept-Ranges", "bytes"))

                connection.send(
                    content: DLNAProxyHTTP.responseHead(status: http.statusCode, headers: headers),
                    completion: .idempotent
                )

                var buffer = Data()
                buffer.reserveCapacity(32 * 1_024)
                for try await byte in bytes {
                    buffer.append(byte)
                    if buffer.count >= 32 * 1_024 {
                        let chunk = buffer
                        buffer.removeAll(keepingCapacity: true)
                        connection.send(content: chunk, completion: .idempotent)
                    }
                }
                if !buffer.isEmpty {
                    connection.send(content: buffer, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                } else {
                    connection.cancel()
                }
            } catch {
                connection.cancel()
            }
        }
    }
}

/// 只放行一次 continuation，避免 listener 状态多次回调导致重复 resume。
private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<UInt16, Error>?

    init(_ continuation: CheckedContinuation<UInt16, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<UInt16, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
