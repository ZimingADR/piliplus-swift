import Foundation

// MARK: - 番剧详情

struct PGCSeason: Sendable {
    let seasonID: Int
    let title: String
    let coverURL: URL?
    let evaluate: String
    let score: Double
    let areas: [String]
    let episodes: [PGCEpisode]
    let viewCount: Int
    let newEpisodeText: String

    var episodeCountText: String {
        episodes.isEmpty ? "暂无剧集" : "全 \(episodes.count) 话"
    }
}

struct PGCEpisode: Identifiable, Sendable, Equatable {
    let id: Int
    let aid: Int?
    let bvid: String
    let cid: Int?
    let title: String
    let longTitle: String
    let coverURL: URL?
    let duration: Int
    let badge: String?

    var displayTitle: String {
        longTitle.isEmpty ? title : "\(title) · \(longTitle)"
    }

    var durationText: String {
        duration > 0 ? VideoCard.formatDuration(duration) : ""
    }
}

struct PGCSeasonResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Rating: Decodable, Sendable {
            let score: FlexDouble?
        }

        struct Area: Decodable, Sendable {
            let name: String?
        }

        struct Stat: Decodable, Sendable {
            let views: FlexInt?
        }

        struct NewEpisode: Decodable, Sendable {
            let indexShow: String?

            enum CodingKeys: String, CodingKey {
                case indexShow = "index_show"
            }
        }

        struct Episode: Decodable, Sendable {
            let id: FlexInt?
            let epID: FlexInt?
            let aid: FlexInt?
            let bvid: String?
            let cid: FlexInt?
            let title: String?
            let longTitle: String?
            let cover: String?
            let duration: FlexInt?
            let badge: String?

            enum CodingKeys: String, CodingKey {
                case id, aid, bvid, cid, title, cover, duration, badge
                case epID = "ep_id"
                case longTitle = "long_title"
            }
        }

        let seasonID: FlexInt?
        let title: String?
        let cover: String?
        let evaluate: String?
        let rating: Rating?
        let areas: [Area]?
        let episodes: [Episode]?
        let stat: Stat?
        let newEp: NewEpisode?

        enum CodingKeys: String, CodingKey {
            case title, cover, evaluate, rating, areas, episodes, stat
            case seasonID = "season_id"
            case newEp = "new_ep"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension PGCSeasonResponse.Payload {
    func domainModel() -> PGCSeason? {
        guard let seasonID = seasonID?.value, seasonID > 0 else { return nil }
        let mappedEpisodes: [PGCEpisode] = (episodes ?? []).compactMap { episode in
            let epID = episode.epID?.value ?? episode.id?.value ?? 0
            guard epID > 0 else { return nil }
            return PGCEpisode(
                id: epID,
                aid: episode.aid?.value,
                bvid: episode.bvid ?? "",
                cid: episode.cid?.value,
                title: episode.title ?? "第 \(epID) 话",
                longTitle: episode.longTitle ?? "",
                coverURL: Self.httpsURL(episode.cover),
                duration: (episode.duration?.value ?? 0) / 1000,
                badge: episode.badge
            )
        }

        return PGCSeason(
            seasonID: seasonID,
            title: title ?? "番剧",
            coverURL: Self.httpsURL(cover),
            evaluate: evaluate ?? "",
            score: rating?.score?.value ?? 0,
            areas: (areas ?? []).compactMap(\.name),
            episodes: mappedEpisodes,
            viewCount: stat?.views?.value ?? 0,
            newEpisodeText: newEp?.indexShow ?? ""
        )
    }

    private static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        return URL(string: raw.hasPrefix("//") ? "https:" + raw : raw)
    }
}

// MARK: - 番剧索引

struct PGCIndexPage: Sendable {
    let items: [PGCIndexItem]
    let hasNext: Bool
}

struct PGCIndexItem: Identifiable, Sendable, Equatable {
    let id: Int
    let title: String
    let coverURL: URL?
    let indexShow: String
    let badge: String?
}

struct PGCIndexResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let seasonID: FlexInt?
            let title: String?
            let cover: String?
            let indexShow: String?
            let badge: String?

            enum CodingKeys: String, CodingKey {
                case title, cover, badge
                case seasonID = "season_id"
                case indexShow = "index_show"
            }
        }

        let hasNext: FlexInt?
        let list: [Item]?

        enum CodingKeys: String, CodingKey {
            case list
            case hasNext = "has_next"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension PGCIndexResponse.Payload {
    var domainPage: PGCIndexPage {
        let items: [PGCIndexItem] = (list ?? []).compactMap { item in
            guard let seasonID = item.seasonID?.value else { return nil }
            let cover = item.cover.flatMap { raw -> URL? in
                URL(string: raw.hasPrefix("//") ? "https:" + raw : raw)
            }
            return PGCIndexItem(
                id: seasonID,
                title: item.title ?? "番剧",
                coverURL: cover,
                indexShow: item.indexShow ?? "",
                badge: item.badge
            )
        }
        return PGCIndexPage(items: items, hasNext: (hasNext?.value ?? 0) != 0)
    }
}
