import Foundation
import Observation

/// 登录账号状态。Cookie 持久化在 Keychain，启动时恢复并刷新资料。
@MainActor
@Observable
final class AccountStore {
    private(set) var profile: AccountProfile?
    private(set) var lastError: String?

    var isLoggedIn: Bool { profile != nil }

    @ObservationIgnored private let client: BiliClient
    @ObservationIgnored private let cookieKey = "account.cookie.v1"

    init(client: BiliClient) {
        self.client = client
    }

    func restore() async {
        guard let cookie = Keychain.read(cookieKey) else { return }
        await client.updateLoginCookie(cookie)
        await refresh()
    }

    func signIn(cookie: String) async {
        Keychain.save(cookie, for: cookieKey)
        await client.updateLoginCookie(cookie)
        await refresh()
    }

    func refresh() async {
        do {
            profile = try await client.accountInfo()
            lastError = nil
        } catch {
            profile = nil
            lastError = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func logout() async {
        Keychain.delete(cookieKey)
        await client.updateLoginCookie(nil)
        profile = nil
        lastError = nil
    }
}
