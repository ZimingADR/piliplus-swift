import Foundation

/// 一条离线下载记录（元数据写入每个下载目录的 manifest.json）。
struct DownloadItem: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let bvid: String
    let aid: Int
    let cid: Int
    let title: String
    let coverURLString: String
    let ownerName: String
    let duration: Double
    let quality: Int
    let createdAt: Date
    let folderName: String
    let videoFileName: String
    let audioFileName: String?
    let sizeBytes: Int64

    var coverURL: URL? {
        guard let url = URL(string: coverURLString) else { return nil }
        return url
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var durationText: String {
        duration > 0 ? VideoCard.formatDuration(Int(duration)) : "--:--"
    }
}
