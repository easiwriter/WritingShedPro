import Foundation
import SwiftData

/// Service for managing Manuscript Analyst reviews and CloudFlare API integration.
@MainActor
final class ManuscriptAnalystService {
    static let shared = ManuscriptAnalystService()

    private var reviewCache: [String: ManuscriptReview] = [:]
    private let cloudFlareEndpoint = "https://wsp-support.writingshedpro.workers.dev/api/manuscript-analyst/review"
    
    // Soft cap tracking
    private var monthlyTokenUsage: Int = 0
    private var monthlyReviewCount: Int = 0
    private var currentSoftCapState: String = "normal"
    
    private init() {}

    // MARK: - Public API

    /// Review a single text file using the Manuscript Analyst service.
    func reviewFile(
        _ textFile: TextFile,
        modelContext: ModelContext
    ) async throws -> ManuscriptReview {
        // Validate subscription
        guard EntitlementManager.shared.isManuscriptAnalystSubscriptionActive() else {
            throw ManuscriptAnalystError.subscriptionInactive
        }

        let cacheKey = "file_\(textFile.id)"
        if let cached = reviewCache[cacheKey] {
            return cached
        }

        guard let project = textFile.project else {
            throw ManuscriptAnalystError.projectNotFound
        }

        let analysisProfile = determineAnalysisProfile(
            projectType: project.type,
            fictionClass: project.fictionClassRaw
        )

        let request = buildRequest(
            analysisMode: "file",
            projectType: project.type.rawValue,
            fictionClass: project.fictionClassRaw,
            analysisProfile: analysisProfile,
            fileName: textFile.name,
            content: textFile.currentContent,
            fileCount: 1
        )

        let response = try await callCloudFlareAPI(request)
        let review = parseResponse(response, fileId: textFile.id, projectId: project.id)

        // Cache the result
        reviewCache[cacheKey] = review
        
        // Track usage
        recordUsage(tokensUsed: response.metadata.tokensUsed)

        return review
    }

    /// Review an entire manuscript (all body-section files in a project).
    func reviewManuscript(
        _ project: Project,
        modelContext: ModelContext
    ) async throws -> ManuscriptReview {
        // Validate subscription
        guard EntitlementManager.shared.isManuscriptAnalystSubscriptionActive() else {
            throw ManuscriptAnalystError.subscriptionInactive
        }

        let cacheKey = "manuscript_\(project.id)"
        if let cached = reviewCache[cacheKey] {
            return cached
        }

        let analysisProfile = determineAnalysisProfile(
            projectType: project.type,
            fictionClass: project.fictionClassRaw
        )

        // Assemble content from all body-section files
        let bodyFiles = assembleManuscriptContent(from: project)
        guard !bodyFiles.content.isEmpty else {
            throw ManuscriptAnalystError.noContentToAnalyze
        }

        let request = buildRequest(
            analysisMode: "manuscript",
            projectType: project.type.rawValue,
            fictionClass: project.fictionClassRaw,
            analysisProfile: analysisProfile,
            fileName: project.name ?? "Untitled Manuscript",
            content: bodyFiles.content,
            fileCount: bodyFiles.fileCount
        )

        let response = try await callCloudFlareAPI(request)
        let review = parseResponse(response, fileId: nil, projectId: project.id)

        // Cache the result
        reviewCache[cacheKey] = review
        
        // Track usage
        recordUsage(tokensUsed: response.metadata.tokensUsed)

        return review
    }

    /// Clear cached review for a text file.
    func clearReviewCache(for textFile: TextFile) {
        let cacheKey = "file_\(textFile.id)"
        reviewCache.removeValue(forKey: cacheKey)
    }

    /// Clear cached review for a manuscript.
    func clearReviewCache(for project: Project) {
        let cacheKey = "manuscript_\(project.id)"
        reviewCache.removeValue(forKey: cacheKey)
    }

    /// Get current soft-cap state.
    func getSoftCapState() -> String {
        return currentSoftCapState
    }

    // MARK: - Private Helpers

    private func determineAnalysisProfile(projectType: ProjectType, fictionClass: String?) -> String {
        switch projectType {
        case .poetry:
            return "poetry"
        case .prose:
            return "prose"
        case .fiction:
            if let fictionClass = fictionClass {
                if fictionClass == "verseNovel" {
                    return "verseNovel"
                } else if fictionClass == "shortFiction" {
                    return "shortFiction"
                }
            }
            return "fiction"
        case .drama:
            return "drama"
        }
    }

