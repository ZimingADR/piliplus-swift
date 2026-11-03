import Foundation

extension BiliClient {
    /// 直播一级分区。
    func liveAreas() async throws -> [LiveArea] {
        let areas = try await object(
            [LiveArea].self,
            path: "/room/v1/Area/getList",
            query: ["parent_id": "0"],
            host: .live,
            signed: false
        )
        return areas.filter { $0.id > 0 }
    }

    /// 分区下的直播间（按人气排序）。
    func liveAreaRooms(parentAreaID: Int, page: Int = 1) async throws -> [LiveRoom] {
        let payload: LiveListResponse.Payload = try await object(
            LiveListResponse.Payload.self,
            path: "/xlive/web-interface/v1/second/getList",
            query: [
                "platform": "web",
                "parent_area_id": String(parentAreaID),
                "area_id": "0",
                "sort_type": "online",
                "page": String(max(1, page)),
            ],
            host: .live,
            signed: false
        )
        return payload.rooms
    }

    /// 关注的主播直播（仅返回正在直播的房间）。
    func followedLiveRooms(page: Int) async throws -> ([LiveRoom], Bool) {
        let payload: LiveFollowResponse.Payload = try await object(
            LiveFollowResponse.Payload.self,
            path: "/xlive/web-ucenter/user/following",
            query: [
                "page": String(max(1, page)),
                "page_size": "9",
                "ignoreRecord": "1",
                "hit_ab": "true",
            ],
            host: .live,
            signed: false
        )

        let rooms: [LiveRoom] = (payload.list ?? []).compactMap { item in
            guard item.liveStatus?.value == 1,
                  let roomID = item.roomID?.value,
                  roomID > 0 else { return nil }

            return LiveRoom(
                id: roomID,
                title: item.title ?? "直播间",
                uname: item.uname ?? "主播",
                coverURL: RecommendFeedResponse.Item.httpsURL(item.roomCover),
                faceURL: nil,
                areaName: item.areaName ?? "直播",
                watchedText: item.textSmall ?? ""
            )
        }

        let totalPage = payload.totalPage?.value ?? 0
        return (rooms, page < totalPage)
    }
}
