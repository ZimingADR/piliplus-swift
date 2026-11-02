import Foundation
import Testing

@testable import PiliPlus

@Suite("VideoCard")
struct VideoCardTests {
    @Test("时长格式化覆盖分钟与小时")
    func formatsDuration() {
        #expect(VideoCard.formatDuration(0) == "--:--")
        #expect(VideoCard.formatDuration(59) == "00:59")
        #expect(VideoCard.formatDuration(125) == "02:05")
        #expect(VideoCard.formatDuration(3_661) == "1:01:01")
    }

    @Test("播放量格式化使用万/亿")
    func formatsCount() {
        #expect(VideoCard.formatCount(0) == "0")
        #expect(VideoCard.formatCount(9_999) == "9999")
        #expect(VideoCard.formatCount(12_345) == "1.2万")
        #expect(VideoCard.formatCount(123_456) == "12万")
        #expect(VideoCard.formatCount(150_000_000) == "1.5亿")
    }

    @Test("搜索结果标题会去掉高亮标签并还原实体")
    func stripsHTML() {
        #expect("<em class=\"keyword\">测试</em> &amp; 标题".removingHTMLTags == "测试 & 标题")
    }

    @Test("搜索结果时长字符串解析")
    func parsesSearchDuration() {
        #expect(SearchTypeResponse.Item.parseDuration("02:05") == 125)
        #expect(SearchTypeResponse.Item.parseDuration("1:01:01") == 3_661)
        #expect(SearchTypeResponse.Item.parseDuration("") == 0)
    }
}
