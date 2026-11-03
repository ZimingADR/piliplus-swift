import Foundation

/// DLNA AVTransport SOAP 控制。
enum DLNACastService {
    enum CastError: LocalizedError {
        case unsupported
        case http(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .unsupported: "该设备不支持 AVTransport 投屏"
            case .http(let code): "投屏请求失败（HTTP \(code)）"
            case .invalidResponse: "投屏设备响应异常"
            }
        }
    }

    static func cast(device: DLNADevice, videoURL: URL, title: String) async throws {
        guard let controlURL = device.controlURL,
              let serviceType = device.avTransportType else {
            throw CastError.unsupported
        }

        try await post(
            controlURL: controlURL,
            soapAction: "\(serviceType)#SetAVTransportURI",
            body: setAVTransportURIBody(
                serviceType: serviceType,
                videoURL: videoURL,
                title: title
            )
        )

        try await post(
            controlURL: controlURL,
            soapAction: "\(serviceType)#Play",
            body: playBody(serviceType: serviceType)
        )
    }

    static func setAVTransportURIBody(
        serviceType: String,
        videoURL: URL,
        title: String
    ) -> String {
        let metadata = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" \
        xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">\
        <item id="0" parentID="-1" restricted="1">\
        <dc:title>\(escape(title))</dc:title>\
        <upnp:class>object.item.videoItem</upnp:class>\
        <res protocolInfo="http-get:*:video/mp4:*">\(escape(videoURL.absoluteString))</res>\
        </item></DIDL-Lite>
        """

        return """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" \
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body>\
        <u:SetAVTransportURI xmlns:u="\(escape(serviceType))">\
        <InstanceID>0</InstanceID>\
        <CurrentURI>\(escape(videoURL.absoluteString))</CurrentURI>\
        <CurrentURIMetaData>\(escape(metadata))</CurrentURIMetaData>\
        </u:SetAVTransportURI>\
        </s:Body></s:Envelope>
        """
    }

    static func playBody(serviceType: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" \
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body>\
        <u:Play xmlns:u="\(escape(serviceType))">\
        <InstanceID>0</InstanceID>\
        <Speed>1</Speed>\
        </u:Play>\
        </s:Body></s:Envelope>
        """
    }

    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func post(
        controlURL: URL,
        soapAction: String,
        body: String
    ) async throws {
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue(soapAction, forHTTPHeaderField: "SOAPACTION")
        request.httpBody = Data(body.utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CastError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw CastError.http(http.statusCode)
        }
    }
}
