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
}
