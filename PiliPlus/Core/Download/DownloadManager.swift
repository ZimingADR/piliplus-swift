import Foundation
import Observation

/// DASH 离线下载管理器。
///
/// 下载视频轨与音频轨为独立文件（`video.m4s` / `audio.m4s`），元数据写入
/// `manifest.json`。播放时直接交给 MPV，不需要 ffmpeg 混流。
@MainActor
@Observable
final class DownloadManager {
    struct ActiveDownload: Equatable {
        var phase: String
        var progress: Double
    }

    private(set) var items: [DownloadItem] = []
    private(set) var active: [String: ActiveDownload] = [:]

    @ObservationIgnored private let client: BiliClient
    @ObservationIgnored private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Downloads", isDirectory: true)
    }

    init(client: BiliClient) {
        self.client = client
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: - 查询

    func isDownloaded(bvid: String, cid: Int) -> Bool {
        items.contains { $0.bvid == bvid && $0.cid == cid }
    }

    func activeState(bvid: String, cid: Int) -> ActiveDownload? {
        active["\(bvid)_\(cid)"]
    }

    func videoURL(for item: DownloadItem) -> URL {
        baseDirectory
            .appendingPathComponent(item.folderName, isDirectory: true)
            .appendingPathComponent(item.videoFileName)
    }

    func audioURL(for item: DownloadItem) -> URL? {
        guard let name = item.audioFileName else { return nil }
        return baseDirectory
            .appendingPathComponent(item.folderName, isDirectory: true)
            .appendingPathComponent(name)
    }

    // MARK: - 列表

    func load() {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        ) else {
            items = []
            return
        }

        items = directories.compactMap { directory in
            let manifest = directory.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifest) else { return nil }
            return try? JSONDecoder().decode(DownloadItem.self, from: data)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func delete(_ item: DownloadItem) {
        try? fileManager.removeItem(
            at: baseDirectory.appendingPathComponent(item.folderName, isDirectory: true)
        )
        load()
    }

    // MARK: - 下载

    func enqueue(
        detail: VideoDetail,
        page: VideoDetail.Page,
        quality: Int
    ) async throws -> DownloadItem {
        let key = "\(detail.bvid)_\(page.cid)"
        guard active[key] == nil else {
            throw BiliAPIError(code: -20, message: "该视频正在下载")
        }
        guard !isDownloaded(bvid: detail.bvid, cid: page.cid) else {
            throw BiliAPIError(code: -21, message: "该视频已下载")
        }

        active[key] = ActiveDownload(phase: "解析播放地址", progress: 0.05)
        do {
            let result = try await client.playURL(
                bvid: detail.bvid,
                aid: detail.aid,
                cid: page.cid,
                quality: quality
            )
            guard let videoTrack = result.videoTrack(preferring: quality),
                  let audioTrack = result.audioTrack() else {
                throw BiliAPIError(code: -22, message: "没有可下载的音视频轨")
            }

            active[key] = ActiveDownload(phase: "准备存储", progress: 0.1)
            let folder = baseDirectory.appendingPathComponent(key, isDirectory: true)
            try? fileManager.removeItem(at: folder)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

            active[key] = ActiveDownload(phase: "下载视频", progress: 0.2)
            let videoTemp = try await downloadFile(from: videoTrack.url)
            let videoName = "video.m4s"
            let videoDestination = folder.appendingPathComponent(videoName)
            try move(videoTemp, to: videoDestination)

            active[key] = ActiveDownload(phase: "下载音频", progress: 0.6)
            let audioTemp = try await downloadFile(from: audioTrack.url)
            let audioName = "audio.m4s"
            let audioDestination = folder.appendingPathComponent(audioName)
            try move(audioTemp, to: audioDestination)

            let videoSize = fileSize(at: videoDestination)
            let audioSize = fileSize(at: audioDestination)
            let duration = result.duration > 0
                ? result.duration
                : Double(page.duration?.value ?? 0)

            let item = DownloadItem(
                id: key,
                bvid: detail.bvid,
                aid: detail.aid,
                cid: page.cid,
                title: detail.title,
                coverURLString: detail.pic ?? "",
                ownerName: detail.owner?.name ?? "",
                duration: duration,
                quality: videoTrack.quality,
                createdAt: .now,
                folderName: key,
                videoFileName: videoName,
                audioFileName: audioName,
                sizeBytes: videoSize + audioSize
            )

            let data = try JSONEncoder().encode(item)
            try data.write(to: folder.appendingPathComponent("manifest.json"))

            active[key] = nil
            load()
            return item
        } catch {
            active[key] = nil
            try? fileManager.removeItem(
                at: baseDirectory.appendingPathComponent(key, isDirectory: true)
            )
            throw error
        }
    }

    // MARK: - 私有

    private func downloadFile(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode) else {
            throw BiliAPIError(
                code: (response as? HTTPURLResponse)?.statusCode ?? -23,
                message: "下载失败"
            )
        }
        return temporaryURL
    }

    private func move(_ source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
    }

    private func fileSize(at url: URL) -> Int64 {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
