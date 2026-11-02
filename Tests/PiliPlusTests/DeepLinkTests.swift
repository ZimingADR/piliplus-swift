import Foundation
import Testing

@testable import PiliPlus

@Suite("DeepLink")
struct DeepLinkTests {
    @Test("解析首页 / 历史深链")
    func parsesSimpleRoutes() {
        #expect(DeepLinkRoute.parse(URL(string: "piliplus://home")!) == .home)
        #expect(DeepLinkRoute.parse(URL(string: "piliplus://history")!) == .history)
    }

    @Test("解析搜索关键词并处理空参数")
    func parsesSearch() {
        #expect(
            DeepLinkRoute.parse(URL(string: "piliplus://search?keyword=%E5%93%94%E5%93%A9")!)
                == .search(keyword: "哔哩")
        )
        #expect(
            DeepLinkRoute.parse(URL(string: "piliplus://search")!)
                == .search(keyword: "")
        )
    }

    @Test("解析视频深链并校验缺参")
    func parsesVideo() {
        #expect(
            DeepLinkRoute.parse(URL(string: "piliplus://video?bvid=BV1xx411c7mD&cid=123")!)
                == .video(bvid: "BV1xx411c7mD", cid: 123)
        )
        #expect(
            DeepLinkRoute.parse(URL(string: "piliplus://video?bvid=BV1xx411c7mD")!)
                == .video(bvid: "BV1xx411c7mD", cid: nil)
        )
        #expect(DeepLinkRoute.parse(URL(string: "piliplus://video")!) == nil)
    }

    @Test("非法 scheme / host 被拒绝")
    func rejectsInvalid() {
        #expect(DeepLinkRoute.parse(URL(string: "https://example.com/home")!) == nil)
        #expect(DeepLinkRoute.parse(URL(string: "piliplus://unknown")!) == nil)
    }

    @Test("深链生成与解析互逆")
    func roundTrip() throws {
        let routes: [DeepLinkRoute] = [
            .home,
            .history,
            .search(keyword: "测试 关键词"),
            .video(bvid: "BV1xx411c7mD", cid: 456),
        ]

        for route in routes {
            let url = try #require(DeepLinkRoute.url(for: route))
            #expect(DeepLinkRoute.parse(url) == route)
        }
    }
}
