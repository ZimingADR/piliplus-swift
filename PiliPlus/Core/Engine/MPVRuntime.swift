import Foundation
import Libmpv

/// libmpv 运行时信息。
///
/// 该类型同时承担「链接冒烟检查」的职责：只要工程能编译，就说明 MPVKit 的
/// `Libmpv` 二进制目标与 Swift 模块映射在 CI 环境下是可用且可链接的。
enum MPVRuntime {
    /// libmpv 客户端 API 版本，形如 `2.2`。
    static var clientAPIVersion: String {
        let version = mpv_client_api_version()
        let major = version >> 16
        let minor = version & 0xFFFF
        return "\(major).\(minor)"
    }

    /// 当前链接到的 libmpv 版本字符串。
    static var libraryVersion: String {
        guard let pointer = mpv_client_api_version_string() else { return "unknown" }
        return String(cString: pointer)
    }
}
