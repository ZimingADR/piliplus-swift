import Foundation
import Observation

// MARK: - 备份数据

struct BackupPayload: Codable, Sendable {
    var version: Int
    var exportedAt: Date
    var history: [HistoryBackup]
    var settings: SettingsBackup
}

struct HistoryBackup: Codable, Sendable {
    let bvid: String
    let aid: Int
    let cid: Int
    let title: String
    let coverURLString: String
    let ownerName: String
    let duration: Double
    let position: Double
    let pageIndex: Int
    let pageTitle: String
    let updatedAt: Date

    init(record: PlaybackRecord) {
        bvid = record.bvid
        aid = record.aid
        cid = record.cid
        title = record.title
        coverURLString = record.coverURLString
        ownerName = record.ownerName
        duration = record.duration
        position = record.position
        pageIndex = record.pageIndex
        pageTitle = record.pageTitle
        updatedAt = record.updatedAt
    }

    func makeRecord() -> PlaybackRecord {
        PlaybackRecord(
            bvid: bvid,
            aid: aid,
            cid: cid,
            title: title,
            coverURLString: coverURLString,
            ownerName: ownerName,
            duration: duration,
            position: position,
            pageIndex: pageIndex,
            pageTitle: pageTitle,
            updatedAt: updatedAt
        )
    }
}

struct SettingsBackup: Codable, Sendable {
    var defaultQuality: Int
    var codecPreference: String
    var backgroundPlaybackEnabled: Bool
    var pictureInPictureEnabled: Bool
    var resumePlaybackEnabled: Bool
    var sponsorBlockEnabled: Bool
    var audioOnlyEnabled: Bool
    var danmakuEnabled: Bool
    var danmakuFontScale: Double
    var danmakuOpacity: Double
    var danmakuSpeed: Double
    var danmakuArea: Double
    var audioNormalizationMode: String
    var loudnessTargetLUFS: Int
    var loudnessStrength: Int
    var appearance: String

    @MainActor
    init(settings: SettingsStore) {
        defaultQuality = settings.defaultQuality
        codecPreference = settings.codecPreference.rawValue
        backgroundPlaybackEnabled = settings.backgroundPlaybackEnabled
        pictureInPictureEnabled = settings.pictureInPictureEnabled
        resumePlaybackEnabled = settings.resumePlaybackEnabled
        sponsorBlockEnabled = settings.sponsorBlockEnabled
        audioOnlyEnabled = settings.audioOnlyEnabled
        danmakuEnabled = settings.danmakuEnabled
        danmakuFontScale = settings.danmakuFontScale
        danmakuOpacity = settings.danmakuOpacity
        danmakuSpeed = settings.danmakuSpeed
        danmakuArea = settings.danmakuArea
        audioNormalizationMode = settings.audioNormalizationMode
        loudnessTargetLUFS = settings.loudnessTargetLUFS
        loudnessStrength = settings.loudnessStrength
        appearance = settings.appearance.rawValue
    }

    @MainActor
    func apply(to settings: SettingsStore) {
        settings.defaultQuality = defaultQuality
        settings.codecPreference = VideoCodecPreference(rawValue: codecPreference) ?? .automatic
        settings.backgroundPlaybackEnabled = backgroundPlaybackEnabled
        settings.pictureInPictureEnabled = pictureInPictureEnabled
        settings.resumePlaybackEnabled = resumePlaybackEnabled
        settings.sponsorBlockEnabled = sponsorBlockEnabled
        settings.audioOnlyEnabled = audioOnlyEnabled
        settings.danmakuEnabled = danmakuEnabled
        settings.danmakuFontScale = danmakuFontScale
        settings.danmakuOpacity = danmakuOpacity
        settings.danmakuSpeed = danmakuSpeed
        settings.danmakuArea = danmakuArea
        settings.audioNormalizationMode = audioNormalizationMode
        settings.loudnessTargetLUFS = loudnessTargetLUFS
        settings.loudnessStrength = loudnessStrength
        settings.appearance = AppearanceMode(rawValue: appearance) ?? .system
    }
}

// MARK: - WebDAV 客户端

enum WebDAVError: Error, LocalizedError {
    case invalidURL
    case missingCredentials
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "服务器地址无效，请填写完整的 http(s) 地址"
        case .missingCredentials: "请填写用户名与密码"
        case .http(let code): "服务器返回 HTTP \(code)"
        }
    }
}

