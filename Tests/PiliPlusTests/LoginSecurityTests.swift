import Foundation
import Testing

@testable import PiliPlus

@Suite("LoginSecurity")
struct LoginSecurityTests {
    @Test("登录设备解码")
    func decodesDevices() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "devices": [
              {
                "device_name": "iPhone 17 Pro",
                "is_current_device": true,
                "latest_login_at": "2026-01-01 10:00:00",
                "source": "iOS"
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            LoginDevicesResponse.self,
            from: Data(json.utf8)
        )
        let item = try #require(response.data?.devices?.first)
        #expect(item.deviceName == "iPhone 17 Pro")
        #expect(item.isCurrentDevice == true)
        #expect(item.source == "iOS")
    }

    @Test("登录历史解码")
    func decodesLog() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "list": [
              {
                "ip": "1.2.3.4",
                "time_at": "2026-01-01 10:00:00",
                "geo": "上海"
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            LoginLogResponse.self,
            from: Data(json.utf8)
        )
        let item = try #require(response.data?.list?.first)
        #expect(item.ip == "1.2.3.4")
        #expect(item.timeAt == "2026-01-01 10:00:00")
        #expect(item.geo == "上海")
    }
}
