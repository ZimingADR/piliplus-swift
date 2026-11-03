import Foundation

extension BiliClient {
    /// 私信会话列表。
    func imSessions() async throws -> [IMSession] {
        let payload: IMSessionsResponse.Payload = try await object(
            IMSessionsResponse.Payload.self,
            path: "/session_svr/v1/session_svr/get_sessions",
            query: [
                "session_type": "1",
                "group_id": "0",
                "build": "0",
                "mobi_app": "web",
            ],
            host: .vc,
            signed: false
        )

        return (payload.sessionList ?? []).compactMap { item in
            guard let talkerID = item.talkerID?.value, talkerID > 0 else { return nil }
            return IMSession(
                talkerID: talkerID,
                name: "用户 \(talkerID)",
                faceURL: nil,
                lastMessage: item.lastMsg?.text ?? "",
                timestamp: item.atTime?.value ?? 0,
                unread: item.unreadCount?.value ?? 0
            )
        }
    }

    /// 某个会话的消息记录（最新在前，UI 自行反转）。
    func imMessages(talkerID: Int, size: Int = 50) async throws -> [IMMessage] {
        let payload: IMMessagesResponse.Payload = try await object(
            IMMessagesResponse.Payload.self,
            path: "/svr_sync/v1/svr_sync/fetch_session_msgs",
            query: [
                "talker_id": String(talkerID),
                "session_type": "1",
                "size": String(max(1, size)),
                "build": "0",
                "mobi_app": "web",
            ],
            host: .vc,
            signed: false
        )

        return (payload.messages ?? []).compactMap { item in
            guard let key = item.msgKey, !key.isEmpty else { return nil }
            let text = Self.imText(from: item.content)
            guard !text.isEmpty else { return nil }
            return IMMessage(
                id: key,
                senderUID: item.senderUID?.value ?? 0,
                timestamp: item.timestamp?.value ?? 0,
                text: text
            )
        }
    }

    /// 发送文本私信。
    func sendIMMessage(talkerID: Int, selfUID: Int, text: String) async throws {
        guard let csrf = csrfToken() else {
            throw BiliAPIError(code: -101, message: "请先登录")
        }

        let contentData = try JSONEncoder().encode(["content": text])
        let contentJSON = String(data: contentData, encoding: .utf8) ?? "{\"content\":\"\"}"
        let timestamp = Int(Date.now.timeIntervalSince1970)

        let data = try await postForm(
            "/web_im/v1/web_im/send_msg",
            form: [
                "msg[sender_uid]": String(selfUID),
                "msg[receiver_id]": String(talkerID),
                "msg[receiver_type]": "1",
                "msg[msg_type]": "1",
                "msg[msg_status]": "0",
                "msg[content]": contentJSON,
                "msg[timestamp]": String(timestamp),
                "csrf": csrf,
            ],
            host: .vc
        )

        let response = try JSONDecoder().decode(ActionResponse.self, from: data)
        guard response.code == 0 else {
            throw BiliAPIError(code: response.code, message: response.message ?? "发送失败")
        }
    }

    /// 用户名片（用于给会话补昵称/头像）。
    func userCard(mid: Int) async throws -> (name: String, faceURL: URL?) {
        let payload: UserCardResponse.Payload = try await object(
            UserCardResponse.Payload.self,
            path: "/x/web-interface/card",
            query: ["mid": String(mid)],
            signed: false
        )

        guard let card = payload.card else {
            throw BiliAPIError(code: -404, message: "用户不存在")
        }
        return (
            card.name ?? "用户 \(mid)",
            RecommendFeedResponse.Item.httpsURL(card.face)
        )
    }

    private static func imText(from raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return raw
        }
        if let content = object["content"] as? String {
            return content
        }
        return ""
    }
}