struct WebDAVClient: Sendable {
    let baseURL: URL
    let username: String
    let password: String

    func testConnection() async throws {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.timeoutInterval = 20
        applyHeaders(&request)

        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
    }

    func upload(_ data: Data, fileName: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(fileName))
        request.httpMethod = "PUT"
        request.httpBody = data
        request.timeoutInterval = 60
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        applyHeaders(&request)

        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
    }

    func download(fileName: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(fileName))
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        applyHeaders(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return data
    }

    private func applyHeaders(_ request: inout URLRequest) {
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("PiliPlus/0.3 (iOS)", forHTTPHeaderField: "User-Agent")
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVError.http(-1)
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw WebDAVError.http(http.statusCode)
        }
    }
}

// MARK: - 同步服务

/// WebDAV 同步：把播放历史与设置备份为 JSON，支持上传与恢复。
@MainActor
@Observable
final class WebDAVSyncService {
    enum Status: Equatable {
        case idle
        case working(String)
        case success(String)
        case failure(String)
    }

    static let fileName = "piliplus-backup.json"

    var serverURL: String {
        didSet { defaults.set(serverURL, forKey: Key.server) }
    }

    var username: String {
        didSet { defaults.set(username, forKey: Key.username) }
    }

    var password: String {
        didSet { Keychain.save(password, for: Key.password) }
    }

    private(set) var status: Status = .idle
    private(set) var lastBackupAt: Date?

    var isWorking: Bool {
        if case .working = status { return true }
        return false
    }

    private enum Key {
        static let server = "webdav.server"
        static let username = "webdav.username"
        static let password = "webdav.password"
        static let lastBackup = "webdav.lastBackup"
    }

    @ObservationIgnored private let history: PlaybackHistoryStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let defaults = UserDefaults.standard

    init(history: PlaybackHistoryStore, settings: SettingsStore) {
        self.history = history
        self.settings = settings
        serverURL = defaults.string(forKey: Key.server) ?? ""
        username = defaults.string(forKey: Key.username) ?? ""
        password = Keychain.read(Key.password) ?? ""
        if let timestamp = defaults.object(forKey: Key.lastBackup) as? Double, timestamp > 0 {
            lastBackupAt = Date(timeIntervalSince1970: timestamp)
        }
    }

    func testConnection() async {
        guard let client = makeClient() else { return }
        status = .working("正在连接 WebDAV…")
        do {
            try await client.testConnection()
            status = .success("连接成功")
        } catch {
            status = .failure(Self.message(for: error))
        }
    }

    func upload() async {
        guard let client = makeClient() else { return }
        status = .working("正在上传备份…")
        do {
            let payload = makePayload()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            try await client.upload(data, fileName: Self.fileName)

            lastBackupAt = .now
            defaults.set(Date.now.timeIntervalSince1970, forKey: Key.lastBackup)
            status = .success("备份完成：\(payload.history.count) 条历史")
        } catch {
            status = .failure(Self.message(for: error))
        }
    }

    func restore() async {
        guard let client = makeClient() else { return }
        status = .working("正在下载备份…")
        do {
            let data = try await client.download(fileName: Self.fileName)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(BackupPayload.self, from: data)

            history.importAll(payload.history.map { $0.makeRecord() })
            payload.settings.apply(to: settings)
            status = .success("恢复完成：\(payload.history.count) 条历史")
        } catch {
            status = .failure(Self.message(for: error))
        }
    }

    func makePayload() -> BackupPayload {
        BackupPayload(
            version: 1,
            exportedAt: .now,
            history: history.allRecords().map(HistoryBackup.init(record:)),
            settings: SettingsBackup(settings: settings)
        )
    }

    private func makeClient() -> WebDAVClient? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil else {
            status = .failure(WebDAVError.invalidURL.errorDescription ?? "地址无效")
            return nil
        }
        guard !username.isEmpty, !password.isEmpty else {
            status = .failure(WebDAVError.missingCredentials.errorDescription ?? "缺少凭据")
            return nil
        }
        return WebDAVClient(baseURL: url, username: username, password: password)
    }

    private static func message(for error: any Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
