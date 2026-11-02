import Foundation

/// 直播接口：推荐列表与房间播放地址。
extension BiliClient {
    func liveRooms(
        page: Int,
        parentAreaID: Int = 0,
        areaID: Int = 0
    ) async throws -> [LiveRoom] {
        let payload: LiveListResponse.Payload = try await object(
            LiveListResponse.Payload.self,
            path: "/xlive/web-interface/v1/second/getList",
            query: [
                "platform": "web",
                "parent_area_id": String(parentAreaID),
                "area_id": String(areaID),
                "sort_type": "",
                "page": String(max(1, page)),
            ],
            signed: false
        )
        return payload.rooms
    }

    func livePlayInfo(roomID: Int) async throws -> LivePlayInfo {
        let payload: LivePlayInfoResponse.Payload = try await object(
            LivePlayInfoResponse.Payload.self,
            path: "/xlive/web-room/v2/index/getRoomPlayInfo",
            query: [
                "room_id": String(roomID),
                "protocol": "0,1",
                "format": "0,1,2",
                "codec": "0,1",
                "qn": "10000",
                "platform": "web",
                "ptype": "8",
                "dolby": "5",
                "panorama": "1",
                "web_location": "444.8",
            ],
            signed: false
        )
        guard let info = payload.bestPlayInfo(roomID: roomID) else {
            throw BiliAPIError(code: -11, message: "直播间暂无可用的播放地址")
        }
        return info
    }
}
