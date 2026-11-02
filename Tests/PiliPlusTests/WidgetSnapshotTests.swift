import Foundation
import Testing

@testable import PiliPlus

@Suite("WidgetSnapshot")
struct WidgetSnapshotTests {
    @Test("进度比例与深链")
    func fractionAndLink() throws {
        let snapshot = SharedRecentPlayback(
            title: "测试视频",
            coverURLString: "https://example.com/cover.jpg",
            bvid: "BV1xx411c7mD",
            cid: 123,
            progress: 30,
            duration: 120,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(snapshot.fraction == 0.25)

        let url = try #require(snapshot.deepLink)
        #expect(DeepLinkRoute.parse(url) == .video(bvid: "BV1xx411c7mD", cid: 123))
    }

    @Test("进度越界被裁剪")
    func clampsFraction() {
        let over = SharedRecentPlayback(
            title: "t", coverURLString: "", bvid: "bv", cid: 1,
            progress: 500, duration: 100, updatedAt: .now
        )
        #expect(over.fraction == 1)

        let zero = SharedRecentPlayback(
            title: "t", coverURLString: "", bvid: "bv", cid: 1,
            progress: 10, duration: 0, updatedAt: .now
        )
        #expect(zero.fraction == 0)
    }

    @Test("共享快照 Codable 往返")
    func codableRoundTrip() throws {
        let snapshot = SharedRecentPlayback.placeholder
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SharedRecentPlayback.self, from: data)
        #expect(decoded == snapshot)
    }
}
