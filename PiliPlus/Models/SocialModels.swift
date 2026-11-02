import Foundation

// MARK: - 通用操作响应

struct ActionResponse: Decodable, Sendable {
    let code: Int
    let message: String?
}

// MARK: - 收藏夹

struct FavoriteFolder: Identifiable, Sendable, Equatable {
    let id: Int
    let title: String
    let mediaCount: Int
    let coverURL: URL?
}

struct FavoriteFoldersResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let id: Int?
            let title: String?
            let mediaCount: FlexInt?
            let cover: String?
        }

        let count: FlexInt?
        let list: [Item]?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct FavoritePage: Sendable {
    let folderTitle: String
    let videos: [VideoCard]
    let page: Int
    let hasMore: Bool
    let total: Int
}

struct FavoriteResourceResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Info: Decodable, Sendable {
            let id: FlexInt?
            let title: String?
            let mediaCount: FlexInt?
        }

        struct Media: Decodable, Sendable {
            struct Upper: Decodable, Sendable {
                let mid: Int?
                let name: String?
            }

            struct CountInfo: Decodable, Sendable {
                let play: FlexInt?
                let danmaku: FlexInt?
            }

            let id: FlexInt?
            let bvid: String?
            let title: String?
            let cover: String?
            let duration: FlexInt?
            let type: FlexInt?
            let upper: Upper?
            let cntInfo: CountInfo?

            enum CodingKeys: String, CodingKey {
                case id, bvid, title, cover, duration, type, upper
                case cntInfo = "cnt_info"
            }
        }

        let info: Info?
        let medias: [Media]?
        let hasMore: Bool?

        enum CodingKeys: String, CodingKey {
            case info, medias
            case hasMore = "has_more"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

// MARK: - 关注

struct FollowUser: Identifiable, Sendable, Equatable {
    let mid: Int
    let name: String
    let faceURL: URL?
    let sign: String
    let isVip: Bool

    var id: Int { mid }
}

struct FollowPage: Sendable {
    let users: [FollowUser]
    let page: Int
    let total: Int
}

struct FollowingsResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            struct VIP: Decodable, Sendable {
                let status: FlexInt?
            }

            let mid: Int?
            let uname: String?
            let face: String?
            let sign: String?
            let vip: VIP?
        }

        let list: [Item]?
        let total: FlexInt?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

// MARK: - 评论

struct VideoComment: Identifiable, Sendable, Equatable {
    let id: Int64
    let userName: String
    let avatarURL: URL?
    let level: Int
    let message: String
    let likeCount: Int
    let replyCount: Int
    let createdAt: Date?
    let isUp: Bool
}

struct CommentPage: Sendable {
    let comments: [VideoComment]
    let nextOffset: String
    let isEnd: Bool
    let total: Int
}

struct CommentsResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Member: Decodable, Sendable {
            struct LevelInfo: Decodable, Sendable {
                let currentLevel: FlexInt?

                enum CodingKeys: String, CodingKey {
                    case currentLevel = "current_level"
                }
            }

            let mid: String?
            let uname: String?
            let avatar: String?
            let levelInfo: LevelInfo?

            enum CodingKeys: String, CodingKey {
                case mid, uname, avatar
                case levelInfo = "level_info"
            }
        }

        struct Content: Decodable, Sendable {
            let message: String?
        }

        struct Reply: Decodable, Sendable {
            let rpid: FlexInt?
            let mid: FlexInt?
            let member: Member?
            let content: Content?
            let like: FlexInt?
            let ctime: FlexInt?
            let rcount: FlexInt?
        }

        struct Cursor: Decodable, Sendable {
            struct Pagination: Decodable, Sendable {
                let nextOffset: String?

                enum CodingKeys: String, CodingKey {
                    case nextOffset = "next_offset"
                }
            }

            let isEnd: Bool?
            let allCount: FlexInt?
            let paginationReply: Pagination?

            enum CodingKeys: String, CodingKey {
                case isEnd = "is_end"
                case allCount = "all_count"
                case paginationReply = "pagination_reply"
            }
        }

        struct Upper: Decodable, Sendable {
            let mid: Int?
        }

        let replies: [Reply]?
        let topReplies: [Reply]?
        let cursor: Cursor?
        let upper: Upper?

        enum CodingKeys: String, CodingKey {
            case replies, cursor, upper
            case topReplies = "top_replies"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

// MARK: - 楼中楼

struct ReplyRepliesResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Page: Decodable, Sendable {
            let pn: FlexInt?
            let ps: FlexInt?
            let count: FlexInt?
        }

        struct Upper: Decodable, Sendable {
            let mid: Int?
        }

        let replies: [CommentsResponse.Payload.Reply]?
        let page: Page?
        let upper: Upper?
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension CommentsResponse.Payload.Reply {
    /// 把接口 DTO 映射成 UI 模型。
    func videoComment(uploaderMid: Int?) -> VideoComment? {
        guard let rpid = rpid?.value else { return nil }
        let text = (content?.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return VideoComment(
            id: Int64(rpid),
            userName: member?.uname ?? "用户",
            avatarURL: RecommendFeedResponse.Item.httpsURL(member?.avatar),
            level: member?.levelInfo?.currentLevel?.value ?? 0,
            message: text,
            likeCount: like?.value ?? 0,
            replyCount: rcount?.value ?? 0,
            createdAt: ctime.map { Date(timeIntervalSince1970: TimeInterval($0.value)) },
            isUp: uploaderMid != nil && mid?.value == uploaderMid
        )
    }
}

/// 常用表情码（B 站会按 `[code]` 渲染图片）。
enum EmoteCatalog {
    static let codes = [
        "[doge]", "[笑哭]", "[妙啊]", "[脱单doge]", "[点赞]",
        "[鼓掌]", "[呲牙]", "[星星眼]", "[吃瓜]", "[惊喜]",
        "[歪嘴]", "[热词系列_好活]", "[笑]", "[思考]", "[委屈]",
    ]
}
