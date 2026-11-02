import Foundation

extension BiliClient {
    /// 当前账号的登录设备。
    func loginDevices() async throws -> [LoginDevice] {
        var query: [String: String] = [:]
        if let csrf = csrfToken() {
            query["csrf"] = csrf
        }

        let payload: LoginDevicesResponse.Payload = try await object(
            LoginDevicesResponse.Payload.self,
            path: "/x/safecenter/user_login_devices",
            query: query,
            host: .passport,
            signed: false
        )

        return (payload.devices ?? []).enumerated().compactMap { index, item in
            guard let name = item.deviceName, !name.isEmpty else { return nil }
            return LoginDevice(
                id: "\(index)-\(name)",
                name: name,
                isCurrent: item.isCurrentDevice ?? false,
                lastLoginAt: item.latestLoginAt ?? "",
                source: item.source ?? ""
            )
        }
    }

    /// 登录历史。
    func loginLog() async throws -> [LoginLogEntry] {
        let payload: LoginLogResponse.Payload = try await object(
            LoginLogResponse.Payload.self,
            path: "/x/member/web/login/log",
            query: [
                "jsonp": "jsonp",
                "web_location": "333.33",
            ],
            signed: false
        )

        return (payload.list ?? []).compactMap { item in
            let ip = item.ip ?? ""
            guard !ip.isEmpty else { return nil }
            return LoginLogEntry(
                ip: ip,
                timeAt: item.timeAt ?? "",
                geo: item.geo ?? ""
            )
        }
    }
}
