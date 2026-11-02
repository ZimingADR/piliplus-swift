import Foundation

/// `playurl` 接口返回的可播放流信息。
struct PlayURLResult: Sendable {
    let quality: Int
    let duration: Double
    let videoTracks: [VideoTrack]
    let audioTracks: [AudioTrack]
    let availableQualities: [VideoQuality]
    let measurement: LoudnessMeasurement?
    /// `platform=html5` 返回的合流 MP4，供系统播放器 / 画中画使用。
    let muxedURL: URL?

    func videoTrack(preferring quality: Int, codec: VideoCodecPreference = .automatic) -> VideoTrack? {
        guard !videoTracks.isEmpty else { return nil }
        let candidates = videoTracks.filter { $0.quality <= quality }
        let pool = candidates.isEmpty ? videoTracks : candidates
        let bestQuality = pool.map(\.quality).max() ?? quality
        let sameQuality = pool.filter { $0.quality == bestQuality }
        return sameQuality.sorted { lhs, rhs in
            codecPriority(lhs, preference: codec) < codecPriority(rhs, preference: codec)
        }.first
    }

    func audioTrack() -> AudioTrack? {
        audioTracks.max { lhs, rhs in
            if lhs.bandwidth == rhs.bandwidth {
                return lhs.id < rhs.id
            }
            return lhs.bandwidth < rhs.bandwidth
        }
    }

    private func codecPriority(_ track: VideoTrack, preference: VideoCodecPreference) -> Int {
        switch preference {
        case .automatic: track.codecid == 7 ? 0 : (track.codecid == 12 ? 1 : 2)
        case .h264: track.codecid == 7 ? 0 : 1
        case .hevc: track.codecid == 12 ? 0 : 1
        case .av1: track.codecid == 13 ? 0 : 1
        }
    }
}

struct VideoTrack: Identifiable, Sendable, Hashable {
    let quality: Int
    let url: URL
    let backupURLs: [URL]
    let codecid: Int
    let codec: String
    let width: Int
    let height: Int
    let frameRate: Int
    let bandwidth: Int

    var id: Int { quality * 100 + codecid }

    var resolutionText: String {
        guard width > 0, height > 0 else { return "未知分辨率" }
        return "\(width)×\(height)"
    }
}

struct AudioTrack: Identifiable, Sendable, Hashable {
    let id: Int
    let url: URL
    let backupURLs: [URL]
    let codec: String
    let bandwidth: Int
}

struct VideoQuality: Identifiable, Sendable, Hashable {
    let id: Int
    let title: String
    let codec: String
}

enum VideoCodecPreference: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case h264
    case hevc
    case av1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "自动"
        case .h264: "H.264 / AVC"
        case .hevc: "H.265 / HEVC"
        case .av1: "AV1"
        }
    }
}

// MARK: - 清晰度

enum BiliQuality {
    static let quality360p = 16
    static let quality480p = 32
    static let quality720p = 64
    static let quality1080p = 80
    static let quality1080pPlus = 112
    static let quality1080p60 = 116
    static let quality4K = 120
    static let qualityHDR = 125
    static let qualityDolby = 126
    static let quality8K = 127

    static let defaultQuality = quality1080p

    static func title(for quality: Int) -> String {
        switch quality {
        case 6: "240P 极速"
        case 16: "360P 流畅"
        case 32: "480P 清晰"
        case 64: "720P 高清"
        case 74: "720P60 高帧率"
        case 80: "1080P 高清"
        case 112: "1080P+ 高码率"
        case 116: "1080P60 高帧率"
        case 120: "4K 超清"
        case 125: "HDR 真彩"
        case 126: "杜比视界"
        case 127: "8K 超高清"
        default: "\(quality)P"
        }
    }
}

// MARK: - 响应解码

struct PlayURLResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Dash: Decodable, Sendable {
            struct Video: Decodable, Sendable {
                enum CodingKeys: String, CodingKey {
                    case id, bandwidth, codecs, codecid, width, height
                    case baseUrl
                    case baseUrlSnake = "base_url"
                    case backupURLs
                    case backupURLsSnake = "backup_url"
                    case frameRate
                    case frameRateSnake = "frame_rate"
                }

