import Foundation
import Testing

@testable import PiliPlus

@Suite("DLNA")
struct DLNATests {
    @Test("SSDP 响应提取 LOCATION")
    func parsesLocation() throws {
        let response = """
        HTTP/1.1 200 OK\r
        CACHE-CONTROL: max-age=1800\r
        LOCATION: http://192.168.1.10:9197/dmr\r
        ST: urn:schemas-upnp-org:device:MediaRenderer:1\r
        USN: uuid:abc::urn:schemas-upnp-org:device:MediaRenderer:1\r
        \r

        """
        let url = try #require(SSDPMessage.location(from: Data(response.utf8)))
        #expect(url.absoluteString == "http://192.168.1.10:9197/dmr")
    }

    @Test("设备描述 XML 解析")
    func parsesDescription() throws {
        let xml = """
        <?xml version="1.0"?>
        <root>
          <device>
            <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
            <friendlyName>客厅电视</friendlyName>
            <modelName>TV-1000</modelName>
          </device>
        </root>
        """
        let info = try #require(DLNADescription.parse(Data(xml.utf8)))
        #expect(info.name == "客厅电视")
        #expect(info.modelName == "TV-1000")
        #expect(info.deviceType.contains("MediaRenderer"))
    }

    @Test("无效响应返回 nil")
    func rejectsInvalid() {
        #expect(SSDPMessage.location(from: Data("not ssdp".utf8)) == nil)
        #expect(DLNADescription.parse(Data("<root></root>".utf8)) == nil)
    }
}
