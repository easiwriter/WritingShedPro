import Foundation
import SwiftData

// MARK: - Manuscript Review

/// Represents a single editorial review of a file or manuscript performed by the Manuscript Analyst service.
@Model
final class ManuscriptReview {
    @Attribute(.unique) var reviewId: String
    var timestamp: Date
    var fileId: UUID?  // Null if manuscript-wide review
    var projectId: UUID
    var analysisMode: String  // "file" | "manuscript"

    var summary: String
    var overallSentiment: String  // "encouraging", "mixed", "critical"
    var suggestedFocusOrder: [String]?
    var analysisProfile: String  // "poetry", "prose", "fiction", "shortFiction", "drama", "verseNovel"

    @Relationship(deleteRule: .cascade) var suggestions: [ReviewSuggestion] = []

    var metadata: ReviewMetadata?
    var isArchived: Bool = false
    var userNotes: String?

    init(
        reviewId: String,
        timestamp: Date,
        fileId: UUID? = nil,
        projectId: UUID,
        analysisMode: String,
        summary: String,
        overallSentiment: String,
        analysisProfile: String,
        suggestedFocusOrder: [String]? = nil
    ) {
        self.reviewId = reviewId
        self.timestamp = timestamp
        self.fileId = fileId
        self.projectId = projectId
        self.analysisMode = analysisMode
        self.summary = summary
        self.overallSentiment = overallSentiment
        self.analysisProfile = analysisProfile
        self.suggestedFocusOrder = suggestedFocusOrder
    }
}

// MARK: - Review Suggestion

/// Represents a single editorial suggestion within a manuscript review.
@Model
final class ReviewSuggestion {
    var suggestionId: String
    var category: String
    var severity: String  // "high", "medium", "low"
    var location: String?
    var observation: String
    var suggestion: String
    var rationale: String
    var isAddressed: Bool = false
    var userNotes: String?

    init(
        suggestionId: String,
        category: String,
        severity: String,
        location: String?,
        observation: String,
        suggestion: String,
        rationale: String
    ) {
        self.suggestionId = suggestionId
        self.category = category
        self.severity = severity
        self.location = location
        self.observation = observation
        self.suggestion = suggestion
        self.rationale = rationale
    }
}

// MARK: - Review Metadata

struct ReviewMetadata: Codable {
    let contentAnalyzed: Int
    let tokensUsed: Int
    let analysisTimeMs: Int
    let model: String
    let softCapState: String  // "normal", "approaching_limit", "throttled"
}

// MARK: - API Request/Response Types

struct ManuscriptAnalystRequest: Codable {
    let analysisMode: String  // "file" | "manuscript"
    let projectType: String  // "fiction", "poetry", "drama", "prose"
    let fictionClass: String?  // "novel", "shortFiction", "verseNovel", or nil
    let analysisProfile: String
    let subscriptionTier: String
    let content: String
    let metadata: RequestMetadata
    let options: AnalysisOptions

    struct RequestMetadata: Codable {
        let fileName: String
        let fileCount: Int
        let wordCount: Int
        let documentationVersion: String
    }
}

struct AnalysisOptions: Codable {
    let focusAreas: [String]?
    let severity: String  // "all", "high", "medium_high"
}

struct ManuscriptAnalystResponse: Codable {
    let status: String
    let timestamp: String
    let reviewId: String
    let analysis: AnalysisResult
    let suggestions: [SuggestionResponse]
    let metadata: ResponseMetadata

    struct AnalysisResult: Codable {
        let summary: String
        let overallSentiment: String
        let analysisProfile: String
        let suggestedFocusOrder: [String]
    }

    struct ResponseMetadata: Codable {
        let contentAnalyzed: Int
        let tokensUsed: Int
        let analysisTimeMs: Int
        let model: String
        let softCapState: String
    }
}

struct SuggestionResponse: Codable {
    let id: String
    let category: String
    let severity: String
    let location: String?
    let observation: String
    let suggestion: String
    let rationale: String
}
