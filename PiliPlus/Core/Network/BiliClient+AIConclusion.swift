import Foundation

extension BiliClient {
    /// 视频 AI 总结（WBI 签名，需要登录态才稳定可用）。
    func aiConclusion(
        bvid: String,
        cid: Int,
        upMid: Int?
    ) async throws -> AIConclusionResponse.Payload {
        var query = [
            "bvid": bvid,
            "cid": String(cid),
        ]
        if let upMid {
            query["up_mid"] = String(upMid)
        }

        let payload: AIConclusionResponse.Payload = try await object(
            AIConclusionResponse.Payload.self,
            path: "/x/web-interface/view/conclusion/get",
            query: query,
            signed: true
        )

        let dataCode = payload.code?.value ?? -1
        guard dataCode == 0 else {
            throw BiliAPIError(code: dataCode, message: "该视频暂无 AI 总结")
        }
        return payload
    }
}
