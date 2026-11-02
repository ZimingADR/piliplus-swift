import Foundation

/// B 站接口返回的业务错误。
struct BiliAPIError: Error, LocalizedError, Sendable, Equatable {
    let code: Int
    let message: String

    var errorDescription: String? {
        if message.isEmpty {
            return "请求失败（\(code)）"
        }
        return code == 0 ? message : "\(message)（\(code)）"
    }

    static let invalidResponse = BiliAPIError(code: -1, message: "响应格式异常")
    static let emptyData = BiliAPIError(code: -2, message: "接口没有返回数据")
}

/// 匿名访问所需的设备标识（buvid3/buvid4）。
///
/// Group 1 不要求登录，但带上稳定的设备 Cookie 可以显著降低风控概率。
struct BiliCredentials: Sendable {
    let buvid3: String
    let buvid4: String

    var cookieHeader: String {
        "buvid3=\(buvid3); buvid4=\(buvid4); CURRENT_FNVAL=4048; b_nut=\(Self.installTimestamp)"
    }

    static let installTimestamp = String(Int(Date().timeIntervalSince1970))

    static func persisted(in defaults: UserDefaults = .standard) -> BiliCredentials {
        let buvid3Key = "bili.buvid3"
        let buvid4Key = "bili.buvid4"

        if let buvid3 = defaults.string(forKey: buvid3Key),
           let buvid4 = defaults.string(forKey: buvid4Key) {
            return BiliCredentials(buvid3: buvid3, buvid4: buvid4)
        }

        let buvid3 = Self.randomUUIDToken() + "infoc"
        let buvid4 = Self.randomUUIDToken() + "infoc"
        defaults.set(buvid3, forKey: buvid3Key)
        defaults.set(buvid4, forKey: buvid4Key)
        return BiliCredentials(buvid3: buvid3, buvid4: buvid4)
    }

    private static func randomUUIDToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
    }
}