                let id: FlexInt?
                let baseUrl: String?
                let backupURLs: [String]?
                let bandwidth: FlexInt?
                let codecs: String?
                let codecid: FlexInt?
                let width: FlexInt?
                let height: FlexInt?
                let frameRate: FlexInt?

                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    id = try? container.decode(FlexInt.self, forKey: .id)
                    baseUrl = (try? container.decodeIfPresent(String.self, forKey: .baseUrl))
                        ?? (try? container.decodeIfPresent(String.self, forKey: .baseUrlSnake))
                    backupURLs = (try? container.decodeIfPresent([String].self, forKey: .backupURLs))
                        ?? (try? container.decodeIfPresent([String].self, forKey: .backupURLsSnake))
                    bandwidth = try? container.decode(FlexInt.self, forKey: .bandwidth)
                    codecs = try? container.decodeIfPresent(String.self, forKey: .codecs)
                    codecid = try? container.decode(FlexInt.self, forKey: .codecid)
                    width = try? container.decode(FlexInt.self, forKey: .width)
                    height = try? container.decode(FlexInt.self, forKey: .height)
                    frameRate = (try? container.decode(FlexInt.self, forKey: .frameRate))
                        ?? (try? container.decode(FlexInt.self, forKey: .frameRateSnake))
                }
            }

            struct Audio: Decodable, Sendable {
                enum CodingKeys: String, CodingKey {
                    case id, bandwidth, codecs
                    case baseUrl
                    case baseUrlSnake = "base_url"
                    case backupURLs
                    case backupURLsSnake = "backup_url"
                }

                let id: FlexInt?
                let baseUrl: String?
                let backupURLs: [String]?
                let bandwidth: FlexInt?
                let codecs: String?

                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    id = try? container.decode(FlexInt.self, forKey: .id)
                    baseUrl = (try? container.decodeIfPresent(String.self, forKey: .baseUrl))
                        ?? (try? container.decodeIfPresent(String.self, forKey: .baseUrlSnake))
                    backupURLs = (try? container.decodeIfPresent([String].self, forKey: .backupURLs))
                        ?? (try? container.decodeIfPresent([String].self, forKey: .backupURLsSnake))
                    bandwidth = try? container.decode(FlexInt.self, forKey: .bandwidth)
                    codecs = try? container.decodeIfPresent(String.self, forKey: .codecs)
                }
            }

            let duration: FlexDouble?
            let video: [Video]?
            let audio: [Audio]?
        }

        struct Durl: Decodable, Sendable {
            let url: String?
        }

        struct SupportFormat: Decodable, Sendable {
            let quality: FlexInt?
            let newDescription: String?
            let displayDesc: String?
            let codecs: String?

            enum CodingKeys: String, CodingKey {
                case quality, codecs
                case newDescription = "new_description"
                case displayDesc = "display_desc"
            }
        }

        struct Volume: Decodable, Sendable {
            let measuredI: FlexDouble?

            enum CodingKeys: String, CodingKey {
                case measuredI = "measured_i"
            }
        }

        let quality: FlexInt?
        let timelength: FlexDouble?
        let dash: Dash?
        let durl: [Durl]?
        let supportFormats: [SupportFormat]?
        let volume: Volume?

        enum CodingKeys: String, CodingKey {
            case quality, timelength, dash, durl, volume
            case supportFormats = "support_formats"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension PlayURLResponse.Payload {
    func result() -> PlayURLResult? {
        let quality = quality?.value ?? BiliQuality.defaultQuality
        let duration = (timelength.map { $0.value / 1000 })
            ?? (dash?.duration.map(\.value))
            ?? 0

        let videoTracks: [VideoTrack] = (dash?.video ?? []).compactMap { item in
            guard let raw = item.baseUrl, let url = Self.httpsURL(raw) else { return nil }
            return VideoTrack(
                quality: item.id?.value ?? quality,
                url: url,
                backupURLs: (item.backupURLs ?? []).compactMap(Self.httpsURL),
                codecid: item.codecid?.value ?? 0,
                codec: item.codecs ?? "",
                width: item.width?.value ?? 0,
                height: item.height?.value ?? 0,
                frameRate: item.frameRate?.value ?? 0,
                bandwidth: item.bandwidth?.value ?? 0
            )
        }

        let audioTracks: [AudioTrack] = (dash?.audio ?? []).compactMap { item in
            guard let raw = item.baseUrl, let url = Self.httpsURL(raw) else { return nil }
            return AudioTrack(
                id: item.id?.value ?? 0,
                url: url,
                backupURLs: (item.backupURLs ?? []).compactMap(Self.httpsURL),
                codec: item.codecs ?? "",
                bandwidth: item.bandwidth?.value ?? 0
            )
        }

        guard !videoTracks.isEmpty else {
            let muxed = (durl ?? []).compactMap { $0.url.flatMap(Self.httpsURL) }.first
            guard let muxed else { return nil }
            return PlayURLResult(
                quality: quality,
                duration: duration,
                videoTracks: [],
                audioTracks: [],
                availableQualities: [VideoQuality(id: quality, title: BiliQuality.title(for: quality), codec: "")],
                measurement: nil,
                muxedURL: muxed
            )
        }

        let qualities: [VideoQuality] = (supportFormats ?? []).compactMap { format in
            guard let qn = format.quality?.value else { return nil }
            let title = format.newDescription?.isEmpty == false
                ? format.newDescription!
                : (format.displayDesc?.isEmpty == false ? format.displayDesc! : BiliQuality.title(for: qn))
            return VideoQuality(id: qn, title: title, codec: format.codecs ?? "")
        }

        return PlayURLResult(
            quality: quality,
            duration: duration,
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            availableQualities: qualities.isEmpty
                ? [VideoQuality(id: quality, title: BiliQuality.title(for: quality), codec: "")]
                : qualities.sorted { $0.id < $1.id },
            measurement: volume?.measuredI.map { LoudnessMeasurement(integratedLUFS: $0.value) },
            muxedURL: (durl ?? []).compactMap { $0.url.flatMap(Self.httpsURL) }.first
        )
    }

    private static func httpsURL(_ raw: String) -> URL? {
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        }
        return URL(string: raw)
    }
}

/// 浮点字段有时是数字、有时是字符串。
struct FlexDouble: Decodable, Sendable, Equatable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = Double(string) ?? 0
        } else {
            value = 0
        }
    }
}
