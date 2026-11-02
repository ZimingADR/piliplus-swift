import Testing

@testable import PiliPlus

@Suite("WbiSigner")
struct WbiSignerTests {
    private let imgKey = "7cd084941338484aae1ad9425b84077c"
    private let subKey = "4932caff0ff746eab6f01bf08b70ac45"

    @Test("mixinKey 与协议官方示例一致")
    func mixinKeyMatchesReference() {
        let key = WbiSigner.mixinKey(imgKey: imgKey, subKey: subKey)
        #expect(key == "ea1db124af3c7062474693fa704f4ff8")
        #expect(key.count == 32)
    }

    @Test("mixinKey 输入不足 64 位时返回空串")
    func mixinKeyRejectsShortInput() {
        #expect(WbiSigner.mixinKey(imgKey: "abc", subKey: "def").isEmpty)
    }

    @Test("官方签名向量：w_rid 与排序后的查询串一致")
    func signatureVector() {
        let signed = WbiSigner.sign(
            ["foo": "114", "bar": "514", "zab": "1919810"],
            mixinKey: "ea1db124af3c7062474693fa704f4ff8",
            timestamp: 1_702_204_169
        )

        #expect(signed["w_rid"] == "8f6f2b5b3d485fe1886cec6a0be8c5d4")
        #expect(
            WbiSigner.canonicalQuery(signed)
                == "bar=514&foo=114&w_rid=8f6f2b5b3d485fe1886cec6a0be8c5d4&wts=1702204169&zab=1919810"
        )
    }

    @Test("特殊字符过滤与 encodeURIComponent 编码")
    func encodesLikeJavaScript() {
        let signed = WbiSigner.sign(
            ["keyword": "a b&c=d!e(f)g*h'i\"j", "bvid": "BV1xx411c7mD", "pn": "1"],
            mixinKey: "ea1db124af3c7062474693fa704f4ff8",
            timestamp: 1_702_204_169
        )

        #expect(signed["w_rid"] == "410fb4252f3e7172a8dcaf387bd5801e")
        #expect(WbiSigner.percentEncode("a b&c=d") == "a%20b%26c%3Dd")
        #expect(WbiSigner.percentEncode("中文") == "%E4%B8%AD%E6%96%87")
        #expect(WbiSigner.canonicalQuery(["k": "a!b'c(d)e*f"]) == "k=abcdef")
    }
}
