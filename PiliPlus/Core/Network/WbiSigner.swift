import CryptoKit
import Foundation

/// Bilibili Wbi 请求签名（`wts` + `w_rid`）。
///
/// 对应 Flutter 版 `lib/utils/wbi_sign.dart`，协议说明见
/// [bilibili-API-collect / wbi](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md)。
///
/// 签名流程：
/// 1. 用 `img_key` + `sub_key`（各 32 个字符）按混淆表重排出 32 位 `mixinKey`；
/// 2. 追加 `wts`（Unix 秒），按 key 字典序排序，丢弃 value 中的 `!'()*` 后做
///    `encodeURIComponent` 编码，拼成 `k=v&k=v`；
/// 3. `w_rid = md5(sortedQuery + mixinKey)`。
///
/// 该类型是纯函数集合，方便用固定向量做回归测试。
public enum WbiSigner {
    /// Wbi 混淆表。上游协议给出 64 项，但只使用前 32 项生成 32 位 mixinKey，
    /// 因此这里直接保存截断后的表（与 Flutter 参考实现一致）。
    public static let mixinKeyEncTable: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
        33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    ]

    /// 与服务端 `encodeURIComponent` 行为一致的保留字符集合。
    private static let unreservedScalars = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~!*'()"
    )

    /// 签名前需要从参数值里剔除的字符（对应 Dart 的 `[!'()*]` 过滤）。
    private static let filteredScalars = CharacterSet(charactersIn: "!'()*")

    /// 由 `img_key` / `sub_key` 生成 mixinKey；输入不足 64 位时返回空串。
    public static func mixinKey(imgKey: String, subKey: String) -> String {
        let raw = Array((imgKey + subKey).unicodeScalars)
        guard raw.count >= 64 else { return "" }
        var view = String.UnicodeScalarView()
        for index in mixinKeyEncTable {
            view.append(raw[index])
        }
        return String(view)
    }

    /// 为一组参数生成签名，返回包含 `wts` 与 `w_rid` 的新字典。
    ///
    /// - Parameter timestamp: Unix 秒。默认取当前时间，测试时可注入固定值。
    public static func sign(
        _ parameters: [String: String],
        mixinKey: String,
        timestamp: Int = Int(Date().timeIntervalSince1970)
    ) -> [String: String] {
        var signed = parameters
        signed["wts"] = String(timestamp)
        let query = canonicalQuery(signed)
        let digest = Insecure.MD5.hash(data: Data((query + mixinKey).utf8))
        signed["w_rid"] = digest.map { String(format: "%02x", $0) }.joined()
        return signed
    }

    /// 生成可直接拼到 URL 上的已签名字符串（含 `wts` / `w_rid`）。
    public static func signedQuery(
        _ parameters: [String: String],
        mixinKey: String,
        timestamp: Int = Int(Date().timeIntervalSince1970)
    ) -> String {
        canonicalQuery(sign(parameters, mixinKey: mixinKey, timestamp: timestamp))
    }

    /// 按 key 字典序生成 `encodeURIComponent` 风格的查询串。
    public static func canonicalQuery(_ parameters: [String: String]) -> String {
        parameters.keys.sorted().compactMap { key -> String? in
            guard let value = parameters[key] else { return nil }
            let sanitized = String(String.UnicodeScalarView(
                value.unicodeScalars.filter { !filteredScalars.contains($0) }
            ))
            return "\(percentEncode(key))=\(percentEncode(sanitized))"
        }
        .joined(separator: "&")
    }

    /// 等价于 JavaScript `encodeURIComponent`（UTF-8，大写十六进制）。
    public static func percentEncode(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.utf8.count * 3)
        for scalar in value.unicodeScalars {
            if unreservedScalars.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                for byte in String(scalar).utf8 {
                    result += String(format: "%%%02X", byte)
                }
            }
        }
        return result
    }
}
