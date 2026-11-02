import Foundation
import Testing

@testable import PiliPlus

@Suite("DanmakuFilter")
struct DanmakuFilterTests {
    private func item(_ content: String, id: Int64 = 1) -> DanmakuItem {
        DanmakuItem(
            id: id,
            time: 0,
            mode: .scrolling,
            fontScale: 25,
            color: 0xFFFFFF,
            content: content,
            weight: 0
        )
    }

    @Test("命中关键词的弹幕被过滤（大小写不敏感）")
    func filtersKeywords() {
        let items = [
            item("前方高能", id: 1),
            item("Buy NOW", id: 2),
            item("普通弹幕", id: 3),
        ]

        let filtered = DanmakuFilter.apply(items, blockedKeywords: ["高能", "buy now"])
        #expect(filtered.map(\.id) == [3])
    }

    @Test("空关键词返回原列表")
    func emptyKeywords() {
        let items = [item("a"), item("b")]
        #expect(DanmakuFilter.apply(items, blockedKeywords: []).count == 2)
        #expect(DanmakuFilter.apply(items, blockedKeywords: ["  "]).count == 2)
    }

    @Test("首尾空格被忽略")
    func trimsKeywords() {
        let items = [item("广告内容")]
        #expect(DanmakuFilter.apply(items, blockedKeywords: [" 广告 "]).isEmpty)
    }
}
