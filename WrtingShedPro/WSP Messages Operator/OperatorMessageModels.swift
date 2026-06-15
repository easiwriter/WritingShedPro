import Foundation

struct OperatorMessage: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var body: String
    let createdAt: TimeInterval
    var updatedAt: TimeInterval
    var isArchived: Bool
}

struct OperatorMessagesResponse: Codable {
    let messages: [OperatorMessage]
}
