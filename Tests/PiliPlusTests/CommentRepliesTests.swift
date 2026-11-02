import Foundation
import Testing

@testable import PiliPlus

@Suite("CommentReplies")
struct CommentRepliesTests {
    private let json = """
    {
      "code": 0,
      "data": {
        "replies": [
          {
            "rpid": 1001,
            "mid": 10,
            "member": {
              "uname": "回复者",
              "avatar": "//i0.hdslb.com/face.jpg",
              "level_info": { "current_level": 4 }
            },
            "content": { "message": "楼中楼内容" },
            "like": 3,
            "ctime": 1700000000,
            "rcount": 0
          }
        ],
        "page": { "pn": 1, "ps": 20, "count": 1 },
        "upper": { "mid": 10 }
      }
    }
    """

    @Test("楼中楼分页解码与 UP 标识")
    func decodesReplies() throws {
        let response = try JSONDecoder().decode(
            ReplyRepliesResponse.self,
            from: Data(json.utf8)
        )
        let payload = try #require(response.data)
        let replies = (payload.replies ?? [])
            .compactMap { $0.videoComment(uploaderMid: payload.upper?.mid) }

        #expect(replies.count == 1)
        let reply = try #require(replies.first)
        #expect(reply.id == 1001)
        #expect(reply.userName == "回复者")
        #expect(reply.message == "楼中楼内容")
        #expect(reply.level == 4)
        #expect(reply.likeCount == 3)
        #expect(reply.isUp)
    }

    @Test("空消息被过滤")
    func filtersEmptyMessage() {
        let reply = CommentsResponse.Payload.Reply(
            rpid: FlexInt(1),
            mid: FlexInt(2),
            member: nil,
            content: CommentsResponse.Payload.Content(message: "   "),
            like: nil,
            ctime: nil,
            rcount: nil
        )
        #expect(reply.videoComment(uploaderMid: nil) == nil)
    }

    @Test("表情码列表非空")
    func emoteCatalog() {
        #expect(!EmoteCatalog.codes.isEmpty)
        #expect(EmoteCatalog.codes.contains("[doge]"))
    }
}
