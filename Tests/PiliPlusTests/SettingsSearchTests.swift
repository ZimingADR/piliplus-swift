import Testing

@testable import PiliPlus

@Suite("SettingsSearch")
struct SettingsSearchTests {
    @Test("空关键词返回全部设置项")
    func emptyQueryMatchesAll() {
        #expect(SettingsSearchItem.allCases.allSatisfy { $0.matches("") })
        #expect(SettingsSearchItem.allCases.allSatisfy { $0.matches("   ") })
    }

    @Test("标题与关键词命中")
    func matchesTitleAndKeywords() {
        #expect(SettingsSearchItem.danmaku.matches("弹幕"))
        #expect(SettingsSearchItem.webdav.matches("备份"))
        #expect(SettingsSearchItem.webdav.matches("webdav"))
        #expect(SettingsSearchItem.logs.matches("日志"))
        #expect(SettingsSearchItem.about.matches("开源"))
    }

    @Test("大小写不敏感")
    func caseInsensitive() {
        #expect(SettingsSearchItem.webdav.matches("WEBDAV"))
        #expect(SettingsSearchItem.pictureInPicture.matches("PIP"))
    }

    @Test("无关关键词不命中")
    func noMatch() {
        #expect(!SettingsSearchItem.danmaku.matches("下载"))
    }
}