    private func buildRequest(
        analysisMode: String,
        projectType: String,
        fictionClass: String?,
        analysisProfile: String,
        fileName: String,
        content: String,
        fileCount: Int
    ) -> ManuscriptAnalystRequest {
        let wordCount = content.split(separator: " ").count
        let metadata = ManuscriptAnalystRequest.RequestMetadata(
            fileName: fileName,
            fileCount: fileCount,
            wordCount: wordCount,
            documentationVersion: "1.0"
        )
        let options = AnalysisOptions(
            focusAreas: nil,
            severity: "all"
        )

        return ManuscriptAnalystRequest(
            analysisMode: analysisMode,
            projectType: projectType,
            fictionClass: fictionClass,
            analysisProfile: analysisProfile,
            subscriptionTier: "analyst.monthly.5_99",
            content: content,
            metadata: metadata,
            options: options
        )
    }

    private func assembleManuscriptContent(from project: Project) -> (content: String, fileCount: Int) {
        var combinedContent = ""
        var fileCount = 0

        // Get body-section folders
        let bodyFolders = project.folders?.filter { folder in
            FolderCapabilityService.isContentFolder(folder)
        } ?? []

        for folder in bodyFolders.sorted(by: { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }) {
            let files = (folder.textFiles ?? []).sorted(by: { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) })
            for file in files {
                let content = file.currentContent
                if !content.isEmpty {
                    combinedContent += "\n\n--- \(file.name) ---\n\n"
                    combinedContent += content
                    fileCount += 1
                }
            }
        }

        return (combinedContent, fileCount)
    }

    private func callCloudFlareAPI(_ request: ManuscriptAnalystRequest) async throws -> ManuscriptAnalystResponse {
        guard let url = URL(string: cloudFlareEndpoint) else {
            throw ManuscriptAnalystError.invalidEndpoint
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ManuscriptAnalystError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let statusError = "\(httpResponse.statusCode)"
            throw ManuscriptAnalystError.apiError("HTTP \(statusError)")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ManuscriptAnalystResponse.self, from: data)

        // Update soft cap state from response
        currentSoftCapState = apiResponse.metadata.softCapState

        return apiResponse
    }

    private func parseResponse(
        _ response: ManuscriptAnalystResponse,
        fileId: UUID?,
        projectId: UUID
    ) -> ManuscriptReview {
        let review = ManuscriptReview(
            reviewId: response.reviewId,
            timestamp: Date(),
            fileId: fileId,
            projectId: projectId,
            analysisMode: response.analysis.analysisProfile.contains("file") ? "file" : "manuscript",
            summary: response.analysis.summary,
            overallSentiment: response.analysis.overallSentiment,
            analysisProfile: response.analysis.analysisProfile,
            suggestedFocusOrder: response.analysis.suggestedFocusOrder
        )

        // Add suggestions
        for suggestionResponse in response.suggestions {
            let suggestion = ReviewSuggestion(
                suggestionId: suggestionResponse.id,
                category: suggestionResponse.category,
                severity: suggestionResponse.severity,
                location: suggestionResponse.location,
                observation: suggestionResponse.observation,
                suggestion: suggestionResponse.suggestion,
                rationale: suggestionResponse.rationale
            )
            review.suggestions.append(suggestion)
        }

        // Add metadata
        review.metadata = ReviewMetadata(
            contentAnalyzed: response.metadata.contentAnalyzed,
            tokensUsed: response.metadata.tokensUsed,
            analysisTimeMs: response.metadata.analysisTimeMs,
            model: response.metadata.model,
            softCapState: response.metadata.softCapState
        )

        return review
    }

    private func recordUsage(tokensUsed: Int) {
        monthlyTokenUsage += tokensUsed
        monthlyReviewCount += 1
        
        // Soft cap thresholds (conservative defaults)
        let tokenThreshold = 100_000  // 100K tokens per month
        
        if monthlyTokenUsage > Int(Double(tokenThreshold) * 0.9) {
            currentSoftCapState = "approaching_limit"
        } else if monthlyTokenUsage > tokenThreshold {
            currentSoftCapState = "throttled"
        }
    }
}

// MARK: - Error Types

enum ManuscriptAnalystError: LocalizedError {
    case subscriptionInactive
    case projectNotFound
    case noContentToAnalyze
    case invalidEndpoint
    case invalidResponse
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .subscriptionInactive:
            return NSLocalizedString("analyst.error.subscriptionInactive", comment: "Subscription inactive")
        case .projectNotFound:
            return NSLocalizedString("analyst.error.projectNotFound", comment: "Project not found")
        case .noContentToAnalyze:
            return NSLocalizedString("analyst.error.noContent", comment: "No content to analyze")
        case .invalidEndpoint:
            return NSLocalizedString("analyst.error.invalidEndpoint", comment: "Invalid endpoint")
        case .invalidResponse:
            return NSLocalizedString("analyst.error.invalidResponse", comment: "Invalid response from server")
        case .apiError(let message):
            return String(format: NSLocalizedString("analyst.error.apiError", comment: "API error: %@"), message)
        case .networkError(let error):
            return String(format: NSLocalizedString("analyst.error.network", comment: "Network error: %@"), error.localizedDescription)
        }
    }
}
