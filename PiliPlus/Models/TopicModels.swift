import Foundation

struct TopicInfo: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let description: String
    let view: Int
    let discuss: Int
}

struct TopicTopResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let id: FlexInt?
            let name: String?
            let description: String?
            let view: FlexInt?
            let discuss: FlexInt?
        }

        struct TopDetails: Decodable, Sendable {
            let topicItem: Item?

            enum CodingKeys: String, CodingKey {
                case topicItem = "topic_item"
            }
        }

        let topDetails: TopDetails?

        enum CodingKeys: String, CodingKey {
            case topDetails = "top_details"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct TopicFeedResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct Item: Decodable, Sendable {
            let dynamicCardItem: DynamicsFeedResponse.Item?
            let topicType: String?

            enum CodingKeys: String, CodingKey {
                case dynamicCardItem = "dynamic_card_item"
                case topicType = "topic_type"
            }
        }

        struct CardList: Decodable, Sendable {
            let items: [Item]?
            let offset: String?
            let hasMore: FlexInt?

            enum CodingKeys: String, CodingKey {
                case items, offset
                case hasMore = "has_more"
            }
        }

        let topicCardList: CardList?

        enum CodingKeys: String, CodingKey {
            case topicCardList = "topic_card_list"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

struct TopicSearchResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        struct PageInfo: Decodable, Sendable {
            let hasMore: FlexInt?

            enum CodingKeys: String, CodingKey {
                case hasMore = "has_more"
            }
        }

        let topicItems: [TopicTopResponse.Payload.Item]?
        let pageInfo: PageInfo?

        enum CodingKeys: String, CodingKey {
            case topicItems = "topic_items"
            case pageInfo = "page_info"
        }
    }

    let code: Int
    let message: String?
    let data: Payload?
}

extension TopicTopResponse.Payload.Item {
    var topicInfo: TopicInfo? {
        guard let id = id?.value, id > 0 else { return nil }
        return TopicInfo(
            id: id,
            name: (name ?? "话题").removingHTMLTags,
            description: (description ?? "").removingHTMLTags,
            view: view?.value ?? 0,
            discuss: discuss?.value ?? 0
        )
    }
}
