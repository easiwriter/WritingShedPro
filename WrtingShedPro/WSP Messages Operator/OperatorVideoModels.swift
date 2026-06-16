import Foundation

struct OperatorVideo: Identifiable, Codable, Equatable {
    let id: String
    let key: String
    let title: String
    let fileName: String
    let fileExtension: String
    let size: Int?
    let updatedAt: TimeInterval?
}

struct OperatorVideosResponse: Codable {
    let videos: [OperatorVideo]
}
