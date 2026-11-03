import Foundation
import Testing

@testable import PiliPlus

@Suite("IM")
struct IMTests {
    @Test("会话列表解码（last_msg 对象与字符串）")
    func decodesSessions() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "session_list": [
              {
                "talker_id": 100,
                "at_time": 1700000000,
                "unread_count": 2,
                "last_msg": { "content": "你好", "msg_type": 1 }
              },
              {
                "talker_id": 200,
                "at_time": 1700000100,
                "unread_count": 0,
                "last_msg": "{\\"content\\":\\"字符串消息\\"}"
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            IMSessionsResponse.self,
            from: Data(json.utf8)
        )
        let list = try #require(response.data?.sessionList)
        #expect(list.count == 2)
        #expect(list[0].talkerID?.value == 100)
        #expect(list[0].lastMsg?.text == "你好")
        #expect(list[1].lastMsg?.text == "字符串消息")
    }

    @Test("消息记录解码")
    func decodesMessages() throws {
        let json = """
        {
          "code": 0,
          "data": {
            "messages": [
              {
                "msg_key": "k1",
                "sender_uid": 100,
                "timestamp": 1700000000,
                "msg_type": 1,
                "content": "{\\"content\\":\\"文本消息\\"}"
              }
            ]
          }
        }
        """

        let response = try JSONDecoder().decode(
            IMMessagesResponse.self,
            from: Data(json.utf8)
        )
        let item = try #require(response.data?.messages?.first)
        #expect(item.msgKey == "k1")
        #expect(item.senderUID?.value == 100)
        #expect(item.content?.contains("文本消息") == true)
    }

    @Test("用户名片解码")
    func decodesCard() throws {
        let json = """
        { "code": 0, "data": { "card": { "name": "用户A", "face": "//i0.hdslb.com/face.jpg" } } }
        """
        let response = try JSONDecoder().decode(
            UserCardResponse.self,
            from: Data(json.utf8)
        )
        #expect(response.data?.card?.name == "用户A")
    }
}
