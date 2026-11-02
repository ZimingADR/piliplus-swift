import Foundation
import Testing

@testable import PiliPlus

@Suite("Dynamics")
struct DynamicsTests {
    @Test("解析视频动态：作者、标题、统计")
    func decodesVideoDynamic() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "has_more": 1,
            "offset": "next-token",
            "items": [
              {
                "id_str": "9001",
                "type": "DYNAMIC_TYPE_AV",
                "modules": {
                  "module_author": {
                    "mid": 12345,
                    "name": "测试 UP",
                    "face": "//i0.hdslb.com/bfs/face.jpg",
                    "pub_ts": 1700000000
                  },
                  "module_dynamic": {
                    "desc": { "text": "今天更新了！" },
                    "major": {
                      "type": "MAJOR_TYPE_ARCHIVE",
                      "archive": {
                        "aid": 100,
                        "bvid": "BV1xx411c7mD",
                        "title": "动态里的视频",
                        "cover": "//i0.hdslb.com/bfs/cover.jpg",
                        "duration_text": "12:34",
                        "stat": { "play": 10000, "danmaku": 66 }
                      }
                    }
                  },
                  "module_stat": {
                    "comment": { "count": 12 },
                    "forward": { "count": 3 },
                    "like": { "count": 99 }
                  }
                }
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            DynamicsFeedResponse.self,
            from: Data(json.utf8)
        )
        let page = try #require(response.data?.domainPage)
        #expect(page.hasMore)
        #expect(page.offset == "next-token")
        #expect(page.items.count == 1)

        let item = try #require(page.items.first)
        #expect(item.kind == .video)
        #expect(item.authorName == "测试 UP")
        #expect(item.text == "今天更新了！")
        #expect(item.video?.bvid == "BV1xx411c7mD")
        #expect(item.video?.duration == 754)
        #expect(item.likeCount == 99)
        #expect(item.commentCount == 12)
    }

    @Test("解析图文与专栏动态")
    func decodesImagesAndArticle() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "has_more": 0,
            "offset": "",
            "items": [
              {
                "id_str": "9002",
                "modules": {
                  "module_author": { "mid": 1, "name": "画师" },
                  "module_dynamic": {
                    "desc": { "text": "两张图" },
                    "major": {
                      "type": "MAJOR_TYPE_DRAW",
                      "draw": { "items": [
                        { "src": "//i0.hdslb.com/a.jpg" },
                        { "src": "//i0.hdslb.com/b.jpg" }
                      ] }
                    }
                  }
                }
              },
              {
                "id_str": "9003",
                "modules": {
                  "module_author": { "mid": 2, "name": "专栏作者" },
                  "module_dynamic": {
                    "major": {
                      "type": "MAJOR_TYPE_ARTICLE",
                      "article": {
                        "id": 4567,
                        "title": "一篇专栏",
                        "covers": ["//i0.hdslb.com/cover.jpg"]
                      }
                    }
                  }
                }
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            DynamicsFeedResponse.self,
            from: Data(json.utf8)
        )
        let page = try #require(response.data?.domainPage)
        #expect(page.items.count == 2)
        #expect(page.items[0].kind == .images)
        #expect(page.items[0].imageURLs.count == 2)
        #expect(page.items[0].imageURLs[0].absoluteString.hasPrefix("https://"))
        #expect(page.items[1].kind == .article)
        #expect(page.items[1].articleID == 4567)
        #expect(page.items[1].articleTitle == "一篇专栏")
    }

    @Test("空正文且无媒体的动态被丢弃")
    func dropsEmptyDynamic() {
        let item = DynamicsFeedResponse.Item(idStr: "1", type: "DYNAMIC_TYPE_WORD", modules: nil)
        #expect(item.domainModel() == nil)
    }
}
