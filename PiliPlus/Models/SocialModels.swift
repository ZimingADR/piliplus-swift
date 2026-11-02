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
