import Darwin
import Foundation

struct DLNADevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let location: URL
    let deviceType: String
    let modelName: String
    let controlURL: URL?
    let avTransportType: String?
}

enum SSDPMessage {
    static let search = """
    M-SEARCH * HTTP/1.1\r
    HOST: 239.255.255.250:1900\r
    MAN: "ssdp:discover"\r
    MX: 2\r
    ST: urn:schemas-upnp-org:device:MediaRenderer:1\r
    \r

    """

    static func location(from data: Data) -> URL? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespaces)
                .caseInsensitiveCompare("LOCATION") == .orderedSame {
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                return URL(string: value)
            }
        }
        return nil
    }
}

enum DLNADescription {
    struct Info {
        let name: String
        let deviceType: String
        let modelName: String
        let avTransportType: String?
        let avTransportControlURL: String?
    }

    static func parse(_ data: Data) -> Info? {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return nil }

        let name = delegate.friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return Info(
            name: name,
            deviceType: delegate.deviceType,
            modelName: delegate.modelName,
            avTransportType: delegate.avTransportType.isEmpty ? nil : delegate.avTransportType,
            avTransportControlURL: delegate.avTransportControl.isEmpty ? nil : delegate.avTransportControl
        )
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var friendlyName = ""
        var deviceType = ""
        var modelName = ""
        var avTransportType = ""
        var avTransportControl = ""

        private var current = ""
        private var inService = false
        private var serviceType = ""
        private var serviceControlURL = ""

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String]
        ) {
            current = elementName
            if elementName == "service" {
                inService = true
                serviceType = ""
                serviceControlURL = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            switch current {
            case "friendlyName": friendlyName += string
            case "deviceType": deviceType += string
            case "modelName": modelName += string
            default: break
            }

            if inService {
                switch current {
                case "serviceType": serviceType += string
                case "controlURL": serviceControlURL += string
                default: break
                }
            }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            if elementName == "service" {
                if serviceType.contains("AVTransport") {
                    avTransportType = serviceType.trimmingCharacters(in: .whitespacesAndNewlines)
                    avTransportControl = serviceControlURL.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                inService = false
            }
            current = ""
        }
    }
}

/// SSDP 局域网发现（阻塞 socket 放到后台队列，避免占用主线程）。
final class DLNADiscovery: @unchecked Sendable {
    func discover(timeout: TimeInterval = 3) async -> [DLNADevice] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.scan(timeout: timeout))
            }
        }
    }

    private static func scan(timeout: TimeInterval) -> [DLNADevice] {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return [] }
        defer { close(fd) }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var receiveTimeout = timeval(tv_sec: 0, tv_usec: 400_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, socklen_t(MemoryLayout<timeval>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(1900).bigEndian
        address.sin_addr.s_addr = inet_addr("239.255.255.250")

        let message = Data(SSDPMessage.search.utf8)
        message.withUnsafeBytes { bytes in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    _ = sendto(
                        fd,
                        bytes.baseAddress,
                        message.count,
                        0,
                        sockaddrPointer,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }

        var locations = Set<URL>()
        var buffer = [UInt8](repeating: 0, count: 8_192)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let received = recv(fd, &buffer, buffer.count, 0)
            guard received > 0 else { continue }
            let data = Data(buffer[0 ..< received])
            if let location = SSDPMessage.location(from: data) {
                locations.insert(location)
            }
        }

        return locations.compactMap { location -> DLNADevice? in
            guard let data = try? Data(contentsOf: location),
                  let info = DLNADescription.parse(data) else { return nil }
            let control = info.avTransportControlURL.flatMap {
                URL(string: $0, relativeTo: location)?.absoluteURL
            }
            return DLNADevice(
                id: location.absoluteString,
                name: info.name,
                location: location,
                deviceType: info.deviceType,
                modelName: info.modelName,
                controlURL: control,
                avTransportType: info.avTransportType
            )
        }
        .sorted { $0.name < $1.name }
    }
}
