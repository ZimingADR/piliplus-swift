import Foundation
import Testing

@testable import PiliPlus

@Suite("LiveActivity")
struct LiveActivityTests {
    @Test("内容状态进度与百分比")
    func contentState() {
        let state = PlaybackActivityAttributes.ContentState(
            isPlaying: true,
            elapsed: 45,
            duration: 180,
            title: "测试视频",
            ownerName: "UP",
            coverURLString: ""
        )
        #expect(state.fraction == 0.25)
        #expect(state.percentText == "25%")
    }

    @Test("内容状态 Codable 往返")
    func codableRoundTrip() throws {
        let state = PlaybackActivityAttributes.ContentState(
            isPlaying: false,
            elapsed: 300,
            duration: 600,
            title: "标题",
            ownerName: "作者",
            coverURLString: "https://example.com/cover.jpg"
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(
            PlaybackActivityAttributes.ContentState.self,
            from: data
        )
        #expect(decoded == state)
    }

    @Test("实时活动深链指向视频")
    func attributesDeepLink() throws {
        let attributes = PlaybackActivityAttributes(bvid: "BV1xx411c7mD", cid: 42)
        let url = try #require(attributes.deepLink)
        #expect(DeepLinkRoute.parse(url) == .video(bvid: "BV1xx411c7mD", cid: 42))
    }
}
