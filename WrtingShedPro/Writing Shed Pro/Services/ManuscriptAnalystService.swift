import Foundation
import SwiftData

/// Service for managing Manuscript Analyst reviews and CloudFlare API integration.
@MainActor
final class ManuscriptAnalystService {
    static let shared = ManuscriptAnalystService()

    private var reviewCache: [String: ManuscriptReview] = [:]
    private let cacheSchemaVersion = "v3"
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

        guard let project = textFile.project else {
            throw ManuscriptAnalystError.projectNotFound
        }

        let content = normalizeContentForAnalysis(
            textFile.currentContent,
            projectType: project.type
        )
        let cacheKey = "\(cacheSchemaVersion)_file_\(textFile.id)_\(contentFingerprint(content))"
        if let cached = reviewCache[cacheKey] {
            return cached
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
            content: content,
            fileCount: 1
        )

        let response = try await callCloudFlareAPI(request)
        let review = parseResponse(
            response,
            fileId: textFile.id,
            projectId: project.id,
            sourceContent: content
        )

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

        let analysisProfile = determineAnalysisProfile(
            projectType: project.type,
            fictionClass: project.fictionClassRaw
        )

        // Assemble content from all body-section files
        let bodyFiles = assembleManuscriptContent(from: project)
        guard !bodyFiles.content.isEmpty else {
            throw ManuscriptAnalystError.noContentToAnalyze
        }

        let cacheKey = "\(cacheSchemaVersion)_manuscript_\(project.id)_\(contentFingerprint(bodyFiles.content))"
        if let cached = reviewCache[cacheKey] {
            return cached
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
        let review = parseResponse(
            response,
            fileId: nil,
            projectId: project.id,
            sourceContent: bodyFiles.content
        )

        // Cache the result
        reviewCache[cacheKey] = review
        
        // Track usage
        recordUsage(tokensUsed: response.metadata.tokensUsed)

        return review
    }

    /// Review raw drama text that is not tied to a persisted TextFile.
    func reviewRawDramaText(
        _ rawText: String,
        fileName: String = "Raw Drama",
        projectId: UUID? = nil
    ) async throws -> ManuscriptReview {
        guard EntitlementManager.shared.isManuscriptAnalystSubscriptionActive() else {
            throw ManuscriptAnalystError.subscriptionInactive
        }

        let content = normalizeContentForAnalysis(rawText, projectType: .drama)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ManuscriptAnalystError.noContentToAnalyze
        }

        let cacheKey = "\(cacheSchemaVersion)_raw_drama_\(contentFingerprint(fileName + "|" + content))"
        if let cached = reviewCache[cacheKey] {
            return cached
        }

        let request = buildRequest(
            analysisMode: "file",
            projectType: ProjectType.drama.rawValue,
            fictionClass: nil,
            analysisProfile: "drama",
            fileName: fileName,
            content: content,
            fileCount: 1
        )

        let response = try await callCloudFlareAPI(request)
        let review = parseResponse(
            response,
            fileId: nil,
            projectId: projectId ?? UUID(),
            sourceContent: content
        )

        reviewCache[cacheKey] = review
        recordUsage(tokensUsed: response.metadata.tokensUsed)