/// 统一的 B 站 API 客户端。
///
/// - 所有请求共享 UA / Referer / 设备 Cookie；
/// - 需要 Wbi 签名的接口在客户端内部完成密钥获取与缓存（同一天复用）；
/// - 返回的领域模型都是 `Sendable`，可以安全地穿过 actor 边界。
actor BiliClient {
    enum Host: String, Sendable {
        case api = "https://api.bilibili.com"
        case search = "https://s.search.bilibili.com"
        case passport = "https://passport.bilibili.com"
    }

    static let shared = BiliClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private var cookie: String
    private var deviceCookie: String
    private var loginCookie: String?
    private var didBootstrapBuvid = false
    private var mixinKey: String?
    private var mixinKeyDate: Date?

    private static let userAgent = """
    Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) \
    AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1
    """

    init(session: URLSession = .biliShared, credentials: BiliCredentials = .persisted()) {
        self.session = session
        self.deviceCookie = credentials.cookieHeader
        self.cookie = credentials.cookieHeader
    }

    // MARK: - 推荐流

    func recommend(freshIndex: Int, pageSize: Int = 12) async throws -> [VideoCard] {
        let payload: RecommendFeedResponse.Payload = try await object(
            RecommendFeedResponse.Payload.self,
            path: "/x/web-interface/wbi/index/top/feed/rcmd",
            query: [
                "version": "1",
                "feed_version": "V8",
                "homepage_ver": "1",
                "ps": String(max(1, min(pageSize, 30))),
                "fresh_idx": String(max(0, freshIndex)),
                "brush": String(max(0, freshIndex)),
                "fresh_type": "4",
            ],
            signed: true
        )
        return (payload.item ?? []).compactMap { $0.videoCard() }
    }

    // MARK: - 搜索

    func searchVideos(
        keyword: String,
        page: Int,
        order: SearchOrder = .relevance
    ) async throws -> SearchPage {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchPage(videos: [], page: 1, totalPages: 0, totalResults: 0)
        }

        let payload: SearchTypeResponse.Payload = try await object(
            SearchTypeResponse.Payload.self,
            path: "/x/web-interface/wbi/search/type",
            query: [
                "search_type": "video",
                "keyword": trimmed,
                "page": String(max(1, page)),
                "page_size": "20",
                "order": order.rawValue,
                "platform": "pc",
                "web_location": "1430654",
            ],
            signed: true
        )

        let videos = (payload.result ?? []).compactMap { $0.videoCard() }
        let totalPages = payload.numPages?.value ?? 0
        return SearchPage(
            videos: videos,
            page: payload.page ?? page,
            totalPages: max(totalPages, videos.isEmpty ? 0 : page),
            totalResults: payload.numResults?.value ?? 0
        )
    }

    func trendingKeywords(limit: Int = 30) async throws -> [TrendingKeyword] {
        do {
            let data = try await requestData(
                "/x/v2/search/trending/ranking",
                query: ["limit": String(limit)],
                host: .api,
                signed: false
            )
            let response = try decoder.decode(TrendingResponse.self, from: data)
            if response.code == 0, !response.keywords.isEmpty {
                return Array(response.keywords.prefix(limit))
            }
        } catch {
            // 主接口失败时回退到旧版 hotword，不向上抛错。
        }

        let data = try await requestData(
            "/main/hotword",
            query: [:],
            host: .search,
            signed: false
        )
        let hotword = try decoder.decode(HotwordResponse.self, from: data)
        return Array(hotword.keywords.prefix(limit))
    }

    func suggestions(term: String) async throws -> [String] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let payload: SuggestResponse.Payload = try await object(
            SuggestResponse.Payload.self,
            path: "/x/web-interface/suggest",
            query: [
                "term": trimmed,
                "highlight": "0",
                "spmid": "333.1365",
                "web_location": "333.1365",
            ],
            signed: true
        )
        return payload.suggestions
    }

    // MARK: - 视频

    func videoDetail(bvid: String, aid: Int? = nil) async throws -> VideoDetail {
        var query: [String: String] = [:]
        if !bvid.isEmpty {
            query["bvid"] = bvid
        } else if let aid {
            query["aid"] = String(aid)
        } else {
            throw BiliAPIError(code: -3, message: "缺少视频标识")
        }

        return try await object(
            VideoDetail.self,
            path: "/x/web-interface/wbi/view",
            query: query,
            signed: true
        )
    }

    func playURL(
        bvid: String,
        aid: Int?,
        cid: Int,
        quality: Int,
        voiceBalance: Bool = false
    ) async throws -> PlayURLResult {
        var query: [String: String] = [
            "cid": String(cid),
            "qn": String(quality),
            "fnval": "4048",
            "fnver": "0",
            "fourk": "1",
            "voice_balance": voiceBalance ? "1" : "0",
            "gaia_source": "pre-load",
            "isGaiaAvoided": "true",
            "web_location": "1315873",
            "try_look": "1",
            "dm_img_list": "[]",
            "dm_img_str": Self.randomBase64(minLength: 16, maxLength: 64),
            "dm_cover_img_str": Self.randomBase64(minLength: 32, maxLength: 128),
            "dm_img_inter": "{\"ds\":[],\"wh\":[0,0,0],\"of\":[0,0,0]}",
        ]
        if !bvid.isEmpty {
            query["bvid"] = bvid
        } else if let aid {
            query["avid"] = String(aid)
        }

        let payload: PlayURLResponse.Payload = try await object(
            PlayURLResponse.Payload.self,
            path: "/x/player/wbi/playurl",
            query: query,
            signed: true
        )
        guard let result = payload.result() else {
            throw BiliAPIError(code: -4, message: "没有可用的视频流")
        }
        return result
    }

    /// 获取合流 MP4（供系统播放器 / 画中画使用，最高 720P）。
    func muxedPlayURL(bvid: String, aid: Int?, cid: Int) async throws -> URL {
        var query: [String: String] = [
            "cid": String(cid),
            "qn": String(BiliQuality.quality720p),
            "platform": "html5",
            "high_quality": "1",
        ]
        if !bvid.isEmpty {
            query["bvid"] = bvid
        } else if let aid {
            query["avid"] = String(aid)
        }

        let data = try await requestData(
            "/x/player/playurl",
            query: query,
            host: .api,
            signed: false
        )
        let payload = try decoder.decode(PlayURLResponse.self, from: data)
        guard payload.code == 0,
              let url = payload.data?.result()?.muxedURL else {
            throw BiliAPIError(
                code: payload.code,
                message: payload.message ?? "无法获取合流视频"
            )
        }
        return url
    }

    // MARK: - 弹幕

    /// - Parameter pid: UGC 为 aid，PG C 番剧为 ep_id。
    func danmakuItems(cid: Int, pid: Int, duration: Double) async throws -> [DanmakuItem] {
        let segmentCount = min(max(1, Int((duration / 360).rounded(.up))), 20)
        let segments = try await withThrowingTaskGroup(of: [DanmakuItem].self) { group in
            for index in 1 ... segmentCount {
                group.addTask { [self] in
                    let data = try await requestData(
                        "/x/v2/dm/web/seg.so",
                        query: [
                            "type": "1",
                            "oid": String(cid),
                            "pid": String(pid),
                            "segment_index": String(index),
                        ],
                        host: .api,
                        signed: false
                    )
                    return DanmakuDecoder.items(from: data)
                }
            }
            var collected: [DanmakuItem] = []
            for try await items in group {
                collected.append(contentsOf: items)
            }
            return collected
        }
        return segments.sorted { $0.time < $1.time }
    }

    // MARK: - 账号与登录

    var hasLoginCookie: Bool {
        !(loginCookie ?? "").isEmpty
    }

    func updateLoginCookie(_ newValue: String?) {
        let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        loginCookie = trimmed.isEmpty ? nil : trimmed
        rebuildCookie()
        // 登录态变化后重新获取 Wbi 密钥，避免继续使用匿名态缓存。
        mixinKey = nil
        mixinKeyDate = nil
    }

    func csrfToken() -> String? {
        cookieValue(named: "bili_jct", in: loginCookie)
    }

    func accountInfo() async throws -> AccountProfile {
        let data = try await requestData(
            "/x/web-interface/nav",
            query: [:],
            host: .api,
            signed: false
        )
        let nav = try decoder.decode(NavResponse.self, from: data)
        guard let payload = nav.data, payload.isLogin == true, let mid = payload.mid else {
            throw BiliAPIError(code: -101, message: "尚未登录")
        }

        let stats = try? await relationStats(mid: mid)
        return AccountProfile(
            mid: mid,
            name: payload.uname ?? "B 站用户",
            faceURL: RecommendFeedResponse.Item.httpsURL(payload.face),
            level: payload.levelInfo?.currentLevel?.value ?? 0,
            coins: Int(payload.money?.value ?? 0),
            isVip: (payload.vipStatus?.value ?? 0) > 0,
            following: stats?.following?.value ?? 0,
            follower: stats?.follower?.value ?? 0
        )
    }

    func relationStats(mid: Int) async throws -> RelationStats {
        try await object(
            RelationStats.self,
            path: "/x/relation/stat",
            query: ["vmid": String(mid)],
            signed: false
        )
    }

    func qrLoginSession() async throws -> QRLoginSession {
        let data = try await requestData(
            "/x/passport-login/web/qrcode/generate",
            query: ["source": "main-fe-header"],
            host: .passport,
            signed: false
        )
        let response = try decoder.decode(QRGenerateResponse.self, from: data)
        guard response.code == 0,
              let payload = response.data,
              !payload.qrcodeKey.isEmpty else {
            throw BiliAPIError(
                code: response.code,
                message: response.message ?? "二维码生成失败"
            )
        }
        return QRLoginSession(url: payload.url, key: payload.qrcodeKey)
    }

    func qrLoginPoll(key: String) async throws -> QRLoginPollResult {
        let (data, http) = try await performRequestWithResponse(
            "/x/passport-login/web/qrcode/poll",
            query: ["qrcode_key": key, "source": "main-fe-header"],
            host: .passport,
            signed: false
        )
        let response = try decoder.decode(QRPollResponse.self, from: data)
        guard response.code == 0, let payload = response.data else {
            throw BiliAPIError(
                code: response.code,
                message: response.message ?? "登录状态查询失败"
            )
        }

        switch payload.code {
        case 0:
            return QRLoginPollResult(
                state: .succeeded,
                message: "登录成功",
                cookie: loginCookie(from: http, redirectURL: payload.url)
            )
        case 86101:
            return QRLoginPollResult(state: .waiting, message: "等待扫码", cookie: nil)
        case 86090:
            return QRLoginPollResult(state: .scanned, message: "已扫码，请在手机上确认", cookie: nil)
        case 86038:
            return QRLoginPollResult(state: .expired, message: "二维码已过期", cookie: nil)
        default:
            return QRLoginPollResult(
                state: .failed,
                message: payload.message ?? "登录失败（\(payload.code)）",
                cookie: nil
            )
        }
    }

    private func rebuildCookie() {
        if let loginCookie, !loginCookie.isEmpty {
            cookie = deviceCookie + "; " + loginCookie
        } else {
            cookie = deviceCookie
        }
    }

    private func cookieValue(named name: String, in header: String?) -> String? {
        guard let header else { return nil }
        for item in header.split(separator: ";") {
            let trimmed = item.trimmingCharacters(in: .whitespaces)
            guard let index = trimmed.firstIndex(of: "=") else { continue }
            if trimmed[..<index] == name {
                return String(trimmed[trimmed.index(after: index)...])
            }
        }
        return nil
    }

    /// 优先从 Set-Cookie 解析，失败时回退到成功回调 URL 的 query 参数。
    private func loginCookie(from response: HTTPURLResponse, redirectURL: String?) -> String? {
        let fields = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            if let key = item.key as? String, let value = item.value as? String {
                result[key] = value
            }
        }
        let url = response.url ?? URL(string: Host.passport.rawValue)!
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
        let wanted: Set<String> = ["SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5", "sid"]

        var pairs = cookies
            .filter { wanted.contains($0.name) }
            .map { "\($0.name)=\($0.value)" }

        if pairs.isEmpty,
           let redirectURL,
           let components = URLComponents(string: redirectURL),
           let items = components.queryItems {
            pairs = items
                .filter { wanted.contains($0.name) }
                .map { "\($0.name)=\($0.value ?? "")" }
        }

        let joined = pairs.joined(separator: "; ")
        return joined.isEmpty ? nil : joined
    }

    // MARK: - 写操作

    func postForm(
        _ path: String,
        form: [String: String],
        host: Host = .api
    ) async throws -> Data {
        await bootstrapBuvidIfNeeded()
        guard let url = URL(string: host.rawValue + path) else {
            throw BiliAPIError(code: -5, message: "无法构建请求地址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(
            "application/x-www-form-urlencoded; charset=UTF-8",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = Data(Self.encodedQuery(form).utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode) else {
            throw BiliAPIError(code: -8, message: "网络请求失败")
        }
        return data
    }

    private func performAction(_ path: String, form: [String: String]) async throws {
        guard let csrf = csrfToken() else {
            throw BiliAPIError(code: -101, message: "请先登录")
        }
        var body = form
        body["csrf"] = csrf
        let data = try await postForm(path, form: body)
        let response = try decoder.decode(ActionResponse.self, from: data)
        guard response.code == 0 else {
            throw BiliAPIError(code: response.code, message: response.message ?? "操作失败")
        }
    }

    func setVideoLike(aid: Int, isLiked: Bool) async throws {
        try await performAction(
            "/x/web-interface/archive/like",
            form: ["aid": String(aid), "like": isLiked ? "1" : "2"]
        )
    }

    func addVideoCoin(aid: Int, multiply: Int = 1, alsoLike: Bool = false) async throws {
        try await performAction(
            "/x/web-interface/coin/add",
            form: [
                "aid": String(aid),
                "multiply": String(min(max(multiply, 1), 2)),
                "select_like": alsoLike ? "1" : "0",
            ]
        )
    }

    func favoriteVideo(aid: Int, addMediaIDs: [Int], delMediaIDs: [Int] = []) async throws {
        try await performAction(
            "/x/v3/fav/resource/batch-deal",
            form: [
                "resources": "\(aid):2",
                "add_media_ids": addMediaIDs.map(String.init).joined(separator: ","),
                "del_media_ids": delMediaIDs.map(String.init).joined(separator: ","),
            ]
        )
    }

    func addToWatchLater(aid: Int, bvid: String) async throws {
        try await performAction(
            "/x/v2/history/toview/add",
            form: ["aid": String(aid), "bvid": bvid]
        )
    }

    func removeFromWatchLater(aids: [Int]) async throws {
        try await performAction(
            "/x/v2/history/toview/v2/dels",
            form: ["resources": aids.map(String.init).joined(separator: ",")]
        )
    }

    func modifyRelation(mid: Int, follow: Bool) async throws {
        try await performAction(
            "/x/relation/modify",
            form: ["fid": String(mid), "act": follow ? "1" : "2", "re_src": "11"]
        )
    }

    func addReply(aid: Int, message: String, root: Int64? = nil, parent: Int64? = nil) async throws {
        var form: [String: String] = [
            "oid": String(aid),
            "type": "1",
            "plat": "1",
            "message": message,
        ]
        if let root { form["root"] = String(root) }
        if let parent { form["parent"] = String(parent) }
        try await performAction("/x/v2/reply/add", form: form)
    }

    // MARK: - 请求基础设施

    private struct Envelope<T: Decodable>: Decodable {
        let code: Int
        let message: String?
        let data: T?
    }

    func object<T: Decodable & Sendable>(
        _ type: T.Type,
        path: String,
        query: [String: String],
        host: Host = .api,
        signed: Bool
    ) async throws -> T {
        let data = try await requestData(path, query: query, host: host, signed: signed)
        let envelope = try decoder.decode(Envelope<T>.self, from: data)
        guard envelope.code == 0 else {
            throw BiliAPIError(code: envelope.code, message: envelope.message ?? "")
        }
        guard let payload = envelope.data else {
            throw BiliAPIError.emptyData
        }
        return payload
    }

    func requestData(
        _ path: String,
        query: [String: String],
        host: Host,
        signed: Bool
    ) async throws -> Data {
        await bootstrapBuvidIfNeeded()
        return try await performRequest(path, query: query, host: host, signed: signed)
    }

    /// 首次请求前向 B 站换取真实的 `buvid3` / `buvid4`，降低匿名接口的风控概率。
    private func bootstrapBuvidIfNeeded() async {
        guard !didBootstrapBuvid else { return }
        didBootstrapBuvid = true
        do {
            let data = try await performRequest(
                "/x/frontend/finger/spi",
                query: [:],
                host: .api,
                signed: false
            )
            let response = try decoder.decode(SpiResponse.self, from: data)
            guard let buvid3 = response.data?.buvid3, !buvid3.isEmpty else { return }
            let buvid4 = response.data?.buvid4 ?? ""
            deviceCookie = "buvid3=\(buvid3); buvid4=\(buvid4); CURRENT_FNVAL=4048; b_nut=\(BiliCredentials.installTimestamp)"
            rebuildCookie()
            UserDefaults.standard.set(buvid3, forKey: "bili.buvid3")
            UserDefaults.standard.set(buvid4, forKey: "bili.buvid4")
        } catch {
            // 获取失败时沿用本地生成的设备标识，不阻塞主流程。
        }
    }

    private struct SpiResponse: Decodable {
        struct Payload: Decodable {
            let buvid3: String?
            let buvid4: String?

            enum CodingKeys: String, CodingKey {
                case buvid3 = "b_3"
                case buvid4 = "b_4"
            }
        }

        let code: Int
        let data: Payload?
    }

    private func performRequest(
        _ path: String,
        query: [String: String],
        host: Host,
        signed: Bool
    ) async throws -> Data {
        let (data, _) = try await performRequestWithResponse(
            path,
            query: query,
            host: host,
            signed: signed
        )
        return data
    }

    private func performRequestWithResponse(
        _ path: String,
        query: [String: String],
        host: Host,
        signed: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        var parameters = query
        if signed {
            parameters = WbiSigner.sign(parameters, mixinKey: try await mixinKeyValue())
        }

        let encodedQuery = Self.encodedQuery(parameters)
        guard var components = URLComponents(string: host.rawValue + path) else {
            throw BiliAPIError(code: -5, message: "无法构建请求地址")
        }
        if !encodedQuery.isEmpty {
            components.percentEncodedQuery = encodedQuery
        }
        guard let url = components.url else {
            throw BiliAPIError(code: -5, message: "无法构建请求地址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Origin")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BiliAPIError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw BiliAPIError(code: http.statusCode, message: "服务器返回 HTTP \(http.statusCode)")
        }
        return (data, http)
    }

    /// Wbi 密钥每天刷新一次；未登录时 `/x/web-interface/nav` 也会返回 `wbi_img`。
    private func mixinKeyValue() async throws -> String {
        if let mixinKey,
           let mixinKeyDate,
           Calendar.current.isDateInToday(mixinKeyDate) {
            return mixinKey
        }

        let data = try await requestData(
            "/x/web-interface/nav",
            query: [:],
            host: .api,
            signed: false
        )
        let nav = try decoder.decode(NavResponse.self, from: data)
        guard let imageURL = nav.data?.wbiImg?.imgUrl,
              let subURL = nav.data?.wbiImg?.subUrl else {
            throw BiliAPIError(code: nav.code, message: nav.message ?? "无法获取 Wbi 签名密钥")
        }

        let key = WbiSigner.mixinKey(
            imgKey: Self.keyFragment(imageURL),
            subKey: Self.keyFragment(subURL)
        )
        guard !key.isEmpty else {
            throw BiliAPIError(code: nav.code, message: "Wbi 签名密钥无效")
        }

        mixinKey = key
        mixinKeyDate = Date()
        return key
    }

    private static func keyFragment(_ rawURL: String) -> String {
        guard let url = URL(string: rawURL) else {
            let name = rawURL.split(separator: "/").last.map(String.init) ?? rawURL
            return (name as NSString).deletingPathExtension
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private static func encodedQuery(_ parameters: [String: String]) -> String {
        parameters.keys.sorted().compactMap { key in
            guard let value = parameters[key] else { return nil }
            return "\(WbiSigner.percentEncode(key))=\(WbiSigner.percentEncode(value))"
        }
        .joined(separator: "&")
    }

    static func randomBase64(minLength: Int, maxLength: Int) -> String {
        let count = Int.random(in: minLength ... max(minLength, maxLength))
        var bytes = [UInt8](repeating: 0, count: count)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: 0 ... 255)
        }
        let encoded = Data(bytes).base64EncodedString()
        return String(encoded.dropLast(2))
    }
}

extension URLSession {
    static let biliShared: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024
        )
        return URLSession(configuration: configuration)
    }()
}
