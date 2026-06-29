import Foundation

struct OperatorMessage: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var body: String
    let createdAt: TimeInterval
    var updatedAt: TimeInterval
    var isArchived: Bool
    var isCritical: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt
        case updatedAt
        case isArchived
        case isCritical
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(TimeInterval.self, forKey: .createdAt)
        updatedAt = try container.decode(TimeInterval.self, forKey: .updatedAt)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isCritical = try container.decodeIfPresent(Bool.self, forKey: .isCritical) ?? false
    }
}

struct OperatorMessagesResponse: Codable {
    let messages: [OperatorMessage]
}