        return review
    }

    /// Review a raw drama text file (for example .txt/.dml) without importing it first.
    func reviewRawDramaFile(
        at url: URL,
        projectId: UUID? = nil
    ) async throws -> ManuscriptReview {
        let fileName = url.deletingPathExtension().lastPathComponent
        let content = try readRawDramaTextFile(at: url)
        return try await reviewRawDramaText(content, fileName: fileName, projectId: projectId)
    }

    /// Clear cached review for a text file.
    func clearReviewCache(for textFile: TextFile) {
        let prefix = "\(cacheSchemaVersion)_file_\(textFile.id)_"
        reviewCache = reviewCache.filter { !$0.key.hasPrefix(prefix) }
    }

    /// Clear cached review for a manuscript.
    func clearReviewCache(for project: Project) {
        let prefix = "\(cacheSchemaVersion)_manuscript_\(project.id)_"
        reviewCache = reviewCache.filter { !$0.key.hasPrefix(prefix) }
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
                let content = normalizeContentForAnalysis(
                    file.currentContent,
                    projectType: project.type
                )
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
        projectId: UUID,
        sourceContent: String
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
                location: reconcileLocation(
                    normalizeLineLocation(suggestionResponse.location),
                    observation: suggestionResponse.observation,
                    sourceContent: sourceContent
                ),
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

    private func normalizeLineLocation(_ rawLocation: String?) -> String? {
        guard let rawLocation else { return nil }
        let trimmed = rawLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let pattern = #"(?i)line\s*(\d+)(?:\s*[-–]\s*(\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let firstRange = Range(match.range(at: 1), in: trimmed),
              let firstValue = Int(trimmed[firstRange]) else {
            return trimmed
        }

        if let secondRange = Range(match.range(at: 2), in: trimmed),
           let secondValue = Int(trimmed[secondRange]) {
            return "Line \(firstValue)-\(secondValue)"
        }

        return "Line \(firstValue)"
    }

    private func reconcileLocation(_ normalizedLocation: String?, observation: String, sourceContent: String) -> String? {
        guard let quotedPhrase = extractQuotedPhrase(from: observation),
              let inferredLine = inferLineNumber(forPhrase: quotedPhrase, in: sourceContent) else {
            return normalizedLocation
        }

        if let normalizedLocation,
           let existingLine = parseSingleLineNumber(from: normalizedLocation),
           existingLine == inferredLine {
            return normalizedLocation
        }

        return "Line \(inferredLine)"
    }

    private func extractQuotedPhrase(from text: String) -> String? {
        let patterns = [#"'([^'\n]{3,160})'"#, #"\"([^\"\n]{3,160})\""#]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let phraseRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let phrase = text[phraseRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if !phrase.isEmpty {
                return phrase
            }
        }

        return nil
    }

    private func inferLineNumber(forPhrase phrase: String, in sourceContent: String) -> Int? {
        guard !phrase.isEmpty, !sourceContent.isEmpty else { return nil }

        let sourceNSString = sourceContent as NSString
        let phraseRange = NSRange(sourceContent.startIndex..., in: sourceContent)
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        guard let regex = try? NSRegularExpression(pattern: escaped, options: [.caseInsensitive]) else {
            return nil
        }

        let matches = regex.matches(in: sourceContent, options: [], range: phraseRange)
        guard matches.count == 1 else {
            return nil
        }

        let location = matches[0].range.location
        let prefix = sourceNSString.substring(to: location)
        return prefix.components(separatedBy: .newlines).count
    }

    private func parseSingleLineNumber(from location: String) -> Int? {
        let pattern = #"(?i)line\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: location, range: NSRange(location.startIndex..., in: location)),
              let lineRange = Range(match.range(at: 1), in: location) else {
            return nil
        }
        return Int(location[lineRange])
    }

    private func contentFingerprint(_ content: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in content.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }

    private func normalizeContentForAnalysis(_ content: String, projectType: ProjectType) -> String {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if projectType == .drama {
            return addDramaLineNumbers(normalized)
        }

        return normalized
    }

    private func addDramaLineNumbers(_ content: String) -> String {
        guard !content.isEmpty else { return content }

        let lines = content.components(separatedBy: "\n")

        // Avoid double-numbering if content already appears line-numbered.
        if let firstNonEmptyLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           firstNonEmptyLine.range(of: #"^\s*\d{3,6}\s\|"#, options: .regularExpression) != nil {
            return content
        }

        return lines.enumerated()
            .map { index, line in
                let number = String(format: "%04d", index + 1)
                return "\(number) | \(line)"
            }
            .joined(separator: "\n")
    }

    private func readRawDramaTextFile(at url: URL) throws -> String {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let utf16LE = String(data: data, encoding: .utf16LittleEndian) {
            return utf16LE
        }
        if let utf16BE = String(data: data, encoding: .utf16BigEndian) {
            return utf16BE
        }

        throw ManuscriptAnalystError.fileReadError("Unable to decode this text file. Please use UTF-8 or UTF-16 encoding.")
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
    case fileReadError(String)

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
        case .fileReadError(let message):
            return message
        }
    }
}
