import Foundation

/// 一条动态（Group 4）。
struct DynamicItem: Identifiable, Sendable, Equatable {
    enum Kind: String, Sendable {
        case text
        case images
        case video
        case article
    }

    let id: String
    let kind: Kind
    let authorMid: Int?
    let authorName: String
    let authorFaceURL: URL?
    let publishedAt: Date?
    let text: String
    let imageURLs: [URL]
    let video: VideoCard?
    let articleID: Int?
    let articleTitle: String?
    let articleCoverURL: URL?
    let likeCount: Int
    let commentCount: Int
    let forwardCount: Int
}

struct DynamicsPage: Sendable {
    let items: [DynamicItem]
    let offset: String
    let hasMore: Bool
}

// MARK: - 响应模型

struct DynamicsFeedResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let hasMore: FlexInt?
        let offset: String?
        let items: [Item]?

        enum CodingKeys: String, CodingKey {
            case offset, items
            case hasMore = "has_more"
        }
    }

    struct Item: Decodable, Sendable {
        let idStr: String?
        let type: String?
        let modules: Modules?

        enum CodingKeys: String, CodingKey {
            case type, modules
            case idStr = "id_str"
        }
    }

    struct Modules: Decodable, Sendable {
        let author: Author?
        let dynamic: DynamicBody?
        let stat: Stat?

        enum CodingKeys: String, CodingKey {
            case author = "module_author"
            case dynamic = "module_dynamic"
            case stat = "module_stat"
        }
    }

    struct Author: Decodable, Sendable {
        let mid: Int?
        let name: String?
        let face: String?
        let pubTs: FlexInt?

        enum CodingKeys: String, CodingKey {
            case mid, name, face
            case pubTs = "pub_ts"
        }
    }

    struct DynamicBody: Decodable, Sendable {
        let desc: Desc?
        let major: Major?
    }

    struct Desc: Decodable, Sendable {
        let text: String?
    }

    struct Major: Decodable, Sendable {
        let type: String?
        let archive: Archive?
        let draw: Draw?
        let opus: Opus?
        let article: Article?
    }

    struct Archive: Decodable, Sendable {
        let aid: FlexInt?
        let bvid: String?
        let title: String?
        let cover: String?
        let desc: String?
        let durationText: String?
        let stat: ArchiveStat?

        enum CodingKeys: String, CodingKey {
            case aid, bvid, title, cover, desc, stat
            case durationText = "duration_text"
        }
    }

    struct ArchiveStat: Decodable, Sendable {
        let play: FlexInt?
        let danmaku: FlexInt?
    }

    struct Draw: Decodable, Sendable {
        let items: [Media]?
    }

    struct Media: Decodable, Sendable {
        let src: String?
        let url: String?
        let width: FlexInt?
        let height: FlexInt?
    }

    struct Opus: Decodable, Sendable {
        let title: String?
        let summary: Desc?
        let pics: [Media]?
    }

    struct Article: Decodable, Sendable {
        let id: FlexInt?
        let title: String?
        let desc: String?
        let covers: [String]?
    }

    struct Stat: Decodable, Sendable {
        struct Count: Decodable, Sendable {
            let count: FlexInt?
        }

        let comment: Count?
        let forward: Count?
        let like: Count?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension DynamicsFeedResponse.Payload {
    var domainPage: DynamicsPage {
        let items = (self.items ?? []).compactMap { $0.domainModel() }
        return DynamicsPage(
            items: items,
            offset: offset ?? "",
            hasMore: (hasMore?.value ?? 0) != 0
        )
    }
}

extension DynamicsFeedResponse.Item {
    func domainModel() -> DynamicItem? {
        guard let idStr, !idStr.isEmpty else { return nil }

        let author = modules?.author
        let body = modules?.dynamic
        let major = body?.major
        let baseText = (body?.desc?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        var kind: DynamicItem.Kind = .text
        var images: [URL] = []
        var video: VideoCard?
        var articleID: Int?
        var articleTitle: String?
        var articleCover: URL?

        if let archive = major?.archive,
           let bvid = archive.bvid,
           !bvid.isEmpty {
            kind = .video
            video = VideoCard(
                bvid: bvid,
                aid: archive.aid?.value,
                cid: nil,
                title: (archive.title ?? "视频").removingHTMLTags,
                coverURL: Self.httpsURL(archive.cover),
                ownerName: author?.name ?? "",
                ownerFaceURL: Self.httpsURL(author?.face),
                duration: SearchTypeResponse.Item.parseDuration(archive.durationText),
                viewCount: archive.stat?.play?.value ?? 0,
                danmakuCount: archive.stat?.danmaku?.value ?? 0,
                publishedAt: nil
            )
        } else if let drawItems = major?.draw?.items, !drawItems.isEmpty {
            kind = .images
            images = drawItems.compactMap { Self.httpsURL($0.src) }
        } else if let pics = major?.opus?.pics, !pics.isEmpty {
            kind = .images
            images = pics.compactMap { Self.httpsURL($0.url) }
        } else if let article = major?.article, let cvid = article.id?.value {
            kind = .article
            articleID = cvid
            articleTitle = article.title
            articleCover = Self.httpsURL(article.covers?.first)
        }

        let text = baseText.isEmpty
            ? (major?.opus?.summary?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            : baseText

        guard !text.isEmpty || !images.isEmpty || video != nil || articleID != nil else {
            return nil
        }

        let stat = modules?.stat
        return DynamicItem(
            id: idStr,
            kind: kind,
            authorMid: author?.mid,
            authorName: author?.name ?? "用户",
            authorFaceURL: Self.httpsURL(author?.face),
            publishedAt: author?.pubTs.map { Date(timeIntervalSince1970: TimeInterval($0.value)) },
            text: text,
            imageURLs: images,
            video: video,
            articleID: articleID,
            articleTitle: articleTitle,
            articleCoverURL: articleCover,
            likeCount: stat?.like?.count?.value ?? 0,
            commentCount: stat?.comment?.count?.value ?? 0,
            forwardCount: stat?.forward?.count?.value ?? 0
        )
    }

    private static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        }
        return URL(string: raw)
    }
}
