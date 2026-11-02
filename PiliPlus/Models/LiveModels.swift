import Foundation

// MARK: - 直播列表

struct LiveRoom: Identifiable, Sendable, Equatable {
    let id: Int
    let title: String
    let uname: String
    let coverURL: URL?
    let faceURL: URL?
    let areaName: String
    let watchedText: String
}

struct LiveListResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct WatchedShow: Decodable, Sendable {
            let textLarge: String?

            enum CodingKeys: String, CodingKey {
                case textLarge = "text_large"
            }
        }

        struct Item: Decodable, Sendable {
            let roomID: FlexInt?
            let uid: FlexInt?
            let uname: String?
            let face: String?
            let cover: String?
            let title: String?
            let areaName: String?
            let watchedShow: WatchedShow?

            enum CodingKeys: String, CodingKey {
                case uid, uname, face, cover, title
                case roomID = "roomid"
                case areaName = "area_name"
                case watchedShow = "watched_show"
            }
        }

        let count: FlexInt?
        let list: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension LiveListResponse.Payload {
    var rooms: [LiveRoom] {
        (list ?? []).compactMap { item in
            guard let roomID = item.roomID?.value, roomID > 0 else { return nil }
            return LiveRoom(
                id: roomID,
                title: item.title ?? "直播间",
                uname: item.uname ?? "主播",
                coverURL: Self.httpsURL(item.cover),
                faceURL: Self.httpsURL(item.face),
                areaName: item.areaName ?? "直播",
                watchedText: item.watchedShow?.textLarge ?? ""
            )
        }
    }

    private static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        return URL(string: raw.hasPrefix("//") ? "https:" + raw : raw)
    }
}

// MARK: - 直播播放地址

struct LivePlayInfo: Sendable {
    let roomID: Int
    let title: String?
    let playURL: URL
    let isHLS: Bool
}

struct LivePlayInfoResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct PlayURLInfo: Decodable, Sendable {
            struct PlayURL: Decodable, Sendable {
                struct Stream: Decodable, Sendable {
                    struct Format: Decodable, Sendable {
                        struct Codec: Decodable, Sendable {
                            struct URLInfo: Decodable, Sendable {
                                let host: String?
                                let extra: String?
                            }

                            let codecName: String?
                            let currentQN: FlexInt?
                            let baseURL: String?
                            let urlInfo: [URLInfo]?

                            enum CodingKeys: String, CodingKey {
                                case codecName = "codec_name"
                                case currentQN = "current_qn"
                                case baseURL = "base_url"
                                case urlInfo = "url_info"
                            }
                        }

                        let formatName: String?
                        let codec: [Codec]?

                        enum CodingKeys: String, CodingKey {
                            case codec
                            case formatName = "format_name"
                        }
                    }

                    let protocolName: String?
                    let format: [Format]?

                    enum CodingKeys: String, CodingKey {
                        case format
                        case protocolName = "protocol_name"
                    }
                }

                let stream: [Stream]?
            }

            let playurl: PlayURL?
        }

        let roomID: FlexInt?
        let liveStatus: FlexInt?
        let playurlInfo: PlayURLInfo?

        enum CodingKeys: String, CodingKey {
            case roomID = "room_id"
            case liveStatus = "live_status"
            case playurlInfo = "playurl_info"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension LivePlayInfoResponse.Payload {
    /// 优先 FLV（http_stream），其次 HLS；取最高码率的一条。
    func bestPlayInfo(roomID fallbackRoomID: Int) -> LivePlayInfo? {
        guard let streams = playurlInfo?.playurl?.stream else { return nil }

        let flvStreams = streams.filter { $0.protocolName == "http_stream" }
        let hlsStreams = streams.filter { $0.protocolName == "http_hls" }
        let ordered = flvStreams + hlsStreams

        for stream in ordered {
            guard let format = stream.format?.first(where: { $0.formatName == "flv" })
                ?? stream.format?.first else { continue }

            let codecs = format.codec ?? []
            let preferred = codecs.first(where: { $0.codecName == "avc" }) ?? codecs.first
            guard let codec = preferred,
                  let baseURL = codec.baseURL,
                  let urlInfo = codec.urlInfo?.first,
                  let host = urlInfo.host else { continue }

            let combined = host + baseURL + (urlInfo.extra ?? "")
            guard let url = URL(string: combined) else { continue }

            return LivePlayInfo(
                roomID: roomID?.value ?? fallbackRoomID,
                title: nil,
                playURL: url,
                isHLS: stream.protocolName == "http_hls"
            )
        }
        return nil
    }
}

// MARK: - 直播分区

struct LiveArea: Identifiable, Hashable, Sendable, Decodable {
    let id: Int
    let name: String
    let parentID: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case parentID = "parent_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(FlexInt.self, forKey: .id).value ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "分区"
        parentID = try container.decodeIfPresent(FlexInt.self, forKey: .parentID)?.value ?? 0
    }
}

// MARK: - 直播搜索

struct LiveSearchResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let roomID: FlexInt?
            let uname: String?
            let title: String?
            let cover: String?
            let online: FlexInt?
            let areaName: String?

            enum CodingKeys: String, CodingKey {
                case uname, title, cover, online
                case roomID = "roomid"
                case areaName = "area_v2_name"
            }
        }

        let result: [Item]?
        let numResults: FlexInt?

        enum CodingKeys: String, CodingKey {
            case result
            case numResults = "numResults"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}
