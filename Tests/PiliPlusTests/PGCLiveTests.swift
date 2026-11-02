import Foundation
import Testing

@testable import PiliPlus

@Suite("PGC")
struct PGCTests {
    @Test("季详情：剧集、评分与标题")
    func decodesSeason() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "season_id": 1001,
            "title": "测试番剧",
            "cover": "//i0.hdslb.com/cover.jpg",
            "evaluate": "一部测试番剧。",
            "rating": { "score": 9.2 },
            "areas": [{ "name": "日本" }, { "name": "奇幻" }],
            "stat": { "views": 123456 },
            "new_ep": { "index_show": "更新至第 2 话" },
            "episodes": [
              {
                "id": 3001,
                "ep_id": 3001,
                "aid": 2001,
                "bvid": "BV1xx411c7mD",
                "cid": 4001,
                "title": "第1话",
                "long_title": "开端",
                "cover": "//i0.hdslb.com/ep1.jpg",
                "duration": 1440000
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(PGCSeasonResponse.self, from: Data(json.utf8))
        let season = try #require(response.data?.domainModel())
        #expect(season.seasonID == 1001)
        #expect(season.title == "测试番剧")
        #expect(season.score == 9.2)
        #expect(season.areas == ["日本", "奇幻"])
        #expect(season.newEpisodeText == "更新至第 2 话")
        #expect(season.episodes.count == 1)
        #expect(season.episodes[0].bvid == "BV1xx411c7mD")
        #expect(season.episodes[0].duration == 1440)
        #expect(season.episodes[0].displayTitle == "第1话 · 开端")
    }

    @Test("索引分页：has_next 与封面")
    func decodesIndex() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "has_next": 1,
            "list": [
              {
                "season_id": 2001,
                "title": "索引番剧",
                "cover": "//i0.hdslb.com/index.jpg",
                "index_show": "全 12 话",
                "badge": "独家"
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(PGCIndexResponse.self, from: Data(json.utf8))
        let page = try #require(response.data?.domainPage)
        #expect(page.hasNext)
        #expect(page.items.count == 1)
        #expect(page.items[0].id == 2001)
        #expect(page.items[0].indexShow == "全 12 话")
        #expect(page.items[0].coverURL?.absoluteString.hasPrefix("https://") == true)
    }
}

@Suite("Live")
struct LiveTests {
    @Test("推荐列表解析")
    func decodesList() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "count": 100,
            "list": [
              {
                "roomid": 5555,
                "uid": 777,
                "uname": "主播",
                "face": "//i0.hdslb.com/face.jpg",
                "cover": "//i0.hdslb.com/live.jpg",
                "title": "测试直播间",
                "area_name": "虚拟主播",
                "watched_show": { "text_large": "1.2万人看过" }
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(LiveListResponse.self, from: Data(json.utf8))
        let rooms = try #require(response.data?.rooms)
        #expect(rooms.count == 1)
        #expect(rooms[0].id == 5555)
        #expect(rooms[0].title == "测试直播间")
        #expect(rooms[0].watchedText == "1.2万人看过")
    }

    @Test("播放地址：FLV 优先并拼接 host/extra")
    func buildsPlayURL() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "room_id": 5555,
            "live_status": 1,
            "playurl_info": {
              "playurl": {
                "stream": [
                  {
                    "protocol_name": "http_hls",
                    "format": [
                      {
                        "format_name": "ts",
                        "codec": [
                          {
                            "codec_name": "avc",
                            "base_url": "/live/hls.m3u8",
                            "url_info": [{ "host": "https://hls.example.com", "extra": "?token=hls" }]
                          }
                        ]
                      }
                    ]
                  },
                  {
                    "protocol_name": "http_stream",
                    "format": [
                      {
                        "format_name": "flv",
                        "codec": [
                          {
                            "codec_name": "avc",
                            "base_url": "/live/stream.flv",
                            "url_info": [{ "host": "https://cdn.example.com", "extra": "?token=abc" }]
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            }
          }
        }
        """

        let response = try JSONDecoder().decode(LivePlayInfoResponse.self, from: Data(json.utf8))
        let info = try #require(response.data?.bestPlayInfo(roomID: 5555))
        #expect(info.playURL.absoluteString == "https://cdn.example.com/live/stream.flv?token=abc")
        #expect(info.isHLS == false)
    }
}
