import Foundation
import Testing

@testable import PiliPlus

@Suite("Topics")
struct TopicTests {
    @Test("话题详情解码")
    func decodesTop() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "top_details": {
              "topic_item": {
                "id": 100,
                "name": "测试话题",
                "description": "话题描述",
                "view": 1000,
                "discuss": 20
              }
            }
          }
        }
        """
        let response = try JSONDecoder().decode(
            TopicTopResponse.self,
            from: Data(json.utf8)
        )
        let item = try #require(response.data?.topDetails?.topicItem)
        let info = try #require(item.topicInfo)
        #expect(info.id == 100)
        #expect(info.name == "测试话题")
        #expect(info.view == 1000)
        #expect(info.discuss == 20)
    }

    @Test("话题动态卡解码")
    func decodesFeed() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "topic_card_list": {
              "has_more": 1,
              "offset": "next",
              "items": [
                {
                  "topic_type": "dynamic",
                  "dynamic_card_item": {
                    "id_str": "123",
                    "type": "DYNAMIC_TYPE_WORD",
                    "modules": {
                      "module_author": { "mid": 1, "name": "作者", "face": "", "pub_ts": 1700000000 },
                      "module_dynamic": { "desc": { "text": "话题内容" } },
                      "module_stat": {
                        "comment": { "count": 2 },
                        "forward": { "count": 3 },
                        "like": { "count": 4 }
                      }
                    }
                  }
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            TopicFeedResponse.self,
            from: Data(json.utf8)
        )
        let cardList = try #require(response.data?.topicCardList)
        #expect(cardList.hasMore?.value == 1)
        #expect(cardList.offset == "next")
        let item = try #require(cardList.items?.first)
        let dynamic = try #require(item.dynamicCardItem?.domainModel())
        #expect(dynamic.id == "123")
        #expect(dynamic.authorName == "作者")
        #expect(dynamic.text == "话题内容")
        #expect(dynamic.likeCount == 4)
    }

    @Test("话题搜索解码")
    func decodesSearch() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "topic_items": [
              { "id": 1, "name": "话题A", "description": "", "view": 10, "discuss": 2 }
            ],
            "page_info": { "has_more": 0 }
          }
        }
        """
        let response = try JSONDecoder().decode(
            TopicSearchResponse.self,
            from: Data(json.utf8)
        )
        #expect(response.data?.topicItems?.count == 1)
        #expect(response.data?.topicItems?.first?.name == "话题A")
        #expect(response.data?.pageInfo?.hasMore?.value == 0)
    }
}
