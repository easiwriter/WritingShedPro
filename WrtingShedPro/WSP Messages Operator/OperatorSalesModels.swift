import Foundation

struct OperatorSalesRecord: Identifiable, Codable, Equatable {
    let month: String
    let projectType: String
    let count: Int
    let updatedAt: TimeInterval

    var id: String { "\(month)-\(projectType)" }

    var displayName: String {
        switch projectType {
        case "prose": return "Prose"
        case "poetry": return "Poetry"
        case "fiction": return "Fiction"
        case "drama": return "Drama"
        case "bundle": return "All-in Bundle"
        case "manuscriptAnalyst": return "Manuscript Analyst"
        default: return projectType
        }
    }

    var sortOrder: Int {
        switch projectType {
        case "prose": return 0
        case "poetry": return 1
        case "fiction": return 2
        case "drama": return 3
        case "bundle": return 4
        case "manuscriptAnalyst": return 5
        default: return 99
        }
    }
}

struct OperatorSalesResponse: Codable {
    let months: [String]
    let selectedMonth: String
    let sales: [OperatorSalesRecord]
}
