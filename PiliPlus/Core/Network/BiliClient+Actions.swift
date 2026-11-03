import Foundation

/// 互动类写操作：动态点赞/转发、收藏夹创建。
extension BiliClient {
    func likeDynamic(id: String, like: Bool) async throws {
        try await performFormAction(
            "/x/dynamic/feed/dyn/thumb",
            form: [
                "dyn_id_str": id,
                "up": like ? "1" : "2",
            ]
        )
    }

    func repostDynamic(id: String, content: String) async throws {
        try await performFormAction(
            "/x/dynamic/feed/dyn/repost",
            form: [
                "dyn_id_str": id,
                "content": content,
            ]
        )
    }

    func createFavoriteFolder(title: String) async throws {
        try await performFormAction(
            "/x/v3/fav/folder/add",
            form: [
                "title": title,
                "privacy": "0",
                "intro": "",
            ]
        )
    }

    func publishDynamic(text: String) async throws {
        guard let payload = DynamicComposePayload(text: text).jsonString else {
            throw BiliAPIError(code: -400, message: "动态内容编码失败")
        }
        try await performFormAction(
            "/x/dynamic/feed/create/dyn",
            form: ["dyn_req": payload]
        )
    }

    func uploadDynamicImage(
        _ data: Data,
        fileName: String = "dynamic.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> DynamicPicture {
        let payload: DynamicImageUpload = try await uploadMultipart(
            DynamicImageUpload.self,
            path: "/x/dynamic/feed/draw/upload_bfs",
            fields: [
                "category": "daily",
                "biz": "new_dyn",
            ],
            fileField: "file_up",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )

        guard let picture = payload.picture else {
            throw BiliAPIError(code: -400, message: "图片上传失败")
        }
        return picture
    }

    func publishDynamic(text: String, pictures: [DynamicPicture]) async throws {
        guard let payload = DynamicComposePayload(text: text, pictures: pictures).jsonString else {
            throw BiliAPIError(code: -400, message: "动态内容编码失败")
        }
        try await performFormAction(
            "/x/dynamic/feed/create/dyn",
            form: ["dyn_req": payload]
        )
    }

    private func performFormAction(
        _ path: String,
        form: [String: String]
    ) async throws {
        guard let csrf = csrfToken() else {
            throw BiliAPIError(code: -101, message: "请先登录")
        }
        var body = form
        body["csrf"] = csrf

        let data = try await postForm(path, form: body)
        let response = try JSONDecoder().decode(ActionResponse.self, from: data)
        guard response.code == 0 else {
            throw BiliAPIError(code: response.code, message: response.message ?? "操作失败")
        }
    }
}
