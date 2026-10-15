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
        case "trial": return "Unconverted Trials"
        case "convertedTrial": return "Converted Trials"
        case "fullAccess": return "Direct Full Access"
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
        case "trial": return 5
        case "convertedTrial": return 6
        case "fullAccess": return 7
        case "manuscriptAnalyst": return 8
        default: return 99
        }
    }
}

struct OperatorSalesResponse: Codable {
    let months: [String]
    let selectedMonth: String
    let sales: [OperatorSalesRecord]
    let verificationFailures: [OperatorVerificationFailure]?
}

struct OperatorVerificationFailure: Identifiable, Codable, Equatable {
    let transactionID: String
    let productID: String
    let category: String
    let statusCode: Int
    let reason: String
    let firstSeenAt: TimeInterval
    let lastSeenAt: TimeInterval
    let attemptCount: Int
    let isResolved: Bool
    let resolvedAt: TimeInterval?

    var id: String { "\(transactionID)-\(productID)" }

    var maskedTransactionID: String {
        "••••\(transactionID.suffix(6))"
    }

    var productDisplayName: String {
        switch productID {
        case "com.writingshedpro.prosewriter": return "Prose Writer"
        case "com.writingshedpro.poetrywriter": return "Poetry Writer"
        case "com.writingshedpro.fictionwriter": return "Fiction Writer"
        case "com.writingshedpro.dramawriter": return "Drama Writer"
        case "com.writingshedpro.allinbundle": return "All-in Bundle"
        case "com.writingshedpro.trial10day": return "10-day Trial"
        case "com.writingshedpro.fullaccess": return "Full Access"
        case "com.writingshedpro.manuscriptanalyst": return "Manuscript Analyst"
        default: return productID
        }
    }

    var categoryDisplayName: String {
        if isResolved {
            return "Resolved"
        }
        return category == "appleRejected" ? "Apple Rejected" : "Temporary Failure"
    }

    var lastSeenDate: Date {
        Date(timeIntervalSince1970: lastSeenAt / 1000)
    }
}
