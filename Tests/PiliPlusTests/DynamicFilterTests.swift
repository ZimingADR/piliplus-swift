import Testing

@testable import PiliPlus

@Suite("DynamicFeedFilter")
struct DynamicFeedFilterTests {
    @Test("分类覆盖全部动态类型")
    func coversAllKinds() {
        #expect(DynamicFeedFilter.allCases.count == 4)
        #expect(DynamicFeedFilter.video.title == "视频")
        #expect(DynamicFeedFilter.article.title == "专栏")
        #expect(DynamicFeedFilter.text.title == "图文")
        #expect(DynamicFeedFilter.all.emptyDescription.contains("关注"))
    }
}
