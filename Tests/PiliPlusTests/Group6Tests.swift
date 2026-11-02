import Foundation
import Testing

@testable import PiliPlus

@Suite("SponsorBlock")
struct SponsorBlockTests {
    @Test("解析片段并按开始时间排序")
    func parsesSegments() {
        let json = """
        [
          {
            "videoID": "BV1xx411c7mD",
            "segments": [
              {
                "UUID": "seg-2",
                "segment": [30.0, 42.5],
                "category": "intro",
                "actionType": "skip"
              },
              {
                "UUID": "seg-1",
                "segment": [5.0, 12.0],
                "category": "sponsor",
                "actionType": "skip"
              }
            ]
          }
        ]
        """

        let segments = SponsorBlockService.parse(Data(json.utf8))
        #expect(segments.count == 2)
        #expect(segments[0].id == "seg-1")
        #expect(segments[0].start == 5.0)
        #expect(segments[0].end == 12.0)
        #expect(segments[0].categoryTitle == "赞助广告")
        #expect(segments[1].categoryTitle == "片头")
    }

    @Test("非法区间与空数据被忽略")
    func ignoresInvalidSegments() {
        let json = """
        [
          {
            "segments": [
              { "UUID": "bad", "segment": [10.0, 3.0], "category": "sponsor" },
              { "segment": [1.0], "category": "sponsor" }
            ]
          }
        ]
        """
        #expect(SponsorBlockService.parse(Data(json.utf8)).isEmpty)
        #expect(SponsorBlockService.parse(Data("[]".utf8)).isEmpty)
        #expect(SponsorBlockService.parse(Data("not json".utf8)).isEmpty)
    }
}

@Suite("Download")
struct DownloadTests {
    @Test("下载元数据 Codable 往返")
    func codableRoundTrip() throws {
        let item = DownloadItem(
            id: "BV1xx411c7mD_100",
            bvid: "BV1xx411c7mD",
            aid: 1,
            cid: 100,
            title: "离线视频",
            coverURLString: "https://example.com/cover.jpg",
            ownerName: "UP",
            duration: 125,
            quality: 80,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            folderName: "BV1xx411c7mD_100",
            videoFileName: "video.m4s",
            audioFileName: "audio.m4s",
            sizeBytes: 1_024
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DownloadItem.self, from: data)
        #expect(decoded == item)
        #expect(decoded.durationText == "02:05")
        #expect(decoded.sizeText.contains("KB"))
    }
}
