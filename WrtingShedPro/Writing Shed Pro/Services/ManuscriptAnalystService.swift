import Foundation
import StoreKit
import SwiftData

/// Service for managing Manuscript Analyst reviews and CloudFlare API integration.
@MainActor
final class ManuscriptAnalystService {
    static let shared = ManuscriptAnalystService()

    private enum ReferenceUnit {
        case line
        case paragraph

        init(projectType: ProjectType) {
            self = projectType == .poetry ? .line : .paragraph
        }

        var label: String {
            switch self {
            case .line: return "Line"
            case .paragraph: return "Paragraph"
            }
        }
    }

    private var reviewCache: [String: ManuscriptReview] = [:]
    private let cacheSchemaVersion = "v8"
    private let manuscriptFileBoundaryPrefix = "[[WSP_FILE:"
    private let cloudFlareEndpoint = "https://wsp-support.wsp-support.workers.dev/api/manuscript-analyst/review"
    
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
        guard EntitlementManager.shared.canUseManuscriptAnalyst() else {
            throw ManuscriptAnalystError.subscriptionInactive
        }

        guard let project = textFile.project else {
            throw ManuscriptAnalystError.projectNotFound
        }

        let rawContent = contentForAnalysis(textFile, project: project)
        guard !rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ManuscriptAnalystError.noContentToAnalyze
        }

        let referenceUnit = ReferenceUnit(projectType: project.type)
        let content = normalizeContentForAnalysis(rawContent, projectType: project.type)
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
            fileCount: 1,
            poetryFormContext: poetryFormContext(for: textFile, projectType: project.type)
        )

        let response = try await callCloudFlareAPI(request)
        let review = parseResponse(
            response,
            fileId: textFile.id,
            projectId: project.id,
            sourceContent: content,
            referenceUnit: referenceUnit
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
        guard EntitlementManager.shared.canUseManuscriptAnalyst() else {
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

        let referenceUnit = ReferenceUnit(projectType: project.type)
    let content = bodyFiles.content

        let cacheKey = "\(cacheSchemaVersion)_manuscript_\(project.id)_\(contentFingerprint(content))"
        if let cached = reviewCache[cacheKey] {
            return cached
        }

        let request = buildRequest(
            analysisMode: "manuscript",
            projectType: project.type.rawValue,
            fictionClass: project.fictionClassRaw,
            analysisProfile: analysisProfile,
            fileName: project.name ?? "Untitled Manuscript",
            content: content,
            fileCount: bodyFiles.fileCount,
            poetryFormContext: manuscriptPoetryFormContext(for: project)
        )

        let response = try await callCloudFlareAPI(request)
        let review = parseResponse(
            response,
            fileId: nil,
            projectId: project.id,
            sourceContent: content,
            referenceUnit: referenceUnit
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
        guard EntitlementManager.shared.canUseManuscriptAnalyst() else {
            throw ManuscriptAnalystError.subscriptionInactive
        }

        let referenceUnit = ReferenceUnit(projectType: .drama)
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
            fileCount: 1,
            poetryFormContext: nil
        )

        let response = try await callCloudFlareAPI(request)
        let review = parseResponse(
            response,
            fileId: nil,
            projectId: projectId ?? UUID(),
            sourceContent: content,
            referenceUnit: referenceUnit
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

    private struct PoetryFormContext {
        let poetryFormName: String?
        let poetryFormRequirementsSummary: String?
        let preservePoetryForm: Bool
    }

    private func poetryFormContext(for textFile: TextFile, projectType: ProjectType) -> PoetryFormContext? {
        guard projectType == .poetry else { return nil }

        if let form = textFile.poetryForm {
            let preserve = form.id != PoetryForm.freeVerseId
            return PoetryFormContext(
                poetryFormName: form.name,
                poetryFormRequirementsSummary: form.requirementsSummary,
                preservePoetryForm: preserve
            )
        }

        guard let rawName = textFile.poetryFormName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else {
            return nil
        }

        let preserve = rawName.caseInsensitiveCompare("Free Verse") != .orderedSame
        return PoetryFormContext(
            poetryFormName: rawName,
            poetryFormRequirementsSummary: nil,
            preservePoetryForm: preserve
        )
    }

    private func manuscriptPoetryFormContext(for project: Project) -> PoetryFormContext? {
        guard project.type == .poetry else { return nil }

        let bodyFolders = project.folders?.filter { FolderCapabilityService.isContentFolder($0) } ?? []
        var fixedFormContexts: [PoetryFormContext] = []

        for folder in bodyFolders {
            for file in folder.textFiles ?? [] {
                guard let context = poetryFormContext(for: file, projectType: .poetry),
                      context.preservePoetryForm else {
                    continue
                }
                fixedFormContexts.append(context)
            }
        }

        guard !fixedFormContexts.isEmpty else { return nil }

        if fixedFormContexts.count == 1 {
            return fixedFormContexts[0]
        }

        return PoetryFormContext(
            poetryFormName: "Multiple fixed forms",
            poetryFormRequirementsSummary: "This manuscript includes poems in multiple fixed forms. Keep each poem's line and stanza structure intact.",
            preservePoetryForm: true
        )
    }

    private func buildRequest(
        analysisMode: String,
        projectType: String,
        fictionClass: String?,
        analysisProfile: String,
        fileName: String,
        content: String,
        fileCount: Int,
        poetryFormContext: PoetryFormContext?
    ) -> ManuscriptAnalystRequest {
        let wordCount = content.split(separator: " ").count
        let metadata = ManuscriptAnalystRequest.RequestMetadata(
            fileName: fileName,
            fileCount: fileCount,
            wordCount: wordCount,
            documentationVersion: "1.0",
            poetryFormName: poetryFormContext?.poetryFormName,
            poetryFormRequirementsSummary: poetryFormContext?.poetryFormRequirementsSummary,
            preservePoetryForm: poetryFormContext?.preservePoetryForm
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
                    contentForAnalysis(file, project: project),
                    projectType: project.type
                )
                if !content.isEmpty {
                    combinedContent += "\n\n\(manuscriptFileBoundaryPrefix) \(file.name)]]\n\n"
                    combinedContent += content
                    fileCount += 1
                }
            }
        }

        return (combinedContent, fileCount)
    }

    private func contentForAnalysis(_ textFile: TextFile, project: Project) -> String {
        let usesPoetrySections = project.type == .poetry
            || textFile.poetryFormId != nil
            || project.fictionClass?.usesPoetryEditor == true

        guard usesPoetrySections,
              let attributedContent = textFile.currentVersion?.attributedContent else {
            return textFile.currentContent
        }

        return attributedContent.extractPoemBody()
    }

    private func callCloudFlareAPI(_ request: ManuscriptAnalystRequest) async throws -> ManuscriptAnalystResponse {
        guard let url = URL(string: cloudFlareEndpoint) else {
            throw ManuscriptAnalystError.invalidEndpoint
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(
            try await activeAnalystTransactionID(),
            forHTTPHeaderField: "X-Apple-Transaction-ID"
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ManuscriptAnalystError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw ManuscriptAnalystError.subscriptionInactive
        }

        if httpResponse.statusCode != 200 {
            let statusError = "\(httpResponse.statusCode)"
            throw ManuscriptAnalystError.apiError("HTTP \(statusError)")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ManuscriptAnalystResponse.self, from: data)

        if apiResponse.status == "update_required" {
            throw ManuscriptAnalystError.appUpdateRequired
        }

        // Update soft cap state from response
        currentSoftCapState = apiResponse.metadata.softCapState

        return apiResponse
    }

    private func activeAnalystTransactionID() async throws -> String {
        let productID = WSPProduct.manuscriptAnalystSubscription.rawValue

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == productID,
                  transaction.revocationDate == nil else {
                continue
            }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }
            return String(transaction.id)
        }

        throw ManuscriptAnalystError.subscriptionInactive
    }

    private func parseResponse(
        _ response: ManuscriptAnalystResponse,
        fileId: UUID?,
        projectId: UUID,
        sourceContent: String,
        referenceUnit: ReferenceUnit
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
                    normalizeLocation(suggestionResponse.location, unit: referenceUnit),
                    observation: suggestionResponse.observation,
                    sourceContent: sourceContent,
                    unit: referenceUnit
                ),
                observation: suggestionResponse.observation,
                suggestion: suggestionResponse.suggestion,
                rationale: suggestionResponse.rationale
            )
            review.suggestions.append(suggestion)
        }

        let authorshipAssessment = response.analysis.authorshipAssessment.map { assessment in
            AuthorshipAssessment(
                classification: assessment.classification,
                confidence: assessment.confidence,
                summary: assessment.summary,
                indicators: assessment.indicators.map { indicator in
                    AuthorshipIndicator(
                        location: reconcileLocation(
                            normalizeLocation(indicator.location, unit: referenceUnit),
                            observation: indicator.observation,
                            sourceContent: sourceContent,
                            unit: referenceUnit
                        ),
                        observation: indicator.observation
                    )
                }
            )
        }

        // Add metadata
        review.metadata = ReviewMetadata(
            contentAnalyzed: response.metadata.contentAnalyzed,
            tokensUsed: response.metadata.tokensUsed,
            analysisTimeMs: response.metadata.analysisTimeMs,
            model: response.metadata.model,
            softCapState: response.metadata.softCapState,
            authorshipAssessment: authorshipAssessment
        )

        return review
    }

    private func normalizeLocation(_ rawLocation: String?, unit: ReferenceUnit) -> String? {
        guard let rawLocation else { return nil }
        let trimmed = rawLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let pattern = #"(?i)(?:line|paragraph)\s*(\d+)(?:\s*[-–]\s*(\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let firstRange = Range(match.range(at: 1), in: trimmed),
              let firstValue = Int(trimmed[firstRange]) else {
            return trimmed
        }

        if let secondRange = Range(match.range(at: 2), in: trimmed),
           let secondValue = Int(trimmed[secondRange]) {
            return "\(unit.label) \(firstValue)-\(secondValue)"
        }

        return "\(unit.label) \(firstValue)"
    }

    private func reconcileLocation(
        _ normalizedLocation: String?,
        observation: String,
        sourceContent: String,
        unit: ReferenceUnit
    ) -> String? {
        guard let quotedPhrase = extractQuotedPhrase(from: observation),
              let inferredNumber = inferReferenceNumber(forPhrase: quotedPhrase, in: sourceContent) else {
            return normalizedLocation
        }

        if let normalizedLocation,
           let existingNumber = parseSingleReferenceNumber(from: normalizedLocation),
           existingNumber == inferredNumber {
            return normalizedLocation
        }

        return "\(unit.label) \(inferredNumber)"
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

    private func inferReferenceNumber(forPhrase phrase: String, in sourceContent: String) -> Int? {
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
        let precedingLines = prefix.components(separatedBy: .newlines).dropLast()
        let precedingNonblankCount = precedingLines.filter {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix(manuscriptFileBoundaryPrefix)
        }.count
        return precedingNonblankCount + 1
    }

    private func parseSingleReferenceNumber(from location: String) -> Int? {
        let pattern = #"(?i)(?:line|paragraph)\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: location, range: NSRange(location.startIndex..., in: location)),
              let numberRange = Range(match.range(at: 1), in: location) else {
            return nil
        }
          return Int(location[numberRange])
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
            return preprocessDramaContentForAnalysis(normalized)
        }

        return normalized
    }

    /// Convert raw DML into lightweight semantic paragraphs for analysis while preserving
    /// one-to-one source paragraph mapping. This helps the model interpret drama structure
    /// without changing reported paragraph references.
    private func preprocessDramaContentForAnalysis(_ content: String) -> String {
        guard !content.isEmpty else { return content }

        let document = DramaMarkupParser.shared.parse(content)
        guard !document.elements.isEmpty else { return content }

        var elementsByLine: [Int: DMLElement] = [:]
        for element in document.elements {
            elementsByLine[element.lineNumber] = element
        }

        let lines = content.components(separatedBy: "\n")
        let structuredLines = lines.enumerated().map { index, fallbackLine in
            let lineNumber = index + 1
            guard let element = elementsByLine[lineNumber] else {
                return fallbackLine
            }

            switch element.type {
            case .sceneHeading:
                return "[SCENE] \(element.content)"
            case .locationMeta:
                return "[LOCATION] \(element.content)"
            case .timeMeta:
                return "[TIME] \(element.content)"
            case .action:
                return "[ACTION] \(element.content)"
            case .transition:
                return "[TRANSITION] \(element.content)"
            case .character:
                return "[CHARACTER] \(element.content)"
            case .parenthetical:
                return "[PARENTHETICAL] \(element.content)"
            case .dialogue:
                return "[DIALOGUE] \(element.content)"
            case .note:
                return "[NOTE] \(element.noteText ?? element.content)"
            case .blank:
                return ""
            }
        }

        return structuredLines.joined(separator: "\n")
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
    case appUpdateRequired
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
        case .appUpdateRequired:
            return NSLocalizedString("analyst.error.appUpdateRequired", comment: "App update required")
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
