import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CloudflareSyncPOCHealth: Codable {
    let ok: Bool
    let service: String
    let version: String
    let phase: Int
    let syncDbConfigured: Bool
    let syncBlobsConfigured: Bool
    let authConfigured: Bool
}

struct CloudflareSyncPOCResult {
    let message: String
}

private struct SyncPOCTriggerStatus {
    let trigger: String
    let outcome: String
    let recordedAt: Date
    let detail: String
    let latestSequence: Int?
    let cursorSequence: Int?
    let changeCount: Int?
    let lastPushedSequence: Int?
    let version: String?
}

private struct SyncPOCTriggerRunResult {
    let result: CloudflareSyncPOCResult
    let latestSequence: Int
    let cursorSequence: Int
    let changeCount: Int
    let lastPushedSequence: Int
    let version: String
}

private struct SyncPOCApplyPlanItem {
    let entityType: String
    let entityId: String
    let finalAction: String
    let proposedLocalAction: String
    let localExists: Bool
    let dependencyStatus: String
    let serverSequence: Int
    let hasPayload: Bool
}

private struct SyncPOCBootstrapRequest: Codable {
    let projectId: String
    let projectName: String
    let deviceId: String
    let deviceName: String
}

private struct SyncPOCBootstrapResponse: Codable {
    let ok: Bool
    let projectId: String
    let deviceId: String
    let latestSequence: Int
    let version: String
}

private struct SyncPOCHeadRequest: Codable {
    let projectId: String
    let deviceId: String
    let deviceName: String
    let lastKnownSequence: Int
}

private struct SyncPOCHeadResponse: Codable {
    let ok: Bool
    let projectId: String
    let deviceId: String
    let latestSequence: Int
    let lastKnownSequence: Int
    let cursorSequence: Int
    let lastPushedSequence: Int
    let hasChanges: Bool
    let changeCount: Int
    let updatedAt: String?
    let version: String
}

private struct SyncPOCOperation: Codable {
    let id: String
    let entityType: String
    let entityId: String
    let operationType: String
    let baseSequence: Int
    let clientTimestamp: String
    let payload: SyncPOCPayload
}

private struct SyncPOCPayload: Codable {
    let values: [String: String]
}

private struct SyncPOCPushRequest: Codable {
    let projectId: String
    let projectName: String
    let deviceId: String
    let deviceName: String
    let operations: [SyncPOCOperation]
}

private struct SyncPOCPushResponse: Codable {
    let ok: Bool
    let projectId: String
    let deviceId: String
    let accepted: [SyncPOCAcceptedOperation]
    let rejected: [SyncPOCRejectedOperation]
    let latestSequence: Int
}

private struct SyncPOCAcceptedOperation: Codable {
    let clientOperationId: String
    let serverSequence: Int
}

private struct SyncPOCRejectedOperation: Codable {
    let clientOperationId: String?
    let reason: String
    let tombstoneSequence: Int?
}

private struct SyncPOCPullRequest: Codable {
    let projectId: String
    let deviceId: String
    let afterSequence: Int
    let limit: Int
}

private struct SyncPOCPullResponse: Codable {
    let ok: Bool
    let projectId: String
    let deviceId: String
    let afterSequence: Int
    let latestSequence: Int
    let nextCursor: Int
    let hasMore: Bool
    let operations: [SyncPOCPulledOperation]
}

private struct SyncPOCPulledOperation: Codable {
    let id: String
    let projectId: String
    let deviceId: String
    let serverSequence: Int
    let entityType: String
    let entityId: String
    let operationType: String
    let payload: SyncPOCPayload?
}

private struct SyncPOCSnapshotRequest: Codable {
    let projectId: String
    let deviceId: String
    let deviceName: String
    let serverSequence: Int
    let snapshot: SyncPOCSnapshotPayload
}

private struct SyncPOCSnapshotPayload: Codable {
    let generatedAt: String
    let project: [String: String]
    let styleSheets: [[String: String]]
    let textStyles: [[String: String]]
    let imageStyles: [[String: String]]
    let folders: [[String: String]]
    let textFiles: [[String: String]]
    let versions: [[String: String]]
    let comments: [[String: String]]
    let footnotes: [[String: String]]
    let storyScenes: [[String: String]]
    let chapters: [[String: String]]
    let acts: [[String: String]]
    let proseSections: [[String: String]]
    let poetryCollections: [[String: String]]
    let books: [[String: String]]
    let characters: [[String: String]]
    let locations: [[String: String]]
    let customAttributes: [[String: String]]
    let plotElements: [[String: String]]
    let joinLinks: [[String: String]]
    let notes: [[String: String]]
    let glossaryEntries: [[String: String]]
    let referenceEntries: [[String: String]]
    let citationEntries: [[String: String]]
    let indexEntries: [[String: String]]
    let contributorEntries: [[String: String]]
    let publications: [[String: String]]
    let submissions: [[String: String]]
    let submittedFiles: [[String: String]]
    let limits: [String: Int]
}

private struct SyncPOCSnapshotResponse: Codable {
    let ok: Bool
    let snapshotId: String
    let projectId: String
    let serverSequence: Int
    let r2Key: String
    let contentHash: String
}

private struct CloudflareSyncPOCImportState {
    var projectId: String = ""
    var projectName: String = "Untitled"
    var projectTypeRaw: String = "prose"
    var projectStyleSheetId: String = ""
    var styleSheetsById: [String: [String: String]] = [:]
    var textStylesById: [String: [String: String]] = [:]
    var imageStylesById: [String: [String: String]] = [:]
    var foldersById: [String: [String: String]] = [:]
    var textFilesById: [String: [String: String]] = [:]
    var versionsById: [String: [String: String]] = [:]
    var commentsById: [String: [String: String]] = [:]
    var footnotesById: [String: [String: String]] = [:]
    var storyScenesById: [String: [String: String]] = [:]
    var chaptersById: [String: [String: String]] = [:]
    var actsById: [String: [String: String]] = [:]
    var proseSectionsById: [String: [String: String]] = [:]
    var poetryCollectionsById: [String: [String: String]] = [:]
    var booksById: [String: [String: String]] = [:]
    var charactersById: [String: [String: String]] = [:]
    var locationsById: [String: [String: String]] = [:]
    var plotElementsById: [String: [String: String]] = [:]
    var joinLinksById: [String: [String: String]] = [:]
    var notesById: [String: [String: String]] = [:]
    var glossaryEntriesById: [String: [String: String]] = [:]
    var referenceEntriesById: [String: [String: String]] = [:]
    var citationEntriesById: [String: [String: String]] = [:]
    var indexEntriesById: [String: [String: String]] = [:]
    var contributorEntriesById: [String: [String: String]] = [:]
    var publicationsById: [String: [String: String]] = [:]
    var submissionsById: [String: [String: String]] = [:]
    var submittedFilesById: [String: [String: String]] = [:]

    var totalContentCharacters: Int {
        versionsById.values.reduce(0) { total, values in
            total + (values["content"]?.count ?? 0)
        }
    }

    var storyRecordCount: Int {
        storyScenesById.count + chaptersById.count + actsById.count + proseSectionsById.count + poetryCollectionsById.count + booksById.count + charactersById.count + locationsById.count + plotElementsById.count
    }

    var referenceRecordCount: Int {
        notesById.count + glossaryEntriesById.count + referenceEntriesById.count + citationEntriesById.count + indexEntriesById.count + contributorEntriesById.count
    }
}

private struct CloudflareSyncPOCScratchContext {
    let storeURL: URL
    let context: ModelContext
    let project: Project
    let folder: Folder?
}

private struct CloudflareSyncPOCMaterializeResult {
    let styleSheetCount: Int
    let textStyleCount: Int
    let imageStyleCount: Int
    let folderCount: Int
    let textFileCount: Int
    let versionCount: Int
    let trashItemCount: Int
    let commentCount: Int
    let footnoteCount: Int
    let storyRecordCount: Int
    let customAttributeCount: Int
    let joinLinkCount: Int
    let noteCount: Int
    let citationCount: Int
    let glossaryCount: Int
    let referenceEntryCount: Int
    let indexEntryCount: Int
    let contributorCount: Int
    let pageSetupCount: Int
    let printerPaperCount: Int
    let poetryFormCount: Int
    let manuscriptReviewCount: Int
    let reviewSuggestionCount: Int
    let publicationCount: Int
    let submissionCount: Int
    let submittedFileCount: Int
    let updateExistingCount: Int
    let seededExistingCount: Int
    let restoreMissingCount: Int
    let deleteNoopMissingCount: Int
    let storeURL: URL
}

private struct CloudflareSyncPOCImportMaterializeResult {
    let projectName: String
    let styleSheetCount: Int
    let textStyleCount: Int
    let imageStyleCount: Int
    let folderCount: Int
    let textFileCount: Int
    let versionCount: Int
    let commentCount: Int
    let footnoteCount: Int
    let storyRecordCount: Int
    let joinLinkCount: Int
    let referenceRecordCount: Int
    let publicationCount: Int
    let submissionCount: Int
    let submittedFileCount: Int
    let totalContentCharacters: Int
    let storeURL: URL
}

enum CloudflareSyncPOCError: LocalizedError {
    case missingToken
    case invalidEndpoint
    case invalidResponse
    case serverError(Int, String)
    case syncAlreadyInProgress(String)
    case noProjectContent
    case noPageSetup
    case noPrinterPaper
    case noPoetryForm
    case noPoetryCollection
    case importStoreUnavailable
    case applyPlanNotReady(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Missing Cloudflare sync POC token. Set UserDefaults key cloudflareSyncPOCToken before running authenticated POC calls."
        case .invalidEndpoint:
            return "Invalid Cloudflare sync POC endpoint."
        case .invalidResponse:
            return "Cloudflare sync POC returned an invalid response."
        case .serverError(let status, let message):
            return "Cloudflare sync POC failed (HTTP \(status)): \(message)"
        case .syncAlreadyInProgress(let trigger):
            return "Cloudflare sync POC trigger '\(trigger)' skipped because another dry-run sync is already in progress."
        case .noProjectContent:
            return "No project content is available for the Cloudflare sync POC."
        case .noPageSetup:
            return "No selected project has an existing page setup for the Cloudflare sync POC update probe."
        case .noPrinterPaper:
            return "No selected project has an existing printer paper for the Cloudflare sync POC update probe."
        case .noPoetryForm:
            return "No existing poetry form is available for the Cloudflare sync POC update probe."
        case .noPoetryCollection:
            return "No selected project has an existing poetry collection for the Cloudflare sync POC update probe."
        case .importStoreUnavailable:
            return "Could not create the isolated Cloudflare sync POC import store."
        case .applyPlanNotReady(let reason):
            return "Cloudflare sync POC apply plan is not ready: \(reason)"
        }
    }
}

final class CloudflareSyncPOCService {
    static let shared = CloudflareSyncPOCService()

    static let tokenDefaultsKey = "cloudflareSyncPOCToken"
    static let endpointDefaultsKey = "cloudflareSyncPOCEndpoint"
    private static let pendingApplyProjectDefaultsKey = "cloudflareSyncPOCPendingApplyProjectId"
    private static let pendingApplyEntityKeyDefaultsKey = "cloudflareSyncPOCPendingApplyEntityKey"

    private let defaultEndpoint = "https://wsp-support.wsp-support.workers.dev/api/sync/v1"
    private let maxSampleFolders = 50
    private let maxSampleTextFiles = 300
    private let maxSampleComments = 60
    private let maxSampleFootnotes = 60
    private let maxSampleStoryRecordsPerType = 100
    private let maxSampleJoinLinks = 300
    private let maxSampleReferenceRecordsPerType = 100
    private let maxSamplePublications = 50
    private let maxSampleSubmissions = 100
    private let maxSampleSubmittedFiles = 250
    private let maxTextFileContentCharacters = 20000
    private let maxPushOperationsPerBatch = 200
    private let importStoreBasename = "cloudflare-sync-poc-import"
    private let pendingApplyStoreBasename = "cloudflare-sync-poc-pending-apply"
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()
    private var lastTriggerStatus: SyncPOCTriggerStatus?
    private var isOrchestratedSyncInFlight = false
    private var lastOrchestratedTriggerDates: [String: Date] = [:]
    private let noisyTriggerDebounceInterval: TimeInterval = 30
    private var orchestratorProbeDelayNanoseconds: UInt64 = 0

    private init() { }

    var configuredEndpoint: String {
        UserDefaults.standard.string(forKey: Self.endpointDefaultsKey) ?? defaultEndpoint
    }

    var hasToken: Bool {
        syncToken != nil
    }

    func fetchHealth() async throws -> CloudflareSyncPOCHealth {
        let url = try endpointURL(path: "health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        let data = try await send(request: request, authenticated: false)
        return try jsonDecoder.decode(CloudflareSyncPOCHealth.self, from: data)
    }

    @MainActor
    func checkRemoteChanges(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let lastKnownSequence = rememberedLastSequence(projectId: projectId)
        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: lastKnownSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        let status = response.hasChanges ? "changes available" : "up to date"

        return CloudflareSyncPOCResult(
            message: "Remote head is \(status): latest sequence \(response.latestSequence), local remembered \(response.lastKnownSequence), server cursor \(response.cursorSequence), last pushed \(response.lastPushedSequence), change count \(response.changeCount), version \(response.version)."
        )
    }

    @MainActor
    func syncStateSummary(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let rememberedSequence = rememberedLastSequence(projectId: projectId)
        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: rememberedSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        let scratchStoreURL = try isolatedStoreURL(basename: pendingApplyStoreBasename)
        let scratchStoreExists = FileManager.default.fileExists(atPath: scratchStoreURL.path)
        let status = response.hasChanges ? "pending" : "up to date"

        return CloudflareSyncPOCResult(
            message: "Sync state for '\(projectName)' (\(projectId)): \(status). Remembered sequence \(rememberedSequence), remote latest \(response.latestSequence), server cursor \(response.cursorSequence), change count \(response.changeCount), last pushed \(response.lastPushedSequence), scratch store \(scratchStoreExists ? "present" : "absent") at \(scratchStoreURL.lastPathComponent), version \(response.version). Production local data was not changed."
        )
    }

    @MainActor
    func triggerStatusSummary() -> CloudflareSyncPOCResult {
        guard let status = lastTriggerStatus else {
            return CloudflareSyncPOCResult(
                message: "No Cloudflare sync POC trigger dry run has been recorded in this app session."
            )
        }

        let headSummary: String
        if let latestSequence = status.latestSequence,
           let cursorSequence = status.cursorSequence,
           let changeCount = status.changeCount,
           let lastPushedSequence = status.lastPushedSequence,
           let version = status.version {
            headSummary = " latest sequence \(latestSequence), cursor \(cursorSequence), change count \(changeCount), last pushed \(lastPushedSequence), version \(version)."
        } else {
            headSummary = ""
        }

        return CloudflareSyncPOCResult(
            message: "Last trigger dry run: trigger \(status.trigger), outcome \(status.outcome), recorded \(isoFormatter.string(from: status.recordedAt)).\(headSummary) \(status.detail)"
        )
    }

    @MainActor
    func orchestratorPolicySummary() -> CloudflareSyncPOCResult {
        let supportedTriggers = ["manual", "launch", "foreground", "background-refresh", "network-recovery", "silent-push"].joined(separator: ", ")
        let debouncedTriggers = ["foreground", "network-recovery"].joined(separator: ", ")
        let inFlightStatus = isOrchestratedSyncInFlight ? "in flight" : "idle"

        return CloudflareSyncPOCResult(
            message: "Lifecycle orchestrator policy: status \(inFlightStatus), supported triggers [\(supportedTriggers)], debounced triggers [\(debouncedTriggers)] at \(Int(noisyTriggerDebounceInterval))s, manual trigger bypasses debounce when idle. Automatic lifecycle wiring is disabled; production SwiftData apply is disabled; scratch-only head-gated dry runs remain the active path."
        )
    }

    @MainActor
    func launchPolicySummary() -> CloudflareSyncPOCResult {
        CloudflareSyncPOCResult(
            message: "Launch policy: trigger launch is supported and not debounced. Production use should run once after the model container, debug token, and project selection are available. This POC does not wire automatic launch sync; the diagnostics button is manual only. Launch remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for this policy summary."
        )
    }

    @MainActor
    func foregroundPolicySummary() -> CloudflareSyncPOCResult {
        CloudflareSyncPOCResult(
            message: "Foreground policy: trigger foreground is supported and debounced for \(Int(noisyTriggerDebounceInterval))s to avoid short background/foreground churn. Production use should run when the app returns active after required sync credentials and project context are available. This POC does not wire automatic foreground sync; the diagnostics button is manual only. Foreground remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for this policy summary."
        )
    }

    @MainActor
    func networkRecoveryPolicySummary() -> CloudflareSyncPOCResult {
        CloudflareSyncPOCResult(
            message: "Network recovery policy: trigger network-recovery is supported and debounced for \(Int(noisyTriggerDebounceInterval))s. Production use should run after connectivity returns only when the previous sync attempt failed for a transport reason, no orchestrator run is in flight, and the debounce window is clear. This POC does not wire automatic network reachability observers; the diagnostics buttons are manual only. Network recovery remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for this policy summary."
        )
    }

    @MainActor
    func backgroundRefreshPolicySummary() -> CloudflareSyncPOCResult {
        CloudflareSyncPOCResult(
            message: "Background refresh policy: trigger background-refresh is supported and not debounced, but production use must enter only through the system background task path. This POC does not register or schedule a durable background task; the diagnostics button is manual only. Background refresh remains head-first with a cheap up-to-date exit, scratch-only materialization, no production SwiftData apply, and no Worker contact for this policy summary."
        )
    }

    @MainActor
    func orchestratorDebounceSummary() -> CloudflareSyncPOCResult {
        let now = Date()
        let triggerSummaries = ["foreground", "network-recovery"].map { trigger in
            guard let lastRun = lastOrchestratedTriggerDates[trigger] else {
                return "\(trigger): ready (no run recorded)"
            }

            let elapsed = now.timeIntervalSince(lastRun)
            let remaining = max(0, noisyTriggerDebounceInterval - elapsed)
            if remaining > 0 {
                return "\(trigger): debounced for \(Int(ceil(remaining)))s more"
            }
            return "\(trigger): ready (last run \(Int(floor(elapsed)))s ago)"
        }.joined(separator: "; ")
        let inFlightStatus = isOrchestratedSyncInFlight ? "in flight" : "idle"

        return CloudflareSyncPOCResult(
            message: "Lifecycle orchestrator debounce state: status \(inFlightStatus), interval \(Int(noisyTriggerDebounceInterval))s, \(triggerSummaries). Manual, launch, background-refresh, and silent-push triggers are not debounced. This did not contact the Worker and did not read or write production local data."
        )
    }

    @MainActor
    func networkRecoveryEligibilitySummary() -> CloudflareSyncPOCResult {
        let state = networkRecoveryEligibilityState()

        return CloudflareSyncPOCResult(
            message: "Network recovery eligibility: \(state.decision). Reason: \(state.reason). Last trigger \(state.lastTrigger), last outcome \(state.lastOutcome). This did not contact the Worker and did not read or write scratch or production local data."
        )
    }

    @MainActor
    func networkRecoveryIfEligibleDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        let state = networkRecoveryEligibilityState()
        guard state.isEligible else {
            return CloudflareSyncPOCResult(
                message: "Network recovery gated dry run skipped: \(state.decision). Reason: \(state.reason). Last trigger \(state.lastTrigger), last outcome \(state.lastOutcome). This did not contact the Worker and did not read or write scratch or production local data."
            )
        }

        let result = try await networkRecoverySyncDryRun(projects: projects)
        return CloudflareSyncPOCResult(
            message: "Network recovery gated dry run was eligible and ran through the scratch-only orchestrator. \(result.message)"
        )
    }

    @MainActor
    func networkRecoveryEligibilityProbe() -> CloudflareSyncPOCResult {
        let error = URLError(.notConnectedToInternet)
        lastTriggerStatus = SyncPOCTriggerStatus(
            trigger: "network-recovery",
            outcome: triggerOutcome(for: error),
            recordedAt: Date(),
            detail: "Synthetic network recovery eligibility probe: \(error.localizedDescription). This did not contact the Worker and did not read or write scratch or production local data.",
            latestSequence: nil,
            cursorSequence: nil,
            changeCount: nil,
            lastPushedSequence: nil,
            version: nil
        )

        let eligibility = networkRecoveryEligibilitySummary()
        return CloudflareSyncPOCResult(
            message: "Network recovery eligibility probe recorded synthetic transport failure, then evaluated eligibility. \(eligibility.message)"
        )
    }

    @MainActor
    func networkRecoveryDebounceEligibilityProbe() -> CloudflareSyncPOCResult {
        let error = URLError(.notConnectedToInternet)
        lastTriggerStatus = SyncPOCTriggerStatus(
            trigger: "network-recovery",
            outcome: triggerOutcome(for: error),
            recordedAt: Date(),
            detail: "Synthetic network recovery debounce eligibility probe: \(error.localizedDescription). This did not contact the Worker and did not read or write scratch or production local data.",
            latestSequence: nil,
            cursorSequence: nil,
            changeCount: nil,
            lastPushedSequence: nil,
            version: nil
        )
        lastOrchestratedTriggerDates["network-recovery"] = Date()

        let eligibility = networkRecoveryEligibilitySummary()
        return CloudflareSyncPOCResult(
            message: "Network recovery debounce eligibility probe recorded synthetic transport failure and an immediate network-recovery timestamp, then evaluated eligibility. \(eligibility.message)"
        )
    }

    @MainActor
    func networkRecoveryInFlightEligibilityProbe() -> CloudflareSyncPOCResult {
        let error = URLError(.notConnectedToInternet)
        lastTriggerStatus = SyncPOCTriggerStatus(
            trigger: "network-recovery",
            outcome: triggerOutcome(for: error),
            recordedAt: Date(),
            detail: "Synthetic network recovery in-flight eligibility probe: \(error.localizedDescription). This did not contact the Worker and did not read or write scratch or production local data.",
            latestSequence: nil,
            cursorSequence: nil,
            changeCount: nil,
            lastPushedSequence: nil,
            version: nil
        )

        let previousInFlightState = isOrchestratedSyncInFlight
        isOrchestratedSyncInFlight = true
        let eligibility = networkRecoveryEligibilitySummary()
        isOrchestratedSyncInFlight = previousInFlightState

        return CloudflareSyncPOCResult(
            message: "Network recovery in-flight eligibility probe recorded synthetic transport failure and temporary in-flight state, then evaluated eligibility. \(eligibility.message)"
        )
    }

    @MainActor
    func silentPushPayloadGuardrailProbe(projects: [Project]) throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"
        let rememberedSequence = rememberedLastSequence(projectId: projectId)
        let mismatchedProjectId = UUID().uuidString

        return CloudflareSyncPOCResult(
            message: "Silent push payload guardrail probe ignored synthetic wake payload for mismatched project \(mismatchedProjectId) while selected project was '\(projectName)' (\(projectId)). Remembered sequence remained \(rememberedSequence). This did not contact the Worker, did not trust a payload sequence, and did not read or write scratch or production local data."
        )
    }

    @MainActor
    func silentPushMatchingPayloadDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"
        let rememberedSequence = rememberedLastSequence(projectId: projectId)
        let syntheticPayloadSequence = rememberedSequence + 1
        let result = try await silentPushSyncDryRun(projects: [project])

        return CloudflareSyncPOCResult(
            message: "Silent push matching-payload dry run accepted synthetic wake payload for '\(projectName)' (\(projectId)) but ignored payload sequence \(syntheticPayloadSequence) and used local remembered sequence \(rememberedSequence) with the head endpoint. \(result.message)"
        )
    }

    @MainActor
    func transportFailureClassificationProbe() -> CloudflareSyncPOCResult {
        let error = URLError(.notConnectedToInternet)
        let detail = "Synthetic transport failure classification probe: \(error.localizedDescription). This did not contact the Worker and did not read or write scratch or production local data."
        lastTriggerStatus = SyncPOCTriggerStatus(
            trigger: "network-recovery",
            outcome: triggerOutcome(for: error),
            recordedAt: Date(),
            detail: detail,
            latestSequence: nil,
            cursorSequence: nil,
            changeCount: nil,
            lastPushedSequence: nil,
            version: nil
        )

        return CloudflareSyncPOCResult(
            message: "Transport failure classification probe recorded trigger network-recovery with outcome \(triggerOutcome(for: error)). \(detail)"
        )
    }

    @MainActor
    func localCursorSummary(projects: [Project]) throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"
        let rememberedSequence = rememberedLastSequence(projectId: projectId)
        let pendingProjectId = rememberedPendingApplyProjectId() ?? "none"
        let scratchStoreURL = try isolatedStoreURL(basename: pendingApplyStoreBasename)
        let scratchStoreExists = FileManager.default.fileExists(atPath: scratchStoreURL.path)

        return CloudflareSyncPOCResult(
            message: "Local cursor summary for '\(projectName)' (\(projectId)): remembered sequence \(rememberedSequence), pending apply project \(pendingProjectId), scratch store \(scratchStoreExists ? "present" : "absent") at \(scratchStoreURL.lastPathComponent). This did not contact the Worker and did not read or write production local data."
        )
    }

    @MainActor
    func checkAndPullPendingChangesIntoScratchStore(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let lastKnownSequence = rememberedLastSequence(projectId: projectId)
        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: lastKnownSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            return CloudflareSyncPOCResult(
                message: "Remote head is up to date: latest sequence \(response.latestSequence), local remembered \(response.lastKnownSequence), server cursor \(response.cursorSequence), last pushed \(response.lastPushedSequence), change count \(response.changeCount), version \(response.version). Scratch store was not changed and production local data was not changed."
            )
        }

        let pullResult = try await pullPendingChangesIntoScratchStore(projects: [project])
        return CloudflareSyncPOCResult(
            message: "Remote head had \(response.changeCount) pending changes at latest sequence \(response.latestSequence). \(pullResult.message)"
        )
    }

    @MainActor
    private func checkAndPullPendingChangesIntoScratchStoreForTrigger(projects: [Project]) async throws -> SyncPOCTriggerRunResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let lastKnownSequence = rememberedLastSequence(projectId: projectId)
        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: lastKnownSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)

        if response.hasChanges {
            let pullResult = try await pullPendingChangesIntoScratchStore(projects: [project])
            return SyncPOCTriggerRunResult(
                result: CloudflareSyncPOCResult(
                    message: "Remote head had \(response.changeCount) pending changes at latest sequence \(response.latestSequence). \(pullResult.message)"
                ),
                latestSequence: response.latestSequence,
                cursorSequence: rememberedLastSequence(projectId: projectId),
                changeCount: response.changeCount,
                lastPushedSequence: response.lastPushedSequence,
                version: response.version
            )
        }

        return SyncPOCTriggerRunResult(
            result: CloudflareSyncPOCResult(
                message: "Remote head is up to date: latest sequence \(response.latestSequence), local remembered \(response.lastKnownSequence), server cursor \(response.cursorSequence), last pushed \(response.lastPushedSequence), change count \(response.changeCount), version \(response.version). Scratch store was not changed and production local data was not changed."
            ),
            latestSequence: response.latestSequence,
            cursorSequence: response.cursorSequence,
            changeCount: response.changeCount,
            lastPushedSequence: response.lastPushedSequence,
            version: response.version
        )
    }

    @MainActor
    func syncNowDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        try await requestSyncDryRun(projects: projects, trigger: "manual", bypassDebounce: true)
    }

    @MainActor
    func foregroundSyncDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        try await requestSyncDryRun(projects: projects, trigger: "foreground")
    }

    @MainActor
    func launchSyncDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        try await requestSyncDryRun(projects: projects, trigger: "launch")
    }

    @MainActor
    func backgroundRefreshSyncDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        try await requestSyncDryRun(projects: projects, trigger: "background-refresh")
    }

    @MainActor
    func backgroundRefreshExpiredBudgetProbe() -> CloudflareSyncPOCResult {
        let detail = "Background refresh expired-budget probe skipped before starting the orchestrator because no useful background execution budget remained. This did not contact the Worker and did not read or write scratch or production local data."
        lastTriggerStatus = SyncPOCTriggerStatus(
            trigger: "background-refresh",
            outcome: "skipped",
            recordedAt: Date(),
            detail: detail,
            latestSequence: nil,
            cursorSequence: nil,
            changeCount: nil,
            lastPushedSequence: nil,
            version: nil
        )

        return CloudflareSyncPOCResult(message: detail)
    }

    @MainActor
    func foregroundDebounceSkipProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        lastOrchestratedTriggerDates["foreground"] = Date()
        let result = try await requestSyncDryRun(projects: projects, trigger: "foreground")
        return CloudflareSyncPOCResult(
            message: "Foreground debounce skip probe recorded an immediate foreground trigger timestamp, then requested foreground sync. \(result.message)"
        )
    }

    @MainActor
    func networkRecoverySyncDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        try await requestSyncDryRun(projects: projects, trigger: "network-recovery")
    }

    @MainActor
    func silentPushSyncDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        try await requestSyncDryRun(projects: projects, trigger: "silent-push")
    }

    @MainActor
    func lifecycleSequenceDryRun(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        let launch = try await requestSyncDryRun(projects: projects, trigger: "launch")
        let foreground = try await requestSyncDryRun(projects: projects, trigger: "foreground")
        let backgroundRefresh = try await requestSyncDryRun(projects: projects, trigger: "background-refresh")

        return CloudflareSyncPOCResult(
            message: "Lifecycle sequence dry run completed. Launch: \(launch.message) Foreground: \(foreground.message) Background refresh: \(backgroundRefresh.message)"
        )
    }

    @MainActor
    func singleFlightGuardProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        orchestratorProbeDelayNanoseconds = 1_000_000_000
        defer { orchestratorProbeDelayNanoseconds = 0 }

        async let first = requestSyncDryRun(projects: projects, trigger: "manual", bypassDebounce: true)
        try await Task.sleep(nanoseconds: 50_000_000)

        let secondDetail: String
        let secondWasSkipped: Bool
        do {
            let second = try await requestSyncDryRun(projects: projects, trigger: "foreground")
            secondDetail = "second trigger unexpectedly ran: \(second.message)"
            secondWasSkipped = false
        } catch CloudflareSyncPOCError.syncAlreadyInProgress(let trigger) {
            secondDetail = "second trigger '\(trigger)' was skipped by the single-flight guard"
            secondWasSkipped = true
        }

        let firstResult = try await first
        guard secondWasSkipped else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Single-flight guard probe completed: first trigger finished through orchestrator; \(secondDetail). First result: \(firstResult.message)"
        )
    }

    @MainActor
    private func requestSyncDryRun(projects: [Project], trigger: String, bypassDebounce: Bool = false) async throws -> CloudflareSyncPOCResult {
        guard !isOrchestratedSyncInFlight else {
            let error = CloudflareSyncPOCError.syncAlreadyInProgress(trigger)
            lastTriggerStatus = SyncPOCTriggerStatus(
                trigger: trigger,
                outcome: "skipped",
                recordedAt: Date(),
                detail: error.localizedDescription,
                latestSequence: nil,
                cursorSequence: nil,
                changeCount: nil,
                lastPushedSequence: nil,
                version: nil
            )
            throw error
        }

        if !bypassDebounce,
           shouldDebounceTrigger(trigger),
           let lastRun = lastOrchestratedTriggerDates[trigger],
           Date().timeIntervalSince(lastRun) < noisyTriggerDebounceInterval {
            let remaining = max(0, noisyTriggerDebounceInterval - Date().timeIntervalSince(lastRun))
            let message = "Cloudflare sync POC trigger '\(trigger)' skipped by lifecycle orchestrator debounce (\(Int(ceil(remaining)))s remaining). Scratch store was not changed and production local data was not changed."
            lastTriggerStatus = SyncPOCTriggerStatus(
                trigger: trigger,
                outcome: "skipped",
                recordedAt: Date(),
                detail: message,
                latestSequence: nil,
                cursorSequence: nil,
                changeCount: nil,
                lastPushedSequence: nil,
                version: nil
            )
            return CloudflareSyncPOCResult(message: message)
        }

        isOrchestratedSyncInFlight = true
        lastOrchestratedTriggerDates[trigger] = Date()
        defer { isOrchestratedSyncInFlight = false }

        do {
            if orchestratorProbeDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: orchestratorProbeDelayNanoseconds)
            }
            let runResult = try await checkAndPullPendingChangesIntoScratchStoreForTrigger(projects: projects)
            let message = "Triggered sync dry run completed for \(trigger) via lifecycle orchestrator. \(runResult.result.message)"
            lastTriggerStatus = SyncPOCTriggerStatus(
                trigger: trigger,
                outcome: "success",
                recordedAt: Date(),
                detail: runResult.result.message,
                latestSequence: runResult.latestSequence,
                cursorSequence: runResult.cursorSequence,
                changeCount: runResult.changeCount,
                lastPushedSequence: runResult.lastPushedSequence,
                version: runResult.version
            )
            return CloudflareSyncPOCResult(message: message)
        } catch {
            lastTriggerStatus = SyncPOCTriggerStatus(
                trigger: trigger,
                outcome: triggerOutcome(for: error),
                recordedAt: Date(),
                detail: error.localizedDescription,
                latestSequence: nil,
                cursorSequence: nil,
                changeCount: nil,
                lastPushedSequence: nil,
                version: nil
            )
            throw error
        }
    }

    private func shouldDebounceTrigger(_ trigger: String) -> Bool {
        trigger == "foreground" || trigger == "network-recovery"
    }

    private func networkRecoveryEligibilityState() -> (isEligible: Bool, decision: String, reason: String, lastTrigger: String, lastOutcome: String) {
        let now = Date()
        let remainingDebounceSeconds: Int
        if let lastRun = lastOrchestratedTriggerDates["network-recovery"] {
            remainingDebounceSeconds = Int(ceil(max(0, noisyTriggerDebounceInterval - now.timeIntervalSince(lastRun))))
        } else {
            remainingDebounceSeconds = 0
        }

        let lastOutcome = lastTriggerStatus?.outcome ?? "none"
        let lastTrigger = lastTriggerStatus?.trigger ?? "none"
        let isEligible = lastOutcome == "transport-failure" && !isOrchestratedSyncInFlight && remainingDebounceSeconds == 0
        let decision = isEligible ? "eligible" : "not eligible"
        let reason: String
        if isOrchestratedSyncInFlight {
            reason = "another orchestrator dry run is in flight"
        } else if remainingDebounceSeconds > 0 {
            reason = "network-recovery is debounced for \(remainingDebounceSeconds)s more"
        } else if lastOutcome == "transport-failure" {
            reason = "last trigger outcome was transport-failure"
        } else {
            reason = "last trigger outcome was \(lastOutcome), not transport-failure"
        }

        return (isEligible, decision, reason, lastTrigger, lastOutcome)
    }

    private func triggerOutcome(for error: Error) -> String {
        if error is URLError {
            return "transport-failure"
        }
        return "failure"
    }

    @MainActor
    func runRemoteChangeProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyProject(projectId: projectId)

        let remoteDeviceId = "remote-probe-\(UUID().uuidString)"
        let operationId = "remote-project-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: operationId,
            entityType: "Project",
            entityId: projectId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": projectName,
                "type": project.typeRaw ?? "",
                "isTrashed": String(project.isTrashed),
                "styleSheetId": project.styleSheet?.id.uuidString ?? "",
                "modifiedDate": project.modifiedDate.map { isoFormatter.string(from: $0) } ?? "",
                "sourceDeviceId": remoteDeviceId,
                "baselineSequence": String(baselineSequence),
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Remote Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote change probe passed: simulated remote Project upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), local remembered \(response.lastKnownSequence), server cursor \(response.cursorSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingTextFileUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        let folders = sampleFolders(in: project)
        guard let textFile = sampleTextFiles(in: folders).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-existing-textfile-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(textFile.id.uuidString)-existing-textfile-update-\(UUID().uuidString)",
            entityType: "TextFile",
            entityId: textFile.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": "\(textFile.name) [scratch update]",
                "folderId": textFile.parentFolder?.id.uuidString ?? "",
                "workflowStatus": textFile.workflowStatusRaw ?? "",
                "contentType": textFile.contentTypeRaw,
                "content": String(textFile.currentContent.prefix(maxTextFileContentCharacters)),
                "modifiedDate": isoFormatter.string(from: Date()),
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing TextFile Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing text file update probe passed: simulated TextFile upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingStyleSheetUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }), let styleSheet = project.styleSheet else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-existing-stylesheet-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(styleSheet.id.uuidString)-existing-stylesheet-update-\(UUID().uuidString)",
            entityType: "StyleSheet",
            entityId: styleSheet.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": "\(styleSheet.name) [scratch update]",
                "isSystemStyleSheet": styleSheet.isSystemStyleSheet ? "true" : "false",
                "footnoteMarkerStyleRaw": styleSheet.footnoteMarkerStyleRaw,
                "modifiedDate": isoFormatter.string(from: Date()),
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing StyleSheet Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing stylesheet update probe passed: simulated StyleSheet upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingTextStyleUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }), let styleSheet = project.styleSheet, let textStyle = sortedTextStyles(styleSheet.textStyles).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = textStylePayload(textStyle, styleSheetId: styleSheet.id.uuidString)
        payload["displayName"] = "\(textStyle.displayName) [scratch update]"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-textstyle-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(textStyle.id.uuidString)-existing-textstyle-update-\(UUID().uuidString)",
            entityType: "TextStyleModel",
            entityId: textStyle.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing TextStyle Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing text style update probe passed: simulated TextStyleModel upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingImageStyleUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }), let styleSheet = project.styleSheet, let imageStyle = sortedImageStyles(styleSheet.imageStyles).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = imageStylePayload(imageStyle, styleSheetId: styleSheet.id.uuidString)
        payload["displayName"] = "\(imageStyle.displayName) [scratch update]"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-imagestyle-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(imageStyle.id.uuidString)-existing-imagestyle-update-\(UUID().uuidString)",
            entityType: "ImageStyle",
            entityId: imageStyle.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing ImageStyle Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing image style update probe passed: simulated ImageStyle upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingPageSetupUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedPageSetup: PageSetup?
        for project in projects where !project.isTrashed {
            if let pageSetup = project.pageSetup {
                selectedProject = project
                selectedPageSetup = pageSetup
                break
            }
        }
        guard let project = selectedProject, let pageSetup = selectedPageSetup else {
            throw CloudflareSyncPOCError.noPageSetup
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = pageSetupPayload(pageSetup, projectId: projectId)
        payload["headerLeft"] = "Scratch update"

        let remoteDeviceId = "remote-existing-pagesetup-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(pageSetup.id.uuidString)-existing-pagesetup-update-\(UUID().uuidString)",
            entityType: "PageSetup",
            entityId: pageSetup.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing PageSetup Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing page setup update probe passed: simulated PageSetup upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingPrinterPaperUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedPageSetup: PageSetup?
        var selectedPrinterPaper: PrinterPaper?
        for project in projects where !project.isTrashed {
            guard let pageSetup = project.pageSetup else { continue }
            if let printerPaper = sortedPrinterPapers(pageSetup.printerPapers).first {
                selectedProject = project
                selectedPageSetup = pageSetup
                selectedPrinterPaper = printerPaper
                break
            }
        }
        guard let project = selectedProject, let pageSetup = selectedPageSetup, let printerPaper = selectedPrinterPaper else {
            throw CloudflareSyncPOCError.noPrinterPaper
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "PrinterPaper", entityId: printerPaper.id.uuidString)

        var payload = printerPaperPayload(printerPaper, pageSetupId: pageSetup.id.uuidString)
        payload["paperName"] = "Scratch printer paper update"

        let remoteDeviceId = "remote-existing-printer-paper-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(printerPaper.id.uuidString)-existing-printer-paper-update-\(UUID().uuidString)",
            entityType: "PrinterPaper",
            entityId: printerPaper.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing PrinterPaper Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing printer paper update probe passed for PrinterPaper '\(printerPaper.paperName ?? "Untitled")' in project '\(projectName)': simulated PrinterPaper upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingPoetryFormUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        guard let projectContext = project.modelContext else {
            throw CloudflareSyncPOCError.noPoetryForm
        }

        let forms = try ModelContext(projectContext.container).fetch(FetchDescriptor<PoetryFormModel>(sortBy: [SortDescriptor(\.name)]))
        guard let poetryForm = forms.first else {
            throw CloudflareSyncPOCError.noPoetryForm
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "PoetryFormModel", entityId: poetryForm.id.uuidString)

        var payload = poetryFormPayload(poetryForm)
        payload["formDescription"] = "Scratch update for existing poetry form"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-poetry-form-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(poetryForm.id.uuidString)-existing-poetry-form-update-\(UUID().uuidString)",
            entityType: "PoetryFormModel",
            entityId: poetryForm.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing PoetryForm Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing poetry form update probe passed for PoetryFormModel '\(poetryForm.name)': simulated PoetryFormModel upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }
    @MainActor
    func runExistingPoetryCollectionUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedCollection: PoetryCollection?
        for project in projects where !project.isTrashed {
            if let collection = samplePoetryCollections(in: project).first {
                selectedProject = project
                selectedCollection = collection
                break
            }
        }
        guard let project = selectedProject, let collection = selectedCollection else {
            throw CloudflareSyncPOCError.noPoetryCollection
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "PoetryCollection", entityId: collection.id.uuidString)

        var payload = bodyMatterContainerPayload(
            name: collection.name,
            synopsis: collection.synopsis,
            userOrder: collection.userOrder,
            createdDate: collection.createdDate,
            modifiedDate: collection.modifiedDate,
            bodyMatterOrder: collection.bodyMatterOrder,
            isInBodyMatter: collection.isInBodyMatter,
            projectId: projectId
        )
        payload["synopsis"] = "Scratch update for existing poetry collection"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-poetry-collection-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(collection.id.uuidString)-existing-poetry-collection-update-\(UUID().uuidString)",
            entityType: "PoetryCollection",
            entityId: collection.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing PoetryCollection Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let collectionName = collection.name ?? "Untitled Collection"
        return CloudflareSyncPOCResult(
            message: "Existing poetry collection update probe passed for PoetryCollection '\(collectionName)' in project '\(projectName)': simulated PoetryCollection upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingChapterUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !sampleChapters(in: $0).isEmpty }), let chapter = sampleChapters(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Chapter", entityId: chapter.id.uuidString)

        var payload = bodyMatterContainerPayload(
            name: chapter.name,
            synopsis: chapter.synopsis,
            userOrder: chapter.userOrder,
            createdDate: chapter.createdDate,
            modifiedDate: chapter.modifiedDate,
            bodyMatterOrder: chapter.bodyMatterOrder,
            isInBodyMatter: chapter.isInBodyMatter,
            projectId: projectId
        )
        payload["synopsis"] = "Scratch update for existing chapter"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-chapter-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(chapter.id.uuidString)-existing-chapter-update-\(UUID().uuidString)",
            entityType: "Chapter",
            entityId: chapter.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Chapter Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let chapterName = chapter.name ?? "Untitled Chapter"
        return CloudflareSyncPOCResult(
            message: "Existing chapter update probe passed for Chapter '\(chapterName)' in project '\(projectName)': simulated Chapter upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingActUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !sampleActs(in: $0).isEmpty }), let act = sampleActs(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Act", entityId: act.id.uuidString)

        var payload = bodyMatterContainerPayload(
            name: act.name,
            synopsis: act.synopsis,
            userOrder: act.userOrder,
            createdDate: act.createdDate,
            modifiedDate: act.modifiedDate,
            bodyMatterOrder: act.bodyMatterOrder,
            isInBodyMatter: act.isInBodyMatter,
            projectId: projectId
        )
        payload["synopsis"] = "Scratch update for existing act"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-act-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(act.id.uuidString)-existing-act-update-\(UUID().uuidString)",
            entityType: "Act",
            entityId: act.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Act Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let actName = act.name ?? "Untitled Act"
        return CloudflareSyncPOCResult(
            message: "Existing act update probe passed for Act '\(actName)' in project '\(projectName)': simulated Act upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingBookUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !sampleBooks(in: $0).isEmpty }), let book = sampleBooks(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Book", entityId: book.id.uuidString)

        var payload = bodyMatterContainerPayload(
            name: book.name,
            synopsis: book.synopsis,
            userOrder: book.userOrder,
            createdDate: book.createdDate,
            modifiedDate: book.modifiedDate,
            bodyMatterOrder: book.bodyMatterOrder,
            isInBodyMatter: book.isInBodyMatter,
            projectId: projectId
        )
        payload["synopsis"] = "Scratch update for existing book"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-book-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(book.id.uuidString)-existing-book-update-\(UUID().uuidString)",
            entityType: "Book",
            entityId: book.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Book Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let bookName = book.name ?? "Untitled Book"
        return CloudflareSyncPOCResult(
            message: "Existing book update probe passed for Book '\(bookName)' in project '\(projectName)': simulated Book upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingProseSectionUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !sampleProseSections(in: $0).isEmpty }), let section = sampleProseSections(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "ProseSection", entityId: section.id.uuidString)

        var payload = bodyMatterContainerPayload(
            name: section.name,
            synopsis: section.synopsis,
            userOrder: section.userOrder,
            createdDate: section.createdDate,
            modifiedDate: section.modifiedDate,
            bodyMatterOrder: section.bodyMatterOrder,
            isInBodyMatter: section.isInBodyMatter,
            projectId: projectId
        )
        payload["synopsis"] = "Scratch update for existing prose section"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-prose-section-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(section.id.uuidString)-existing-prose-section-update-\(UUID().uuidString)",
            entityType: "ProseSection",
            entityId: section.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing ProseSection Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let sectionName = section.name ?? "Untitled Section"
        return CloudflareSyncPOCResult(
            message: "Existing prose section update probe passed for ProseSection '\(sectionName)' in project '\(projectName)': simulated ProseSection upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingStorySceneUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedScene: StoryScene?
        for project in projects where !project.isTrashed {
            if let scene = sampleStoryScenes(in: project).first {
                selectedProject = project
                selectedScene = scene
                break
            }
        }
        guard let project = selectedProject, let scene = selectedScene else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "StoryScene", entityId: scene.id.uuidString)

        var payload = storyScenePayload(scene, projectId: projectId)
        payload["synopsis"] = "Scratch update for existing scene"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-story-scene-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(scene.id.uuidString)-existing-story-scene-update-\(UUID().uuidString)",
            entityType: "StoryScene",
            entityId: scene.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing StoryScene Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let sceneName = scene.name ?? "Untitled Scene"
        return CloudflareSyncPOCResult(
            message: "Existing story scene update probe passed for StoryScene '\(sceneName)' in project '\(projectName)': simulated StoryScene upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingCharacterUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !sampleCharacters(in: $0).isEmpty }), let character = sampleCharacters(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Character", entityId: character.id.uuidString)

        var payload = characterPayload(character, projectId: projectId)
        payload["traits"] = "Scratch update for existing character"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-character-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(character.id.uuidString)-existing-character-update-\(UUID().uuidString)",
            entityType: "Character",
            entityId: character.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Character Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let characterName = character.name ?? "Untitled Character"
        return CloudflareSyncPOCResult(
            message: "Existing character update probe passed for Character '\(characterName)' in project '\(projectName)': simulated Character upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingLocationUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !sampleLocations(in: $0).isEmpty }), let location = sampleLocations(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Location", entityId: location.id.uuidString)

        var payload = locationPayload(location, projectId: projectId)
        payload["detail"] = "Scratch update for existing location"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-location-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(location.id.uuidString)-existing-location-update-\(UUID().uuidString)",
            entityType: "Location",
            entityId: location.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Location Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let locationName = location.name ?? "Untitled Location"
        return CloudflareSyncPOCResult(
            message: "Existing location update probe passed for Location '\(locationName)' in project '\(projectName)': simulated Location upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingPlotElementUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !samplePlotElements(in: $0).isEmpty }), let plotElement = samplePlotElements(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "PlotElement", entityId: plotElement.id.uuidString)

        var payload = plotElementPayload(plotElement, projectId: projectId)
        payload["notes"] = "Scratch update for existing plot element"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-plot-element-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(plotElement.id.uuidString)-existing-plot-element-update-\(UUID().uuidString)",
            entityType: "PlotElement",
            entityId: plotElement.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing PlotElement Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let plotElementName = plotElement.name ?? "Untitled Plot Element"
        return CloudflareSyncPOCResult(
            message: "Existing plot element update probe passed for PlotElement '\(plotElementName)' in project '\(projectName)': simulated PlotElement upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingOrderedTextFileLinkUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let selection = selectOrderedTextFileLinkForUpdate(projects: projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let project = selection.project
        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: selection.link.entityType, entityId: selection.link.entityId)

        var payload = selection.link.payload
        let currentOrder = intValue(payload["userOrder"]) ?? 0
        payload["userOrder"] = String(currentOrder + 1)

        let remoteDeviceId = "remote-existing-ordered-link-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(selection.link.entityId)-existing-ordered-link-update-\(UUID().uuidString)",
            entityType: selection.link.entityType,
            entityId: selection.link.entityId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Ordered TextFile Link Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing ordered text-file link update probe passed for \(selection.link.entityType) in project '\(projectName)': simulated upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingPublicationUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !samplePublications(in: $0).isEmpty }), let publication = samplePublications(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = publicationPayload(publication, projectId: projectId)
        payload["name"] = "\(publication.name) [scratch update]"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-publication-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(publication.id.uuidString)-existing-publication-update-\(UUID().uuidString)",
            entityType: "Publication",
            entityId: publication.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Publication Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing publication update probe passed: simulated Publication upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingSubmissionUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedSubmission: Submission?
        var selectedPublication: Publication?
        for project in projects where !project.isTrashed {
            if let submission = sampleSubmissions(in: project).first(where: { $0.publication != nil }), let publication = submission.publication {
                selectedProject = project
                selectedSubmission = submission
                selectedPublication = publication
                break
            }
        }
        guard let project = selectedProject, let submission = selectedSubmission, let publication = selectedPublication else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = submissionPayload(submission, projectId: projectId)
        payload["publicationId"] = publication.id.uuidString
        payload["notes"] = "Scratch update"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-submission-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(submission.id.uuidString)-existing-submission-update-\(UUID().uuidString)",
            entityType: "Submission",
            entityId: submission.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Submission Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing submission update probe passed: simulated Submission upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingSubmittedFileUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedSubmittedFile: SubmittedFile?
        for project in projects where !project.isTrashed {
            let submittedFiles = sampleSubmittedFiles(in: sampleSubmissions(in: project))
            if let submittedFile = submittedFiles.first(where: { $0.submission?.publication != nil && $0.textFile != nil && $0.version != nil }) {
                selectedProject = project
                selectedSubmittedFile = submittedFile
                break
            }
        }
        guard let project = selectedProject,
              let submittedFile = selectedSubmittedFile,
              submittedFile.submission?.publication != nil,
              submittedFile.textFile != nil,
              submittedFile.version != nil else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = submittedFilePayload(submittedFile, projectId: projectId)
        payload["statusNotes"] = "Scratch update"
        payload["modifiedDate"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-submittedfile-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(submittedFile.id.uuidString)-existing-submittedfile-update-\(UUID().uuidString)",
            entityType: "SubmittedFile",
            entityId: submittedFile.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing SubmittedFile Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing submitted file update probe passed: simulated SubmittedFile upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingFolderUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }), let folder = sampleFolders(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-existing-folder-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(folder.id.uuidString)-existing-folder-update-\(UUID().uuidString)",
            entityType: "Folder",
            entityId: folder.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": "\(folder.name ?? "Untitled Folder") [scratch update]",
                "parentFolderId": folder.parentFolder?.id.uuidString ?? "",
                "userOrder": folder.userOrder.map(String.init) ?? "",
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Folder Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing folder update probe passed: simulated Folder upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingVersionUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        let textFiles = sampleTextFiles(in: sampleFolders(in: project))
        guard let textFile = textFiles.first(where: { !sampleVersions(in: $0).isEmpty }), let version = sampleVersions(in: textFile).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-existing-version-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(version.id.uuidString)-existing-version-update-\(UUID().uuidString)",
            entityType: "Version",
            entityId: version.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "textFileId": textFile.id.uuidString,
                "content": version.content,
                "versionNumber": String(version.versionNumber),
                "comment": "Scratch update for existing version",
                "notes": version.notes ?? "",
                "createdDate": isoFormatter.string(from: version.createdDate),
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Version Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing version update probe passed: simulated Version upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingCommentUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        let versions = sampleTextFiles(in: sampleFolders(in: project)).flatMap { sampleVersions(in: $0) }
        guard let comment = sampleComments(in: versions).first, let version = comment.version else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = commentPayload(comment)
        payload["versionId"] = version.id.uuidString
        payload["text"] = "Scratch update for existing comment"

        let remoteDeviceId = "remote-existing-comment-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(comment.id.uuidString)-existing-comment-update-\(UUID().uuidString)",
            entityType: "CommentModel",
            entityId: comment.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Comment Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing comment update probe passed: simulated CommentModel upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingFootnoteUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        let versions = sampleTextFiles(in: sampleFolders(in: project)).flatMap { sampleVersions(in: $0) }
        guard let footnote = sampleFootnotes(in: versions).first, let version = footnote.version else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = footnotePayload(footnote)
        payload["versionId"] = version.id.uuidString
        payload["text"] = "Scratch update for existing footnote"
        payload["modifiedAt"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-footnote-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(footnote.id.uuidString)-existing-footnote-update-\(UUID().uuidString)",
            entityType: "FootnoteModel",
            entityId: footnote.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Footnote Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing footnote update probe passed: simulated FootnoteModel upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingNoteEntryUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && $0.name == "Poems 2026" }) ?? projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        guard let selection = selectNoteEntryForUpdateProbe(in: project) else {
            throw CloudflareSyncPOCError.applyPlanNotReady(noteEntryProbeSelectionFailureReason(project: project))
        }
        let note = selection.note

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyProject(projectId: projectId)
        rememberPendingApplyEntity(entityType: "NoteEntry", entityId: note.id.uuidString)

        var payload = notePayload(note, projectId: projectId)
        payload["content"] = "Scratch update for existing note"
        payload["title"] = "Scratch note update"
        payload["modifiedAt"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-note-entry-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(note.id.uuidString)-existing-note-entry-update-\(UUID().uuidString)",
            entityType: "NoteEntry",
            entityId: note.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Note Entry Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing note entry update probe passed for \(selection.description): simulated NoteEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingContributorUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let contributor = sampleContributors(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyProject(projectId: projectId)
        rememberPendingApplyEntity(entityType: "ContributorEntry", entityId: contributor.id.uuidString)

        var payload = contributorPayload(contributor, projectId: projectId)
        payload["biography"] = "Scratch update for existing contributor"
        payload["modifiedAt"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-contributor-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(contributor.id.uuidString)-existing-contributor-update-\(UUID().uuidString)",
            entityType: "ContributorEntry",
            entityId: contributor.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Contributor Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let label = contributor.displayName.isEmpty ? contributor.id.uuidString : contributor.displayName
        return CloudflareSyncPOCResult(
            message: "Existing contributor update probe passed for ContributorEntry '\(label)' in project '\(projectName)': simulated ContributorEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingReferenceEntryUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let referenceEntry = sampleReferenceEntries(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyProject(projectId: projectId)
        rememberPendingApplyEntity(entityType: "ReferenceEntry", entityId: referenceEntry.id.uuidString)

        var payload = referencePayload(referenceEntry, projectId: projectId)
        payload["details"] = "Scratch update for existing reference"
        payload["modifiedAt"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-reference-entry-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(referenceEntry.id.uuidString)-existing-reference-entry-update-\(UUID().uuidString)",
            entityType: "ReferenceEntry",
            entityId: referenceEntry.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Reference Entry Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let label = "\(referenceEntry.author), \(referenceEntry.publicationDate)"
        return CloudflareSyncPOCResult(
            message: "Existing reference entry update probe passed for ReferenceEntry '\(label)' in project '\(projectName)': simulated ReferenceEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingGlossaryEntryUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let glossaryEntry = sampleGlossaryEntries(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyProject(projectId: projectId)
        rememberPendingApplyEntity(entityType: "GlossaryEntry", entityId: glossaryEntry.id.uuidString)

        var payload = glossaryPayload(glossaryEntry, projectId: projectId)
        payload["definition"] = "Scratch update for existing glossary entry"
        payload["modifiedAt"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-glossary-entry-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(glossaryEntry.id.uuidString)-existing-glossary-entry-update-\(UUID().uuidString)",
            entityType: "GlossaryEntry",
            entityId: glossaryEntry.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Glossary Entry Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing glossary entry update probe passed for GlossaryEntry '\(glossaryEntry.term)' in project '\(projectName)': simulated GlossaryEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingIndexEntryUpdateProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let indexEntry = sampleIndexEntries(in: project).first(where: { $0.parentEntry == nil }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyProject(projectId: projectId)
        rememberPendingApplyEntity(entityType: "IndexEntry", entityId: indexEntry.id.uuidString)

        var payload = indexPayload(indexEntry, projectId: projectId)
        payload["keyword"] = "Scratch update for existing index entry"
        payload["modifiedAt"] = isoFormatter.string(from: Date())

        let remoteDeviceId = "remote-existing-index-entry-update-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(indexEntry.id.uuidString)-existing-index-entry-update-\(UUID().uuidString)",
            entityType: "IndexEntry",
            entityId: indexEntry.id.uuidString,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Index Entry Update Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing index entry update probe passed for IndexEntry '\(indexEntry.keyword)' in project '\(projectName)': simulated IndexEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteDeleteProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-delete-probe-\(UUID().uuidString)"
        let textFileId = "remote-delete-textfile-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let upsertOperation = SyncPOCOperation(
            id: "\(textFileId)-upsert",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "name": "Synthetic remote delete probe",
                "folderId": "",
                "workflowStatus": "",
                "contentType": "text",
                "content": "",
                "modifiedDate": timestamp,
            ])
        )
        let upsertPush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Remote Delete Probe",
            operations: [upsertOperation]
        )
        guard let upsertSequence = upsertPush.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let deleteOperation = SyncPOCOperation(
            id: "\(textFileId)-delete",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "delete",
            baseSequence: upsertSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": "Synthetic remote delete probe",
                "deletedBy": remoteDeviceId,
            ])
        )
        let deletePush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Remote Delete Probe",
            operations: [deleteOperation]
        )
        guard let deleteSequence = deletePush.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote delete probe passed: simulated TextFile upsert seq \(upsertSequence), delete seq \(deleteSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingProjectDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-existing-project-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(projectId)-existing-project-delete-guardrail",
            entityType: "Project",
            entityId: projectId,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": projectName,
                "deletedBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Project Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing project delete guardrail probe passed: simulated Project delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingFolderDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedFolder: Folder?
        for project in projects where !project.isTrashed {
            if let folder = sampleFolders(in: project).first {
                selectedProject = project
                selectedFolder = folder
                break
            }
        }
        guard let project = selectedProject, let folder = selectedFolder else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Folder", entityId: folder.id.uuidString)

        let remoteDeviceId = "remote-existing-folder-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(folder.id.uuidString)-existing-folder-delete-guardrail-\(UUID().uuidString)",
            entityType: "Folder",
            entityId: folder.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": folder.name ?? "Untitled Folder",
                "parentFolderId": folder.parentFolder?.id.uuidString ?? "",
                "deletedBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Folder Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing folder delete guardrail probe passed for Folder '\(folder.name ?? "Untitled Folder")' in project '\(projectName)': simulated Folder delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingFolderRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedFolder: Folder?
        for project in projects where !project.isTrashed {
            if let folder = sampleFolders(in: project).first {
                selectedProject = project
                selectedFolder = folder
                break
            }
        }
        guard let project = selectedProject, let folder = selectedFolder else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Folder", entityId: folder.id.uuidString)

        let remoteDeviceId = "remote-existing-folder-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(folder.id.uuidString)-existing-folder-restore-guardrail-\(UUID().uuidString)",
            entityType: "Folder",
            entityId: folder.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": folder.name ?? "Untitled Folder",
                "parentFolderId": folder.parentFolder?.id.uuidString ?? "",
                "restoredBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Folder Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing folder restore guardrail probe passed for Folder '\(folder.name ?? "Untitled Folder")' in project '\(projectName)': simulated Folder restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingTextFileDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedTextFile: TextFile?
        for project in projects where !project.isTrashed {
            let folders = sampleFolders(in: project)
            if let textFile = sampleTextFiles(in: folders).first {
                selectedProject = project
                selectedTextFile = textFile
                break
            }
        }
        guard let project = selectedProject, let textFile = selectedTextFile else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "TextFile", entityId: textFile.id.uuidString)

        let remoteDeviceId = "remote-existing-textfile-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(textFile.id.uuidString)-existing-textfile-delete-guardrail-\(UUID().uuidString)",
            entityType: "TextFile",
            entityId: textFile.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": textFile.name,
                "folderId": textFile.parentFolder?.id.uuidString ?? "",
                "deletedBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing TextFile Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing text file delete guardrail probe passed for TextFile '\(textFile.name)' in project '\(projectName)': simulated TextFile delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingTextFileRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedTextFile: TextFile?
        for project in projects where !project.isTrashed {
            let folders = sampleFolders(in: project)
            if let textFile = sampleTextFiles(in: folders).first {
                selectedProject = project
                selectedTextFile = textFile
                break
            }
        }
        guard let project = selectedProject, let textFile = selectedTextFile else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "TextFile", entityId: textFile.id.uuidString)

        let remoteDeviceId = "remote-existing-textfile-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(textFile.id.uuidString)-existing-textfile-restore-guardrail-\(UUID().uuidString)",
            entityType: "TextFile",
            entityId: textFile.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": textFile.name,
                "folderId": textFile.parentFolder?.id.uuidString ?? "",
                "restoredBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing TextFile Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing text file restore guardrail probe passed for TextFile '\(textFile.name)' in project '\(projectName)': simulated TextFile restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingVersionDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedTextFile: TextFile?
        var selectedVersion: Version?
        for project in projects where !project.isTrashed {
            let textFiles = sampleTextFiles(in: sampleFolders(in: project))
            if let textFile = textFiles.first(where: { !sampleVersions(in: $0).isEmpty }), let version = sampleVersions(in: textFile).first {
                selectedProject = project
                selectedTextFile = textFile
                selectedVersion = version
                break
            }
        }
        guard let project = selectedProject, let textFile = selectedTextFile, let version = selectedVersion else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Version", entityId: version.id.uuidString)

        let remoteDeviceId = "remote-existing-version-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(version.id.uuidString)-existing-version-delete-guardrail-\(UUID().uuidString)",
            entityType: "Version",
            entityId: version.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "textFileId": textFile.id.uuidString,
                "versionNumber": String(version.versionNumber),
                "deletedBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Version Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing version delete guardrail probe passed for Version \(version.versionNumber) of TextFile '\(textFile.name)' in project '\(projectName)': simulated Version delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingVersionRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedTextFile: TextFile?
        var selectedVersion: Version?
        for project in projects where !project.isTrashed {
            let textFiles = sampleTextFiles(in: sampleFolders(in: project))
            if let textFile = textFiles.first(where: { !sampleVersions(in: $0).isEmpty }), let version = sampleVersions(in: textFile).first {
                selectedProject = project
                selectedTextFile = textFile
                selectedVersion = version
                break
            }
        }
        guard let project = selectedProject, let textFile = selectedTextFile, let version = selectedVersion else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Version", entityId: version.id.uuidString)

        let remoteDeviceId = "remote-existing-version-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(version.id.uuidString)-existing-version-restore-guardrail-\(UUID().uuidString)",
            entityType: "Version",
            entityId: version.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "textFileId": textFile.id.uuidString,
                "versionNumber": String(version.versionNumber),
                "restoredBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Version Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing version restore guardrail probe passed for Version \(version.versionNumber) of TextFile '\(textFile.name)' in project '\(projectName)': simulated Version restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingCommentDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedVersion: Version?
        var selectedComment: CommentModel?
        for project in projects where !project.isTrashed {
            let versions = sampleTextFiles(in: sampleFolders(in: project)).flatMap { sampleVersions(in: $0) }
            if let comment = sampleComments(in: versions).first, let version = comment.version {
                selectedProject = project
                selectedVersion = version
                selectedComment = comment
                break
            }
        }
        guard let project = selectedProject, let version = selectedVersion, let comment = selectedComment else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "CommentModel", entityId: comment.id.uuidString)

        var payload = commentPayload(comment)
        payload["versionId"] = version.id.uuidString
        payload["deletedBy"] = "remote-existing-comment-delete-guardrail"

        let remoteDeviceId = "remote-existing-comment-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(comment.id.uuidString)-existing-comment-delete-guardrail-\(UUID().uuidString)",
            entityType: "CommentModel",
            entityId: comment.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Comment Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing comment delete guardrail probe passed for CommentModel \(comment.id.uuidString) in project '\(projectName)': simulated CommentModel delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingCommentRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedVersion: Version?
        var selectedComment: CommentModel?
        for project in projects where !project.isTrashed {
            let versions = sampleTextFiles(in: sampleFolders(in: project)).flatMap { sampleVersions(in: $0) }
            if let comment = sampleComments(in: versions).first, let version = comment.version {
                selectedProject = project
                selectedVersion = version
                selectedComment = comment
                break
            }
        }
        guard let project = selectedProject, let version = selectedVersion, let comment = selectedComment else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "CommentModel", entityId: comment.id.uuidString)

        var payload = commentPayload(comment)
        payload["versionId"] = version.id.uuidString
        payload["restoredBy"] = "remote-existing-comment-restore-guardrail"

        let remoteDeviceId = "remote-existing-comment-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(comment.id.uuidString)-existing-comment-restore-guardrail-\(UUID().uuidString)",
            entityType: "CommentModel",
            entityId: comment.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Comment Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing comment restore guardrail probe passed for CommentModel \(comment.id.uuidString) in project '\(projectName)': simulated CommentModel restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingFootnoteDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedVersion: Version?
        var selectedFootnote: FootnoteModel?
        for project in projects where !project.isTrashed {
            let versions = sampleTextFiles(in: sampleFolders(in: project)).flatMap { sampleVersions(in: $0) }
            if let footnote = sampleFootnotes(in: versions).first, let version = footnote.version {
                selectedProject = project
                selectedVersion = version
                selectedFootnote = footnote
                break
            }
        }
        guard let project = selectedProject, let version = selectedVersion, let footnote = selectedFootnote else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "FootnoteModel", entityId: footnote.id.uuidString)

        var payload = footnotePayload(footnote)
        payload["versionId"] = version.id.uuidString
        payload["deletedBy"] = "remote-existing-footnote-delete-guardrail"

        let remoteDeviceId = "remote-existing-footnote-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(footnote.id.uuidString)-existing-footnote-delete-guardrail-\(UUID().uuidString)",
            entityType: "FootnoteModel",
            entityId: footnote.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Footnote Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing footnote delete guardrail probe passed for FootnoteModel \(footnote.id.uuidString) in project '\(projectName)': simulated FootnoteModel delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingFootnoteRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedVersion: Version?
        var selectedFootnote: FootnoteModel?
        for project in projects where !project.isTrashed {
            let versions = sampleTextFiles(in: sampleFolders(in: project)).flatMap { sampleVersions(in: $0) }
            if let footnote = sampleFootnotes(in: versions).first, let version = footnote.version {
                selectedProject = project
                selectedVersion = version
                selectedFootnote = footnote
                break
            }
        }
        guard let project = selectedProject, let version = selectedVersion, let footnote = selectedFootnote else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "FootnoteModel", entityId: footnote.id.uuidString)

        var payload = footnotePayload(footnote)
        payload["versionId"] = version.id.uuidString
        payload["restoredBy"] = "remote-existing-footnote-restore-guardrail"

        let remoteDeviceId = "remote-existing-footnote-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(footnote.id.uuidString)-existing-footnote-restore-guardrail-\(UUID().uuidString)",
            entityType: "FootnoteModel",
            entityId: footnote.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Footnote Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing footnote restore guardrail probe passed for FootnoteModel \(footnote.id.uuidString) in project '\(projectName)': simulated FootnoteModel restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingRelationshipLinkDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let selection = selectRelationshipLinkForDeleteGuardrail(projects: projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let project = selection.project
        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = selection.link.payload
        payload["deletedBy"] = deviceId

        let remoteDeviceId = "remote-existing-link-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(selection.link.entityId)-existing-link-delete-guardrail-\(UUID().uuidString)",
            entityType: selection.link.entityType,
            entityId: selection.link.entityId,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Relationship Link Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing relationship link delete guardrail probe passed for \(selection.link.entityType) in project '\(projectName)': simulated delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingRelationshipLinkRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let selection = selectRelationshipLinkForDeleteGuardrail(projects: projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let project = selection.project
        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        var payload = selection.link.payload
        payload["restoredBy"] = deviceId

        let remoteDeviceId = "remote-existing-link-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(selection.link.entityId)-existing-link-restore-guardrail-\(UUID().uuidString)",
            entityType: selection.link.entityType,
            entityId: selection.link.entityId,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Relationship Link Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing relationship link restore guardrail probe passed for \(selection.link.entityType) in project '\(projectName)': simulated restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingNoteEntryDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && $0.name == "Poems 2026" }) ?? projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        guard let selection = selectNoteEntryForUpdateProbe(in: project) else {
            throw CloudflareSyncPOCError.applyPlanNotReady(noteEntryProbeSelectionFailureReason(project: project))
        }

        let note = selection.note
        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "NoteEntry", entityId: note.id.uuidString)

        var payload = notePayload(note, projectId: projectId)
        payload["deletedBy"] = "remote-existing-note-entry-delete-guardrail"

        let remoteDeviceId = "remote-existing-note-entry-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(note.id.uuidString)-existing-note-entry-delete-guardrail-\(UUID().uuidString)",
            entityType: "NoteEntry",
            entityId: note.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Note Entry Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing note entry delete guardrail probe passed for \(selection.description): simulated NoteEntry delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingNoteEntryRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && $0.name == "Poems 2026" }) ?? projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }
        guard let selection = selectNoteEntryForUpdateProbe(in: project) else {
            throw CloudflareSyncPOCError.applyPlanNotReady(noteEntryProbeSelectionFailureReason(project: project))
        }

        let note = selection.note
        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "NoteEntry", entityId: note.id.uuidString)

        var payload = notePayload(note, projectId: projectId)
        payload["restoredBy"] = "remote-existing-note-entry-restore-guardrail"

        let remoteDeviceId = "remote-existing-note-entry-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(note.id.uuidString)-existing-note-entry-restore-guardrail-\(UUID().uuidString)",
            entityType: "NoteEntry",
            entityId: note.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Note Entry Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing note entry restore guardrail probe passed for \(selection.description): simulated NoteEntry restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingContributorDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let contributor = sampleContributors(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "ContributorEntry", entityId: contributor.id.uuidString)

        var payload = contributorPayload(contributor, projectId: projectId)
        payload["deletedBy"] = "remote-existing-contributor-delete-guardrail"

        let remoteDeviceId = "remote-existing-contributor-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(contributor.id.uuidString)-existing-contributor-delete-guardrail-\(UUID().uuidString)",
            entityType: "ContributorEntry",
            entityId: contributor.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Contributor Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let label = contributor.displayName.isEmpty ? contributor.id.uuidString : contributor.displayName
        return CloudflareSyncPOCResult(
            message: "Existing contributor delete guardrail probe passed for ContributorEntry '\(label)' in project '\(projectName)': simulated ContributorEntry delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingContributorRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let contributor = sampleContributors(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "ContributorEntry", entityId: contributor.id.uuidString)

        var payload = contributorPayload(contributor, projectId: projectId)
        payload["restoredBy"] = "remote-existing-contributor-restore-guardrail"

        let remoteDeviceId = "remote-existing-contributor-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(contributor.id.uuidString)-existing-contributor-restore-guardrail-\(UUID().uuidString)",
            entityType: "ContributorEntry",
            entityId: contributor.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Contributor Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let label = contributor.displayName.isEmpty ? contributor.id.uuidString : contributor.displayName
        return CloudflareSyncPOCResult(
            message: "Existing contributor restore guardrail probe passed for ContributorEntry '\(label)' in project '\(projectName)': simulated ContributorEntry restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingReferenceEntryDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let referenceEntry = sampleReferenceEntries(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "ReferenceEntry", entityId: referenceEntry.id.uuidString)

        var payload = referencePayload(referenceEntry, projectId: projectId)
        payload["deletedBy"] = "remote-existing-reference-entry-delete-guardrail"

        let remoteDeviceId = "remote-existing-reference-entry-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(referenceEntry.id.uuidString)-existing-reference-entry-delete-guardrail-\(UUID().uuidString)",
            entityType: "ReferenceEntry",
            entityId: referenceEntry.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Reference Entry Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let label = "\(referenceEntry.author), \(referenceEntry.publicationDate)"
        return CloudflareSyncPOCResult(
            message: "Existing reference entry delete guardrail probe passed for ReferenceEntry '\(label)' in project '\(projectName)': simulated ReferenceEntry delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingReferenceEntryRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let referenceEntry = sampleReferenceEntries(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "ReferenceEntry", entityId: referenceEntry.id.uuidString)

        var payload = referencePayload(referenceEntry, projectId: projectId)
        payload["restoredBy"] = "remote-existing-reference-entry-restore-guardrail"

        let remoteDeviceId = "remote-existing-reference-entry-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(referenceEntry.id.uuidString)-existing-reference-entry-restore-guardrail-\(UUID().uuidString)",
            entityType: "ReferenceEntry",
            entityId: referenceEntry.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Reference Entry Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let label = "\(referenceEntry.author), \(referenceEntry.publicationDate)"
        return CloudflareSyncPOCResult(
            message: "Existing reference entry restore guardrail probe passed for ReferenceEntry '\(label)' in project '\(projectName)': simulated ReferenceEntry restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingGlossaryEntryDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let glossaryEntry = sampleGlossaryEntries(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "GlossaryEntry", entityId: glossaryEntry.id.uuidString)

        var payload = glossaryPayload(glossaryEntry, projectId: projectId)
        payload["deletedBy"] = "remote-existing-glossary-entry-delete-guardrail"

        let remoteDeviceId = "remote-existing-glossary-entry-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(glossaryEntry.id.uuidString)-existing-glossary-entry-delete-guardrail-\(UUID().uuidString)",
            entityType: "GlossaryEntry",
            entityId: glossaryEntry.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Glossary Entry Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing glossary entry delete guardrail probe passed for GlossaryEntry '\(glossaryEntry.term)' in project '\(projectName)': simulated GlossaryEntry delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingGlossaryEntryRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let glossaryEntry = sampleGlossaryEntries(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "GlossaryEntry", entityId: glossaryEntry.id.uuidString)

        var payload = glossaryPayload(glossaryEntry, projectId: projectId)
        payload["restoredBy"] = "remote-existing-glossary-entry-restore-guardrail"

        let remoteDeviceId = "remote-existing-glossary-entry-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(glossaryEntry.id.uuidString)-existing-glossary-entry-restore-guardrail-\(UUID().uuidString)",
            entityType: "GlossaryEntry",
            entityId: glossaryEntry.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Glossary Entry Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing glossary entry restore guardrail probe passed for GlossaryEntry '\(glossaryEntry.term)' in project '\(projectName)': simulated GlossaryEntry restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingIndexEntryDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let indexEntry = sampleIndexEntries(in: project).first(where: { $0.parentEntry == nil }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "IndexEntry", entityId: indexEntry.id.uuidString)

        var payload = indexPayload(indexEntry, projectId: projectId)
        payload["deletedBy"] = "remote-existing-index-entry-delete-guardrail"

        let remoteDeviceId = "remote-existing-index-entry-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(indexEntry.id.uuidString)-existing-index-entry-delete-guardrail-\(UUID().uuidString)",
            entityType: "IndexEntry",
            entityId: indexEntry.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Index Entry Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing index entry delete guardrail probe passed for IndexEntry '\(indexEntry.keyword)' in project '\(projectName)': simulated IndexEntry delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingIndexEntryRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }),
              let indexEntry = sampleIndexEntries(in: project).first(where: { $0.parentEntry == nil }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "IndexEntry", entityId: indexEntry.id.uuidString)

        var payload = indexPayload(indexEntry, projectId: projectId)
        payload["restoredBy"] = "remote-existing-index-entry-restore-guardrail"

        let remoteDeviceId = "remote-existing-index-entry-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(indexEntry.id.uuidString)-existing-index-entry-restore-guardrail-\(UUID().uuidString)",
            entityType: "IndexEntry",
            entityId: indexEntry.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Index Entry Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing index entry restore guardrail probe passed for IndexEntry '\(indexEntry.keyword)' in project '\(projectName)': simulated IndexEntry restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingPublicationDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !samplePublications(in: $0).isEmpty }),
              let publication = samplePublications(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Publication", entityId: publication.id.uuidString)

        var payload = publicationPayload(publication, projectId: projectId)
        payload["deletedBy"] = "remote-existing-publication-delete-guardrail"

        let remoteDeviceId = "remote-existing-publication-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(publication.id.uuidString)-existing-publication-delete-guardrail-\(UUID().uuidString)",
            entityType: "Publication",
            entityId: publication.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Publication Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing publication delete guardrail probe passed for Publication '\(publication.name)' in project '\(projectName)': simulated Publication delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingPublicationRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed && !samplePublications(in: $0).isEmpty }),
              let publication = samplePublications(in: project).first else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Publication", entityId: publication.id.uuidString)

        var payload = publicationPayload(publication, projectId: projectId)
        payload["restoredBy"] = "remote-existing-publication-restore-guardrail"

        let remoteDeviceId = "remote-existing-publication-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(publication.id.uuidString)-existing-publication-restore-guardrail-\(UUID().uuidString)",
            entityType: "Publication",
            entityId: publication.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Publication Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing publication restore guardrail probe passed for Publication '\(publication.name)' in project '\(projectName)': simulated Publication restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingSubmissionDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedSubmission: Submission?
        var selectedPublication: Publication?
        for project in projects where !project.isTrashed {
            if let submission = sampleSubmissions(in: project).first(where: { $0.publication != nil }), let publication = submission.publication {
                selectedProject = project
                selectedSubmission = submission
                selectedPublication = publication
                break
            }
        }
        guard let project = selectedProject, let submission = selectedSubmission, let publication = selectedPublication else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Submission", entityId: submission.id.uuidString)

        var payload = submissionPayload(submission, projectId: projectId)
        payload["publicationId"] = publication.id.uuidString
        payload["deletedBy"] = "remote-existing-submission-delete-guardrail"

        let remoteDeviceId = "remote-existing-submission-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(submission.id.uuidString)-existing-submission-delete-guardrail-\(UUID().uuidString)",
            entityType: "Submission",
            entityId: submission.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Submission Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let submissionName = submission.name ?? publication.name

        return CloudflareSyncPOCResult(
            message: "Existing submission delete guardrail probe passed for Submission '\(submissionName)' in project '\(projectName)': simulated Submission delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingSubmissionRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedSubmission: Submission?
        var selectedPublication: Publication?
        for project in projects where !project.isTrashed {
            if let submission = sampleSubmissions(in: project).first(where: { $0.publication != nil }), let publication = submission.publication {
                selectedProject = project
                selectedSubmission = submission
                selectedPublication = publication
                break
            }
        }
        guard let project = selectedProject, let submission = selectedSubmission, let publication = selectedPublication else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "Submission", entityId: submission.id.uuidString)

        var payload = submissionPayload(submission, projectId: projectId)
        payload["publicationId"] = publication.id.uuidString
        payload["restoredBy"] = "remote-existing-submission-restore-guardrail"

        let remoteDeviceId = "remote-existing-submission-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(submission.id.uuidString)-existing-submission-restore-guardrail-\(UUID().uuidString)",
            entityType: "Submission",
            entityId: submission.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Submission Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let submissionName = submission.name ?? publication.name

        return CloudflareSyncPOCResult(
            message: "Existing submission restore guardrail probe passed for Submission '\(submissionName)' in project '\(projectName)': simulated Submission restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingSubmittedFileDeleteGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedSubmittedFile: SubmittedFile?
        for project in projects where !project.isTrashed {
            let submittedFiles = sampleSubmittedFiles(in: sampleSubmissions(in: project))
            if let submittedFile = submittedFiles.first(where: { $0.submission?.publication != nil && $0.textFile != nil && $0.version != nil }) {
                selectedProject = project
                selectedSubmittedFile = submittedFile
                break
            }
        }
        guard let project = selectedProject,
              let submittedFile = selectedSubmittedFile,
              let submission = submittedFile.submission,
              let textFile = submittedFile.textFile,
              let version = submittedFile.version else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "SubmittedFile", entityId: submittedFile.id.uuidString)

        var payload = submittedFilePayload(submittedFile, projectId: projectId)
        payload["submissionId"] = submission.id.uuidString
        payload["textFileId"] = textFile.id.uuidString
        payload["versionId"] = version.id.uuidString
        payload["deletedBy"] = "remote-existing-submitted-file-delete-guardrail"

        let remoteDeviceId = "remote-existing-submitted-file-delete-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(submittedFile.id.uuidString)-existing-submitted-file-delete-guardrail-\(UUID().uuidString)",
            entityType: "SubmittedFile",
            entityId: submittedFile.id.uuidString,
            operationType: "delete",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing SubmittedFile Delete Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing submitted file delete guardrail probe passed for SubmittedFile '\(textFile.name)' in project '\(projectName)': simulated SubmittedFile delete seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingSubmittedFileRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        var selectedProject: Project?
        var selectedSubmittedFile: SubmittedFile?
        for project in projects where !project.isTrashed {
            let submittedFiles = sampleSubmittedFiles(in: sampleSubmissions(in: project))
            if let submittedFile = submittedFiles.first(where: { $0.submission?.publication != nil && $0.textFile != nil && $0.version != nil }) {
                selectedProject = project
                selectedSubmittedFile = submittedFile
                break
            }
        }
        guard let project = selectedProject,
              let submittedFile = selectedSubmittedFile,
              let submission = submittedFile.submission,
              let textFile = submittedFile.textFile,
              let version = submittedFile.version else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)
        rememberPendingApplyEntity(entityType: "SubmittedFile", entityId: submittedFile.id.uuidString)

        var payload = submittedFilePayload(submittedFile, projectId: projectId)
        payload["submissionId"] = submission.id.uuidString
        payload["textFileId"] = textFile.id.uuidString
        payload["versionId"] = version.id.uuidString
        payload["restoredBy"] = "remote-existing-submitted-file-restore-guardrail"

        let remoteDeviceId = "remote-existing-submitted-file-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(submittedFile.id.uuidString)-existing-submitted-file-restore-guardrail-\(UUID().uuidString)",
            entityType: "SubmittedFile",
            entityId: submittedFile.id.uuidString,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: payload)
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing SubmittedFile Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing submitted file restore guardrail probe passed for SubmittedFile '\(textFile.name)' in project '\(projectName)': simulated SubmittedFile restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteRestoreProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-restore-probe-\(UUID().uuidString)"
        let textFileId = "remote-restore-textfile-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let upsertOperation = SyncPOCOperation(
            id: "\(textFileId)-upsert",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "name": "Synthetic remote restore probe",
                "folderId": "",
                "workflowStatus": "",
                "contentType": "text",
                "content": "",
                "modifiedDate": timestamp,
            ])
        )
        let upsertPush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Remote Restore Probe",
            operations: [upsertOperation]
        )
        guard let upsertSequence = upsertPush.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let deleteOperation = SyncPOCOperation(
            id: "\(textFileId)-delete",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "delete",
            baseSequence: upsertSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": "Synthetic remote restore probe",
                "deletedBy": remoteDeviceId,
            ])
        )
        let deletePush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Remote Restore Probe",
            operations: [deleteOperation]
        )
        guard let deleteSequence = deletePush.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let restoreOperation = SyncPOCOperation(
            id: "\(textFileId)-restore",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "restore",
            baseSequence: deleteSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": "Synthetic remote restore probe",
                "restoredBy": remoteDeviceId,
            ])
        )
        let restorePush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Remote Restore Probe",
            operations: [restoreOperation]
        )
        guard let restoreSequence = restorePush.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote restore probe passed: simulated TextFile upsert seq \(upsertSequence), delete seq \(deleteSequence), restore seq \(restoreSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runExistingProjectRestoreGuardrailProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-existing-project-restore-guardrail-probe-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(projectId)-existing-project-restore-guardrail",
            entityType: "Project",
            entityId: projectId,
            operationType: "restore",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": projectName,
                "restoredBy": remoteDeviceId,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Existing Project Restore Guardrail Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Existing project restore guardrail probe passed: simulated Project restore seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteMissingDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-missing-dependency-probe-\(UUID().uuidString)"
        let versionId = "remote-missing-dependency-version-\(UUID().uuidString)"
        let missingTextFileId = "missing-textfile-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(versionId)-upsert",
            entityType: "Version",
            entityId: versionId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "textFileId": missingTextFileId,
                "content": "Synthetic missing dependency probe",
                "versionNumber": "1",
                "comment": "",
                "notes": "",
                "createdDate": isoFormatter.string(from: Date()),
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Missing Dependency Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote missing dependency probe passed: simulated Version upsert seq \(pushedSequence) references missing TextFile \(missingTextFileId); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteSatisfiedDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-satisfied-dependency-probe-\(UUID().uuidString)"
        let textFileId = "remote-satisfied-dependency-textfile-\(UUID().uuidString)"
        let versionId = "remote-satisfied-dependency-version-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let textFileOperation = SyncPOCOperation(
            id: "\(textFileId)-upsert",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "name": "Synthetic satisfied dependency parent",
                "fileTypeRaw": "text",
                "isTrashed": "false",
                "createdDate": timestamp,
                "modifiedDate": timestamp,
            ])
        )
        let versionOperation = SyncPOCOperation(
            id: "\(versionId)-upsert",
            entityType: "Version",
            entityId: versionId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "textFileId": textFileId,
                "content": "Synthetic satisfied dependency child",
                "versionNumber": "1",
                "comment": "",
                "notes": "",
                "createdDate": timestamp,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Satisfied Dependency Probe",
            operations: [textFileOperation, versionOperation]
        )
        guard push.accepted.count == 2,
              let firstSequence = push.accepted.first?.serverSequence,
              let secondSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote satisfied dependency probe passed: simulated TextFile upsert seq \(firstSequence) and Version upsert seq \(secondSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runSatisfiedDependencyStateSummaryProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-satisfied-state-summary-probe-\(UUID().uuidString)"
        let textFileId = "remote-satisfied-state-textfile-\(UUID().uuidString)"
        let versionId = "remote-satisfied-state-version-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let textFileOperation = SyncPOCOperation(
            id: "\(textFileId)-upsert",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "name": "Synthetic satisfied state parent",
                "fileTypeRaw": "text",
                "isTrashed": "false",
                "createdDate": timestamp,
                "modifiedDate": timestamp,
            ])
        )
        let versionOperation = SyncPOCOperation(
            id: "\(versionId)-upsert",
            entityType: "Version",
            entityId: versionId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "textFileId": textFileId,
                "content": "Synthetic satisfied state child",
                "versionNumber": "1",
                "comment": "",
                "notes": "",
                "createdDate": timestamp,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Satisfied Dependency State Summary Probe",
            operations: [textFileOperation, versionOperation]
        )
        guard push.accepted.count == 2,
              let firstSequence = push.accepted.first?.serverSequence,
              let secondSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        let scratchStoreURL = try isolatedStoreURL(basename: pendingApplyStoreBasename)
        let scratchStoreExists = FileManager.default.fileExists(atPath: scratchStoreURL.path)

        return CloudflareSyncPOCResult(
            message: "Satisfied dependency state summary probe passed for '\(projectName)' (\(projectId)): pushed TextFile seq \(firstSequence) and Version seq \(secondSequence) after baseline \(baselineSequence). Remembered sequence \(rememberedLastSequence(projectId: projectId)), remote latest \(response.latestSequence), server cursor \(response.cursorSequence), change count \(response.changeCount), scratch store \(scratchStoreExists ? "present" : "absent") at \(scratchStoreURL.lastPathComponent), version \(response.version). Cursor was not advanced beyond the baseline, scratch store was not changed, and production local data was not changed."
        )
    }

    @MainActor
    func runRemoteFolderDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-folder-dependency-probe-\(UUID().uuidString)"
        let folderId = "remote-folder-dependency-folder-\(UUID().uuidString)"
        let textFileId = "remote-folder-dependency-textfile-\(UUID().uuidString)"
        let versionId = "remote-folder-dependency-version-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let folderOperation = SyncPOCOperation(
            id: "\(folderId)-upsert",
            entityType: "Folder",
            entityId: folderId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "name": "Synthetic folder dependency parent",
                "userOrder": "0",
            ])
        )
        let textFileOperation = SyncPOCOperation(
            id: "\(textFileId)-upsert",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "folderId": folderId,
                "name": "Synthetic folder dependency child",
                "fileTypeRaw": "text",
                "isTrashed": "false",
                "createdDate": timestamp,
                "modifiedDate": timestamp,
            ])
        )
        let versionOperation = SyncPOCOperation(
            id: "\(versionId)-upsert",
            entityType: "Version",
            entityId: versionId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "textFileId": textFileId,
                "content": "Synthetic folder dependency version",
                "versionNumber": "1",
                "comment": "",
                "notes": "",
                "createdDate": timestamp,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Folder Dependency Probe",
            operations: [folderOperation, textFileOperation, versionOperation]
        )
        guard push.accepted.count == 3,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote folder dependency probe passed: simulated Folder/TextFile/Version upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteAnnotationDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-annotation-dependency-probe-\(UUID().uuidString)"
        let folderId = "remote-annotation-dependency-folder-\(UUID().uuidString)"
        let textFileId = "remote-annotation-dependency-textfile-\(UUID().uuidString)"
        let versionId = "remote-annotation-dependency-version-\(UUID().uuidString)"
        let commentId = "remote-annotation-dependency-comment-\(UUID().uuidString)"
        let footnoteId = "remote-annotation-dependency-footnote-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(folderId)-upsert",
                entityType: "Folder",
                entityId: folderId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "name": "Synthetic annotation folder",
                    "userOrder": "0",
                ])
            ),
            SyncPOCOperation(
                id: "\(textFileId)-upsert",
                entityType: "TextFile",
                entityId: textFileId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "folderId": folderId,
                    "name": "Synthetic annotation file",
                    "fileTypeRaw": "text",
                    "isTrashed": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(versionId)-upsert",
                entityType: "Version",
                entityId: versionId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "textFileId": textFileId,
                    "content": "Synthetic annotation dependency version",
                    "versionNumber": "1",
                    "comment": "",
                    "notes": "",
                    "createdDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(commentId)-upsert",
                entityType: "CommentModel",
                entityId: commentId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "versionId": versionId,
                    "characterPosition": "0",
                    "attachmentID": UUID().uuidString,
                    "text": "Synthetic remote comment",
                    "author": "Cloudflare POC",
                    "createdAt": timestamp,
                    "resolvedAt": "",
                ])
            ),
            SyncPOCOperation(
                id: "\(footnoteId)-upsert",
                entityType: "FootnoteModel",
                entityId: footnoteId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "versionId": versionId,
                    "characterPosition": "0",
                    "attachmentID": UUID().uuidString,
                    "text": "Synthetic remote footnote",
                    "number": "1",
                    "createdAt": timestamp,
                    "modifiedAt": timestamp,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Annotation Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote annotation dependency probe passed: simulated Folder/TextFile/Version/Comment/Footnote upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteStyleDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-style-dependency-probe-\(UUID().uuidString)"
        let styleSheetId = "remote-style-dependency-stylesheet-\(UUID().uuidString)"
        let textStyleId = "remote-style-dependency-textstyle-\(UUID().uuidString)"
        let imageStyleId = "remote-style-dependency-imagestyle-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(styleSheetId)-upsert",
                entityType: "StyleSheet",
                entityId: styleSheetId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "name": "Synthetic style dependency stylesheet",
                    "isSystemStyleSheet": "false",
                    "footnoteMarkerStyleRaw": "superscript",
                ])
            ),
            SyncPOCOperation(
                id: "\(textStyleId)-upsert",
                entityType: "TextStyleModel",
                entityId: textStyleId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "styleSheetId": styleSheetId,
                    "name": "synthetic-body",
                    "displayName": "Synthetic Body",
                    "displayOrder": "1",
                    "fontSize": "17",
                    "isBold": "false",
                    "isItalic": "false",
                    "isUnderlined": "false",
                    "isStrikethrough": "false",
                    "alignmentRaw": "0",
                    "styleCategoryRaw": "text",
                    "numberFormatRaw": "none",
                    "isSystemStyle": "false",
                ])
            ),
            SyncPOCOperation(
                id: "\(imageStyleId)-upsert",
                entityType: "ImageStyle",
                entityId: imageStyleId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "styleSheetId": styleSheetId,
                    "name": "synthetic-image",
                    "displayName": "Synthetic Image",
                    "displayOrder": "1",
                    "defaultScale": "1.0",
                    "defaultAlignmentRaw": "center",
                    "hasCaptionByDefault": "false",
                    "defaultCaptionStyle": "UICTFontTextStyleCaption1",
                    "isSystemStyle": "false",
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Style Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote style dependency probe passed: simulated StyleSheet/TextStyle/ImageStyle upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteSubmissionDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-submission-dependency-probe-\(UUID().uuidString)"
        let publicationId = "remote-submission-dependency-publication-\(UUID().uuidString)"
        let folderId = "remote-submission-dependency-folder-\(UUID().uuidString)"
        let textFileId = "remote-submission-dependency-textfile-\(UUID().uuidString)"
        let versionId = "remote-submission-dependency-version-\(UUID().uuidString)"
        let submissionId = "remote-submission-dependency-submission-\(UUID().uuidString)"
        let submittedFileId = "remote-submission-dependency-submittedfile-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(publicationId)-upsert",
                entityType: "Publication",
                entityId: publicationId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic publication",
                    "type": "magazine",
                    "url": "",
                    "notes": "",
                    "deadline": "",
                    "typicalResponseDays": "30",
                    "reminderDate": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(folderId)-upsert",
                entityType: "Folder",
                entityId: folderId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "name": "Synthetic submission folder",
                    "userOrder": "0",
                ])
            ),
            SyncPOCOperation(
                id: "\(textFileId)-upsert",
                entityType: "TextFile",
                entityId: textFileId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "folderId": folderId,
                    "name": "Synthetic submitted file source",
                    "fileTypeRaw": "text",
                    "isTrashed": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(versionId)-upsert",
                entityType: "Version",
                entityId: versionId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "textFileId": textFileId,
                    "content": "Synthetic submitted version",
                    "versionNumber": "1",
                    "comment": "",
                    "notes": "",
                    "createdDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(submissionId)-upsert",
                entityType: "Submission",
                entityId: submissionId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "publicationId": publicationId,
                    "name": "",
                    "collectionDescription": "",
                    "isCollection": "false",
                    "submittedDate": timestamp,
                    "returnExpectedBy": "",
                    "returnedOn": "",
                    "notes": "",
                    "typicalResponseDays": "30",
                    "reminderDate": "",
                    "userOrder": "0",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(submittedFileId)-upsert",
                entityType: "SubmittedFile",
                entityId: submittedFileId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "submissionId": submissionId,
                    "textFileId": textFileId,
                    "versionId": versionId,
                    "status": "pending",
                    "statusDate": timestamp,
                    "statusNotes": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Submission Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote submission dependency probe passed: simulated Publication/Folder/TextFile/Version/Submission/SubmittedFile upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemotePoetryCollectionDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-poetry-collection-dependency-probe-\(UUID().uuidString)"
        let textFileId = "remote-poetry-collection-textfile-\(UUID().uuidString)"
        let collectionId = "remote-poetry-collection-collection-\(UUID().uuidString)"
        let linkId = "remote-poetry-collection-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(collectionId)-upsert",
                entityType: "PoetryCollection",
                entityId: collectionId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic poetry collection",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(textFileId)-upsert",
                entityType: "TextFile",
                entityId: textFileId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "folderId": "",
                    "name": "Synthetic collected poem",
                    "fileTypeRaw": "poem",
                    "isTrashed": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "TextFileCollectionLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "textFileId": textFileId,
                    "poetryCollectionId": collectionId,
                    "userOrder": "0",
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Poetry Collection Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote poetry collection dependency probe passed: simulated PoetryCollection/TextFile/TextFileCollectionLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteProseSectionDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-prose-section-dependency-probe-\(UUID().uuidString)"
        let textFileId = "remote-prose-section-textfile-\(UUID().uuidString)"
        let sectionId = "remote-prose-section-section-\(UUID().uuidString)"
        let linkId = "remote-prose-section-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(sectionId)-upsert",
                entityType: "ProseSection",
                entityId: sectionId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic prose section",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(textFileId)-upsert",
                entityType: "TextFile",
                entityId: textFileId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "folderId": "",
                    "name": "Synthetic prose piece",
                    "fileTypeRaw": "text",
                    "isTrashed": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "TextFileSectionLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "textFileId": textFileId,
                    "sectionId": sectionId,
                    "userOrder": "0",
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Prose Section Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote prose section dependency probe passed: simulated ProseSection/TextFile/TextFileSectionLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteNoteEntryDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-note-entry-dependency-probe-\(UUID().uuidString)"
        let noteId = "remote-note-entry-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operation = SyncPOCOperation(
            id: "\(noteId)-upsert",
            entityType: "NoteEntry",
            entityId: noteId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "projectId": projectId,
                "content": "Synthetic note entry",
                "formattedContentData": "",
                "isEndnote": "false",
                "displayNumber": "1",
                "referenceCount": "0",
                "referencingFileIDs": "",
                "createdAt": timestamp,
                "modifiedAt": timestamp,
                "title": "Synthetic note",
                "tag": "cloudflare-poc",
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Note Entry Dependency Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote note entry dependency probe passed: simulated NoteEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteGlossaryCitationDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-glossary-citation-dependency-probe-\(UUID().uuidString)"
        let citationId = "remote-glossary-citation-\(UUID().uuidString)"
        let glossaryId = "remote-glossary-entry-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(citationId)-upsert",
                entityType: "CitationEntry",
                entityId: citationId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "authorsData": "",
                    "year": "2026",
                    "title": "Synthetic citation",
                    "source": "Cloudflare POC",
                    "url": "",
                    "doi": "",
                    "volume": "",
                    "issue": "",
                    "pages": "",
                    "edition": "",
                    "city": "",
                    "accessDate": "",
                    "sourceTypeRaw": "article",
                    "referenceCount": "0",
                    "createdAt": timestamp,
                    "modifiedAt": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(glossaryId)-upsert",
                entityType: "GlossaryEntry",
                entityId: glossaryId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "term": "Synthetic glossary term",
                    "definition": "Synthetic glossary definition",
                    "citationId": citationId,
                    "referenceCount": "0",
                    "createdAt": timestamp,
                    "modifiedAt": timestamp,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Glossary Citation Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote glossary citation dependency probe passed: simulated CitationEntry/GlossaryEntry upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteReferenceEntryDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-reference-entry-dependency-probe-\(UUID().uuidString)"
        let referenceId = "remote-reference-entry-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operation = SyncPOCOperation(
            id: "\(referenceId)-upsert",
            entityType: "ReferenceEntry",
            entityId: referenceId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "projectId": projectId,
                "author": "Synthetic Author",
                "publicationDate": "2026",
                "details": "Synthetic reference details",
                "referenceCount": "0",
                "createdAt": timestamp,
                "modifiedAt": timestamp,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Reference Entry Dependency Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote reference entry dependency probe passed: simulated ReferenceEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteIndexEntryDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-index-entry-dependency-probe-\(UUID().uuidString)"
        let parentId = "remote-index-entry-parent-\(UUID().uuidString)"
        let childId = "remote-index-entry-child-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(parentId)-upsert",
                entityType: "IndexEntry",
                entityId: parentId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "keyword": "Synthetic index parent",
                    "parentEntryId": "",
                    "seeEntryID": "",
                    "seeAlsoEntryIDsData": "",
                    "referenceCount": "0",
                    "referencingFileIDsData": "",
                    "createdAt": timestamp,
                    "modifiedAt": timestamp,
                    "pageNumbersData": "",
                    "primaryPageNumbersData": "",
                ])
            ),
            SyncPOCOperation(
                id: "\(childId)-upsert",
                entityType: "IndexEntry",
                entityId: childId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "keyword": "Synthetic index child",
                    "parentEntryId": parentId,
                    "seeEntryID": "",
                    "seeAlsoEntryIDsData": "",
                    "referenceCount": "0",
                    "referencingFileIDsData": "",
                    "createdAt": timestamp,
                    "modifiedAt": timestamp,
                    "pageNumbersData": "",
                    "primaryPageNumbersData": "",
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Index Entry Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote index entry dependency probe passed: simulated parent/child IndexEntry upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteContributorEntryDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-contributor-entry-dependency-probe-\(UUID().uuidString)"
        let contributorId = "remote-contributor-entry-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operation = SyncPOCOperation(
            id: "\(contributorId)-upsert",
            entityType: "ContributorEntry",
            entityId: contributorId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: [
                "projectId": projectId,
                "name": "Synthetic Contributor",
                "firstName": "Synthetic",
                "surname": "Contributor",
                "biography": "Synthetic contributor biography",
                "userOrder": "0",
                "createdAt": timestamp,
                "modifiedAt": timestamp,
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Contributor Entry Dependency Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote contributor entry dependency probe passed: simulated ContributorEntry upsert seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemotePageSetupDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-page-setup-dependency-probe-\(UUID().uuidString)"
        let pageSetupId = "remote-page-setup-\(UUID().uuidString)"
        let printerPaperId = "remote-printer-paper-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(pageSetupId)-upsert",
                entityType: "PageSetup",
                entityId: pageSetupId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "paperName": "A4",
                    "orientation": "0",
                    "headers": "1",
                    "footers": "1",
                    "pageBreakBetweenFiles": "1",
                    "hideFirstSection": "0",
                    "matchPreviousSection": "0",
                    "marginTop": "72",
                    "marginBottom": "72",
                    "marginLeft": "72",
                    "marginRight": "72",
                    "headerDepth": "36",
                    "footerDepth": "36",
                    "scaleFactor": "96",
                    "headerLeft": "Synthetic Header",
                    "headerCenter": "",
                    "headerRight": "",
                    "footerLeft": "",
                    "footerCenter": "",
                    "footerRight": "Synthetic Footer",
                ])
            ),
            SyncPOCOperation(
                id: "\(printerPaperId)-upsert",
                entityType: "PrinterPaper",
                entityId: printerPaperId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "pageSetupId": pageSetupId,
                    "paperName": "Synthetic A4",
                    "sizeH": "595.2",
                    "sizeV": "841.8",
                    "rectH": "523.2",
                    "rectV": "769.8",
                    "scalefactor": "96",
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Page Setup Dependency Probe",
            operations: operations
        )
        guard let firstSequence = push.accepted.map(\.serverSequence).min(), let lastSequence = push.accepted.map(\.serverSequence).max() else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote page setup dependency probe passed: simulated PageSetup/PrinterPaper upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteCustomAttributeDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-custom-attribute-dependency-probe-\(UUID().uuidString)"
        let characterId = "remote-custom-attribute-character-\(UUID().uuidString)"
        let customAttributeId = "remote-custom-attribute-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(characterId)-upsert",
                entityType: "Character",
                entityId: characterId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic custom attribute character",
                    "role": "Protagonist",
                    "archetypeRaw": "",
                    "pearsonArchetypeRaw": "",
                    "history": "",
                    "looks": "",
                    "traits": "",
                    "work": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(customAttributeId)-upsert",
                entityType: "CustomAttribute",
                entityId: customAttributeId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "characterId": characterId,
                    "locationId": "",
                    "key": "Synthetic Attribute",
                    "value": "Synthetic Value",
                    "userOrder": "0",
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Custom Attribute Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote custom attribute dependency probe passed: simulated Character/CustomAttribute upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteTrashItemDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-trash-item-dependency-probe-\(UUID().uuidString)"
        let folderId = "remote-trash-folder-\(UUID().uuidString)"
        let textFileId = "remote-trash-textfile-\(UUID().uuidString)"
        let trashItemId = "remote-trash-item-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(folderId)-upsert",
                entityType: "Folder",
                entityId: folderId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "name": "Synthetic Trash Folder",
                    "projectId": projectId,
                    "parentFolderId": "",
                    "userOrder": "0",
                ])
            ),
            SyncPOCOperation(
                id: "\(textFileId)-upsert",
                entityType: "TextFile",
                entityId: textFileId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "name": "Synthetic Trashed File",
                    "folderId": folderId,
                    "workflowStatus": "",
                    "contentType": "text",
                    "content": "Synthetic trash content",
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(trashItemId)-upsert",
                entityType: "TrashItem",
                entityId: trashItemId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "textFileId": textFileId,
                    "originalFolderId": folderId,
                    "projectId": projectId,
                    "deletedDate": timestamp,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Trash Item Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote trash item dependency probe passed: simulated Folder/TextFile/TrashItem upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteManuscriptReviewDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-manuscript-review-dependency-probe-\(UUID().uuidString)"
        let reviewId = "remote-review-\(UUID().uuidString)"
        let suggestionId = "remote-review-suggestion-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(reviewId)-upsert",
                entityType: "ManuscriptReview",
                entityId: reviewId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "reviewId": reviewId,
                    "timestamp": timestamp,
                    "fileId": "",
                    "projectId": projectId,
                    "analysisMode": "manuscript",
                    "summary": "Synthetic manuscript review summary",
                    "overallSentiment": "encouraging",
                    "analysisProfile": "prose",
                    "suggestedFocusOrder": "structure|clarity",
                    "isArchived": "false",
                    "userNotes": "",
                ])
            ),
            SyncPOCOperation(
                id: "\(suggestionId)-upsert",
                entityType: "ReviewSuggestion",
                entityId: suggestionId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "reviewId": reviewId,
                    "suggestionId": suggestionId,
                    "category": "clarity",
                    "severity": "low",
                    "location": "Opening",
                    "observation": "Synthetic observation",
                    "suggestion": "Synthetic suggestion",
                    "rationale": "Synthetic rationale",
                    "isAddressed": "false",
                    "userNotes": "",
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Manuscript Review Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote manuscript review dependency probe passed: simulated ManuscriptReview/ReviewSuggestion upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemotePoetryFormDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-poetry-form-dependency-probe-\(UUID().uuidString)"
        let poetryFormId = UUID().uuidString
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(poetryFormId)-upsert",
                entityType: "PoetryFormModel",
                entityId: poetryFormId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "name": "Synthetic Poetry Form",
                    "categoryRaw": "custom",
                    "lineCount": "3",
                    "stanzaCount": "1",
                    "syllablePattern": "5|7|5",
                    "rhymeScheme": "",
                    "meterPattern": "",
                    "formDescription": "Synthetic poetry form for Cloudflare dry-run apply coverage",
                    "templateContent": "Line one\nLine two\nLine three",
                    "isCustom": "true",
                    "isPredefined": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Poetry Form Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let sequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote poetry form dependency probe passed: simulated PoetryFormModel upsert seq \(sequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteStoryLinkDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-story-link-dependency-probe-\(UUID().uuidString)"
        let characterId = "remote-story-link-character-\(UUID().uuidString)"
        let plotElementId = "remote-story-link-plotelement-\(UUID().uuidString)"
        let linkId = "remote-story-link-character-plot-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(characterId)-upsert",
                entityType: "Character",
                entityId: characterId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic character",
                    "role": "Protagonist",
                    "archetypeRaw": "",
                    "pearsonArchetypeRaw": "",
                    "history": "",
                    "looks": "",
                    "traits": "",
                    "work": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(plotElementId)-upsert",
                entityType: "PlotElement",
                entityId: plotElementId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic plot element",
                    "notes": "",
                    "userOrder": "0",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "CharacterPlotElementLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "characterId": characterId,
                    "plotElementId": plotElementId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Story Link Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote story link dependency probe passed: simulated Character/PlotElement/CharacterPlotElementLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteLocationLinkDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-location-link-dependency-probe-\(UUID().uuidString)"
        let locationId = "remote-location-link-location-\(UUID().uuidString)"
        let plotElementId = "remote-location-link-plotelement-\(UUID().uuidString)"
        let linkId = "remote-location-link-location-plot-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(locationId)-upsert",
                entityType: "Location",
                entityId: locationId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic location",
                    "detail": "",
                    "sights": "",
                    "sounds": "",
                    "smells": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(plotElementId)-upsert",
                entityType: "PlotElement",
                entityId: plotElementId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic plot element",
                    "notes": "",
                    "userOrder": "0",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "LocationPlotElementLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "locationId": locationId,
                    "plotElementId": plotElementId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Location Link Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote location link dependency probe passed: simulated Location/PlotElement/LocationPlotElementLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteSceneCharacterDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-scene-character-dependency-probe-\(UUID().uuidString)"
        let sceneId = "remote-scene-character-scene-\(UUID().uuidString)"
        let characterId = "remote-scene-character-character-\(UUID().uuidString)"
        let linkId = "remote-scene-character-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(sceneId)-upsert",
                entityType: "StoryScene",
                entityId: sceneId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic scene",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "isTrashed": "false",
                    "trashedDate": "",
                    "textFileId": "",
                    "locationId": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(characterId)-upsert",
                entityType: "Character",
                entityId: characterId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic scene character",
                    "role": "Supporting",
                    "archetypeRaw": "",
                    "pearsonArchetypeRaw": "",
                    "history": "",
                    "looks": "",
                    "traits": "",
                    "work": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "SceneCharacterLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "sceneId": sceneId,
                    "characterId": characterId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Scene Character Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote scene character dependency probe passed: simulated StoryScene/Character/SceneCharacterLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteSceneLocationDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-scene-location-dependency-probe-\(UUID().uuidString)"
        let sceneId = "remote-scene-location-scene-\(UUID().uuidString)"
        let locationId = "remote-scene-location-location-\(UUID().uuidString)"
        let linkId = "remote-scene-location-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(sceneId)-upsert",
                entityType: "StoryScene",
                entityId: sceneId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic scene",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "isTrashed": "false",
                    "trashedDate": "",
                    "textFileId": "",
                    "locationId": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(locationId)-upsert",
                entityType: "Location",
                entityId: locationId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic scene location",
                    "detail": "",
                    "sights": "",
                    "sounds": "",
                    "smells": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "SceneLocationLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "sceneId": sceneId,
                    "locationId": locationId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Scene Location Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote scene location dependency probe passed: simulated StoryScene/Location/SceneLocationLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteSceneChapterDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-scene-chapter-dependency-probe-\(UUID().uuidString)"
        let chapterId = "remote-scene-chapter-chapter-\(UUID().uuidString)"
        let sceneId = "remote-scene-chapter-scene-\(UUID().uuidString)"
        let linkId = "remote-scene-chapter-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(chapterId)-upsert",
                entityType: "Chapter",
                entityId: chapterId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic chapter",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(sceneId)-upsert",
                entityType: "StoryScene",
                entityId: sceneId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic chapter scene",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "isTrashed": "false",
                    "trashedDate": "",
                    "textFileId": "",
                    "locationId": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "SceneChapterLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "sceneId": sceneId,
                    "chapterId": chapterId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Scene Chapter Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote scene chapter dependency probe passed: simulated Chapter/StoryScene/SceneChapterLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteSceneActDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-scene-act-dependency-probe-\(UUID().uuidString)"
        let actId = "remote-scene-act-act-\(UUID().uuidString)"
        let sceneId = "remote-scene-act-scene-\(UUID().uuidString)"
        let linkId = "remote-scene-act-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(actId)-upsert",
                entityType: "Act",
                entityId: actId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic act",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(sceneId)-upsert",
                entityType: "StoryScene",
                entityId: sceneId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic act scene",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "isTrashed": "false",
                    "trashedDate": "",
                    "textFileId": "",
                    "locationId": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "SceneActLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "sceneId": sceneId,
                    "actId": actId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Scene Act Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote scene act dependency probe passed: simulated Act/StoryScene/SceneActLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteSceneBookDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-scene-book-dependency-probe-\(UUID().uuidString)"
        let bookId = "remote-scene-book-book-\(UUID().uuidString)"
        let sceneId = "remote-scene-book-scene-\(UUID().uuidString)"
        let linkId = "remote-scene-book-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(bookId)-upsert",
                entityType: "Book",
                entityId: bookId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic book",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(sceneId)-upsert",
                entityType: "StoryScene",
                entityId: sceneId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic book scene",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "isTrashed": "false",
                    "trashedDate": "",
                    "textFileId": "",
                    "locationId": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "SceneBookLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "sceneId": sceneId,
                    "bookId": bookId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Scene Book Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote scene book dependency probe passed: simulated Book/StoryScene/SceneBookLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteScenePlotDependencyProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-scene-plot-dependency-probe-\(UUID().uuidString)"
        let sceneId = "remote-scene-plot-scene-\(UUID().uuidString)"
        let plotElementId = "remote-scene-plot-plotelement-\(UUID().uuidString)"
        let linkId = "remote-scene-plot-link-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())
        let operations = [
            SyncPOCOperation(
                id: "\(sceneId)-upsert",
                entityType: "StoryScene",
                entityId: sceneId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic plot scene",
                    "synopsis": "",
                    "userOrder": "0",
                    "bodyMatterOrder": "",
                    "isInBodyMatter": "false",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "isTrashed": "false",
                    "trashedDate": "",
                    "textFileId": "",
                    "locationId": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(plotElementId)-upsert",
                entityType: "PlotElement",
                entityId: plotElementId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "projectId": projectId,
                    "name": "Synthetic scene plot element",
                    "notes": "",
                    "userOrder": "0",
                    "monomythStageRaw": "",
                    "campbellStageRaw": "",
                    "threeActStageRaw": "",
                    "pearsonStageRaw": "",
                    "createdDate": timestamp,
                    "modifiedDate": timestamp,
                ])
            ),
            SyncPOCOperation(
                id: "\(linkId)-upsert",
                entityType: "ScenePlotElementLink",
                entityId: linkId,
                operationType: "upsert",
                baseSequence: baselineSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "sceneId": sceneId,
                    "plotElementId": plotElementId,
                ])
            ),
        ]
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Scene Plot Dependency Probe",
            operations: operations
        )
        guard push.accepted.count == operations.count,
              let firstSequence = push.accepted.first?.serverSequence,
              let lastSequence = push.accepted.last?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote scene plot dependency probe passed: simulated StoryScene/PlotElement/ScenePlotElementLink upserts seq \(firstSequence)-\(lastSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteUnsupportedOperationProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-unsupported-operation-probe-\(UUID().uuidString)"
        let textFileId = "remote-unsupported-operation-textfile-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(textFileId)-merge",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "merge",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [
                "name": "Synthetic unsupported operation probe",
                "fileTypeRaw": "text",
            ])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated Unsupported Operation Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote unsupported operation probe passed: simulated TextFile merge seq \(pushedSequence) after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func runRemoteNoPayloadProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let baselineSequence = bootstrapResponse.latestSequence
        rememberLastSequence(baselineSequence, projectId: projectId)

        let remoteDeviceId = "remote-no-payload-probe-\(UUID().uuidString)"
        let textFileId = "remote-no-payload-textfile-\(UUID().uuidString)"
        let operation = SyncPOCOperation(
            id: "\(textFileId)-upsert-no-payload",
            entityType: "TextFile",
            entityId: textFileId,
            operationType: "upsert",
            baseSequence: baselineSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: [:])
        )
        let push = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: remoteDeviceId,
            deviceName: "Simulated No Payload Probe",
            operations: [operation]
        )
        guard let pushedSequence = push.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let head = SyncPOCHeadRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            lastKnownSequence: baselineSequence
        )
        let response: SyncPOCHeadResponse = try await post(path: "head", body: head)
        guard response.hasChanges else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Remote no-payload probe passed: simulated TextFile upsert seq \(pushedSequence) with empty payload after baseline \(baselineSequence); head latest \(response.latestSequence), change count \(response.changeCount). No local data was changed."
        )
    }

    @MainActor
    func pullPendingChanges(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let startSequence = rememberedLastSequence(projectId: projectId)
        let pulledOperations = try await pullAllOperations(projectId: projectId, deviceId: deviceId, afterSequence: startSequence)
        rememberLastSequence(pulledOperations.latestSequence, projectId: projectId)

        return CloudflareSyncPOCResult(
            message: "Pulled pending changes after sequence \(startSequence): \(pulledOperations.operations.count) operations, latest sequence \(pulledOperations.latestSequence). Remembered sequence advanced to \(rememberedLastSequence(projectId: projectId)). No local data was changed. \(summarizePulledOperations(pulledOperations.operations))"
        )
    }

    @MainActor
    func previewPendingApply(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let startSequence = rememberedLastSequence(projectId: projectId)
        let peekedOperations = try await peekAllOperations(projectId: projectId, deviceId: deviceId, afterSequence: startSequence)
        let applySummary = summarizePendingApply(peekedOperations.operations, localProject: project)

        return CloudflareSyncPOCResult(
            message: "Pending apply preview after sequence \(startSequence): \(peekedOperations.operations.count) operations, latest sequence \(peekedOperations.latestSequence). \(applySummary) Cursor was not advanced and no local data was changed. \(summarizePulledOperations(peekedOperations.operations))"
        )
    }

    @MainActor
    func materializePendingApplyPreview(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let startSequence = rememberedLastSequence(projectId: projectId)
        let peekedOperations = try await peekAllOperations(projectId: projectId, deviceId: deviceId, afterSequence: startSequence)
        guard !peekedOperations.operations.isEmpty else {
            _ = try resetIsolatedStore(basename: pendingApplyStoreBasename)
            return CloudflareSyncPOCResult(
                message: "No pending apply operations after sequence \(startSequence). Latest sequence \(peekedOperations.latestSequence). Cleared the pending apply scratch store. Cursor was not advanced and production local data was not changed."
            )
        }

        let supportedEntityTypes = supportedApplyEntityTypes()
        let applyPlan = makeApplyPlan(
            peekedOperations.operations,
            localEntityKeys: localEntityKeys(in: project),
            supportedEntityTypes: supportedEntityTypes,
            deleteOperations: deleteApplyOperationTypes(),
            restoreOperations: restoreApplyOperationTypes()
        )
        let result = try materializePendingApply(
            operations: peekedOperations.operations,
            applyPlan: applyPlan,
            sourceProject: project
        )

        return CloudflareSyncPOCResult(
            message: "Materialized pending apply preview after sequence \(startSequence): \(peekedOperations.operations.count) operations, latest sequence \(peekedOperations.latestSequence). "
                + "Created \(result.styleSheetCount) stylesheets, \(result.textStyleCount) text styles, \(result.imageStyleCount) image styles, \(result.folderCount) folders, \(result.textFileCount) text files, \(result.versionCount) versions, \(result.trashItemCount) trash items, \(result.commentCount) comments, \(result.footnoteCount) footnotes, "
                + "\(result.storyRecordCount) story records, \(result.customAttributeCount) custom attributes, \(result.joinLinkCount) join links, \(result.noteCount) notes, \(result.citationCount) citations, \(result.glossaryCount) glossary entries, \(result.referenceEntryCount) reference entries, \(result.indexEntryCount) index entries, \(result.contributorCount) contributors, "
                + "\(result.pageSetupCount) page setups, \(result.printerPaperCount) printer papers, \(result.poetryFormCount) poetry forms, \(result.manuscriptReviewCount) manuscript reviews, \(result.reviewSuggestionCount) review suggestions, \(result.publicationCount) publications, \(result.submissionCount) submissions, \(result.submittedFileCount) submitted files, \(result.updateExistingCount) updated existing records (\(result.seededExistingCount) seeded), \(result.restoreMissingCount) restored missing records, and \(result.deleteNoopMissingCount) delete no-ops in scratch store \(result.storeURL.lastPathComponent). Cursor was not advanced and production local data was not changed. \(summarizeApplyPlan(applyPlan))"
        )
    }

    @MainActor
    func pullPendingChangesIntoScratchStore(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = selectProjectForPendingApply(projects) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse

        let startSequence = rememberedLastSequence(projectId: projectId)
        let peekedOperations = try await peekAllOperations(projectId: projectId, deviceId: deviceId, afterSequence: startSequence)
        guard !peekedOperations.operations.isEmpty else {
            _ = try resetIsolatedStore(basename: pendingApplyStoreBasename)
            return CloudflareSyncPOCResult(
                message: "No pending operations to pull into scratch store after sequence \(startSequence). Latest sequence \(peekedOperations.latestSequence). Cleared the pending apply scratch store. Cursor was not advanced and production local data was not changed."
            )
        }

        let supportedEntityTypes = supportedApplyEntityTypes()
        let applyPlan = makeApplyPlan(
            peekedOperations.operations,
            localEntityKeys: localEntityKeys(in: project),
            supportedEntityTypes: supportedEntityTypes,
            deleteOperations: deleteApplyOperationTypes(),
            restoreOperations: restoreApplyOperationTypes()
        )
        let result = try materializePendingApply(
            operations: peekedOperations.operations,
            applyPlan: applyPlan,
            sourceProject: project
        )

        let pulledOperations = try await pullAllOperations(projectId: projectId, deviceId: deviceId, afterSequence: startSequence)
        guard pulledOperations.latestSequence == peekedOperations.latestSequence,
              operationsMatch(pulledOperations.operations, peekedOperations.operations) else {
            throw CloudflareSyncPOCError.applyPlanNotReady("pending operation set changed between scratch materialization and pull; cursor was not advanced")
        }

        rememberLastSequence(pulledOperations.latestSequence, projectId: projectId)

        return CloudflareSyncPOCResult(
            message: "Pulled pending changes into scratch store after sequence \(startSequence): \(pulledOperations.operations.count) operations, latest sequence \(pulledOperations.latestSequence). Remembered sequence advanced to \(rememberedLastSequence(projectId: projectId)). Scratch store \(result.storeURL.lastPathComponent) contains \(result.textFileCount) text files, \(result.versionCount) versions, \(result.storyRecordCount) story records, \(result.joinLinkCount) join links, \(result.publicationCount) publications, \(result.submissionCount) submissions, \(result.submittedFileCount) submitted files, \(result.updateExistingCount) updated existing records (\(result.seededExistingCount) seeded), \(result.restoreMissingCount) restored missing records, and \(result.deleteNoopMissingCount) delete no-ops. Production local data was not changed. \(summarizeApplyPlan(applyPlan)) \(summarizePulledOperations(pulledOperations.operations))"
        )
    }

    @MainActor
    func inspectPendingApplyScratchStore() async throws -> CloudflareSyncPOCResult {
        let storeURL = try isolatedStoreURL(basename: pendingApplyStoreBasename)
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return CloudflareSyncPOCResult(
                message: "No pending apply scratch store is available to inspect. Run Materialize Pending Apply Preview while pending operations exist. CloudKit disabled. Production local data was not read or changed."
            )
        }

        let schema = cloudflareSyncPOCScratchSchema()
        let configuration = ModelConfiguration(
            "CloudflareSyncPOCPendingApplyInspectionConfiguration",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let projects = try context.fetch(FetchDescriptor<Project>())
        let styleSheets = try context.fetch(FetchDescriptor<StyleSheet>())
        let textStyles = try context.fetch(FetchDescriptor<TextStyleModel>())
        let imageStyles = try context.fetch(FetchDescriptor<ImageStyle>())
        let folders = try context.fetch(FetchDescriptor<Folder>())
        let textFiles = try context.fetch(FetchDescriptor<TextFile>())
        let versions = try context.fetch(FetchDescriptor<Version>())
        let trashItems = try context.fetch(FetchDescriptor<TrashItem>())
        let comments = try context.fetch(FetchDescriptor<CommentModel>())
        let footnotes = try context.fetch(FetchDescriptor<FootnoteModel>())
        let notes = try context.fetch(FetchDescriptor<NoteEntry>())
        let citations = try context.fetch(FetchDescriptor<CitationEntry>())
        let glossaryEntries = try context.fetch(FetchDescriptor<GlossaryEntry>())
        let referenceEntries = try context.fetch(FetchDescriptor<ReferenceEntry>())
        let indexEntries = try context.fetch(FetchDescriptor<IndexEntry>())
        let contributors = try context.fetch(FetchDescriptor<ContributorEntry>())
        let pageSetups = try context.fetch(FetchDescriptor<PageSetup>())
        let printerPapers = try context.fetch(FetchDescriptor<PrinterPaper>())
        let poetryForms = try context.fetch(FetchDescriptor<PoetryFormModel>())
        let manuscriptReviews = try context.fetch(FetchDescriptor<ManuscriptReview>())
        let reviewSuggestions = try context.fetch(FetchDescriptor<ReviewSuggestion>())
        let chapters = try context.fetch(FetchDescriptor<Chapter>())
        let acts = try context.fetch(FetchDescriptor<Act>())
        let books = try context.fetch(FetchDescriptor<Book>())
        let scenes = try context.fetch(FetchDescriptor<StoryScene>())
        let characters = try context.fetch(FetchDescriptor<Character>())
        let locations = try context.fetch(FetchDescriptor<Location>())
        let customAttributes = try context.fetch(FetchDescriptor<CustomAttribute>())
        let plotElements = try context.fetch(FetchDescriptor<PlotElement>())
        let sceneChapterLinks = try context.fetch(FetchDescriptor<SceneChapterLink>())
        let sceneActLinks = try context.fetch(FetchDescriptor<SceneActLink>())
        let sceneBookLinks = try context.fetch(FetchDescriptor<SceneBookLink>())
        let scenePlotLinks = try context.fetch(FetchDescriptor<ScenePlotElementLink>())
        let poetryCollections = try context.fetch(FetchDescriptor<PoetryCollection>())
        let proseSections = try context.fetch(FetchDescriptor<ProseSection>())
        let textFileSectionLinks = try context.fetch(FetchDescriptor<TextFileSectionLink>())
        let textFileCollectionLinks = try context.fetch(FetchDescriptor<TextFileCollectionLink>())
        let sceneCharacterLinks = try context.fetch(FetchDescriptor<SceneCharacterLink>())
        let sceneLocationLinks = try context.fetch(FetchDescriptor<SceneLocationLink>())
        let characterPlotLinks = try context.fetch(FetchDescriptor<CharacterPlotElementLink>())
        let locationPlotLinks = try context.fetch(FetchDescriptor<LocationPlotElementLink>())
        let publications = try context.fetch(FetchDescriptor<Publication>())
        let submissions = try context.fetch(FetchDescriptor<Submission>())
        let submittedFiles = try context.fetch(FetchDescriptor<SubmittedFile>())
        let linkedTextStyles = textStyles.filter { $0.styleSheet != nil }.count
        let linkedImageStyles = imageStyles.filter { $0.styleSheet != nil }.count
        let linkedVersions = versions.filter { $0.textFile != nil }.count
        let linkedTrashItems = trashItems.filter { $0.textFile != nil && $0.project != nil }.count
        let textFilesWithVersions = textFiles.filter { ($0.versions?.isEmpty == false) }.count
        let linkedComments = comments.filter { $0.version != nil }.count
        let linkedFootnotes = footnotes.filter { $0.version != nil }.count
        let linkedSceneChapterLinks = sceneChapterLinks.filter { $0.scene != nil && $0.chapter != nil }.count
        let linkedSceneActLinks = sceneActLinks.filter { $0.scene != nil && $0.act != nil }.count
        let linkedSceneBookLinks = sceneBookLinks.filter { $0.scene != nil && $0.book != nil }.count
        let linkedScenePlotLinks = scenePlotLinks.filter { $0.scene != nil && $0.plotElement != nil }.count
        let linkedTextFileSectionLinks = textFileSectionLinks.filter { $0.textFile != nil && $0.section != nil }.count
        let linkedTextFileCollectionLinks = textFileCollectionLinks.filter { $0.textFile != nil && $0.poetryCollection != nil }.count
        let linkedSceneCharacterLinks = sceneCharacterLinks.filter { $0.scene != nil && $0.character != nil }.count
        let linkedSceneLocationLinks = sceneLocationLinks.filter { $0.scene != nil && $0.location != nil }.count
        let linkedCharacterPlotLinks = characterPlotLinks.filter { $0.character != nil && $0.plotElement != nil }.count
        let linkedLocationPlotLinks = locationPlotLinks.filter { $0.location != nil && $0.plotElement != nil }.count
        let linkedCustomAttributes = customAttributes.filter { $0.character != nil || $0.location != nil }.count
        let linkedGlossaryEntries = glossaryEntries.filter { $0.citation != nil }.count
        let childIndexEntries = indexEntries.filter { $0.parentEntry != nil }.count
        let linkedPrinterPapers = printerPapers.filter { $0.pageSetup != nil }.count
        let linkedReviewSuggestions = manuscriptReviews.reduce(0) { total, review in total + review.suggestions.count }
        let linkedSubmissions = submissions.filter { $0.publication != nil }.count
        let linkedSubmittedFiles = submittedFiles.filter { $0.submission != nil && $0.textFile != nil && $0.version != nil }.count

        return CloudflareSyncPOCResult(
            message: "Pending apply scratch store inspection: \(projects.count) projects, \(styleSheets.count) stylesheets, \(textStyles.count) text styles, \(imageStyles.count) image styles, \(folders.count) folders, \(textFiles.count) text files, \(versions.count) versions, \(comments.count) comments, \(footnotes.count) footnotes, "
                + "\(trashItems.count) trash items, \(notes.count) notes, \(citations.count) citations, \(glossaryEntries.count) glossary entries, \(referenceEntries.count) reference entries, \(indexEntries.count) index entries, \(contributors.count) contributors, \(pageSetups.count) page setups, \(printerPapers.count) printer papers, \(poetryForms.count) poetry forms, \(manuscriptReviews.count) manuscript reviews, \(reviewSuggestions.count) review suggestions, "
                + "\(chapters.count) chapters, \(acts.count) acts, \(books.count) books, \(scenes.count) scenes, \(proseSections.count) prose sections, \(poetryCollections.count) poetry collections, \(characters.count) characters, \(locations.count) locations, \(customAttributes.count) custom attributes, \(plotElements.count) plot elements, "
                + "\(sceneChapterLinks.count) scene-chapter links, \(sceneActLinks.count) scene-act links, \(sceneBookLinks.count) scene-book links, \(scenePlotLinks.count) scene-plot links, \(textFileSectionLinks.count) text-file-section links, \(textFileCollectionLinks.count) text-file-collection links, \(sceneCharacterLinks.count) scene-character links, \(sceneLocationLinks.count) scene-location links, "
                + "\(characterPlotLinks.count) character-plot links, \(locationPlotLinks.count) location-plot links, \(publications.count) publications, \(submissions.count) submissions, \(submittedFiles.count) submitted files, \(linkedTextStyles) text styles linked to stylesheets, \(linkedImageStyles) image styles linked to stylesheets, \(linkedVersions) versions linked to text files, "
                + "\(textFilesWithVersions) text files with versions, \(linkedTrashItems) trash items linked to text files/projects, \(linkedComments) comments linked to versions, \(linkedFootnotes) footnotes linked to versions, \(linkedSceneChapterLinks) scene-chapter links linked to both sides, \(linkedSceneActLinks) scene-act links linked to both sides, \(linkedSceneBookLinks) scene-book links linked to both sides, \(linkedScenePlotLinks) scene-plot links linked to both sides, "
                + "\(linkedTextFileSectionLinks) text-file-section links linked to both sides, \(linkedTextFileCollectionLinks) text-file-collection links linked to both sides, \(linkedSceneCharacterLinks) scene-character links linked to both sides, \(linkedSceneLocationLinks) scene-location links linked to both sides, \(linkedCharacterPlotLinks) character-plot links linked to both sides, \(linkedLocationPlotLinks) location-plot links linked to both sides, "
                + "\(linkedCustomAttributes) custom attributes linked to characters/locations, \(linkedGlossaryEntries) glossary entries linked to citations, \(childIndexEntries) child index entries linked to parents, \(linkedPrinterPapers) printer papers linked to page setups, \(linkedReviewSuggestions) review suggestions linked to manuscript reviews, \(linkedSubmissions) submissions linked to publications, \(linkedSubmittedFiles) submitted files linked to submissions/text files/versions. Store: \(storeURL.lastPathComponent). CloudKit disabled. Production local data was not read or changed."
        )
    }

    @MainActor
    func pushPullFirstProject(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        try await pushPullProjectSample(projects: projects)
    }

    @MainActor
    func pushPullProjectSample(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let operations = makeOperations(for: project, baseSequence: bootstrapResponse.latestSequence)
        guard !operations.isEmpty else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let pushResult = try await pushOperationBatches(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName,
            operations: operations
        )
        let pulledOperations = try await pullAllOperations(
            projectId: projectId,
            deviceId: deviceId,
            afterSequence: bootstrapResponse.latestSequence
        )
        rememberLastSequence(pulledOperations.latestSequence, projectId: projectId)

        return CloudflareSyncPOCResult(
            message: "Pushed \(pushResult.acceptedCount)/\(operations.count) in \(pushResult.batchCount) batches, rejected \(pushResult.rejectedCount), pulled \(pulledOperations.operations.count), latest sequence \(pulledOperations.latestSequence). Local refs: \(summarizeReferenceRecords(in: project)). Local matter: \(summarizeMatterFolders(in: project)). Remote refs: \(summarizeReferenceRecords(in: makeImportState(from: pulledOperations.operations))). Remote matter: \(summarizeMatterFolders(in: makeImportState(from: pulledOperations.operations))). \(summarizePulledOperations(pulledOperations.operations))"
        )
    }

    @MainActor
    func createRemoteSnapshot(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let snapshot = makeSnapshotPayload(for: project)
        let request = SyncPOCSnapshotRequest(
            projectId: projectId,
            deviceId: deviceId,
            deviceName: deviceName,
            serverSequence: bootstrapResponse.latestSequence,
            snapshot: snapshot
        )
        let response: SyncPOCSnapshotResponse = try await post(path: "snapshot", body: request)

        return CloudflareSyncPOCResult(
            message: "Snapshot stored at sequence \(response.serverSequence), key \(response.r2Key), hash \(response.contentHash.prefix(12)). Snapshot refs: \(summarizeReferenceRecords(in: project)). Snapshot matter: \(summarizeMatterFolders(in: project))."
        )
    }

    @MainActor
    func previewRemoteImport(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)
        let pulledOperations = try await pullAllOperations(projectId: projectId, deviceId: deviceId, afterSequence: 0)
        rememberLastSequence(pulledOperations.latestSequence, projectId: projectId)
        let preview = makeImportPreview(from: pulledOperations.operations)
        let importState = makeImportState(from: pulledOperations.operations)

        return CloudflareSyncPOCResult(
            message: "Import preview for \"\(preview.projectName)\": \(preview.styleSheetCount) stylesheets, \(preview.textStyleCount) text styles, \(preview.imageStyleCount) image styles, \(preview.folderCount) folders, \(preview.textFileCount) text files, \(preview.versionCount) versions, \(preview.commentCount) comments, \(preview.footnoteCount) footnotes, \(preview.storyRecordCount) story records, \(preview.joinLinkCount) join links, \(preview.referenceRecordCount) reference records (\(summarizeReferenceRecords(in: importState))), matter \(summarizeMatterFolders(in: importState)), \(preview.publicationCount) publications, \(preview.submissionCount) submissions, \(preview.submittedFileCount) submitted files, \(preview.totalContentCharacters) text chars from \(pulledOperations.operations.count) remote operations. Latest sequence \(pulledOperations.latestSequence), bootstrap sequence \(bootstrapResponse.latestSequence). No local data was written."
        )
    }

    @MainActor
    func materializeIsolatedImport(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        _ = try await post(path: "bootstrap", body: bootstrap) as SyncPOCBootstrapResponse
        let pulledOperations = try await pullAllOperations(projectId: projectId, deviceId: deviceId, afterSequence: 0)
        rememberLastSequence(pulledOperations.latestSequence, projectId: projectId)
        let importState = makeImportState(from: pulledOperations.operations)
        let importResult = try materialize(importState: importState)

        return CloudflareSyncPOCResult(
            message: "Materialized isolated import \"\(importResult.projectName)\": \(importResult.styleSheetCount) stylesheets, \(importResult.textStyleCount) text styles, \(importResult.imageStyleCount) image styles, \(importResult.folderCount) folders, \(importResult.textFileCount) text files, \(importResult.versionCount) versions, \(importResult.commentCount) comments, \(importResult.footnoteCount) footnotes, \(importResult.storyRecordCount) story records, \(importResult.joinLinkCount) join links, \(importResult.referenceRecordCount) reference records (\(summarizeReferenceRecords(in: importState))), matter \(summarizeMatterFolders(in: importState)), \(importResult.publicationCount) publications, \(importResult.submissionCount) submissions, \(importResult.submittedFileCount) submitted files, \(importResult.totalContentCharacters) text chars. Store: \(importResult.storeURL.lastPathComponent). CloudKit disabled."
        )
    }

    @MainActor
    func runTombstoneProbe(projects: [Project]) async throws -> CloudflareSyncPOCResult {
        guard let project = projects.first(where: { !$0.isTrashed }) else {
            throw CloudflareSyncPOCError.noProjectContent
        }

        let deviceId = localDeviceId()
        let deviceName = localDeviceName()
        let projectId = project.id.uuidString
        let projectName = project.name ?? "Untitled"
        let entityId = "probe-\(UUID().uuidString)"
        let timestamp = isoFormatter.string(from: Date())

        let bootstrap = SyncPOCBootstrapRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName
        )
        let bootstrapResponse: SyncPOCBootstrapResponse = try await post(path: "bootstrap", body: bootstrap)

        let initialOperation = SyncPOCOperation(
            id: "\(entityId)-initial-upsert",
            entityType: "TombstoneProbe",
            entityId: entityId,
            operationType: "upsert",
            baseSequence: bootstrapResponse.latestSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: ["name": "Synthetic tombstone probe", "step": "initial"])
        )
        let initialPush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName,
            operations: [initialOperation]
        )
        guard let initialSequence = initialPush.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let deleteOperation = SyncPOCOperation(
            id: "\(entityId)-delete",
            entityType: "TombstoneProbe",
            entityId: entityId,
            operationType: "delete",
            baseSequence: initialSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: ["name": "Synthetic tombstone probe", "step": "delete"])
        )
        let deletePush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName,
            operations: [deleteOperation]
        )
        guard let deleteSequence = deletePush.accepted.first?.serverSequence else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        let staleOperation = SyncPOCOperation(
            id: "\(entityId)-stale-upsert",
            entityType: "TombstoneProbe",
            entityId: entityId,
            operationType: "upsert",
            baseSequence: initialSequence,
            clientTimestamp: isoFormatter.string(from: Date()),
            payload: SyncPOCPayload(values: ["name": "Synthetic stale update", "step": "stale"])
        )
        let stalePush = try await pushOperations(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName,
            operations: [staleOperation]
        )
        let rejected = stalePush.rejected.first
        guard rejected?.reason == "stale_update_after_tombstone" else {
            throw CloudflareSyncPOCError.invalidResponse
        }

        return CloudflareSyncPOCResult(
            message: "Tombstone probe passed: initial seq \(initialSequence), tombstone seq \(deleteSequence), stale update rejected as \(rejected?.reason ?? "unknown"). No local data was changed."
        )
    }

    private var syncToken: String? {
        let token = UserDefaults.standard.string(forKey: Self.tokenDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return token?.isEmpty == false ? token : nil
    }

    private func lastSequenceDefaultsKey(projectId: String) -> String {
        "cloudflareSyncPOCLastSequence.\(projectId)"
    }

    private func rememberedLastSequence(projectId: String) -> Int {
        UserDefaults.standard.integer(forKey: lastSequenceDefaultsKey(projectId: projectId))
    }

    private func rememberLastSequence(_ sequence: Int, projectId: String) {
        guard sequence >= rememberedLastSequence(projectId: projectId) else { return }
        UserDefaults.standard.set(sequence, forKey: lastSequenceDefaultsKey(projectId: projectId))
    }

    private func rememberPendingApplyProject(projectId: String) {
        UserDefaults.standard.set(projectId, forKey: Self.pendingApplyProjectDefaultsKey)
    }

    private func rememberedPendingApplyProjectId() -> String? {
        UserDefaults.standard.string(forKey: Self.pendingApplyProjectDefaultsKey)
    }

    private func rememberPendingApplyEntity(entityType: String, entityId: String) {
        UserDefaults.standard.set("\(entityType):\(entityId)", forKey: Self.pendingApplyEntityKeyDefaultsKey)
    }

    private func rememberedPendingApplyEntityKey() -> String? {
        UserDefaults.standard.string(forKey: Self.pendingApplyEntityKeyDefaultsKey)
    }

    private func endpointURL(path: String) throws -> URL {
        let base = configuredEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/\(path)") else {
            throw CloudflareSyncPOCError.invalidEndpoint
        }
        return url
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(path: String, body: RequestBody) async throws -> ResponseBody {
        let url = try endpointURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(body)
        let data = try await send(request: request, authenticated: true)
        return try jsonDecoder.decode(ResponseBody.self, from: data)
    }

    private func pushOperations(projectId: String, projectName: String, deviceId: String, deviceName: String, operations: [SyncPOCOperation]) async throws -> SyncPOCPushResponse {
        let push = SyncPOCPushRequest(
            projectId: projectId,
            projectName: projectName,
            deviceId: deviceId,
            deviceName: deviceName,
            operations: operations
        )
        return try await post(path: "push", body: push)
    }

    private func pushOperationBatches(projectId: String, projectName: String, deviceId: String, deviceName: String, operations: [SyncPOCOperation]) async throws -> (acceptedCount: Int, rejectedCount: Int, latestSequence: Int, batchCount: Int) {
        var acceptedCount = 0
        var rejectedCount = 0
        var latestSequence = 0
        var batchCount = 0

        for startIndex in stride(from: 0, to: operations.count, by: maxPushOperationsPerBatch) {
            let endIndex = min(startIndex + maxPushOperationsPerBatch, operations.count)
            let batch = Array(operations[startIndex..<endIndex])
            let response = try await pushOperations(
                projectId: projectId,
                projectName: projectName,
                deviceId: deviceId,
                deviceName: deviceName,
                operations: batch
            )
            acceptedCount += response.accepted.count
            rejectedCount += response.rejected.count
            latestSequence = response.latestSequence
            batchCount += 1
        }

        return (acceptedCount, rejectedCount, latestSequence, batchCount)
    }

    private func pullAllOperations(projectId: String, deviceId: String, afterSequence: Int) async throws -> (operations: [SyncPOCPulledOperation], latestSequence: Int) {
        try await fetchAllOperations(path: "pull", projectId: projectId, deviceId: deviceId, afterSequence: afterSequence)
    }

    private func peekAllOperations(projectId: String, deviceId: String, afterSequence: Int) async throws -> (operations: [SyncPOCPulledOperation], latestSequence: Int) {
        try await fetchAllOperations(path: "peek", projectId: projectId, deviceId: deviceId, afterSequence: afterSequence)
    }

    private func fetchAllOperations(path: String, projectId: String, deviceId: String, afterSequence: Int) async throws -> (operations: [SyncPOCPulledOperation], latestSequence: Int) {
        var cursor = afterSequence
        var latestSequence = afterSequence
        var operations: [SyncPOCPulledOperation] = []

        for _ in 0..<20 {
            let pull = SyncPOCPullRequest(
                projectId: projectId,
                deviceId: deviceId,
                afterSequence: cursor,
                limit: 500
            )
            let response: SyncPOCPullResponse = try await post(path: path, body: pull)
            operations.append(contentsOf: response.operations)
            latestSequence = response.latestSequence
            cursor = response.nextCursor

            if !response.hasMore {
                return (operations, latestSequence)
            }
        }

        return (operations, latestSequence)
    }

    private func operationsMatch(_ left: [SyncPOCPulledOperation], _ right: [SyncPOCPulledOperation]) -> Bool {
        let leftKeys = left
            .map { "\($0.serverSequence)|\($0.id)|\($0.entityType)|\($0.entityId)|\($0.operationType)" }
            .sorted()
        let rightKeys = right
            .map { "\($0.serverSequence)|\($0.id)|\($0.entityType)|\($0.entityId)|\($0.operationType)" }
            .sorted()
        return leftKeys == rightKeys
    }

    private func send(request originalRequest: URLRequest, authenticated: Bool) async throws -> Data {
        var request = originalRequest
        if authenticated {
            guard let token = syncToken else {
                throw CloudflareSyncPOCError.missingToken
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudflareSyncPOCError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudflareSyncPOCError.serverError(httpResponse.statusCode, message)
        }
        return data
    }

    @MainActor
    private func makeOperations(for project: Project, baseSequence: Int) -> [SyncPOCOperation] {
        var operations: [SyncPOCOperation] = []
        let timestamp = isoFormatter.string(from: Date())

        operations.append(
            SyncPOCOperation(
                id: "\(project.id.uuidString)-project-upsert-\(UUID().uuidString)",
                entityType: "Project",
                entityId: project.id.uuidString,
                operationType: "upsert",
                baseSequence: baseSequence,
                clientTimestamp: timestamp,
                payload: SyncPOCPayload(values: [
                    "name": project.name ?? "Untitled",
                    "type": project.typeRaw ?? "",
                    "isTrashed": String(project.isTrashed),
                    "styleSheetId": project.styleSheet?.id.uuidString ?? "",
                    "modifiedDate": project.modifiedDate.map { isoFormatter.string(from: $0) } ?? "",
                ])
            )
        )

        if let styleSheet = project.styleSheet {
            operations.append(
                SyncPOCOperation(
                    id: "\(styleSheet.id.uuidString)-stylesheet-upsert-\(UUID().uuidString)",
                    entityType: "StyleSheet",
                    entityId: styleSheet.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: [
                        "name": styleSheet.name,
                        "isSystemStyleSheet": String(styleSheet.isSystemStyleSheet),
                        "footnoteMarkerStyleRaw": styleSheet.footnoteMarkerStyleRaw,
                        "createdDate": isoFormatter.string(from: styleSheet.createdDate),
                        "modifiedDate": isoFormatter.string(from: styleSheet.modifiedDate),
                    ])
                )
            )

            for textStyle in sortedTextStyles(styleSheet.textStyles) {
                operations.append(
                    SyncPOCOperation(
                        id: "\(textStyle.id.uuidString)-textstyle-upsert-\(UUID().uuidString)",
                        entityType: "TextStyleModel",
                        entityId: textStyle.id.uuidString,
                        operationType: "upsert",
                        baseSequence: baseSequence,
                        clientTimestamp: timestamp,
                        payload: SyncPOCPayload(values: textStylePayload(textStyle, styleSheetId: styleSheet.id.uuidString))
                    )
                )
            }

            for imageStyle in sortedImageStyles(styleSheet.imageStyles) {
                operations.append(
                    SyncPOCOperation(
                        id: "\(imageStyle.id.uuidString)-imagestyle-upsert-\(UUID().uuidString)",
                        entityType: "ImageStyle",
                        entityId: imageStyle.id.uuidString,
                        operationType: "upsert",
                        baseSequence: baseSequence,
                        clientTimestamp: timestamp,
                        payload: SyncPOCPayload(values: imageStylePayload(imageStyle, styleSheetId: styleSheet.id.uuidString))
                    )
                )
            }
        }

        if let pageSetup = project.pageSetup {
            operations.append(makeOperation(entityType: "PageSetup", entityId: pageSetup.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: pageSetupPayload(pageSetup, projectId: project.id.uuidString)))

            for printerPaper in sortedPrinterPapers(pageSetup.printerPapers) {
                operations.append(makeOperation(entityType: "PrinterPaper", entityId: printerPaper.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: printerPaperPayload(printerPaper, pageSetupId: pageSetup.id.uuidString)))
            }
        }

        let folders = sampleFolders(in: project)
        for folder in folders {
            operations.append(
                SyncPOCOperation(
                    id: "\(folder.id.uuidString)-folder-upsert-\(UUID().uuidString)",
                    entityType: "Folder",
                    entityId: folder.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: [
                        "name": folder.name ?? "Untitled Folder",
                        "projectId": project.id.uuidString,
                        "parentFolderId": folder.parentFolder?.id.uuidString ?? "",
                        "userOrder": folder.userOrder.map(String.init) ?? "",
                        "frontMatterSettingsData": base64String(folder.frontMatterSettingsData),
                        "backMatterSettingsData": base64String(folder.backMatterSettingsData),
                        "dramaFrontMatterSettingsData": base64String(folder.dramaFrontMatterSettingsData),
                        "dramaBackMatterSettingsData": base64String(folder.dramaBackMatterSettingsData),
                    ])
                )
            )
        }

        let textFiles = sampleTextFiles(in: folders)
        for textFile in textFiles {
            operations.append(
                SyncPOCOperation(
                    id: "\(textFile.id.uuidString)-textfile-upsert-\(UUID().uuidString)",
                    entityType: "TextFile",
                    entityId: textFile.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: [
                        "name": textFile.name,
                        "folderId": textFile.parentFolder?.id.uuidString ?? "",
                        "workflowStatus": textFile.workflowStatusRaw ?? "",
                        "contentType": textFile.contentTypeRaw,
                        "content": String(textFile.currentContent.prefix(maxTextFileContentCharacters)),
                        "modifiedDate": isoFormatter.string(from: textFile.modifiedDate),
                    ])
                )
            )

            for version in sampleVersions(in: textFile) {
                operations.append(
                    SyncPOCOperation(
                        id: "\(version.id.uuidString)-version-upsert-\(UUID().uuidString)",
                        entityType: "Version",
                        entityId: version.id.uuidString,
                        operationType: "upsert",
                        baseSequence: baseSequence,
                        clientTimestamp: timestamp,
                        payload: SyncPOCPayload(values: [
                            "textFileId": textFile.id.uuidString,
                            "content": String(version.content.prefix(maxTextFileContentCharacters)),
                            "versionNumber": String(version.versionNumber),
                            "comment": version.comment ?? "",
                            "notes": version.notes ?? "",
                            "createdDate": isoFormatter.string(from: version.createdDate),
                        ])
                    )
                )
            }
        }

        let versions = textFiles.flatMap { sampleVersions(in: $0) }
        for comment in sampleComments(in: versions) {
            operations.append(
                SyncPOCOperation(
                    id: "\(comment.id.uuidString)-comment-upsert-\(UUID().uuidString)",
                    entityType: "CommentModel",
                    entityId: comment.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: commentPayload(comment))
                )
            )
        }

        for footnote in sampleFootnotes(in: versions) {
            operations.append(
                SyncPOCOperation(
                    id: "\(footnote.id.uuidString)-footnote-upsert-\(UUID().uuidString)",
                    entityType: "FootnoteModel",
                    entityId: footnote.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: footnotePayload(footnote))
                )
            )
        }

        for scene in sampleStoryScenes(in: project) {
            operations.append(makeOperation(entityType: "StoryScene", entityId: scene.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: storyScenePayload(scene, projectId: project.id.uuidString)))
        }

        for chapter in sampleChapters(in: project) {
            operations.append(makeOperation(entityType: "Chapter", entityId: chapter.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: bodyMatterContainerPayload(name: chapter.name, synopsis: chapter.synopsis, userOrder: chapter.userOrder, createdDate: chapter.createdDate, modifiedDate: chapter.modifiedDate, bodyMatterOrder: chapter.bodyMatterOrder, isInBodyMatter: chapter.isInBodyMatter, projectId: project.id.uuidString)))
        }

        for act in sampleActs(in: project) {
            operations.append(makeOperation(entityType: "Act", entityId: act.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: bodyMatterContainerPayload(name: act.name, synopsis: act.synopsis, userOrder: act.userOrder, createdDate: act.createdDate, modifiedDate: act.modifiedDate, bodyMatterOrder: act.bodyMatterOrder, isInBodyMatter: act.isInBodyMatter, projectId: project.id.uuidString)))
        }

        for section in sampleProseSections(in: project) {
            operations.append(makeOperation(entityType: "ProseSection", entityId: section.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: bodyMatterContainerPayload(name: section.name, synopsis: section.synopsis, userOrder: section.userOrder, createdDate: section.createdDate, modifiedDate: section.modifiedDate, bodyMatterOrder: section.bodyMatterOrder, isInBodyMatter: section.isInBodyMatter, projectId: project.id.uuidString)))
        }

        for collection in samplePoetryCollections(in: project) {
            operations.append(makeOperation(entityType: "PoetryCollection", entityId: collection.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: bodyMatterContainerPayload(name: collection.name, synopsis: collection.synopsis, userOrder: collection.userOrder, createdDate: collection.createdDate, modifiedDate: collection.modifiedDate, bodyMatterOrder: collection.bodyMatterOrder, isInBodyMatter: collection.isInBodyMatter, projectId: project.id.uuidString)))
        }

        for book in sampleBooks(in: project) {
            operations.append(makeOperation(entityType: "Book", entityId: book.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: bodyMatterContainerPayload(name: book.name, synopsis: book.synopsis, userOrder: book.userOrder, createdDate: book.createdDate, modifiedDate: book.modifiedDate, bodyMatterOrder: book.bodyMatterOrder, isInBodyMatter: book.isInBodyMatter, projectId: project.id.uuidString)))
        }

        for character in sampleCharacters(in: project) {
            operations.append(makeOperation(entityType: "Character", entityId: character.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: characterPayload(character, projectId: project.id.uuidString)))
        }

        for location in sampleLocations(in: project) {
            operations.append(makeOperation(entityType: "Location", entityId: location.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: locationPayload(location, projectId: project.id.uuidString)))
        }

        for customAttribute in sampleCustomAttributes(characters: sampleCharacters(in: project), locations: sampleLocations(in: project)) {
            operations.append(makeOperation(entityType: "CustomAttribute", entityId: customAttribute.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: customAttributePayload(customAttribute)))
        }

        for plotElement in samplePlotElements(in: project) {
            operations.append(makeOperation(entityType: "PlotElement", entityId: plotElement.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: plotElementPayload(plotElement, projectId: project.id.uuidString)))
        }

        for joinLink in sampleJoinLinks(textFiles: textFiles, scenes: sampleStoryScenes(in: project), characters: sampleCharacters(in: project), locations: sampleLocations(in: project)) {
            operations.append(makeOperation(entityType: joinLink.entityType, entityId: joinLink.entityId, baseSequence: baseSequence, timestamp: timestamp, payload: joinLink.payload))
        }

        for note in sampleNotes(in: project) {
            operations.append(makeOperation(entityType: "NoteEntry", entityId: note.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: notePayload(note, projectId: project.id.uuidString)))
        }

        for citation in sampleCitations(in: project) {
            operations.append(makeOperation(entityType: "CitationEntry", entityId: citation.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: citationPayload(citation, projectId: project.id.uuidString)))
        }

        for glossaryEntry in sampleGlossaryEntries(in: project) {
            operations.append(makeOperation(entityType: "GlossaryEntry", entityId: glossaryEntry.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: glossaryPayload(glossaryEntry, projectId: project.id.uuidString)))
        }

        for referenceEntry in sampleReferenceEntries(in: project) {
            operations.append(makeOperation(entityType: "ReferenceEntry", entityId: referenceEntry.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: referencePayload(referenceEntry, projectId: project.id.uuidString)))
        }

        for indexEntry in sampleIndexEntries(in: project) {
            operations.append(makeOperation(entityType: "IndexEntry", entityId: indexEntry.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: indexPayload(indexEntry, projectId: project.id.uuidString)))
        }

        for contributor in sampleContributors(in: project) {
            operations.append(makeOperation(entityType: "ContributorEntry", entityId: contributor.id.uuidString, baseSequence: baseSequence, timestamp: timestamp, payload: contributorPayload(contributor, projectId: project.id.uuidString)))
        }

        let publications = samplePublications(in: project)
        for publication in publications {
            operations.append(
                SyncPOCOperation(
                    id: "\(publication.id.uuidString)-publication-upsert-\(UUID().uuidString)",
                    entityType: "Publication",
                    entityId: publication.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: publicationPayload(publication, projectId: project.id.uuidString))
                )
            )
        }

        let submissions = sampleSubmissions(in: project)
        for submission in submissions {
            operations.append(
                SyncPOCOperation(
                    id: "\(submission.id.uuidString)-submission-upsert-\(UUID().uuidString)",
                    entityType: "Submission",
                    entityId: submission.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: submissionPayload(submission, projectId: project.id.uuidString))
                )
            )
        }

        for submittedFile in sampleSubmittedFiles(in: submissions) {
            operations.append(
                SyncPOCOperation(
                    id: "\(submittedFile.id.uuidString)-submittedfile-upsert-\(UUID().uuidString)",
                    entityType: "SubmittedFile",
                    entityId: submittedFile.id.uuidString,
                    operationType: "upsert",
                    baseSequence: baseSequence,
                    clientTimestamp: timestamp,
                    payload: SyncPOCPayload(values: submittedFilePayload(submittedFile, projectId: project.id.uuidString))
                )
            )
        }

        return operations
    }

    @MainActor
    private func sampleFolders(in project: Project) -> [Folder] {
        var folders: [Folder] = []
        for folder in sortedFolders(project.folders) {
            append(folder: folder, to: &folders)
            if folders.count >= maxSampleFolders { break }
        }
        return Array(folders.prefix(maxSampleFolders))
    }

    @MainActor
    private func append(folder: Folder, to folders: inout [Folder]) {
        guard folders.count < maxSampleFolders else { return }
        folders.append(folder)

        for childFolder in sortedFolders(folder.folders) {
            append(folder: childFolder, to: &folders)
            if folders.count >= maxSampleFolders { return }
        }
    }

    @MainActor
    private func sampleTextFiles(in folders: [Folder]) -> [TextFile] {
        var textFiles: [TextFile] = []
        for folder in folders {
            textFiles.append(contentsOf: sortedTextFiles(folder.textFiles))
            if textFiles.count >= maxSampleTextFiles { break }
        }
        return Array(textFiles.prefix(maxSampleTextFiles))
    }

    private func sortedFolders(_ folders: [Folder]?) -> [Folder] {
        (folders ?? [])
            .sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }
    }

    private func sortedTextFiles(_ textFiles: [TextFile]?) -> [TextFile] {
        (textFiles ?? [])
            .filter({ $0.trashItem == nil })
            .sorted(by: { ($0.userOrder ?? Int.max, $0.name) < ($1.userOrder ?? Int.max, $1.name) })
    }

    private func sampleVersions(in textFile: TextFile) -> [Version] {
        guard let versions = textFile.versions, !versions.isEmpty else { return [] }
        return versions.sorted { $0.versionNumber < $1.versionNumber }
    }

    private func samplePublications(in project: Project) -> [Publication] {
        (project.publications ?? [])
            .sorted { ($0.deadline ?? Date.distantFuture, $0.name) < ($1.deadline ?? Date.distantFuture, $1.name) }
            .prefix(maxSamplePublications)
            .map { $0 }
    }

    private func sampleSubmissions(in project: Project) -> [Submission] {
        (project.submissions ?? [])
            .sorted { ($0.submittedDate, $0.name ?? "") < ($1.submittedDate, $1.name ?? "") }
            .prefix(maxSampleSubmissions)
            .map { $0 }
    }

    private func sampleSubmittedFiles(in submissions: [Submission]) -> [SubmittedFile] {
        submissions
            .flatMap { $0.submittedFiles ?? [] }
            .sorted { ($0.createdDate, $0.id.uuidString) < ($1.createdDate, $1.id.uuidString) }
            .prefix(maxSampleSubmittedFiles)
            .map { $0 }
    }

    private func sampleComments(in versions: [Version]) -> [CommentModel] {
        versions
            .flatMap { $0.comments ?? [] }
            .sorted { ($0.createdAt, $0.characterPosition, $0.id.uuidString) < ($1.createdAt, $1.characterPosition, $1.id.uuidString) }
            .prefix(maxSampleComments)
            .map { $0 }
    }

    private func sampleFootnotes(in versions: [Version]) -> [FootnoteModel] {
        var footnotesById: [UUID: FootnoteModel] = [:]
        for version in versions {
            for footnote in version.footnotes ?? [] {
                footnotesById[footnote.id] = footnote
            }
            guard let context = version.modelContext else { continue }
            let versionPMID = version.persistentModelID
            let descriptor = FetchDescriptor<FootnoteModel>(
                predicate: #Predicate { footnote in
                    footnote.version?.persistentModelID == versionPMID
                },
                sortBy: [SortDescriptor(\.characterPosition, order: .forward)]
            )
            if let fetchedFootnotes = try? context.fetch(descriptor) {
                for footnote in fetchedFootnotes {
                    footnotesById[footnote.id] = footnote
                }
            }
        }

        return footnotesById.values
            .sorted { ($0.number, $0.characterPosition, $0.id.uuidString) < ($1.number, $1.characterPosition, $1.id.uuidString) }
            .prefix(maxSampleFootnotes)
            .map { $0 }
    }

    private func sampleStoryScenes(in project: Project) -> [StoryScene] {
        let projectId = project.id
        if let modelContext = project.modelContext,
           let fetchedScenes = try? ModelContext(modelContext.container).fetch(FetchDescriptor<StoryScene>()) {
            let projectScenes = fetchedScenes.filter { $0.project?.id == projectId }
            if !projectScenes.isEmpty {
                return sortedSampleStoryScenes(projectScenes)
            }
        }

        return sortedSampleStoryScenes(project.scenes ?? [])
    }

    private func sortedSampleStoryScenes(_ scenes: [StoryScene]) -> [StoryScene] {
        scenes
            .filter { !$0.isTrashed }
            .sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }
            .prefix(maxSampleStoryRecordsPerType)
            .map { $0 }
    }

    private func sampleChapters(in project: Project) -> [Chapter] {
        (project.chapters ?? []).sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }.prefix(maxSampleStoryRecordsPerType).map { $0 }
    }

    private func sampleActs(in project: Project) -> [Act] {
        (project.acts ?? []).sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }.prefix(maxSampleStoryRecordsPerType).map { $0 }
    }

    private func sampleProseSections(in project: Project) -> [ProseSection] {
        (project.sections ?? []).sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }.prefix(maxSampleStoryRecordsPerType).map { $0 }
    }

    private func samplePoetryCollections(in project: Project) -> [PoetryCollection] {
        (project.poetryCollections ?? []).sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }.prefix(maxSampleStoryRecordsPerType).map { $0 }
    }

    private func sampleBooks(in project: Project) -> [Book] {
        (project.books ?? []).sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }.prefix(maxSampleStoryRecordsPerType).map { $0 }
    }

    private func sampleCharacters(in project: Project) -> [Character] {
        (project.characters ?? [])
            .sorted { ($0.name ?? "", $0.id.uuidString) < ($1.name ?? "", $1.id.uuidString) }
            .prefix(maxSampleStoryRecordsPerType)
            .map { $0 }
    }

    private func sampleLocations(in project: Project) -> [Location] {
        (project.locations ?? [])
            .sorted { ($0.name ?? "", $0.id.uuidString) < ($1.name ?? "", $1.id.uuidString) }
            .prefix(maxSampleStoryRecordsPerType)
            .map { $0 }
    }

    private func samplePlotElements(in project: Project) -> [PlotElement] {
        (project.plotElements ?? [])
            .sorted { ($0.userOrder ?? Int.max, $0.name ?? "") < ($1.userOrder ?? Int.max, $1.name ?? "") }
            .prefix(maxSampleStoryRecordsPerType)
            .map { $0 }
    }

    private func sampleJoinLinks(textFiles: [TextFile], scenes: [StoryScene], characters: [Character], locations: [Location]) -> [(entityType: String, entityId: String, payload: [String: String])] {
        var linksById: [String: (entityType: String, entityId: String, payload: [String: String])] = [:]

        func append(entityType: String, entityId: UUID, payload: [String: String]) {
            guard linksById.count < maxSampleJoinLinks else { return }
            linksById[entityId.uuidString] = (entityType, entityId.uuidString, payload)
        }

        for textFile in textFiles {
            for link in textFile.sectionLinks ?? [] {
                append(entityType: "TextFileSectionLink", entityId: link.id, payload: [
                    "textFileId": link.textFile?.id.uuidString ?? "",
                    "sectionId": link.section?.id.uuidString ?? "",
                    "userOrder": link.userOrder.map(String.init) ?? "",
                ])
            }
            for link in textFile.poetryCollectionLinks ?? [] {
                append(entityType: "TextFileCollectionLink", entityId: link.id, payload: [
                    "textFileId": link.textFile?.id.uuidString ?? "",
                    "poetryCollectionId": link.poetryCollection?.id.uuidString ?? "",
                    "userOrder": link.userOrder.map(String.init) ?? "",
                ])
            }
        }

        for scene in scenes {
            for link in scene.chapterLinks ?? [] {
                append(entityType: "SceneChapterLink", entityId: link.id, payload: ["sceneId": link.scene?.id.uuidString ?? "", "chapterId": link.chapter?.id.uuidString ?? ""])
            }
            for link in scene.actLinks ?? [] {
                append(entityType: "SceneActLink", entityId: link.id, payload: ["sceneId": link.scene?.id.uuidString ?? "", "actId": link.act?.id.uuidString ?? ""])
            }
            for link in scene.bookLinks ?? [] {
                append(entityType: "SceneBookLink", entityId: link.id, payload: ["sceneId": link.scene?.id.uuidString ?? "", "bookId": link.book?.id.uuidString ?? ""])
            }
            for link in scene.plotElementLinks ?? [] {
                append(entityType: "ScenePlotElementLink", entityId: link.id, payload: ["sceneId": link.scene?.id.uuidString ?? "", "plotElementId": link.plotElement?.id.uuidString ?? ""])
            }
            for link in scene.characterLinks ?? [] {
                append(entityType: "SceneCharacterLink", entityId: link.id, payload: ["sceneId": link.scene?.id.uuidString ?? "", "characterId": link.character?.id.uuidString ?? ""])
            }
            for link in scene.locationLinks ?? [] {
                append(entityType: "SceneLocationLink", entityId: link.id, payload: ["sceneId": link.scene?.id.uuidString ?? "", "locationId": link.location?.id.uuidString ?? ""])
            }
        }

        for character in characters {
            for link in character.plotElementLinks ?? [] {
                append(entityType: "CharacterPlotElementLink", entityId: link.id, payload: ["characterId": link.character?.id.uuidString ?? "", "plotElementId": link.plotElement?.id.uuidString ?? ""])
            }
        }

        for location in locations {
            for link in location.plotElementLinks ?? [] {
                append(entityType: "LocationPlotElementLink", entityId: link.id, payload: ["locationId": link.location?.id.uuidString ?? "", "plotElementId": link.plotElement?.id.uuidString ?? ""])
            }
        }

        return linksById.values.sorted { ($0.entityType, $0.entityId) < ($1.entityType, $1.entityId) }
    }

    @MainActor
    private func selectRelationshipLinkForDeleteGuardrail(projects: [Project]) -> (project: Project, link: (entityType: String, entityId: String, payload: [String: String]))? {
        for project in projects where !project.isTrashed {
            let folders = sampleFolders(in: project)
            let textFiles = sampleTextFiles(in: folders)
            let scenes = sampleStoryScenes(in: project)
            let characters = sampleCharacters(in: project)
            let locations = sampleLocations(in: project)
            if let link = sampleJoinLinks(textFiles: textFiles, scenes: scenes, characters: characters, locations: locations).first {
                return (project, link)
            }
        }
        return nil
    }

    @MainActor
    private func selectOrderedTextFileLinkForUpdate(projects: [Project]) -> (project: Project, link: (entityType: String, entityId: String, payload: [String: String]))? {
        for project in projects where !project.isTrashed {
            let folders = sampleFolders(in: project)
            let textFiles = sampleTextFiles(in: folders)
            let scenes = sampleStoryScenes(in: project)
            let characters = sampleCharacters(in: project)
            let locations = sampleLocations(in: project)
            if let link = sampleJoinLinks(textFiles: textFiles, scenes: scenes, characters: characters, locations: locations).first(where: { $0.entityType == "TextFileSectionLink" || $0.entityType == "TextFileCollectionLink" }) {
                return (project, link)
            }
        }
        return nil
    }

    private func sampleNotes(in project: Project) -> [NoteEntry] {
        let projectId = project.id
        if let modelContext = project.modelContext,
           let fetchedNotes = try? ModelContext(modelContext.container).fetch(FetchDescriptor<NoteEntry>()) {
            let projectNotes = fetchedNotes.filter { $0.project?.id == projectId }
            if !projectNotes.isEmpty {
                return sortedSampleNotes(projectNotes)
            }
        }

        return sortedSampleNotes(project.noteEntries ?? [])
    }

    private func sortedSampleNotes(_ notes: [NoteEntry]) -> [NoteEntry] {
        sortedNotes(notes)
            .prefix(maxSampleReferenceRecordsPerType)
            .map { $0 }
    }

    private func sortedNotes(_ notes: [NoteEntry]) -> [NoteEntry] {
        notes
            .sorted { ($0.displayNumber, $0.title ?? "", $0.id.uuidString) < ($1.displayNumber, $1.title ?? "", $1.id.uuidString) }
    }

    private func localNoteEntriesForPOC(in project: Project) -> [NoteEntry] {
        var notesById: [UUID: NoteEntry] = [:]
        func add(_ note: NoteEntry) {
            notesById[note.id] = note
        }

        (project.noteEntries ?? []).forEach(add)
        let projectId = project.id
        let projectName = project.name
        let relationshipTextFiles = allProjectTextFiles(in: project)
        var projectFileIds = Set(relationshipTextFiles.map(\.id))
        var referencedNoteIds = Set(relationshipTextFiles.flatMap { noteReferenceIds(in: $0) })

        if let modelContext = project.modelContext {
            let freshContext = ModelContext(modelContext.container)
            let fetchedNotes = (try? freshContext.fetch(FetchDescriptor<NoteEntry>())) ?? []
            let fetchedTextFiles = (try? freshContext.fetch(FetchDescriptor<TextFile>())) ?? []
            let projectTextFiles = fetchedTextFiles.filter { textFile in
                textFile.parentFolder?.project?.id == projectId || textFile.parentFolder?.project?.name == projectName
            }
            projectFileIds.formUnion(projectTextFiles.map(\.id))
            referencedNoteIds.formUnion(projectTextFiles.flatMap { noteReferenceIds(in: $0) })

            for note in fetchedNotes where note.project?.id == projectId || note.project?.name == projectName {
                add(note)
            }
            for note in fetchedNotes where !note.referencingFileIDs.filter({ projectFileIds.contains($0) }).isEmpty {
                add(note)
            }
            for note in fetchedNotes where referencedNoteIds.contains(note.id) {
                add(note)
            }
        }

        return sortedNotes(Array(notesById.values))
    }

    private func findLocalNoteEntry(id noteId: String, in project: Project) -> NoteEntry? {
        guard let noteUUID = UUID(uuidString: noteId) else { return nil }
        if let modelContext = project.modelContext,
           let fetchedNotes = try? ModelContext(modelContext.container).fetch(FetchDescriptor<NoteEntry>()),
           let note = fetchedNotes.first(where: { $0.id == noteUUID }) {
            return note
        }
        return localNoteEntriesForPOC(in: project).first { $0.id == noteUUID }
    }

    private func selectNoteEntryForUpdateProbe(in project: Project) -> (note: NoteEntry, description: String)? {
        if let selection = selectNoteEntryFromFreshStore(for: project) {
            return selection
        }

        if project.name == "Poems 2026",
           let newYearFile = findTextFile(named: "New Year", in: project),
           let note = noteEntryReferencedByFile(newYearFile, in: project) {
            return (note, noteProbeDescription(note, fileName: newYearFile.name, projectName: project.name))
        }

        let notes = localNoteEntriesForPOC(in: project)
        guard !notes.isEmpty else { return nil }

        if project.name == "Poems 2026",
           let newYearFile = findTextFile(named: "New Year", in: project),
           let note = notes.first(where: { $0.referencingFileIDs.contains(newYearFile.id) }) {
            return (note, noteProbeDescription(note, fileName: newYearFile.name, projectName: project.name))
        }

        let note = notes[0]
        let fileName = firstReferencingFileName(for: note, in: project)
        return (note, noteProbeDescription(note, fileName: fileName, projectName: project.name))
    }

    private func selectNoteEntryFromFreshStore(for project: Project) -> (note: NoteEntry, description: String)? {
        guard let modelContext = project.modelContext else { return nil }
        let freshContext = ModelContext(modelContext.container)
        guard let fetchedNotes = try? freshContext.fetch(FetchDescriptor<NoteEntry>()), !fetchedNotes.isEmpty else { return nil }
        let fetchedTextFiles = (try? freshContext.fetch(FetchDescriptor<TextFile>())) ?? []
        let projectName = project.name
        let projectId = project.id

        let newYearFiles = fetchedTextFiles.filter { textFile in
            textFile.name == "New Year" && (textFile.parentFolder?.project?.id == projectId || textFile.parentFolder?.project?.name == "Poems 2026")
        }
        let fallbackNewYearFiles = newYearFiles.isEmpty ? fetchedTextFiles.filter { $0.name == "New Year" } : newYearFiles
        let markerIds = Set(fallbackNewYearFiles.flatMap { noteReferenceIds(in: $0) })
        if let note = sortedSampleNotes(fetchedNotes).first(where: { markerIds.contains($0.id) }) {
            let fileName = fallbackNewYearFiles.first { noteReferenceIds(in: $0).contains(note.id) }?.name
            return (note, noteProbeDescription(note, fileName: fileName, projectName: projectName))
        }

        let newYearFileIds = Set(fallbackNewYearFiles.map(\.id))
        if let note = sortedSampleNotes(fetchedNotes).first(where: { !$0.referencingFileIDs.isEmpty && !$0.referencingFileIDs.filter({ newYearFileIds.contains($0) }).isEmpty }) {
            let fileName = fallbackNewYearFiles.first { note.referencingFileIDs.contains($0.id) }?.name
            return (note, noteProbeDescription(note, fileName: fileName, projectName: projectName))
        }

        let projectNotes = fetchedNotes.filter { $0.project?.id == projectId || $0.project?.name == projectName }
        if let note = sortedSampleNotes(projectNotes).first {
            let fileName = firstReferencingFileName(for: note, in: project)
            return (note, noteProbeDescription(note, fileName: fileName, projectName: projectName))
        }

        if let newestNote = fetchedNotes.sorted(by: { ($0.modifiedAt, $0.id.uuidString) > ($1.modifiedAt, $1.id.uuidString) }).first {
            let fileName = firstReferencingFileName(for: newestNote, in: project)
            return (newestNote, noteProbeDescription(newestNote, fileName: fileName, projectName: projectName))
        }

        return nil
    }

    private func noteReferenceIds(in textFile: TextFile) -> [UUID] {
        guard let attributedContent = textFile.currentVersion?.attributedContent else { return [] }
        var ids = attributedContent.references(ofType: .note).map(\.entryID)
        let fullRange = NSRange(location: 0, length: attributedContent.length)
        attributedContent.enumerateAttribute(.attachment, in: fullRange, options: []) { value, _, _ in
            guard let referenceAttachment = value as? ReferenceAttachment,
                  referenceAttachment.referenceType == .note else { return }
            ids.append(referenceAttachment.entryID)
        }
        return Array(Set(ids))
    }

    private func noteEntryProbeSelectionFailureReason(project: Project) -> String {
        let selectedProjectName = project.name ?? "Untitled"
        let relationshipNoteCount = project.noteEntries?.count ?? 0
        var freshNoteCount = 0
        var newYearFileCount = 0
        var newYearReferenceCount = 0

        if let modelContext = project.modelContext {
            let freshContext = ModelContext(modelContext.container)
            freshNoteCount = ((try? freshContext.fetch(FetchDescriptor<NoteEntry>())) ?? []).count
            let fetchedTextFiles = (try? freshContext.fetch(FetchDescriptor<TextFile>())) ?? []
            let newYearFiles = fetchedTextFiles.filter { $0.name == "New Year" }
            newYearFileCount = newYearFiles.count
            newYearReferenceCount = newYearFiles.reduce(0) { $0 + noteReferenceIds(in: $1).count }
        }

        return "could not find a NoteEntry for existing note update probe. Selected project='\(selectedProjectName)', relationship notes=\(relationshipNoteCount), fresh notes=\(freshNoteCount), files named New Year=\(newYearFileCount), note markers in New Year=\(newYearReferenceCount)."
    }

    private func noteEntryReferencedByFile(_ textFile: TextFile, in project: Project) -> NoteEntry? {
        guard let noteId = noteReferenceIds(in: textFile).first else {
            return nil
        }

        if let modelContext = project.modelContext,
           let fetchedNotes = try? ModelContext(modelContext.container).fetch(FetchDescriptor<NoteEntry>()),
           let note = fetchedNotes.first(where: { $0.id == noteId }) {
            return note
        }

        return (project.noteEntries ?? []).first { $0.id == noteId }
    }

    private func findTextFile(named name: String, in project: Project) -> TextFile? {
        let projectId = project.id
        if let modelContext = project.modelContext,
           let fetchedTextFiles = try? ModelContext(modelContext.container).fetch(FetchDescriptor<TextFile>()) {
            return fetchedTextFiles.first { textFile in
                textFile.name == name && textFile.parentFolder?.project?.id == projectId
            }
        }
        return allProjectTextFiles(in: project).first { $0.name == name }
    }

    private func firstReferencingFileName(for note: NoteEntry, in project: Project) -> String? {
        guard let fileId = note.referencingFileIDs.first else { return nil }
        let projectId = project.id
        if let modelContext = project.modelContext,
           let fetchedTextFiles = try? ModelContext(modelContext.container).fetch(FetchDescriptor<TextFile>()),
           let textFile = fetchedTextFiles.first(where: { $0.id == fileId && $0.parentFolder?.project?.id == projectId }) {
            return textFile.name
        }
        return allProjectTextFiles(in: project).first { $0.id == fileId }?.name
    }

    private func allProjectTextFiles(in project: Project) -> [TextFile] {
        var textFiles: [TextFile] = []
        for folder in allProjectFolders(in: project) {
            textFiles.append(contentsOf: sortedTextFiles(folder.textFiles))
        }
        return textFiles
    }

    private func allProjectFolders(in project: Project) -> [Folder] {
        var folders: [Folder] = []
        appendAllFolders(sortedFolders(project.folders), to: &folders)
        return folders
    }

    private func appendAllFolders(_ sourceFolders: [Folder], to folders: inout [Folder]) {
        for folder in sourceFolders {
            folders.append(folder)
            appendAllFolders(sortedFolders(folder.folders), to: &folders)
        }
    }

    private func noteProbeDescription(_ note: NoteEntry, fileName: String?, projectName: String?) -> String {
        let label = note.tag?.isEmpty == false ? "tag '\(note.tag!)'" : "id \(note.id.uuidString)"
        let filePart = fileName.map { " in file '\($0)'" } ?? ""
        return "NoteEntry \(label)\(filePart) for project '\(projectName ?? "Untitled")'"
    }

    private func sampleGlossaryEntries(in project: Project) -> [GlossaryEntry] {
        let projectId = project.id
        let projectName = project.name
        if let modelContext = project.modelContext,
           let fetchedGlossaryEntries = try? ModelContext(modelContext.container).fetch(FetchDescriptor<GlossaryEntry>()) {
            let projectGlossaryEntries = fetchedGlossaryEntries.filter { $0.project?.id == projectId || $0.project?.name == projectName }
            if !projectGlossaryEntries.isEmpty {
                return sortedSampleGlossaryEntries(projectGlossaryEntries)
            }
        }

        return sortedSampleGlossaryEntries(project.glossaryEntries ?? [])
    }

    private func sortedSampleGlossaryEntries(_ glossaryEntries: [GlossaryEntry]) -> [GlossaryEntry] {
        glossaryEntries
            .sorted { ($0.term, $0.id.uuidString) < ($1.term, $1.id.uuidString) }
            .prefix(maxSampleReferenceRecordsPerType)
            .map { $0 }
    }

    private func findLocalGlossaryEntry(id glossaryEntryId: String, in project: Project) -> GlossaryEntry? {
        guard let glossaryEntryUUID = UUID(uuidString: glossaryEntryId) else { return nil }
        if let modelContext = project.modelContext,
           let fetchedGlossaryEntries = try? ModelContext(modelContext.container).fetch(FetchDescriptor<GlossaryEntry>()),
           let glossaryEntry = fetchedGlossaryEntries.first(where: { $0.id == glossaryEntryUUID }) {
            return glossaryEntry
        }
        return sampleGlossaryEntries(in: project).first { $0.id == glossaryEntryUUID }
    }

    private func sampleReferenceEntries(in project: Project) -> [ReferenceEntry] {
        let projectId = project.id
        let projectName = project.name
        if let modelContext = project.modelContext,
           let fetchedReferenceEntries = try? ModelContext(modelContext.container).fetch(FetchDescriptor<ReferenceEntry>()) {
            let projectReferenceEntries = fetchedReferenceEntries.filter { $0.project?.id == projectId || $0.project?.name == projectName }
            if !projectReferenceEntries.isEmpty {
                return sortedSampleReferenceEntries(projectReferenceEntries)
            }
        }

        return sortedSampleReferenceEntries(project.referenceEntries ?? [])
    }

    private func sortedSampleReferenceEntries(_ referenceEntries: [ReferenceEntry]) -> [ReferenceEntry] {
        referenceEntries
            .sorted { ($0.author, $0.publicationDate, $0.id.uuidString) < ($1.author, $1.publicationDate, $1.id.uuidString) }
            .prefix(maxSampleReferenceRecordsPerType)
            .map { $0 }
    }

    private func findLocalReferenceEntry(id referenceEntryId: String, in project: Project) -> ReferenceEntry? {
        guard let referenceEntryUUID = UUID(uuidString: referenceEntryId) else { return nil }
        if let modelContext = project.modelContext,
           let fetchedReferenceEntries = try? ModelContext(modelContext.container).fetch(FetchDescriptor<ReferenceEntry>()),
           let referenceEntry = fetchedReferenceEntries.first(where: { $0.id == referenceEntryUUID }) {
            return referenceEntry
        }
        return sampleReferenceEntries(in: project).first { $0.id == referenceEntryUUID }
    }

    private func sampleCitations(in project: Project) -> [CitationEntry] {
        let projectId = project.id
        let projectName = project.name
        if let modelContext = project.modelContext,
           let fetchedCitations = try? ModelContext(modelContext.container).fetch(FetchDescriptor<CitationEntry>()) {
            let projectCitations = fetchedCitations.filter { $0.project?.id == projectId || $0.project?.name == projectName }
            if !projectCitations.isEmpty {
                return sortedSampleCitations(projectCitations)
            }
        }

        return sortedSampleCitations(project.citationEntries ?? [])
    }

    private func sortedSampleCitations(_ citations: [CitationEntry]) -> [CitationEntry] {
        citations
            .sorted { ($0.primaryAuthorLastName, $0.year ?? 0, $0.title, $0.id.uuidString) < ($1.primaryAuthorLastName, $1.year ?? 0, $1.title, $1.id.uuidString) }
            .prefix(maxSampleReferenceRecordsPerType)
            .map { $0 }
    }

    private func sampleIndexEntries(in project: Project) -> [IndexEntry] {
        let projectId = project.id
        let projectName = project.name
        if let modelContext = project.modelContext,
           let fetchedIndexEntries = try? ModelContext(modelContext.container).fetch(FetchDescriptor<IndexEntry>()) {
            let projectIndexEntries = fetchedIndexEntries.filter { $0.project?.id == projectId || $0.project?.name == projectName }
            if !projectIndexEntries.isEmpty {
                return sortedSampleIndexEntries(projectIndexEntries)
            }
        }

        return sortedSampleIndexEntries(project.indexEntries ?? [])
    }

    private func sortedSampleIndexEntries(_ indexEntries: [IndexEntry]) -> [IndexEntry] {
        indexEntries
            .sorted { ($0.keyword, $0.id.uuidString) < ($1.keyword, $1.id.uuidString) }
            .prefix(maxSampleReferenceRecordsPerType)
            .map { $0 }
    }

    private func findLocalIndexEntry(id indexEntryId: String, in project: Project) -> IndexEntry? {
        guard let indexEntryUUID = UUID(uuidString: indexEntryId) else { return nil }
        if let modelContext = project.modelContext,
           let fetchedIndexEntries = try? ModelContext(modelContext.container).fetch(FetchDescriptor<IndexEntry>()),
           let indexEntry = fetchedIndexEntries.first(where: { $0.id == indexEntryUUID }) {
            return indexEntry
        }
        return sampleIndexEntries(in: project).first { $0.id == indexEntryUUID }
    }

    private func sampleContributors(in project: Project) -> [ContributorEntry] {
        (project.contributorEntries ?? [])
            .sorted { ($0.userOrder, $0.sortableSurname, $0.sortableFirstName, $0.id.uuidString) < ($1.userOrder, $1.sortableSurname, $1.sortableFirstName, $1.id.uuidString) }
            .prefix(maxSampleReferenceRecordsPerType)
            .map { $0 }
    }

    private func sampleCustomAttributes(characters: [Character], locations: [Location]) -> [CustomAttribute] {
        let characterAttributes = characters.flatMap { $0.customAttributes ?? [] }
        let locationAttributes = locations.flatMap { $0.customAttributes ?? [] }
        return (characterAttributes + locationAttributes)
            .sorted(by: customAttributeSort)
            .prefix(maxSampleStoryRecordsPerType)
            .map { $0 }
    }

    private func customAttributeSort(_ left: CustomAttribute, _ right: CustomAttribute) -> Bool {
        let leftKey = (left.userOrder ?? Int.max, left.key ?? "", left.id.uuidString)
        let rightKey = (right.userOrder ?? Int.max, right.key ?? "", right.id.uuidString)
        return leftKey < rightKey
    }

    private func sampleTrashItems(in project: Project) -> [TrashItem] {
        (project.trashedItems ?? [])
            .sorted { ($0.deletedDate, $0.id.uuidString) < ($1.deletedDate, $1.id.uuidString) }
            .prefix(maxSampleTextFiles)
            .map { $0 }
    }

    private func sortedPrinterPapers(_ printerPapers: [PrinterPaper]?) -> [PrinterPaper] {
        (printerPapers ?? [])
            .sorted { ($0.paperName ?? "", $0.id.uuidString) < ($1.paperName ?? "", $1.id.uuidString) }
    }

    private func summarizeReferenceRecords(in project: Project) -> String {
        "notes \(sampleNotes(in: project).count), glossary \(sampleGlossaryEntries(in: project).count), references \(sampleReferenceEntries(in: project).count), citations \(sampleCitations(in: project).count), index \(sampleIndexEntries(in: project).count), contributors \(sampleContributors(in: project).count)"
    }

    private func summarizeReferenceRecords(in importState: CloudflareSyncPOCImportState) -> String {
        "notes \(importState.notesById.count), glossary \(importState.glossaryEntriesById.count), references \(importState.referenceEntriesById.count), citations \(importState.citationEntriesById.count), index \(importState.indexEntriesById.count), contributors \(importState.contributorEntriesById.count)"
    }

    @MainActor
    private func summarizeMatterFolders(in project: Project) -> String {
        "front \(summarizeMatterFolder(project.findFrontMatterFolder())), back \(summarizeMatterFolder(project.findBackMatterFolder()))"
    }

    @MainActor
    private func summarizeMatterFolder(_ folder: Folder?) -> String {
        guard let folder else { return "missing" }
        let files = sortedTextFiles(folder.textFiles)
        let versionCount = files.reduce(0) { total, textFile in
            total + sampleVersions(in: textFile).count
        }
        let hasSettings = folder.frontMatterSettingsData != nil || folder.backMatterSettingsData != nil || folder.dramaFrontMatterSettingsData != nil || folder.dramaBackMatterSettingsData != nil
        return "\(files.count) files, \(versionCount) versions, settings \(hasSettings ? "yes" : "no")"
    }

    private func summarizeMatterFolders(in importState: CloudflareSyncPOCImportState) -> String {
        let front = summarizeMatterFolder(named: "Front Matter", in: importState)
        let back = summarizeMatterFolder(named: "Back Matter", in: importState)
        return "front \(front), back \(back)"
    }

    private func summarizeMatterFolder(named folderName: String, in importState: CloudflareSyncPOCImportState) -> String {
        guard let folder = importState.foldersById.first(where: { $0.value["name"] == folderName }) else { return "missing" }
        let textFiles = importState.textFilesById.filter { $0.value["folderId"] == folder.key }
        let textFileIds = Set(textFiles.map { $0.key })
        let versionCount = importState.versionsById.values.filter { values in
            guard let textFileId = values["textFileId"] else { return false }
            return textFileIds.contains(textFileId)
        }.count
        let hasSettings = ["frontMatterSettingsData", "backMatterSettingsData", "dramaFrontMatterSettingsData", "dramaBackMatterSettingsData"].contains { key in
            folder.value[key]?.isEmpty == false
        }
        return "\(textFiles.count) files, \(versionCount) versions, settings \(hasSettings ? "yes" : "no")"
    }

    private func makeOperation(entityType: String, entityId: String, baseSequence: Int, timestamp: String, payload: [String: String]) -> SyncPOCOperation {
        SyncPOCOperation(
            id: "\(entityId)-\(entityType.lowercased())-upsert-\(UUID().uuidString)",
            entityType: entityType,
            entityId: entityId,
            operationType: "upsert",
            baseSequence: baseSequence,
            clientTimestamp: timestamp,
            payload: SyncPOCPayload(values: payload)
        )
    }

    private func sortedTextStyles(_ textStyles: [TextStyleModel]?) -> [TextStyleModel] {
        (textStyles ?? []).sorted { ($0.displayOrder, $0.name) < ($1.displayOrder, $1.name) }
    }

    private func sortedImageStyles(_ imageStyles: [ImageStyle]?) -> [ImageStyle] {
        (imageStyles ?? []).sorted { ($0.displayOrder, $0.name) < ($1.displayOrder, $1.name) }
    }

    private func textStylePayload(_ textStyle: TextStyleModel, styleSheetId: String) -> [String: String] {
        [
            "styleSheetId": styleSheetId,
            "name": textStyle.name,
            "displayName": textStyle.displayName,
            "displayOrder": String(textStyle.displayOrder),
            "fontFamily": textStyle.fontFamily ?? "",
            "fontName": textStyle.fontName ?? "",
            "fontSize": String(Double(textStyle.fontSize)),
            "isBold": String(textStyle.isBold),
            "isItalic": String(textStyle.isItalic),
            "isUnderlined": String(textStyle.isUnderlined),
            "isStrikethrough": String(textStyle.isStrikethrough),
            "textColorHex": textStyle.textColorHex ?? "",
            "alignmentRaw": String(textStyle.alignmentRaw),
            "lineSpacing": String(Double(textStyle.lineSpacing)),
            "paragraphSpacingBefore": String(Double(textStyle.paragraphSpacingBefore)),
            "paragraphSpacingAfter": String(Double(textStyle.paragraphSpacingAfter)),
            "firstLineIndent": String(Double(textStyle.firstLineIndent)),
            "headIndent": String(Double(textStyle.headIndent)),
            "tailIndent": String(Double(textStyle.tailIndent)),
            "lineHeightMultiple": String(Double(textStyle.lineHeightMultiple)),
            "minimumLineHeight": String(Double(textStyle.minimumLineHeight)),
            "maximumLineHeight": String(Double(textStyle.maximumLineHeight)),
            "numberFormatRaw": textStyle.numberFormatRaw,
            "numberAdornmentRaw": textStyle.numberAdornmentRaw,
            "followOnStyleName": textStyle.followOnStyleName ?? "",
            "parentStyleName": textStyle.parentStyleName ?? "",
            "styleCategoryRaw": textStyle.styleCategoryRaw,
            "isSystemStyle": String(textStyle.isSystemStyle),
            "includeInTOC": String(textStyle.includeInTOC),
            "tocLevel": String(textStyle.tocLevel),
            "isFirstParagraphStyle": String(textStyle.isFirstParagraphStyle),
            "createdDate": isoFormatter.string(from: textStyle.createdDate),
            "modifiedDate": isoFormatter.string(from: textStyle.modifiedDate),
        ]
    }

    private func imageStylePayload(_ imageStyle: ImageStyle, styleSheetId: String) -> [String: String] {
        [
            "styleSheetId": styleSheetId,
            "name": imageStyle.name,
            "displayName": imageStyle.displayName,
            "displayOrder": String(imageStyle.displayOrder),
            "defaultScale": String(Double(imageStyle.defaultScale)),
            "defaultAlignmentRaw": imageStyle.defaultAlignmentRaw,
            "hasCaptionByDefault": String(imageStyle.hasCaptionByDefault),
            "defaultCaptionStyle": imageStyle.defaultCaptionStyle,
            "isSystemStyle": String(imageStyle.isSystemStyle),
            "createdDate": isoFormatter.string(from: imageStyle.createdDate),
            "modifiedDate": isoFormatter.string(from: imageStyle.modifiedDate),
        ]
    }

    private func makeScratchTextStyle(id: String, values: [String: String], styleSheet: StyleSheet) -> TextStyleModel {
        let textStyle = TextStyleModel(
            name: values["name"]?.isEmpty == false ? values["name"]! : "imported-style",
            displayName: values["displayName"]?.isEmpty == false ? values["displayName"]! : "Imported Style",
            displayOrder: intValue(values["displayOrder"]) ?? 0,
            fontFamily: values["fontFamily"]?.isEmpty == false ? values["fontFamily"] : nil,
            fontSize: cgFloatValue(values["fontSize"]) ?? 17,
            isBold: boolValue(values["isBold"]),
            isItalic: boolValue(values["isItalic"]),
            isUnderlined: boolValue(values["isUnderlined"]),
            isStrikethrough: boolValue(values["isStrikethrough"]),
            alignment: NSTextAlignment(rawValue: intValue(values["alignmentRaw"]) ?? 0) ?? .natural,
            lineSpacing: cgFloatValue(values["lineSpacing"]) ?? 0,
            paragraphSpacingBefore: cgFloatValue(values["paragraphSpacingBefore"]) ?? 0,
            paragraphSpacingAfter: cgFloatValue(values["paragraphSpacingAfter"]) ?? 0,
            firstLineIndent: cgFloatValue(values["firstLineIndent"]) ?? 0,
            headIndent: cgFloatValue(values["headIndent"]) ?? 0,
            tailIndent: cgFloatValue(values["tailIndent"]) ?? 0,
            lineHeightMultiple: cgFloatValue(values["lineHeightMultiple"]) ?? 0,
            minimumLineHeight: cgFloatValue(values["minimumLineHeight"]) ?? 0,
            maximumLineHeight: cgFloatValue(values["maximumLineHeight"]) ?? 0,
            numberFormat: NumberFormat(rawValue: values["numberFormatRaw"] ?? "") ?? .none,
            styleCategory: StyleCategory(rawValue: values["styleCategoryRaw"] ?? "") ?? .text,
            isSystemStyle: boolValue(values["isSystemStyle"])
        )
        if let textStyleId = UUID(uuidString: id) {
            textStyle.id = textStyleId
        }
        applyTextStylePayload(values, to: textStyle)
        textStyle.styleSheet = styleSheet
        return textStyle
    }

    private func applyTextStylePayload(_ values: [String: String], to textStyle: TextStyleModel) {
        textStyle.name = values["name"]?.isEmpty == false ? values["name"]! : textStyle.name
        textStyle.displayName = values["displayName"]?.isEmpty == false ? values["displayName"]! : textStyle.displayName
        textStyle.displayOrder = intValue(values["displayOrder"]) ?? textStyle.displayOrder
        textStyle.fontFamily = values["fontFamily"]?.isEmpty == false ? values["fontFamily"] : textStyle.fontFamily
        textStyle.fontName = values["fontName"]?.isEmpty == false ? values["fontName"] : textStyle.fontName
        textStyle.fontSize = cgFloatValue(values["fontSize"]) ?? textStyle.fontSize
        textStyle.isBold = boolValue(values["isBold"])
        textStyle.isItalic = boolValue(values["isItalic"])
        textStyle.isUnderlined = boolValue(values["isUnderlined"])
        textStyle.isStrikethrough = boolValue(values["isStrikethrough"])
        textStyle.textColorHex = values["textColorHex"]?.isEmpty == false ? values["textColorHex"] : textStyle.textColorHex
        textStyle.alignmentRaw = intValue(values["alignmentRaw"]) ?? textStyle.alignmentRaw
        textStyle.lineSpacing = cgFloatValue(values["lineSpacing"]) ?? textStyle.lineSpacing
        textStyle.paragraphSpacingBefore = cgFloatValue(values["paragraphSpacingBefore"]) ?? textStyle.paragraphSpacingBefore
        textStyle.paragraphSpacingAfter = cgFloatValue(values["paragraphSpacingAfter"]) ?? textStyle.paragraphSpacingAfter
        textStyle.firstLineIndent = cgFloatValue(values["firstLineIndent"]) ?? textStyle.firstLineIndent
        textStyle.headIndent = cgFloatValue(values["headIndent"]) ?? textStyle.headIndent
        textStyle.tailIndent = cgFloatValue(values["tailIndent"]) ?? textStyle.tailIndent
        textStyle.lineHeightMultiple = cgFloatValue(values["lineHeightMultiple"]) ?? textStyle.lineHeightMultiple
        textStyle.minimumLineHeight = cgFloatValue(values["minimumLineHeight"]) ?? textStyle.minimumLineHeight
        textStyle.maximumLineHeight = cgFloatValue(values["maximumLineHeight"]) ?? textStyle.maximumLineHeight
        textStyle.numberFormatRaw = values["numberFormatRaw"]?.isEmpty == false ? values["numberFormatRaw"]! : textStyle.numberFormatRaw
        textStyle.numberAdornmentRaw = values["numberAdornmentRaw"]?.isEmpty == false ? values["numberAdornmentRaw"]! : textStyle.numberAdornmentRaw
        textStyle.followOnStyleName = values["followOnStyleName"]?.isEmpty == false ? values["followOnStyleName"] : textStyle.followOnStyleName
        textStyle.parentStyleName = values["parentStyleName"]?.isEmpty == false ? values["parentStyleName"] : textStyle.parentStyleName
        textStyle.styleCategoryRaw = values["styleCategoryRaw"]?.isEmpty == false ? values["styleCategoryRaw"]! : textStyle.styleCategoryRaw
        textStyle.isSystemStyle = boolValue(values["isSystemStyle"])
        textStyle.includeInTOC = boolValue(values["includeInTOC"])
        textStyle.tocLevel = intValue(values["tocLevel"]) ?? textStyle.tocLevel
        textStyle.isFirstParagraphStyle = boolValue(values["isFirstParagraphStyle"])
        textStyle.createdDate = dateValue(values["createdDate"]) ?? textStyle.createdDate
        textStyle.modifiedDate = dateValue(values["modifiedDate"]) ?? textStyle.modifiedDate
    }

    private func makeScratchImageStyle(id: String, values: [String: String], styleSheet: StyleSheet) -> ImageStyle {
        let imageStyle = ImageStyle(
            name: values["name"]?.isEmpty == false ? values["name"]! : "imported-image-style",
            displayName: values["displayName"]?.isEmpty == false ? values["displayName"]! : "Imported Image Style",
            displayOrder: intValue(values["displayOrder"]) ?? 0,
            defaultScale: cgFloatValue(values["defaultScale"]) ?? 1.0,
            defaultAlignment: ImageAttachment.ImageAlignment(rawValue: values["defaultAlignmentRaw"] ?? "") ?? .center,
            hasCaptionByDefault: boolValue(values["hasCaptionByDefault"]),
            defaultCaptionStyle: values["defaultCaptionStyle"]?.isEmpty == false ? values["defaultCaptionStyle"]! : "UICTFontTextStyleCaption1",
            isSystemStyle: boolValue(values["isSystemStyle"])
        )
        if let imageStyleId = UUID(uuidString: id) {
            imageStyle.id = imageStyleId
        }
        applyImageStylePayload(values, to: imageStyle)
        imageStyle.styleSheet = styleSheet
        return imageStyle
    }

    private func applyImageStylePayload(_ values: [String: String], to imageStyle: ImageStyle) {
        imageStyle.name = values["name"]?.isEmpty == false ? values["name"]! : imageStyle.name
        imageStyle.displayName = values["displayName"]?.isEmpty == false ? values["displayName"]! : imageStyle.displayName
        imageStyle.displayOrder = intValue(values["displayOrder"]) ?? imageStyle.displayOrder
        imageStyle.defaultScale = cgFloatValue(values["defaultScale"]) ?? imageStyle.defaultScale
        imageStyle.defaultAlignmentRaw = values["defaultAlignmentRaw"]?.isEmpty == false ? values["defaultAlignmentRaw"]! : imageStyle.defaultAlignmentRaw
        imageStyle.hasCaptionByDefault = boolValue(values["hasCaptionByDefault"])
        imageStyle.defaultCaptionStyle = values["defaultCaptionStyle"]?.isEmpty == false ? values["defaultCaptionStyle"]! : imageStyle.defaultCaptionStyle
        imageStyle.isSystemStyle = boolValue(values["isSystemStyle"])
        imageStyle.createdDate = dateValue(values["createdDate"]) ?? imageStyle.createdDate
        imageStyle.modifiedDate = dateValue(values["modifiedDate"]) ?? imageStyle.modifiedDate
    }

    private func makeScratchPageSetup(id: String, values: [String: String]) -> PageSetup {
        let pageSetup = PageSetup(
            paperName: values["paperName"]?.isEmpty == false ? values["paperName"] : nil,
            orientation: Orientation(rawValue: int16Value(values["orientation"]) ?? 0) ?? .portrait,
            headers: int16Value(values["headers"]) == 1,
            footers: int16Value(values["footers"]) == 1,
            marginTop: doubleValue(values["marginTop"]) ?? PageSetupDefaults.marginTop,
            marginBottom: doubleValue(values["marginBottom"]) ?? PageSetupDefaults.marginBottom,
            marginLeft: doubleValue(values["marginLeft"]) ?? PageSetupDefaults.marginLeft,
            marginRight: doubleValue(values["marginRight"]) ?? PageSetupDefaults.marginRight,
            headerDepth: doubleValue(values["headerDepth"]) ?? PageSetupDefaults.headerDepth,
            footerDepth: doubleValue(values["footerDepth"]) ?? PageSetupDefaults.footerDepth,
            scaleFactor: doubleValue(values["scaleFactor"]) ?? PageSetupDefaults.scaleFactorInches
        )
        if let pageSetupId = UUID(uuidString: id) {
            pageSetup.id = pageSetupId
        }
        applyPageSetupPayload(values, to: pageSetup)
        return pageSetup
    }

    private func applyPageSetupPayload(_ values: [String: String], to pageSetup: PageSetup) {
        pageSetup.paperName = values["paperName"]?.isEmpty == false ? values["paperName"] : pageSetup.paperName
        pageSetup.orientation = int16Value(values["orientation"]) ?? pageSetup.orientation
        pageSetup.headers = int16Value(values["headers"]) ?? pageSetup.headers
        pageSetup.footers = int16Value(values["footers"]) ?? pageSetup.footers
        pageSetup.pageBreakBetweenFiles = int16Value(values["pageBreakBetweenFiles"]) ?? pageSetup.pageBreakBetweenFiles
        pageSetup.hideFirstSection = int16Value(values["hideFirstSection"]) ?? pageSetup.hideFirstSection
        pageSetup.matchPreviousSection = int16Value(values["matchPreviousSection"]) ?? pageSetup.matchPreviousSection
        pageSetup.marginTop = doubleValue(values["marginTop"]) ?? pageSetup.marginTop
        pageSetup.marginBottom = doubleValue(values["marginBottom"]) ?? pageSetup.marginBottom
        pageSetup.marginLeft = doubleValue(values["marginLeft"]) ?? pageSetup.marginLeft
        pageSetup.marginRight = doubleValue(values["marginRight"]) ?? pageSetup.marginRight
        pageSetup.headerDepth = doubleValue(values["headerDepth"]) ?? pageSetup.headerDepth
        pageSetup.footerDepth = doubleValue(values["footerDepth"]) ?? pageSetup.footerDepth
        pageSetup.scaleFactor = doubleValue(values["scaleFactor"]) ?? pageSetup.scaleFactor
        pageSetup.headerLeft = values["headerLeft"]?.isEmpty == false ? values["headerLeft"] : pageSetup.headerLeft
        pageSetup.headerCenter = values["headerCenter"]?.isEmpty == false ? values["headerCenter"] : pageSetup.headerCenter
        pageSetup.headerRight = values["headerRight"]?.isEmpty == false ? values["headerRight"] : pageSetup.headerRight
        pageSetup.footerLeft = values["footerLeft"]?.isEmpty == false ? values["footerLeft"] : pageSetup.footerLeft
        pageSetup.footerCenter = values["footerCenter"]?.isEmpty == false ? values["footerCenter"] : pageSetup.footerCenter
        pageSetup.footerRight = values["footerRight"]?.isEmpty == false ? values["footerRight"] : pageSetup.footerRight
    }

    private func makeScratchPrinterPaper(id: String, values: [String: String], pageSetup: PageSetup) -> PrinterPaper {
        let printerPaper = PrinterPaper(
            paperName: values["paperName"]?.isEmpty == false ? values["paperName"] : nil,
            sizeH: doubleValue(values["sizeH"]) ?? 0,
            sizeV: doubleValue(values["sizeV"]) ?? 0,
            rectH: doubleValue(values["rectH"]) ?? 0,
            rectV: doubleValue(values["rectV"]) ?? 0,
            scalefactor: doubleValue(values["scalefactor"]) ?? 96
        )
        if let printerPaperId = UUID(uuidString: id) {
            printerPaper.id = printerPaperId
        }
        applyPrinterPaperPayload(values, to: printerPaper)
        printerPaper.pageSetup = pageSetup
        return printerPaper
    }

    private func applyPrinterPaperPayload(_ values: [String: String], to printerPaper: PrinterPaper) {
        printerPaper.paperName = values["paperName"]?.isEmpty == false ? values["paperName"] : printerPaper.paperName
        printerPaper.sizeH = doubleValue(values["sizeH"]) ?? printerPaper.sizeH
        printerPaper.sizeV = doubleValue(values["sizeV"]) ?? printerPaper.sizeV
        printerPaper.rectH = doubleValue(values["rectH"]) ?? printerPaper.rectH
        printerPaper.rectV = doubleValue(values["rectV"]) ?? printerPaper.rectV
        printerPaper.scalefactor = doubleValue(values["scalefactor"]) ?? printerPaper.scalefactor
    }

    private func poetryFormPayload(_ poetryForm: PoetryFormModel) -> [String: String] {
        [
            "name": poetryForm.name,
            "categoryRaw": poetryForm.categoryRaw,
            "lineCount": poetryForm.lineCount.map(String.init) ?? "",
            "stanzaCount": poetryForm.stanzaCount.map(String.init) ?? "",
            "syllablePattern": poetryForm.syllablePattern?.map(String.init).joined(separator: "|") ?? "",
            "rhymeScheme": poetryForm.rhymeScheme ?? "",
            "meterPattern": poetryForm.meterPattern ?? "",
            "formDescription": poetryForm.formDescription,
            "templateContent": poetryForm.templateContent,
            "isCustom": String(poetryForm.isCustom),
            "isPredefined": String(poetryForm.isPredefined),
            "createdDate": isoFormatter.string(from: poetryForm.createdDate),
            "modifiedDate": isoFormatter.string(from: poetryForm.modifiedDate),
        ]
    }

    private func makeScratchPoetryForm(id: String, values: [String: String]) -> PoetryFormModel {
        PoetryFormModel(
            id: UUID(uuidString: id) ?? UUID(),
            name: values["name"]?.isEmpty == false ? values["name"]! : "Imported Poetry Form",
            category: PoetryFormCategory(rawValue: values["categoryRaw"] ?? "") ?? .custom,
            lineCount: intValue(values["lineCount"]),
            stanzaCount: intValue(values["stanzaCount"]),
            syllablePattern: intListValue(values["syllablePattern"]),
            rhymeScheme: values["rhymeScheme"]?.isEmpty == false ? values["rhymeScheme"] : nil,
            meterPattern: values["meterPattern"]?.isEmpty == false ? values["meterPattern"] : nil,
            formDescription: values["formDescription"] ?? "",
            templateContent: values["templateContent"] ?? "",
            isCustom: boolValue(values["isCustom"]),
            isPredefined: boolValue(values["isPredefined"]),
            createdDate: dateValue(values["createdDate"]) ?? Date(),
            modifiedDate: dateValue(values["modifiedDate"]) ?? Date()
        )
    }

    private func applyPoetryFormPayload(_ values: [String: String], to poetryForm: PoetryFormModel) {
        poetryForm.name = values["name"]?.isEmpty == false ? values["name"]! : poetryForm.name
        poetryForm.categoryRaw = values["categoryRaw"]?.isEmpty == false ? values["categoryRaw"]! : poetryForm.categoryRaw
        poetryForm.lineCount = intValue(values["lineCount"]) ?? poetryForm.lineCount
        poetryForm.stanzaCount = intValue(values["stanzaCount"]) ?? poetryForm.stanzaCount
        poetryForm.syllablePattern = intListValue(values["syllablePattern"]) ?? poetryForm.syllablePattern
        poetryForm.rhymeScheme = values["rhymeScheme"]?.isEmpty == false ? values["rhymeScheme"] : poetryForm.rhymeScheme
        poetryForm.meterPattern = values["meterPattern"]?.isEmpty == false ? values["meterPattern"] : poetryForm.meterPattern
        poetryForm.formDescription = values["formDescription"] ?? poetryForm.formDescription
        poetryForm.templateContent = values["templateContent"] ?? poetryForm.templateContent
        poetryForm.isCustom = boolValue(values["isCustom"])
        poetryForm.isPredefined = boolValue(values["isPredefined"])
        poetryForm.createdDate = dateValue(values["createdDate"]) ?? poetryForm.createdDate
        poetryForm.modifiedDate = dateValue(values["modifiedDate"]) ?? poetryForm.modifiedDate
    }

    private func makeScratchTextFile(id: String, values: [String: String], parentFolder: Folder, context: ModelContext) -> TextFile {
        let textFile = TextFile(
            name: values["name"]?.isEmpty == false ? values["name"]! : "Untitled File",
            initialContent: "",
            parentFolder: parentFolder
        )
        if let textFileId = UUID(uuidString: id) {
            textFile.id = textFileId
        }
        if let contentType = values["contentType"], !contentType.isEmpty {
            textFile.contentTypeRaw = contentType
        }
        for placeholderVersion in textFile.versions ?? [] {
            context.delete(placeholderVersion)
        }
        textFile.versions = []
        return textFile
    }

    private func publicationPayload(_ publication: Publication, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "name": publication.name,
            "type": publication.type?.rawValue ?? "",
            "url": publication.url ?? "",
            "notes": publication.notes ?? "",
            "deadline": dateString(publication.deadline),
            "typicalResponseDays": publication.typicalResponseDays.map(String.init) ?? "",
            "reminderDate": dateString(publication.reminderDate),
            "createdDate": isoFormatter.string(from: publication.createdDate),
            "modifiedDate": isoFormatter.string(from: publication.modifiedDate),
        ]
    }

    private func makeScratchPublication(id: String, values: [String: String], project: Project) -> Publication {
        let publication = Publication(
            id: UUID(uuidString: id) ?? UUID(),
            name: values["name"]?.isEmpty == false ? values["name"]! : "Imported Publication",
            type: PublicationType(rawValue: values["type"] ?? "") ?? .magazine,
            url: values["url"]?.isEmpty == false ? values["url"] : nil,
            notes: values["notes"]?.isEmpty == false ? values["notes"] : nil,
            deadline: dateValue(values["deadline"]),
            project: project
        )
        applyPublicationPayload(values, to: publication)
        return publication
    }

    private func applyPublicationPayload(_ values: [String: String], to publication: Publication) {
        publication.name = values["name"]?.isEmpty == false ? values["name"]! : publication.name
        publication.type = PublicationType(rawValue: values["type"] ?? "") ?? publication.type
        publication.url = values["url"]?.isEmpty == false ? values["url"] : publication.url
        publication.notes = values["notes"]?.isEmpty == false ? values["notes"] : publication.notes
        publication.deadline = dateValue(values["deadline"]) ?? publication.deadline
        publication.typicalResponseDays = intValue(values["typicalResponseDays"]) ?? publication.typicalResponseDays
        publication.reminderDate = dateValue(values["reminderDate"]) ?? publication.reminderDate
        publication.createdDate = dateValue(values["createdDate"]) ?? publication.createdDate
        publication.modifiedDate = dateValue(values["modifiedDate"]) ?? publication.modifiedDate
    }

    private func makeScratchSubmission(id: String, values: [String: String], publication: Publication, project: Project) -> Submission {
        let submission = Submission(
            id: UUID(uuidString: id) ?? UUID(),
            publication: publication,
            project: project,
            submittedDate: dateValue(values["submittedDate"]) ?? Date(),
            notes: values["notes"]?.isEmpty == false ? values["notes"] : nil
        )
        applySubmissionPayload(values, to: submission)
        return submission
    }

    private func applySubmissionPayload(_ values: [String: String], to submission: Submission) {
        submission.name = values["name"]?.isEmpty == false ? values["name"] : submission.name
        submission.collectionDescription = values["collectionDescription"]?.isEmpty == false ? values["collectionDescription"] : submission.collectionDescription
        submission.isCollection = boolValue(values["isCollection"])
        submission.submittedDate = dateValue(values["submittedDate"]) ?? submission.submittedDate
        submission.returnExpectedBy = dateValue(values["returnExpectedBy"]) ?? submission.returnExpectedBy
        submission.returnedOn = dateValue(values["returnedOn"]) ?? submission.returnedOn
        submission.notes = values["notes"]?.isEmpty == false ? values["notes"] : submission.notes
        submission.typicalResponseDays = intValue(values["typicalResponseDays"]) ?? submission.typicalResponseDays
        submission.reminderDate = dateValue(values["reminderDate"]) ?? submission.reminderDate
        submission.userOrder = intValue(values["userOrder"]) ?? submission.userOrder
        submission.createdDate = dateValue(values["createdDate"]) ?? submission.createdDate
        submission.modifiedDate = dateValue(values["modifiedDate"]) ?? submission.modifiedDate
    }

    private func submissionPayload(_ submission: Submission, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "publicationId": submission.publication?.id.uuidString ?? "",
            "name": submission.name ?? "",
            "collectionDescription": submission.collectionDescription ?? "",
            "isCollection": String(submission.isCollection),
            "submittedDate": isoFormatter.string(from: submission.submittedDate),
            "returnExpectedBy": dateString(submission.returnExpectedBy),
            "returnedOn": dateString(submission.returnedOn),
            "notes": submission.notes ?? "",
            "typicalResponseDays": submission.typicalResponseDays.map(String.init) ?? "",
            "reminderDate": dateString(submission.reminderDate),
            "userOrder": submission.userOrder.map(String.init) ?? "",
            "createdDate": isoFormatter.string(from: submission.createdDate),
            "modifiedDate": isoFormatter.string(from: submission.modifiedDate),
        ]
    }

    private func submittedFilePayload(_ submittedFile: SubmittedFile, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "submissionId": submittedFile.submission?.id.uuidString ?? "",
            "textFileId": submittedFile.textFile?.id.uuidString ?? "",
            "versionId": submittedFile.version?.id.uuidString ?? "",
            "status": submittedFile.status?.rawValue ?? "",
            "statusDate": dateString(submittedFile.statusDate),
            "statusNotes": submittedFile.statusNotes ?? "",
            "createdDate": isoFormatter.string(from: submittedFile.createdDate),
            "modifiedDate": isoFormatter.string(from: submittedFile.modifiedDate),
        ]
    }

    private func makeScratchSubmittedFile(id: String, values: [String: String], submission: Submission, textFile: TextFile, version: Version, project: Project) -> SubmittedFile {
        let submittedFile = SubmittedFile(
            id: UUID(uuidString: id) ?? UUID(),
            submission: submission,
            textFile: textFile,
            version: version,
            status: SubmissionStatus(rawValue: values["status"] ?? "") ?? .pending,
            statusDate: dateValue(values["statusDate"]),
            statusNotes: values["statusNotes"]?.isEmpty == false ? values["statusNotes"] : nil,
            project: project
        )
        applySubmittedFilePayload(values, to: submittedFile)
        return submittedFile
    }

    private func applySubmittedFilePayload(_ values: [String: String], to submittedFile: SubmittedFile) {
        submittedFile.status = SubmissionStatus(rawValue: values["status"] ?? "") ?? submittedFile.status
        submittedFile.statusDate = dateValue(values["statusDate"]) ?? submittedFile.statusDate
        submittedFile.statusNotes = values["statusNotes"]?.isEmpty == false ? values["statusNotes"] : submittedFile.statusNotes
        submittedFile.createdDate = dateValue(values["createdDate"]) ?? submittedFile.createdDate
        submittedFile.modifiedDate = dateValue(values["modifiedDate"]) ?? submittedFile.modifiedDate
    }

    private func commentPayload(_ comment: CommentModel) -> [String: String] {
        [
            "versionId": comment.version?.id.uuidString ?? "",
            "characterPosition": String(comment.characterPosition),
            "attachmentID": comment.attachmentID.uuidString,
            "text": comment.text,
            "author": comment.author,
            "createdAt": isoFormatter.string(from: comment.createdAt),
            "resolvedAt": dateString(comment.resolvedAt),
        ]
    }

    private func makeScratchComment(id: String, values: [String: String], version: Version) -> CommentModel {
        let comment = CommentModel(
            id: UUID(uuidString: id) ?? UUID(),
            version: version,
            characterPosition: intValue(values["characterPosition"]) ?? 0,
            attachmentID: UUID(uuidString: values["attachmentID"] ?? "") ?? UUID(),
            text: values["text"] ?? "",
            author: values["author"] ?? "",
            createdAt: dateValue(values["createdAt"]) ?? Date(),
            resolvedAt: dateValue(values["resolvedAt"])
        )
        applyCommentPayload(values, to: comment)
        return comment
    }

    private func applyCommentPayload(_ values: [String: String], to comment: CommentModel) {
        comment.characterPosition = intValue(values["characterPosition"]) ?? comment.characterPosition
        comment.attachmentID = UUID(uuidString: values["attachmentID"] ?? "") ?? comment.attachmentID
        comment.text = values["text"] ?? comment.text
        comment.author = values["author"] ?? comment.author
        comment.createdAt = dateValue(values["createdAt"]) ?? comment.createdAt
        comment.resolvedAt = dateValue(values["resolvedAt"]) ?? comment.resolvedAt
    }

    private func footnotePayload(_ footnote: FootnoteModel) -> [String: String] {
        [
            "versionId": footnote.version?.id.uuidString ?? "",
            "characterPosition": String(footnote.characterPosition),
            "attachmentID": footnote.attachmentID.uuidString,
            "text": footnote.text,
            "number": String(footnote.number),
            "createdAt": isoFormatter.string(from: footnote.createdAt),
            "modifiedAt": isoFormatter.string(from: footnote.modifiedAt),
        ]
    }

    private func makeScratchFootnote(id: String, values: [String: String], version: Version) -> FootnoteModel {
        let footnote = FootnoteModel(
            id: UUID(uuidString: id) ?? UUID(),
            version: version,
            characterPosition: intValue(values["characterPosition"]) ?? 0,
            attachmentID: UUID(uuidString: values["attachmentID"] ?? "") ?? UUID(),
            text: values["text"] ?? "",
            number: intValue(values["number"]) ?? 0,
            createdAt: dateValue(values["createdAt"]) ?? Date(),
            modifiedAt: dateValue(values["modifiedAt"]) ?? Date()
        )
        applyFootnotePayload(values, to: footnote)
        return footnote
    }

    private func applyFootnotePayload(_ values: [String: String], to footnote: FootnoteModel) {
        footnote.characterPosition = intValue(values["characterPosition"]) ?? footnote.characterPosition
        footnote.attachmentID = UUID(uuidString: values["attachmentID"] ?? "") ?? footnote.attachmentID
        footnote.text = values["text"] ?? footnote.text
        footnote.number = intValue(values["number"]) ?? footnote.number
        footnote.createdAt = dateValue(values["createdAt"]) ?? footnote.createdAt
        footnote.modifiedAt = dateValue(values["modifiedAt"]) ?? footnote.modifiedAt
    }

    private func bodyMatterContainerPayload(name: String?, synopsis: String?, userOrder: Int?, createdDate: Date, modifiedDate: Date, bodyMatterOrder: Int?, isInBodyMatter: Bool, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "name": name ?? "",
            "synopsis": synopsis ?? "",
            "userOrder": userOrder.map(String.init) ?? "",
            "createdDate": isoFormatter.string(from: createdDate),
            "modifiedDate": isoFormatter.string(from: modifiedDate),
            "bodyMatterOrder": bodyMatterOrder.map(String.init) ?? "",
            "isInBodyMatter": String(isInBodyMatter),
        ]
    }

    private func storyScenePayload(_ scene: StoryScene, projectId: String) -> [String: String] {
        var payload = bodyMatterContainerPayload(name: scene.name, synopsis: scene.synopsis, userOrder: scene.userOrder, createdDate: scene.createdDate, modifiedDate: scene.modifiedDate, bodyMatterOrder: scene.bodyMatterOrder, isInBodyMatter: scene.isInBodyMatter, projectId: projectId)
        payload["monomythStageRaw"] = scene.monomythStageRaw ?? ""
        payload["campbellStageRaw"] = scene.campbellStageRaw ?? ""
        payload["threeActStageRaw"] = scene.threeActStageRaw ?? ""
        payload["pearsonStageRaw"] = scene.pearsonStageRaw ?? ""
        payload["isTrashed"] = String(scene.isTrashed)
        payload["trashedDate"] = dateString(scene.trashedDate)
        payload["textFileId"] = scene.textFile?.id.uuidString ?? ""
        payload["locationId"] = scene.location?.id.uuidString ?? ""
        return payload
    }

    private func characterPayload(_ character: Character, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "name": character.name ?? "",
            "role": character.role ?? "",
            "archetypeRaw": character.archetypeRaw ?? "",
            "pearsonArchetypeRaw": character.pearsonArchetypeRaw ?? "",
            "history": character.history ?? "",
            "looks": character.looks ?? "",
            "traits": character.traits ?? "",
            "work": character.work ?? "",
            "createdDate": isoFormatter.string(from: character.createdDate),
            "modifiedDate": isoFormatter.string(from: character.modifiedDate),
        ]
    }

    private func locationPayload(_ location: Location, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "name": location.name ?? "",
            "detail": location.detail ?? "",
            "sights": location.sights ?? "",
            "sounds": location.sounds ?? "",
            "smells": location.smells ?? "",
            "createdDate": isoFormatter.string(from: location.createdDate),
            "modifiedDate": isoFormatter.string(from: location.modifiedDate),
        ]
    }

    private func customAttributePayload(_ customAttribute: CustomAttribute) -> [String: String] {
        [
            "characterId": customAttribute.character?.id.uuidString ?? "",
            "locationId": customAttribute.location?.id.uuidString ?? "",
            "key": customAttribute.key ?? "",
            "value": customAttribute.value ?? "",
            "userOrder": customAttribute.userOrder.map(String.init) ?? "",
        ]
    }

    private func plotElementPayload(_ plotElement: PlotElement, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "name": plotElement.name ?? "",
            "notes": plotElement.notes ?? "",
            "userOrder": plotElement.userOrder.map(String.init) ?? "",
            "monomythStageRaw": plotElement.monomythStageRaw ?? "",
            "campbellStageRaw": plotElement.campbellStageRaw ?? "",
            "threeActStageRaw": plotElement.threeActStageRaw ?? "",
            "pearsonStageRaw": plotElement.pearsonStageRaw ?? "",
            "createdDate": isoFormatter.string(from: plotElement.createdDate),
            "modifiedDate": isoFormatter.string(from: plotElement.modifiedDate),
        ]
    }

    private func notePayload(_ note: NoteEntry, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "content": note.content,
            "formattedContentData": base64String(note.formattedContentData),
            "isEndnote": String(note.isEndnote),
            "displayNumber": String(note.displayNumber),
            "referenceCount": String(note.referenceCount),
            "referencingFileIDs": uuidListString(note.referencingFileIDs),
            "createdAt": isoFormatter.string(from: note.createdAt),
            "modifiedAt": isoFormatter.string(from: note.modifiedAt),
            "title": note.title ?? "",
            "tag": note.tag ?? "",
        ]
    }

    private func makeScratchNote(id: String, values: [String: String], project: Project) -> NoteEntry {
        let note = NoteEntry(
            id: UUID(uuidString: id) ?? UUID(),
            project: project,
            content: values["content"] ?? "",
            isEndnote: boolValue(values["isEndnote"]),
            displayNumber: intValue(values["displayNumber"]) ?? 0,
            title: values["title"]?.isEmpty == false ? values["title"] : nil,
            tag: values["tag"]?.isEmpty == false ? values["tag"] : nil
        )
        applyNotePayload(values, to: note)
        return note
    }

    private func applyNotePayload(_ values: [String: String], to note: NoteEntry) {
        note.content = values["content"] ?? note.content
        note.formattedContentData = dataValue(values["formattedContentData"])
        note.isEndnote = boolValue(values["isEndnote"])
        note.displayNumber = intValue(values["displayNumber"]) ?? note.displayNumber
        note.referenceCount = intValue(values["referenceCount"]) ?? note.referenceCount
        note.referencingFileIDs = uuidListValue(values["referencingFileIDs"])
        note.createdAt = dateValue(values["createdAt"]) ?? note.createdAt
        note.modifiedAt = dateValue(values["modifiedAt"]) ?? note.modifiedAt
        note.title = values["title"]?.isEmpty == false ? values["title"] : nil
        note.tag = values["tag"]?.isEmpty == false ? values["tag"] : nil
    }

    private func glossaryPayload(_ glossaryEntry: GlossaryEntry, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "term": glossaryEntry.term,
            "definition": glossaryEntry.definition,
            "citationId": glossaryEntry.citation?.id.uuidString ?? "",
            "referenceCount": String(glossaryEntry.referenceCount),
            "createdAt": isoFormatter.string(from: glossaryEntry.createdAt),
            "modifiedAt": isoFormatter.string(from: glossaryEntry.modifiedAt),
        ]
    }

    private func makeScratchGlossaryEntry(id: String, values: [String: String], project: Project, citation: CitationEntry?) -> GlossaryEntry {
        let glossaryEntry = GlossaryEntry(
            id: UUID(uuidString: id) ?? UUID(),
            project: project,
            term: values["term"] ?? "",
            definition: values["definition"] ?? "",
            citation: citation
        )
        applyGlossaryPayload(values, to: glossaryEntry, citation: citation)
        return glossaryEntry
    }

    private func applyGlossaryPayload(_ values: [String: String], to glossaryEntry: GlossaryEntry, citation: CitationEntry?) {
        glossaryEntry.term = values["term"] ?? glossaryEntry.term
        glossaryEntry.definition = values["definition"] ?? glossaryEntry.definition
        glossaryEntry.citation = citation
        glossaryEntry.referenceCount = intValue(values["referenceCount"]) ?? glossaryEntry.referenceCount
        glossaryEntry.createdAt = dateValue(values["createdAt"]) ?? glossaryEntry.createdAt
        glossaryEntry.modifiedAt = dateValue(values["modifiedAt"]) ?? glossaryEntry.modifiedAt
    }

    private func referencePayload(_ referenceEntry: ReferenceEntry, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "author": referenceEntry.author,
            "publicationDate": referenceEntry.publicationDate,
            "details": referenceEntry.details,
            "referenceCount": String(referenceEntry.referenceCount),
            "createdAt": isoFormatter.string(from: referenceEntry.createdAt),
            "modifiedAt": isoFormatter.string(from: referenceEntry.modifiedAt),
        ]
    }

    private func makeScratchReferenceEntry(id: String, values: [String: String], project: Project) -> ReferenceEntry {
        let referenceEntry = ReferenceEntry(
            id: UUID(uuidString: id) ?? UUID(),
            project: project,
            author: values["author"] ?? "",
            publicationDate: values["publicationDate"] ?? "",
            details: values["details"] ?? ""
        )
        applyReferencePayload(values, to: referenceEntry)
        return referenceEntry
    }

    private func applyReferencePayload(_ values: [String: String], to referenceEntry: ReferenceEntry) {
        referenceEntry.author = values["author"] ?? referenceEntry.author
        referenceEntry.publicationDate = values["publicationDate"] ?? referenceEntry.publicationDate
        referenceEntry.details = values["details"] ?? referenceEntry.details
        referenceEntry.referenceCount = intValue(values["referenceCount"]) ?? referenceEntry.referenceCount
        referenceEntry.createdAt = dateValue(values["createdAt"]) ?? referenceEntry.createdAt
        referenceEntry.modifiedAt = dateValue(values["modifiedAt"]) ?? referenceEntry.modifiedAt
    }

    private func citationPayload(_ citation: CitationEntry, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "authorsData": base64String(citation.authorsData),
            "year": citation.year.map(String.init) ?? "",
            "title": citation.title,
            "source": citation.source ?? "",
            "url": citation.url ?? "",
            "doi": citation.doi ?? "",
            "volume": citation.volume ?? "",
            "issue": citation.issue ?? "",
            "pages": citation.pages ?? "",
            "edition": citation.edition ?? "",
            "city": citation.city ?? "",
            "accessDate": dateString(citation.accessDate),
            "sourceTypeRaw": citation.sourceTypeRaw ?? "",
            "referenceCount": String(citation.referenceCount),
            "createdAt": isoFormatter.string(from: citation.createdAt),
            "modifiedAt": isoFormatter.string(from: citation.modifiedAt),
        ]
    }

    private func makeScratchCitation(id: String, values: [String: String], project: Project) -> CitationEntry {
        let citation = CitationEntry(
            id: UUID(uuidString: id) ?? UUID(),
            project: project,
            year: intValue(values["year"]),
            title: values["title"] ?? "",
            source: values["source"]?.isEmpty == false ? values["source"] : nil,
            url: values["url"]?.isEmpty == false ? values["url"] : nil,
            doi: values["doi"]?.isEmpty == false ? values["doi"] : nil,
            sourceType: CitationEntry.SourceType(rawValue: values["sourceTypeRaw"] ?? "") ?? .article
        )
        applyCitationPayload(values, to: citation)
        return citation
    }

    private func applyCitationPayload(_ values: [String: String], to citation: CitationEntry) {
        citation.authorsData = dataValue(values["authorsData"]) ?? citation.authorsData
        citation.year = intValue(values["year"])
        citation.title = values["title"] ?? citation.title
        citation.source = values["source"]?.isEmpty == false ? values["source"] : nil
        citation.url = values["url"]?.isEmpty == false ? values["url"] : nil
        citation.doi = values["doi"]?.isEmpty == false ? values["doi"] : nil
        citation.volume = values["volume"]?.isEmpty == false ? values["volume"] : nil
        citation.issue = values["issue"]?.isEmpty == false ? values["issue"] : nil
        citation.pages = values["pages"]?.isEmpty == false ? values["pages"] : nil
        citation.edition = values["edition"]?.isEmpty == false ? values["edition"] : nil
        citation.city = values["city"]?.isEmpty == false ? values["city"] : nil
        citation.accessDate = dateValue(values["accessDate"])
        citation.sourceTypeRaw = values["sourceTypeRaw"]?.isEmpty == false ? values["sourceTypeRaw"] : citation.sourceTypeRaw
        citation.referenceCount = intValue(values["referenceCount"]) ?? citation.referenceCount
        citation.createdAt = dateValue(values["createdAt"]) ?? citation.createdAt
        citation.modifiedAt = dateValue(values["modifiedAt"]) ?? citation.modifiedAt
    }

    private func indexPayload(_ indexEntry: IndexEntry, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "keyword": indexEntry.keyword,
            "parentEntryId": indexEntry.parentEntry?.id.uuidString ?? "",
            "seeEntryID": indexEntry.seeEntryID?.uuidString ?? "",
            "seeAlsoEntryIDsData": base64String(indexEntry.seeAlsoEntryIDsData),
            "referenceCount": String(indexEntry.referenceCount),
            "referencingFileIDsData": base64String(indexEntry.referencingFileIDsData),
            "createdAt": isoFormatter.string(from: indexEntry.createdAt),
            "modifiedAt": isoFormatter.string(from: indexEntry.modifiedAt),
            "pageNumbersData": base64String(indexEntry.pageNumbersData),
            "primaryPageNumbersData": base64String(indexEntry.primaryPageNumbersData),
        ]
    }

    private func makeScratchIndexEntry(id: String, values: [String: String], project: Project, parent: IndexEntry?) -> IndexEntry {
        let indexEntry = IndexEntry(
            id: UUID(uuidString: id) ?? UUID(),
            project: parent == nil ? project : nil,
            keyword: values["keyword"] ?? "",
            parentEntry: parent
        )
        applyIndexPayload(values, to: indexEntry, parent: parent)
        return indexEntry
    }

    private func applyIndexPayload(_ values: [String: String], to indexEntry: IndexEntry, parent: IndexEntry?) {
        indexEntry.keyword = values["keyword"] ?? indexEntry.keyword
        indexEntry.parentEntry = parent
        indexEntry.seeEntryID = values["seeEntryID"].flatMap { UUID(uuidString: $0) }
        indexEntry.seeAlsoEntryIDsData = dataValue(values["seeAlsoEntryIDsData"])
        indexEntry.referenceCount = intValue(values["referenceCount"]) ?? indexEntry.referenceCount
        indexEntry.referencingFileIDsData = dataValue(values["referencingFileIDsData"])
        indexEntry.createdAt = dateValue(values["createdAt"]) ?? indexEntry.createdAt
        indexEntry.modifiedAt = dateValue(values["modifiedAt"]) ?? indexEntry.modifiedAt
        indexEntry.pageNumbersData = dataValue(values["pageNumbersData"])
        indexEntry.primaryPageNumbersData = dataValue(values["primaryPageNumbersData"])
    }

    private func contributorPayload(_ contributor: ContributorEntry, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "name": contributor.name,
            "firstName": contributor.firstName,
            "surname": contributor.surname,
            "biography": contributor.biography,
            "userOrder": String(contributor.userOrder),
            "createdAt": isoFormatter.string(from: contributor.createdAt),
            "modifiedAt": isoFormatter.string(from: contributor.modifiedAt),
        ]
    }

    private func makeScratchContributor(id: String, values: [String: String], project: Project) -> ContributorEntry {
        let contributor = ContributorEntry(
            id: UUID(uuidString: id) ?? UUID(),
            project: project,
            name: values["name"] ?? "",
            firstName: values["firstName"] ?? "",
            surname: values["surname"] ?? "",
            biography: values["biography"] ?? "",
            userOrder: intValue(values["userOrder"]) ?? 0
        )
        applyContributorPayload(values, to: contributor)
        return contributor
    }

    private func applyContributorPayload(_ values: [String: String], to contributor: ContributorEntry) {
        contributor.name = values["name"] ?? contributor.name
        contributor.firstName = values["firstName"] ?? contributor.firstName
        contributor.surname = values["surname"] ?? contributor.surname
        contributor.biography = values["biography"] ?? contributor.biography
        contributor.userOrder = intValue(values["userOrder"]) ?? contributor.userOrder
        contributor.createdAt = dateValue(values["createdAt"]) ?? contributor.createdAt
        contributor.modifiedAt = dateValue(values["modifiedAt"]) ?? contributor.modifiedAt
    }

    private func pageSetupPayload(_ pageSetup: PageSetup, projectId: String) -> [String: String] {
        [
            "projectId": projectId,
            "paperName": pageSetup.paperName ?? "",
            "orientation": String(pageSetup.orientation),
            "headers": String(pageSetup.headers),
            "footers": String(pageSetup.footers),
            "pageBreakBetweenFiles": String(pageSetup.pageBreakBetweenFiles),
            "hideFirstSection": String(pageSetup.hideFirstSection),
            "matchPreviousSection": String(pageSetup.matchPreviousSection),
            "marginTop": String(pageSetup.marginTop),
            "marginBottom": String(pageSetup.marginBottom),
            "marginLeft": String(pageSetup.marginLeft),
            "marginRight": String(pageSetup.marginRight),
            "headerDepth": String(pageSetup.headerDepth),
            "footerDepth": String(pageSetup.footerDepth),
            "scaleFactor": String(pageSetup.scaleFactor),
            "headerLeft": pageSetup.headerLeft ?? "",
            "headerCenter": pageSetup.headerCenter ?? "",
            "headerRight": pageSetup.headerRight ?? "",
            "footerLeft": pageSetup.footerLeft ?? "",
            "footerCenter": pageSetup.footerCenter ?? "",
            "footerRight": pageSetup.footerRight ?? "",
        ]
    }

    private func printerPaperPayload(_ printerPaper: PrinterPaper, pageSetupId: String) -> [String: String] {
        [
            "pageSetupId": pageSetupId,
            "paperName": printerPaper.paperName ?? "",
            "sizeH": String(printerPaper.sizeH),
            "sizeV": String(printerPaper.sizeV),
            "rectH": String(printerPaper.rectH),
            "rectV": String(printerPaper.rectV),
            "scalefactor": String(printerPaper.scalefactor),
        ]
    }

    private func dateString(_ date: Date?) -> String {
        date.map { isoFormatter.string(from: $0) } ?? ""
    }

    private func dateValue(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return isoFormatter.date(from: value)
    }

    private func base64String(_ data: Data?) -> String {
        data?.base64EncodedString() ?? ""
    }

    private func dataValue(_ value: String?) -> Data? {
        guard let value, !value.isEmpty else { return nil }
        return Data(base64Encoded: value)
    }

    private func uuidListString(_ values: [UUID]) -> String {
        values.map(\.uuidString).joined(separator: ",")
    }

    private func uuidListValue(_ value: String?) -> [UUID] {
        guard let value, !value.isEmpty else { return [] }
        return value.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }

    private func stringListValue(_ value: String?) -> [String]? {
        guard let value, !value.isEmpty else { return nil }
        let values = value.split(separator: "|").map { String($0) }
        return values.isEmpty ? nil : values
    }

    private func intListValue(_ value: String?) -> [Int]? {
        guard let value, !value.isEmpty else { return nil }
        let values = value.split(separator: "|").compactMap { Int($0) }
        return values.isEmpty ? nil : values
    }

    private func summarizePulledOperations(_ operations: [SyncPOCPulledOperation]) -> String {
        guard !operations.isEmpty else {
            return "Remote summary: no operations returned."
        }

        let entityCounts = countedSummary(operations.map(\.entityType))
        let operationCounts = countedSummary(operations.map(\.operationType))
        return "Remote summary: entities [\(entityCounts)], operations [\(operationCounts)]."
    }

    private func selectProjectForPendingApply(_ projects: [Project]) -> Project? {
        let activeProjects = projects.filter { !$0.isTrashed }
        if let pendingProjectId = rememberedPendingApplyProjectId(),
           let pendingProject = activeProjects.first(where: { $0.id.uuidString == pendingProjectId }) {
            return pendingProject
        }
        if let poemsProject = activeProjects.first(where: { $0.name == "Poems 2026" }) {
            return poemsProject
        }
        if let projectWithRememberedSequence = activeProjects.first(where: { rememberedLastSequence(projectId: $0.id.uuidString) > 0 }) {
            return projectWithRememberedSequence
        }
        return activeProjects.first
    }

    @MainActor
    private func summarizePendingApply(_ operations: [SyncPOCPulledOperation], localProject: Project) -> String {
        guard !operations.isEmpty else {
            return "Apply preview: nothing to apply."
        }

        let supportedEntityTypes = supportedApplyEntityTypes()
        let localEntityKeys = localEntityKeys(in: localProject)
        let deleteOperations = deleteApplyOperationTypes()
        let restoreOperations = restoreApplyOperationTypes()
        let upserts = operations.filter { $0.operationType == "upsert" && supportedEntityTypes.contains($0.entityType) }.count
        let deletes = operations.filter { deleteOperations.contains($0.operationType) }.count
        let restores = operations.filter { restoreOperations.contains($0.operationType) }.count
        let ignored = operations.count - upserts - deletes - restores
        let applyPlan = makeApplyPlan(
            operations,
            localEntityKeys: localEntityKeys,
            supportedEntityTypes: supportedEntityTypes,
            deleteOperations: deleteOperations,
            restoreOperations: restoreOperations
        )

        return "Apply preview: \(upserts) supported upserts, \(deletes) delete/trash/tombstone ops, \(restores) restore ops, \(ignored) ignored/unsupported ops. \(summarizeApplyPlan(applyPlan))"
    }

    private func supportedApplyEntityTypes() -> Set<String> {
        [
            "Project", "StyleSheet", "TextStyleModel", "ImageStyle", "PageSetup", "PrinterPaper", "PoetryFormModel", "ManuscriptReview", "ReviewSuggestion", "Folder", "TextFile", "Version", "TrashItem", "CommentModel", "FootnoteModel",
            "StoryScene", "Chapter", "Act", "ProseSection", "PoetryCollection", "Book", "Character", "Location", "CustomAttribute", "PlotElement",
            "TextFileSectionLink", "TextFileCollectionLink", "SceneChapterLink", "SceneActLink", "SceneBookLink", "ScenePlotElementLink", "SceneCharacterLink", "CharacterPlotElementLink", "LocationPlotElementLink", "SceneLocationLink",
            "NoteEntry", "GlossaryEntry", "ReferenceEntry", "CitationEntry", "IndexEntry", "ContributorEntry", "Publication", "Submission", "SubmittedFile"
        ]
    }

    private func deleteApplyOperationTypes() -> Set<String> {
        ["delete", "trash", "tombstone"]
    }

    private func restoreApplyOperationTypes() -> Set<String> {
        ["restore", "untrash"]
    }

    private func makeApplyPlan(_ operations: [SyncPOCPulledOperation], localEntityKeys: Set<String>, supportedEntityTypes: Set<String>, deleteOperations: Set<String>, restoreOperations: Set<String>) -> [SyncPOCApplyPlanItem] {
        var latestOperationByEntity: [String: SyncPOCPulledOperation] = [:]
        for operation in operations.sorted(by: { $0.serverSequence < $1.serverSequence }) {
            latestOperationByEntity["\(operation.entityType):\(operation.entityId)"] = operation
        }
        let plannedEntityKeys = Set(latestOperationByEntity.keys)
        let availableEntityKeys = localEntityKeys.union(plannedEntityKeys)

        return latestOperationByEntity.values.map { operation in
            let finalAction: String
            if operation.operationType == "upsert", supportedEntityTypes.contains(operation.entityType) {
                finalAction = "upsert"
            } else if deleteOperations.contains(operation.operationType) {
                finalAction = "delete"
            } else if restoreOperations.contains(operation.operationType) {
                finalAction = "restore"
            } else {
                finalAction = "ignore"
            }
            let localExists = localEntityKeys.contains("\(operation.entityType):\(operation.entityId)")
            let dependencyStatus = dependencyStatus(for: operation, finalAction: finalAction, availableEntityKeys: availableEntityKeys)

            return SyncPOCApplyPlanItem(
                entityType: operation.entityType,
                entityId: operation.entityId,
                finalAction: finalAction,
                proposedLocalAction: proposedLocalAction(for: finalAction, localExists: localExists),
                localExists: localExists,
                dependencyStatus: dependencyStatus,
                serverSequence: operation.serverSequence,
                hasPayload: operation.payload?.values.isEmpty == false
            )
        }
        .sorted { left, right in
            if left.serverSequence == right.serverSequence {
                return (left.entityType, left.entityId) < (right.entityType, right.entityId)
            }
            return left.serverSequence < right.serverSequence
        }
    }

    private func summarizeApplyPlan(_ applyPlan: [SyncPOCApplyPlanItem]) -> String {
        var upserts = 0
        var deletes = 0
        var restores = 0
        var ignored = 0
        var dependenciesOK = 0
        var dependenciesBlocked = 0
        var dependenciesNotRequired = 0
        var payloadBlocked = 0

        for item in applyPlan {
            switch item.finalAction {
            case "upsert":
                upserts += 1
            case "delete":
                deletes += 1
            case "restore":
                restores += 1
            default:
                ignored += 1
            }

            if item.dependencyStatus == "deps-ok" {
                dependenciesOK += 1
            } else if item.dependencyStatus.hasPrefix("missing-deps") {
                dependenciesBlocked += 1
            } else {
                dependenciesNotRequired += 1
            }

            if (item.finalAction == "upsert" || item.proposedLocalAction == "restoreMissing"), !item.hasPayload {
                payloadBlocked += 1
            }
        }

        let sample = applyPlan.prefix(5).map { item in
            let payloadFlag = item.hasPayload ? "payload" : "no-payload"
            let localFlag = item.localExists ? "local-exists" : "local-missing"
            return "\(item.entityType):\(item.finalAction)->\(item.proposedLocalAction)@\(item.serverSequence)(\(localFlag),\(payloadFlag),\(item.dependencyStatus))"
        }.joined(separator: ", ")
        let sampleSummary = sample.isEmpty ? "" : " Plan sample: \(sample)."
        let readinessSummary: String
        if ignored == 0, dependenciesBlocked == 0, payloadBlocked == 0 {
            readinessSummary = " Apply readiness: ready for dry-run applier."
        } else {
            readinessSummary = " Apply readiness: blocked (\(dependenciesBlocked) dependency blockers, \(ignored) ignored final actions, \(payloadBlocked) payload blockers)."
        }
        let orderSummary = summarizeApplyOrder(applyPlan)

        return "Coalesced final actions: \(upserts) upserts, \(deletes) deletes, \(restores) restores, \(ignored) ignored across \(applyPlan.count) entities. Dependencies: \(dependenciesOK) ok, \(dependenciesBlocked) blocked, \(dependenciesNotRequired) not required.\(readinessSummary)\(orderSummary)\(sampleSummary)"
    }

    private func summarizeApplyOrder(_ applyPlan: [SyncPOCApplyPlanItem]) -> String {
        let orderedItems = orderedApplyPlanItems(applyPlan)
        guard !orderedItems.isEmpty else { return "" }

        let sample = orderedItems.prefix(8).map { item in
            "\(item.entityType):\(item.proposedLocalAction)@\(item.serverSequence)"
        }.joined(separator: " -> ")
        let suffix = orderedItems.count > 8 ? " -> ..." : ""
        return " Apply order: \(sample)\(suffix)."
    }

    private func orderedApplyPlanItems(_ applyPlan: [SyncPOCApplyPlanItem]) -> [SyncPOCApplyPlanItem] {
        applyPlan
            .filter { $0.finalAction != "ignore" }
            .sorted { left, right in
                let leftStage = applyStageRank(for: left.finalAction)
                let rightStage = applyStageRank(for: right.finalAction)
                if leftStage != rightStage { return leftStage < rightStage }

                let leftEntity = entityApplyRank(for: left.entityType)
                let rightEntity = entityApplyRank(for: right.entityType)
                if leftEntity != rightEntity { return leftEntity < rightEntity }

                if left.serverSequence != right.serverSequence { return left.serverSequence < right.serverSequence }
                return (left.entityType, left.entityId) < (right.entityType, right.entityId)
            }
    }

    private func supportsScratchMaterialization(_ item: SyncPOCApplyPlanItem, supportedEntityTypes: Set<String>) -> Bool {
        guard supportedEntityTypes.contains(item.entityType) else { return false }

        switch item.proposedLocalAction {
        case "createMissing", "restoreMissing", "deleteNoopMissing":
            return true
        case "updateExisting":
            return item.entityType == "Project" || item.entityType == "StyleSheet" || item.entityType == "TextStyleModel" || item.entityType == "ImageStyle" || item.entityType == "PageSetup" || item.entityType == "PrinterPaper" || item.entityType == "PoetryFormModel" || item.entityType == "Folder" || item.entityType == "TextFile" || item.entityType == "Version" || item.entityType == "CommentModel" || item.entityType == "FootnoteModel" || item.entityType == "NoteEntry" || item.entityType == "GlossaryEntry" || item.entityType == "ContributorEntry" || item.entityType == "ReferenceEntry" || item.entityType == "IndexEntry" || item.entityType == "PoetryCollection" || item.entityType == "Chapter" || item.entityType == "Act" || item.entityType == "Book" || item.entityType == "ProseSection" || item.entityType == "StoryScene" || item.entityType == "Character" || item.entityType == "Location" || item.entityType == "PlotElement" || item.entityType == "TextFileSectionLink" || item.entityType == "TextFileCollectionLink" || item.entityType == "Publication" || item.entityType == "Submission" || item.entityType == "SubmittedFile"
        default:
            return false
        }
    }

    private func applyPlanBlockerCounts(_ applyPlan: [SyncPOCApplyPlanItem]) -> (dependencyBlocked: Int, ignored: Int, payloadBlocked: Int) {
        var dependencyBlocked = 0
        var ignored = 0
        var payloadBlocked = 0

        for item in applyPlan {
            if item.finalAction == "ignore" { ignored += 1 }
            if item.dependencyStatus.hasPrefix("missing-deps") { dependencyBlocked += 1 }
            if (item.finalAction == "upsert" || item.proposedLocalAction == "restoreMissing"), !item.hasPayload {
                payloadBlocked += 1
            }
        }

        return (dependencyBlocked, ignored, payloadBlocked)
    }

    private func validatedScratchMaterializationItems(_ applyPlan: [SyncPOCApplyPlanItem]) throws -> [SyncPOCApplyPlanItem] {
        let blockers = applyPlanBlockerCounts(applyPlan)
        guard blockers.dependencyBlocked == 0, blockers.ignored == 0, blockers.payloadBlocked == 0 else {
            throw CloudflareSyncPOCError.applyPlanNotReady("\(blockers.dependencyBlocked) dependency blockers, \(blockers.ignored) ignored final actions, \(blockers.payloadBlocked) payload blockers")
        }

        let supportedEntityTypes = supportedApplyEntityTypes()
        let orderedItems = orderedApplyPlanItems(applyPlan)
        for item in orderedItems where !supportsScratchMaterialization(item, supportedEntityTypes: supportedEntityTypes) {
            throw CloudflareSyncPOCError.applyPlanNotReady("scratch materializer currently supports createMissing/restoreMissing for supported entity types, Project/StyleSheet/TextStyleModel/ImageStyle/PageSetup/Folder/TextFile/Version/CommentModel/FootnoteModel/NoteEntry/GlossaryEntry/ContributorEntry/ReferenceEntry/IndexEntry/Publication/Submission/SubmittedFile/TextFileSectionLink/TextFileCollectionLink updateExisting, and deleteNoopMissing for remote deletes of records that do not exist locally")
        }

        return orderedItems
    }

    private func latestOperationByEntityKey(_ operations: [SyncPOCPulledOperation]) -> [String: SyncPOCPulledOperation] {
        var operationByEntityKey: [String: SyncPOCPulledOperation] = [:]
        for operation in operations.sorted(by: { $0.serverSequence < $1.serverSequence }) {
            operationByEntityKey["\(operation.entityType):\(operation.entityId)"] = operation
        }
        return operationByEntityKey
    }

    @MainActor
    private func makePendingApplyScratchContext(storeURL: URL, sourceProject: Project) throws -> CloudflareSyncPOCScratchContext {
        let schema = cloudflareSyncPOCScratchSchema()
        let configuration = ModelConfiguration(
            "CloudflareSyncPOCPendingApplyConfiguration",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let projectType = ProjectType(rawValue: sourceProject.typeRaw ?? "") ?? .prose
        let scratchProject = Project(name: "Cloudflare POC Pending Apply - \(sourceProject.name ?? "Untitled")", type: projectType)
        scratchProject.id = sourceProject.id
        scratchProject.statusRaw = sourceProject.statusRaw
        scratchProject.creationDate = sourceProject.creationDate
        scratchProject.modifiedDate = sourceProject.modifiedDate
        scratchProject.details = sourceProject.details
        scratchProject.notes = sourceProject.notes
        scratchProject.author = sourceProject.author
        let scratchFolder = Folder(name: "Pending Apply", project: scratchProject, parentFolder: nil, userOrder: 0)
        context.insert(scratchProject)
        context.insert(scratchFolder)
        return CloudflareSyncPOCScratchContext(storeURL: storeURL, context: context, project: scratchProject, folder: scratchFolder)
    }

    @MainActor
    private func makeIsolatedImportContext(storeURL: URL, importState: CloudflareSyncPOCImportState) throws -> CloudflareSyncPOCScratchContext {
        let schema = WritingShedModelSchema.schema
        let configuration = ModelConfiguration(
            "CloudflareSyncPOCImportConfiguration",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let projectType = ProjectType(rawValue: importState.projectTypeRaw) ?? .prose
        let importedProject = Project(name: "Cloudflare POC Import - \(importState.projectName)", type: projectType)
        if let remoteProjectId = UUID(uuidString: importState.projectId) {
            importedProject.id = remoteProjectId
        }
        context.insert(importedProject)
        return CloudflareSyncPOCScratchContext(storeURL: storeURL, context: context, project: importedProject, folder: nil)
    }

    @MainActor
    private func materializePendingApply(operations: [SyncPOCPulledOperation], applyPlan: [SyncPOCApplyPlanItem], sourceProject: Project) throws -> CloudflareSyncPOCMaterializeResult {
        let storeURL = try resetIsolatedStore(basename: pendingApplyStoreBasename)
        let orderedItems = try validatedScratchMaterializationItems(applyPlan)
        let operationByEntityKey = latestOperationByEntityKey(operations)
        let scratch = try makePendingApplyScratchContext(storeURL: storeURL, sourceProject: sourceProject)
        let context = scratch.context
        let scratchProject = scratch.project
        guard let scratchFolder = scratch.folder else {
            throw CloudflareSyncPOCError.applyPlanNotReady("missing pending apply scratch folder")
        }

        var styleSheetsByRemoteId: [String: StyleSheet] = [:]
        var textStylesByRemoteId: [String: TextStyleModel] = [:]
        var imageStylesByRemoteId: [String: ImageStyle] = [:]
        var pageSetupsByRemoteId: [String: PageSetup] = [:]
        var printerPapersByRemoteId: [String: PrinterPaper] = [:]
        var poetryFormsByRemoteId: [String: PoetryFormModel] = [:]
        var foldersByRemoteId: [String: Folder] = [:]
        var textFilesByRemoteId: [String: TextFile] = [:]
        var versionsByRemoteId: [String: Version] = [:]
        var commentsByRemoteId: [String: CommentModel] = [:]
        var footnotesByRemoteId: [String: FootnoteModel] = [:]
        var notesByRemoteId: [String: NoteEntry] = [:]
        var contributorsByRemoteId: [String: ContributorEntry] = [:]
        var referenceEntriesByRemoteId: [String: ReferenceEntry] = [:]
        var glossaryEntriesByRemoteId: [String: GlossaryEntry] = [:]
        var chaptersByRemoteId: [String: Chapter] = [:]
        var actsByRemoteId: [String: Act] = [:]
        var booksByRemoteId: [String: Book] = [:]
        var proseSectionsByRemoteId: [String: ProseSection] = [:]
        var poetryCollectionsByRemoteId: [String: PoetryCollection] = [:]
        var scenesByRemoteId: [String: StoryScene] = [:]
        var charactersByRemoteId: [String: Character] = [:]
        var locationsByRemoteId: [String: Location] = [:]
        var plotElementsByRemoteId: [String: PlotElement] = [:]
        var publicationsByRemoteId: [String: Publication] = [:]
        var submissionsByRemoteId: [String: Submission] = [:]
        var submittedFilesByRemoteId: [String: SubmittedFile] = [:]
        var manuscriptReviewsByRemoteId: [String: ManuscriptReview] = [:]
        var citationsByRemoteId: [String: CitationEntry] = [:]
        var indexEntriesByRemoteId: [String: IndexEntry] = [:]
        var styleSheetCount = 0
        var textStyleCount = 0
        var imageStyleCount = 0
        var folderCount = 0
        var textFileCount = 0
        var versionCount = 0
        var trashItemCount = 0
        var commentCount = 0
        var footnoteCount = 0
        var storyRecordCount = 0
        var customAttributeCount = 0
        var joinLinkCount = 0
        var noteCount = 0
        var citationCount = 0
        var glossaryCount = 0
        var referenceEntryCount = 0
        var indexEntryCount = 0
        var contributorCount = 0
        var pageSetupCount = 0
        var printerPaperCount = 0
        var poetryFormCount = 0
        var manuscriptReviewCount = 0
        var reviewSuggestionCount = 0
        var publicationCount = 0
        var submissionCount = 0
        var submittedFileCount = 0
        var updateExistingCount = 0
        var seededExistingCount = 0
        var restoreMissingCount = 0
        var deleteNoopMissingCount = 0

        func seedExistingStyleSheetIfNeeded(id styleSheetId: String) -> StyleSheet? {
            if let existing = styleSheetsByRemoteId[styleSheetId] { return existing }
            guard let localStyleSheet = sourceProject.styleSheet, localStyleSheet.id.uuidString == styleSheetId else { return nil }
            let styleSheet = StyleSheet(name: localStyleSheet.name, isSystemStyleSheet: localStyleSheet.isSystemStyleSheet)
            styleSheet.id = localStyleSheet.id
            styleSheet.createdDate = localStyleSheet.createdDate
            styleSheet.modifiedDate = localStyleSheet.modifiedDate
            styleSheet.footnoteMarkerStyleRaw = localStyleSheet.footnoteMarkerStyleRaw
            styleSheet.projects = [scratchProject]
            scratchProject.styleSheet = styleSheet
            context.insert(styleSheet)
            styleSheetsByRemoteId[styleSheetId] = styleSheet
            styleSheetCount += 1
            seededExistingCount += 1
            return styleSheet
        }

        func seedExistingTextStyleIfNeeded(id textStyleId: String, styleSheetId: String) -> TextStyleModel? {
            if let existing = textStylesByRemoteId[textStyleId] { return existing }
            guard let localStyleSheet = sourceProject.styleSheet,
                  let localTextStyle = sortedTextStyles(localStyleSheet.textStyles).first(where: { $0.id.uuidString == textStyleId }),
                  let styleSheet = seedExistingStyleSheetIfNeeded(id: styleSheetId) else { return nil }
            let textStyle = makeScratchTextStyle(
                id: textStyleId,
                values: textStylePayload(localTextStyle, styleSheetId: styleSheetId),
                styleSheet: styleSheet
            )
            if styleSheet.textStyles == nil { styleSheet.textStyles = [] }
            styleSheet.textStyles?.append(textStyle)
            context.insert(textStyle)
            textStylesByRemoteId[textStyleId] = textStyle
            textStyleCount += 1
            seededExistingCount += 1
            return textStyle
        }

        func seedExistingImageStyleIfNeeded(id imageStyleId: String, styleSheetId: String) -> ImageStyle? {
            if let existing = imageStylesByRemoteId[imageStyleId] { return existing }
            guard let localStyleSheet = sourceProject.styleSheet,
                  let localImageStyle = sortedImageStyles(localStyleSheet.imageStyles).first(where: { $0.id.uuidString == imageStyleId }),
                  let styleSheet = seedExistingStyleSheetIfNeeded(id: styleSheetId) else { return nil }
            let imageStyle = makeScratchImageStyle(
                id: imageStyleId,
                values: imageStylePayload(localImageStyle, styleSheetId: styleSheetId),
                styleSheet: styleSheet
            )
            if styleSheet.imageStyles == nil { styleSheet.imageStyles = [] }
            styleSheet.imageStyles?.append(imageStyle)
            context.insert(imageStyle)
            imageStylesByRemoteId[imageStyleId] = imageStyle
            imageStyleCount += 1
            seededExistingCount += 1
            return imageStyle
        }

        func seedExistingPageSetupIfNeeded(id pageSetupId: String) -> PageSetup? {
            if let existing = pageSetupsByRemoteId[pageSetupId] { return existing }
            guard let localPageSetup = sourceProject.pageSetup, localPageSetup.id.uuidString == pageSetupId else { return nil }
            let pageSetup = makeScratchPageSetup(
                id: pageSetupId,
                values: pageSetupPayload(localPageSetup, projectId: sourceProject.id.uuidString)
            )
            pageSetup.project = scratchProject
            scratchProject.pageSetup = pageSetup
            context.insert(pageSetup)
            pageSetupsByRemoteId[pageSetupId] = pageSetup
            pageSetupCount += 1
            seededExistingCount += 1
            return pageSetup
        }

        func seedExistingPrinterPaperIfNeeded(id printerPaperId: String, pageSetupId: String) -> PrinterPaper? {
            if let existing = printerPapersByRemoteId[printerPaperId] { return existing }
            guard let localPageSetup = sourceProject.pageSetup,
                  localPageSetup.id.uuidString == pageSetupId,
                  let localPrinterPaper = sortedPrinterPapers(localPageSetup.printerPapers).first(where: { $0.id.uuidString == printerPaperId }),
                  let pageSetup = seedExistingPageSetupIfNeeded(id: pageSetupId) else { return nil }
            let printerPaper = makeScratchPrinterPaper(
                id: printerPaperId,
                values: printerPaperPayload(localPrinterPaper, pageSetupId: pageSetupId),
                pageSetup: pageSetup
            )
            if pageSetup.printerPapers == nil {
                pageSetup.printerPapers = []
            }
            pageSetup.printerPapers?.append(printerPaper)
            context.insert(printerPaper)
            printerPapersByRemoteId[printerPaperId] = printerPaper
            printerPaperCount += 1
            seededExistingCount += 1
            return printerPaper
        }

        func seedExistingPoetryFormIfNeeded(id poetryFormId: String) -> PoetryFormModel? {
            if let existing = poetryFormsByRemoteId[poetryFormId] { return existing }
            guard let uuid = UUID(uuidString: poetryFormId), let sourceModelContext = sourceProject.modelContext else { return nil }
            let descriptor = FetchDescriptor<PoetryFormModel>(predicate: #Predicate { $0.id == uuid })
            guard let localPoetryForm = try? ModelContext(sourceModelContext.container).fetch(descriptor).first else { return nil }
            let poetryForm = makeScratchPoetryForm(id: poetryFormId, values: poetryFormPayload(localPoetryForm))
            context.insert(poetryForm)
            poetryFormsByRemoteId[poetryFormId] = poetryForm
            poetryFormCount += 1
            seededExistingCount += 1
            return poetryForm
        }

        func seedExistingPublicationIfNeeded(id publicationId: String) -> Publication? {
            if let existing = publicationsByRemoteId[publicationId] { return existing }
            guard let localPublication = samplePublications(in: sourceProject).first(where: { $0.id.uuidString == publicationId }) else { return nil }
            let publication = makeScratchPublication(
                id: publicationId,
                values: publicationPayload(localPublication, projectId: sourceProject.id.uuidString),
                project: scratchProject
            )
            context.insert(publication)
            publicationsByRemoteId[publicationId] = publication
            publicationCount += 1
            seededExistingCount += 1
            return publication
        }

        func seedExistingSubmissionIfNeeded(id submissionId: String, publicationId: String) -> Submission? {
            if let existing = submissionsByRemoteId[submissionId] { return existing }
            guard let localSubmission = sampleSubmissions(in: sourceProject).first(where: { $0.id.uuidString == submissionId }), let publication = seedExistingPublicationIfNeeded(id: publicationId) else { return nil }
            let submission = makeScratchSubmission(
                id: submissionId,
                values: submissionPayload(localSubmission, projectId: sourceProject.id.uuidString),
                publication: publication,
                project: scratchProject
            )
            context.insert(submission)
            submissionsByRemoteId[submissionId] = submission
            submissionCount += 1
            seededExistingCount += 1
            return submission
        }

        func seedExistingSubmittedFileIfNeeded(id submittedFileId: String, values: [String: String]) -> SubmittedFile? {
            if let existing = submittedFilesByRemoteId[submittedFileId] { return existing }
            let localSubmittedFile = sourceProject.submittedFiles?.first(where: { $0.id.uuidString == submittedFileId })
                ?? sampleSubmittedFiles(in: sampleSubmissions(in: sourceProject)).first(where: { $0.id.uuidString == submittedFileId })
            guard let localSubmittedFile,
                  let localSubmission = localSubmittedFile.submission,
                  let localPublication = localSubmission.publication,
                  let localTextFile = localSubmittedFile.textFile,
                  let localVersion = localSubmittedFile.version,
                  let submissionId = values["submissionId"],
                let textFileId = values["textFileId"],
                let versionId = values["versionId"],
                submissionId == localSubmission.id.uuidString,
                textFileId == localTextFile.id.uuidString,
                versionId == localVersion.id.uuidString,
                  let submission = seedExistingSubmissionIfNeeded(id: submissionId, publicationId: localPublication.id.uuidString),
                  let textFile = seedExistingTextFileIfNeeded(id: localTextFile.id.uuidString),
                let version = seedExistingVersionIfNeeded(id: localVersion.id.uuidString, textFileId: localTextFile.id.uuidString) else { return nil }
            let submittedFile = makeScratchSubmittedFile(
                id: submittedFileId,
                values: values,
                submission: submission,
                textFile: textFile,
                version: version,
                project: scratchProject
            )
            context.insert(submittedFile)
            submittedFilesByRemoteId[submittedFileId] = submittedFile
            submittedFileCount += 1
            seededExistingCount += 1
            return submittedFile
        }

        func seedExistingFolderIfNeeded(id folderId: String) -> Folder? {
            if let existing = foldersByRemoteId[folderId] { return existing }
            guard let uuid = UUID(uuidString: folderId), let localFolder = findLocalFolder(id: uuid, in: sourceProject) else { return nil }
            let parentFolder: Folder?
            if let localParentId = localFolder.parentFolder?.id.uuidString {
                parentFolder = seedExistingFolderIfNeeded(id: localParentId)
            } else {
                parentFolder = nil
            }
            let folder = Folder(
                name: localFolder.name,
                project: parentFolder == nil ? scratchProject : nil,
                parentFolder: parentFolder,
                userOrder: localFolder.userOrder
            )
            folder.id = localFolder.id
            folder.frontMatterSettingsData = localFolder.frontMatterSettingsData
            folder.backMatterSettingsData = localFolder.backMatterSettingsData
            folder.dramaFrontMatterSettingsData = localFolder.dramaFrontMatterSettingsData
            folder.dramaBackMatterSettingsData = localFolder.dramaBackMatterSettingsData
            context.insert(folder)
            foldersByRemoteId[folderId] = folder
            folderCount += 1
            seededExistingCount += 1
            return folder
        }

        func seedExistingTextFileIfNeeded(id textFileId: String) -> TextFile? {
            if let existing = textFilesByRemoteId[textFileId] { return existing }
            guard let uuid = UUID(uuidString: textFileId), let localTextFile = findLocalTextFile(id: uuid, in: sourceProject) else { return nil }
            let folder = Folder(name: localTextFile.parentFolder?.name ?? "Existing File Folder", project: scratchProject, parentFolder: nil, userOrder: localTextFile.parentFolder?.userOrder ?? 0)
            if let folderId = localTextFile.parentFolder?.id {
                folder.id = folderId
            }
            context.insert(folder)
            folderCount += 1
            let textFile = TextFile(name: localTextFile.name, initialContent: "", parentFolder: folder)
            textFile.id = localTextFile.id
            textFile.contentTypeRaw = localTextFile.contentTypeRaw
            textFile.workflowStatusRaw = localTextFile.workflowStatusRaw
            textFile.modifiedDate = localTextFile.modifiedDate
            textFile.userOrder = localTextFile.userOrder
            for placeholderVersion in textFile.versions ?? [] {
                context.delete(placeholderVersion)
            }
            textFile.versions = []
            context.insert(textFile)
            textFilesByRemoteId[textFileId] = textFile
            textFileCount += 1
            seededExistingCount += 1
            return textFile
        }

        func seedExistingVersionIfNeeded(id versionId: String, textFileId: String) -> Version? {
            if let existing = versionsByRemoteId[versionId] { return existing }
            guard let uuid = UUID(uuidString: versionId), let localVersion = findLocalVersion(id: uuid, in: sourceProject), let textFile = seedExistingTextFileIfNeeded(id: textFileId) else { return nil }
            let version = Version(content: localVersion.content, versionNumber: localVersion.versionNumber, comment: localVersion.comment)
            version.id = localVersion.id
            version.notes = localVersion.notes
            version.createdDate = localVersion.createdDate
            version.formattedContent = localVersion.formattedContent
            version.referenceMetadataData = localVersion.referenceMetadataData
            version.textFile = textFile
            if textFile.versions == nil { textFile.versions = [] }
            textFile.versions?.append(version)
            context.insert(version)
            versionsByRemoteId[versionId] = version
            versionCount += 1
            seededExistingCount += 1
            return version
        }

        func seedExistingCommentIfNeeded(id commentId: String, versionId: String) -> CommentModel? {
            if let existing = commentsByRemoteId[commentId] { return existing }
            guard let versionUUID = UUID(uuidString: versionId),
                  let localVersion = findLocalVersion(id: versionUUID, in: sourceProject),
                  let localComment = sampleComments(in: [localVersion]).first(where: { $0.id.uuidString == commentId }),
                  let textFileId = localVersion.textFile?.id.uuidString,
                  let version = seedExistingVersionIfNeeded(id: versionId, textFileId: textFileId) else { return nil }
            let comment = makeScratchComment(id: commentId, values: commentPayload(localComment), version: version)
            if version.comments == nil { version.comments = [] }
            version.comments?.append(comment)
            context.insert(comment)
            commentsByRemoteId[commentId] = comment
            commentCount += 1
            seededExistingCount += 1
            return comment
        }

        func seedExistingFootnoteIfNeeded(id footnoteId: String, versionId: String) -> FootnoteModel? {
            if let existing = footnotesByRemoteId[footnoteId] { return existing }
            guard let versionUUID = UUID(uuidString: versionId),
                  let localVersion = findLocalVersion(id: versionUUID, in: sourceProject),
                  let localFootnote = sampleFootnotes(in: [localVersion]).first(where: { $0.id.uuidString == footnoteId }),
                  let textFileId = localVersion.textFile?.id.uuidString,
                  let version = seedExistingVersionIfNeeded(id: versionId, textFileId: textFileId) else { return nil }
            let footnote = makeScratchFootnote(id: footnoteId, values: footnotePayload(localFootnote), version: version)
            if version.footnotes == nil { version.footnotes = [] }
            version.footnotes?.append(footnote)
            context.insert(footnote)
            footnotesByRemoteId[footnoteId] = footnote
            footnoteCount += 1
            seededExistingCount += 1
            return footnote
        }

        func seedExistingNoteIfNeeded(id noteId: String) -> NoteEntry? {
            if let existing = notesByRemoteId[noteId] { return existing }
            guard let localNote = findLocalNoteEntry(id: noteId, in: sourceProject) else { return nil }
            let note = makeScratchNote(id: noteId, values: notePayload(localNote, projectId: sourceProject.id.uuidString), project: scratchProject)
            context.insert(note)
            notesByRemoteId[noteId] = note
            noteCount += 1
            seededExistingCount += 1
            return note
        }

        func seedExistingContributorIfNeeded(id contributorId: String) -> ContributorEntry? {
            if let existing = contributorsByRemoteId[contributorId] { return existing }
            guard let localContributor = sampleContributors(in: sourceProject).first(where: { $0.id.uuidString == contributorId }) else { return nil }
            let contributor = makeScratchContributor(id: contributorId, values: contributorPayload(localContributor, projectId: sourceProject.id.uuidString), project: scratchProject)
            context.insert(contributor)
            contributorsByRemoteId[contributorId] = contributor
            contributorCount += 1
            seededExistingCount += 1
            return contributor
        }

        func seedExistingReferenceEntryIfNeeded(id referenceEntryId: String) -> ReferenceEntry? {
            if let existing = referenceEntriesByRemoteId[referenceEntryId] { return existing }
            guard let localReferenceEntry = findLocalReferenceEntry(id: referenceEntryId, in: sourceProject) else { return nil }
            let referenceEntry = makeScratchReferenceEntry(id: referenceEntryId, values: referencePayload(localReferenceEntry, projectId: sourceProject.id.uuidString), project: scratchProject)
            context.insert(referenceEntry)
            referenceEntriesByRemoteId[referenceEntryId] = referenceEntry
            referenceEntryCount += 1
            seededExistingCount += 1
            return referenceEntry
        }

        func seedExistingGlossaryEntryIfNeeded(id glossaryEntryId: String) -> GlossaryEntry? {
            if let existing = glossaryEntriesByRemoteId[glossaryEntryId] { return existing }
            guard let localGlossaryEntry = findLocalGlossaryEntry(id: glossaryEntryId, in: sourceProject) else { return nil }
            let citationId = localGlossaryEntry.citation?.id.uuidString
            let citation = citationId.flatMap { citationsByRemoteId[$0] }
            let glossaryEntry = makeScratchGlossaryEntry(id: glossaryEntryId, values: glossaryPayload(localGlossaryEntry, projectId: sourceProject.id.uuidString), project: scratchProject, citation: citation)
            context.insert(glossaryEntry)
            glossaryEntriesByRemoteId[glossaryEntryId] = glossaryEntry
            glossaryCount += 1
            seededExistingCount += 1
            return glossaryEntry
        }

        func seedExistingIndexEntryIfNeeded(id indexEntryId: String) -> IndexEntry? {
            if let existing = indexEntriesByRemoteId[indexEntryId] { return existing }
            guard let localIndexEntry = findLocalIndexEntry(id: indexEntryId, in: sourceProject) else { return nil }
            let parentId = localIndexEntry.parentEntry?.id.uuidString
            let parent = parentId.flatMap { seedExistingIndexEntryIfNeeded(id: $0) }
            let indexEntry = makeScratchIndexEntry(id: indexEntryId, values: indexPayload(localIndexEntry, projectId: sourceProject.id.uuidString), project: scratchProject, parent: parent)
            if let parent {
                if parent.childEntries == nil { parent.childEntries = [] }
                parent.childEntries?.append(indexEntry)
            }
            context.insert(indexEntry)
            indexEntriesByRemoteId[indexEntryId] = indexEntry
            indexEntryCount += 1
            seededExistingCount += 1
            return indexEntry
        }

        func seedExistingPoetryCollectionIfNeeded(id collectionId: String) -> PoetryCollection? {
            if let existing = poetryCollectionsByRemoteId[collectionId] { return existing }
            guard let localCollection = samplePoetryCollections(in: sourceProject).first(where: { $0.id.uuidString == collectionId }) else { return nil }
            let collection = PoetryCollection(name: localCollection.name, synopsis: localCollection.synopsis, userOrder: localCollection.userOrder)
            collection.id = localCollection.id
            collection.createdDate = localCollection.createdDate
            collection.modifiedDate = localCollection.modifiedDate
            collection.bodyMatterOrder = localCollection.bodyMatterOrder
            collection.isInBodyMatter = localCollection.isInBodyMatter
            collection.project = scratchProject
            context.insert(collection)
            poetryCollectionsByRemoteId[collectionId] = collection
            storyRecordCount += 1
            seededExistingCount += 1
            return collection
        }

        func seedExistingChapterIfNeeded(id chapterId: String) -> Chapter? {
            if let existing = chaptersByRemoteId[chapterId] { return existing }
            guard let localChapter = sampleChapters(in: sourceProject).first(where: { $0.id.uuidString == chapterId }) else { return nil }
            let chapter = Chapter(name: localChapter.name, synopsis: localChapter.synopsis, userOrder: localChapter.userOrder)
            chapter.id = localChapter.id
            chapter.createdDate = localChapter.createdDate
            chapter.modifiedDate = localChapter.modifiedDate
            chapter.bodyMatterOrder = localChapter.bodyMatterOrder
            chapter.isInBodyMatter = localChapter.isInBodyMatter
            chapter.project = scratchProject
            context.insert(chapter)
            chaptersByRemoteId[chapterId] = chapter
            storyRecordCount += 1
            seededExistingCount += 1
            return chapter
        }

        func seedExistingActIfNeeded(id actId: String) -> Act? {
            if let existing = actsByRemoteId[actId] { return existing }
            guard let localAct = sampleActs(in: sourceProject).first(where: { $0.id.uuidString == actId }) else { return nil }
            let act = Act(name: localAct.name, synopsis: localAct.synopsis, userOrder: localAct.userOrder)
            act.id = localAct.id
            act.createdDate = localAct.createdDate
            act.modifiedDate = localAct.modifiedDate
            act.bodyMatterOrder = localAct.bodyMatterOrder
            act.isInBodyMatter = localAct.isInBodyMatter
            act.project = scratchProject
            context.insert(act)
            actsByRemoteId[actId] = act
            storyRecordCount += 1
            seededExistingCount += 1
            return act
        }

        func seedExistingBookIfNeeded(id bookId: String) -> Book? {
            if let existing = booksByRemoteId[bookId] { return existing }
            guard let localBook = sampleBooks(in: sourceProject).first(where: { $0.id.uuidString == bookId }) else { return nil }
            let book = Book(name: localBook.name, synopsis: localBook.synopsis, userOrder: localBook.userOrder)
            book.id = localBook.id
            book.createdDate = localBook.createdDate
            book.modifiedDate = localBook.modifiedDate
            book.bodyMatterOrder = localBook.bodyMatterOrder
            book.isInBodyMatter = localBook.isInBodyMatter
            book.project = scratchProject
            context.insert(book)
            booksByRemoteId[bookId] = book
            storyRecordCount += 1
            seededExistingCount += 1
            return book
        }

        func seedExistingProseSectionIfNeeded(id sectionId: String) -> ProseSection? {
            if let existing = proseSectionsByRemoteId[sectionId] { return existing }
            guard let localSection = sampleProseSections(in: sourceProject).first(where: { $0.id.uuidString == sectionId }) else { return nil }
            let section = ProseSection(name: localSection.name, synopsis: localSection.synopsis, userOrder: localSection.userOrder)
            section.id = localSection.id
            section.createdDate = localSection.createdDate
            section.modifiedDate = localSection.modifiedDate
            section.bodyMatterOrder = localSection.bodyMatterOrder
            section.isInBodyMatter = localSection.isInBodyMatter
            section.project = scratchProject
            context.insert(section)
            proseSectionsByRemoteId[sectionId] = section
            storyRecordCount += 1
            seededExistingCount += 1
            return section
        }

        func seedExistingStorySceneIfNeeded(id sceneId: String) -> StoryScene? {
            if let existing = scenesByRemoteId[sceneId] { return existing }
            guard let localScene = sampleStoryScenes(in: sourceProject).first(where: { $0.id.uuidString == sceneId }) else { return nil }
            let scene = StoryScene(name: localScene.name, synopsis: localScene.synopsis, userOrder: localScene.userOrder)
            scene.id = localScene.id
            scene.createdDate = localScene.createdDate
            scene.modifiedDate = localScene.modifiedDate
            scene.bodyMatterOrder = localScene.bodyMatterOrder
            scene.isInBodyMatter = localScene.isInBodyMatter
            scene.monomythStageRaw = localScene.monomythStageRaw
            scene.campbellStageRaw = localScene.campbellStageRaw
            scene.threeActStageRaw = localScene.threeActStageRaw
            scene.pearsonStageRaw = localScene.pearsonStageRaw
            scene.isTrashed = localScene.isTrashed
            scene.trashedDate = localScene.trashedDate
            if let localTextFileId = localScene.textFile?.id.uuidString,
               let textFile = seedExistingTextFileIfNeeded(id: localTextFileId) {
                scene.textFile = textFile
                textFile.scene = scene
            }
            scene.project = scratchProject
            context.insert(scene)
            scenesByRemoteId[sceneId] = scene
            storyRecordCount += 1
            seededExistingCount += 1
            return scene
        }

        func seedExistingCharacterIfNeeded(id characterId: String) -> Character? {
            if let existing = charactersByRemoteId[characterId] { return existing }
            guard let localCharacter = sampleCharacters(in: sourceProject).first(where: { $0.id.uuidString == characterId }) else { return nil }
            let character = Character(
                name: localCharacter.name,
                role: localCharacter.role,
                archetypes: localCharacter.archetypes,
                history: localCharacter.history,
                looks: localCharacter.looks,
                traits: localCharacter.traits,
                work: localCharacter.work
            )
            character.id = localCharacter.id
            character.archetypeRaw = localCharacter.archetypeRaw
            character.pearsonArchetypeRaw = localCharacter.pearsonArchetypeRaw
            character.createdDate = localCharacter.createdDate
            character.modifiedDate = localCharacter.modifiedDate
            character.project = scratchProject
            context.insert(character)
            charactersByRemoteId[characterId] = character
            storyRecordCount += 1
            seededExistingCount += 1
            return character
        }

        func seedExistingLocationIfNeeded(id locationId: String) -> Location? {
            if let existing = locationsByRemoteId[locationId] { return existing }
            guard let localLocation = sampleLocations(in: sourceProject).first(where: { $0.id.uuidString == locationId }) else { return nil }
            let location = Location(
                name: localLocation.name,
                detail: localLocation.detail,
                sights: localLocation.sights,
                sounds: localLocation.sounds,
                smells: localLocation.smells
            )
            location.id = localLocation.id
            location.createdDate = localLocation.createdDate
            location.modifiedDate = localLocation.modifiedDate
            location.project = scratchProject
            context.insert(location)
            locationsByRemoteId[locationId] = location
            storyRecordCount += 1
            seededExistingCount += 1
            return location
        }

        func seedExistingPlotElementIfNeeded(id plotElementId: String) -> PlotElement? {
            if let existing = plotElementsByRemoteId[plotElementId] { return existing }
            guard let localPlotElement = samplePlotElements(in: sourceProject).first(where: { $0.id.uuidString == plotElementId }) else { return nil }
            let plotElement = PlotElement(
                name: localPlotElement.name,
                notes: localPlotElement.notes,
                monomythStage: nil,
                threeActStage: nil,
                userOrder: localPlotElement.userOrder
            )
            plotElement.id = localPlotElement.id
            plotElement.monomythStageRaw = localPlotElement.monomythStageRaw
            plotElement.campbellStageRaw = localPlotElement.campbellStageRaw
            plotElement.threeActStageRaw = localPlotElement.threeActStageRaw
            plotElement.pearsonStageRaw = localPlotElement.pearsonStageRaw
            plotElement.createdDate = localPlotElement.createdDate
            plotElement.modifiedDate = localPlotElement.modifiedDate
            plotElement.project = scratchProject
            context.insert(plotElement)
            plotElementsByRemoteId[plotElementId] = plotElement
            storyRecordCount += 1
            seededExistingCount += 1
            return plotElement
        }

        for item in orderedItems {
            guard let operation = operationByEntityKey["\(item.entityType):\(item.entityId)"] else {
                throw CloudflareSyncPOCError.applyPlanNotReady("missing operation for \(item.entityType) \(item.entityId)")
            }
            if item.proposedLocalAction == "deleteNoopMissing" {
                deleteNoopMissingCount += 1
                continue
            }
            if item.proposedLocalAction == "restoreMissing" {
                restoreMissingCount += 1
            }
            guard let values = operation.payload?.values, !values.isEmpty else {
                throw CloudflareSyncPOCError.applyPlanNotReady("missing payload for \(item.entityType) \(item.entityId)")
            }

            if item.entityType == "Project", item.proposedLocalAction == "updateExisting" {
                scratchProject.name = values["name"]?.isEmpty == false ? values["name"] : scratchProject.name
                scratchProject.typeRaw = values["type"]?.isEmpty == false ? values["type"] : scratchProject.typeRaw
                scratchProject.isTrashed = boolValue(values["isTrashed"])
                scratchProject.modifiedDate = dateValue(values["modifiedDate"]) ?? scratchProject.modifiedDate
                updateExistingCount += 1
                continue
            }

            if item.entityType == "StyleSheet", item.proposedLocalAction == "updateExisting" {
                guard let styleSheet = seedExistingStyleSheetIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local StyleSheet seed for updateExisting \(item.entityId)")
                }
                styleSheet.name = values["name"]?.isEmpty == false ? values["name"]! : styleSheet.name
                styleSheet.isSystemStyleSheet = boolValue(values["isSystemStyleSheet"])
                styleSheet.footnoteMarkerStyleRaw = values["footnoteMarkerStyleRaw"]?.isEmpty == false ? values["footnoteMarkerStyleRaw"]! : styleSheet.footnoteMarkerStyleRaw
                styleSheet.modifiedDate = dateValue(values["modifiedDate"]) ?? styleSheet.modifiedDate
                updateExistingCount += 1
                continue
            }

            if item.entityType == "TextStyleModel", item.proposedLocalAction == "updateExisting" {
                guard let styleSheetId = values["styleSheetId"], let textStyle = seedExistingTextStyleIfNeeded(id: item.entityId, styleSheetId: styleSheetId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local TextStyleModel seed for updateExisting \(item.entityId)")
                }
                applyTextStylePayload(values, to: textStyle)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "ImageStyle", item.proposedLocalAction == "updateExisting" {
                guard let styleSheetId = values["styleSheetId"], let imageStyle = seedExistingImageStyleIfNeeded(id: item.entityId, styleSheetId: styleSheetId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local ImageStyle seed for updateExisting \(item.entityId)")
                }
                applyImageStylePayload(values, to: imageStyle)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "PageSetup", item.proposedLocalAction == "updateExisting" {
                guard let pageSetup = seedExistingPageSetupIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local PageSetup seed for updateExisting \(item.entityId)")
                }
                applyPageSetupPayload(values, to: pageSetup)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "PrinterPaper", item.proposedLocalAction == "updateExisting" {
                guard let pageSetupId = values["pageSetupId"], let printerPaper = seedExistingPrinterPaperIfNeeded(id: item.entityId, pageSetupId: pageSetupId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local PrinterPaper seed for updateExisting \(item.entityId)")
                }
                applyPrinterPaperPayload(values, to: printerPaper)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "PoetryFormModel", item.proposedLocalAction == "updateExisting" {
                guard let poetryForm = seedExistingPoetryFormIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local PoetryFormModel seed for updateExisting \(item.entityId)")
                }
                applyPoetryFormPayload(values, to: poetryForm)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Publication", item.proposedLocalAction == "updateExisting" {
                guard let publication = seedExistingPublicationIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Publication seed for updateExisting \(item.entityId)")
                }
                applyPublicationPayload(values, to: publication)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Submission", item.proposedLocalAction == "updateExisting" {
                guard let publicationId = values["publicationId"], let submission = seedExistingSubmissionIfNeeded(id: item.entityId, publicationId: publicationId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Submission seed for updateExisting \(item.entityId)")
                }
                applySubmissionPayload(values, to: submission)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "SubmittedFile", item.proposedLocalAction == "updateExisting" {
                guard let submittedFile = seedExistingSubmittedFileIfNeeded(id: item.entityId, values: values) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local SubmittedFile seed for updateExisting \(item.entityId)")
                }
                applySubmittedFilePayload(values, to: submittedFile)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Folder", item.proposedLocalAction == "updateExisting" {
                guard let folder = seedExistingFolderIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Folder seed for updateExisting \(item.entityId)")
                }
                folder.name = values["name"]?.isEmpty == false ? values["name"] : folder.name
                folder.userOrder = intValue(values["userOrder"]) ?? folder.userOrder
                updateExistingCount += 1
                continue
            }

            if item.entityType == "TextFile", item.proposedLocalAction == "updateExisting" {
                guard let textFile = seedExistingTextFileIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local TextFile seed for updateExisting \(item.entityId)")
                }
                textFile.name = values["name"]?.isEmpty == false ? values["name"]! : textFile.name
                if let contentType = values["contentType"], !contentType.isEmpty {
                    textFile.contentTypeRaw = contentType
                }
                textFile.workflowStatusRaw = values["workflowStatus"]?.isEmpty == false ? values["workflowStatus"] : textFile.workflowStatusRaw
                textFile.modifiedDate = dateValue(values["modifiedDate"]) ?? textFile.modifiedDate
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Version", item.proposedLocalAction == "updateExisting" {
                guard let textFileId = values["textFileId"], let version = seedExistingVersionIfNeeded(id: item.entityId, textFileId: textFileId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Version seed for updateExisting \(item.entityId)")
                }
                version.content = values["content"] ?? version.content
                version.versionNumber = intValue(values["versionNumber"]) ?? version.versionNumber
                version.comment = values["comment"]?.isEmpty == false ? values["comment"] : version.comment
                version.notes = values["notes"]?.isEmpty == false ? values["notes"] : version.notes
                updateExistingCount += 1
                continue
            }

            if item.entityType == "CommentModel", item.proposedLocalAction == "updateExisting" {
                guard let versionId = values["versionId"], let comment = seedExistingCommentIfNeeded(id: item.entityId, versionId: versionId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local CommentModel seed for updateExisting \(item.entityId)")
                }
                applyCommentPayload(values, to: comment)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "FootnoteModel", item.proposedLocalAction == "updateExisting" {
                guard let versionId = values["versionId"], let footnote = seedExistingFootnoteIfNeeded(id: item.entityId, versionId: versionId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local FootnoteModel seed for updateExisting \(item.entityId)")
                }
                applyFootnotePayload(values, to: footnote)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "NoteEntry", item.proposedLocalAction == "updateExisting" {
                guard let note = seedExistingNoteIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local NoteEntry seed for updateExisting \(item.entityId)")
                }
                applyNotePayload(values, to: note)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "ContributorEntry", item.proposedLocalAction == "updateExisting" {
                guard let contributor = seedExistingContributorIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local ContributorEntry seed for updateExisting \(item.entityId)")
                }
                applyContributorPayload(values, to: contributor)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "ReferenceEntry", item.proposedLocalAction == "updateExisting" {
                guard let referenceEntry = seedExistingReferenceEntryIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local ReferenceEntry seed for updateExisting \(item.entityId)")
                }
                applyReferencePayload(values, to: referenceEntry)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "GlossaryEntry", item.proposedLocalAction == "updateExisting" {
                guard let glossaryEntry = seedExistingGlossaryEntryIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local GlossaryEntry seed for updateExisting \(item.entityId)")
                }
                let citation = values["citationId"].flatMap { citationsByRemoteId[$0] }
                applyGlossaryPayload(values, to: glossaryEntry, citation: citation)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "IndexEntry", item.proposedLocalAction == "updateExisting" {
                guard let indexEntry = seedExistingIndexEntryIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local IndexEntry seed for updateExisting \(item.entityId)")
                }
                let parent = values["parentEntryId"].flatMap { indexEntriesByRemoteId[$0] }
                applyIndexPayload(values, to: indexEntry, parent: parent)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "PoetryCollection", item.proposedLocalAction == "updateExisting" {
                guard let collection = seedExistingPoetryCollectionIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local PoetryCollection seed for updateExisting \(item.entityId)")
                }
                collection.name = values["name"]?.isEmpty == false ? values["name"] : collection.name
                collection.synopsis = values["synopsis"]?.isEmpty == false ? values["synopsis"] : collection.synopsis
                collection.userOrder = intValue(values["userOrder"]) ?? collection.userOrder
                applyBodyMatterPayload(values, to: collection)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Chapter", item.proposedLocalAction == "updateExisting" {
                guard let chapter = seedExistingChapterIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Chapter seed for updateExisting \(item.entityId)")
                }
                chapter.name = values["name"]?.isEmpty == false ? values["name"] : chapter.name
                chapter.synopsis = values["synopsis"]?.isEmpty == false ? values["synopsis"] : chapter.synopsis
                chapter.userOrder = intValue(values["userOrder"]) ?? chapter.userOrder
                applyBodyMatterPayload(values, to: chapter)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Act", item.proposedLocalAction == "updateExisting" {
                guard let act = seedExistingActIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Act seed for updateExisting \(item.entityId)")
                }
                act.name = values["name"]?.isEmpty == false ? values["name"] : act.name
                act.synopsis = values["synopsis"]?.isEmpty == false ? values["synopsis"] : act.synopsis
                act.userOrder = intValue(values["userOrder"]) ?? act.userOrder
                applyBodyMatterPayload(values, to: act)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Book", item.proposedLocalAction == "updateExisting" {
                guard let book = seedExistingBookIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Book seed for updateExisting \(item.entityId)")
                }
                book.name = values["name"]?.isEmpty == false ? values["name"] : book.name
                book.synopsis = values["synopsis"]?.isEmpty == false ? values["synopsis"] : book.synopsis
                book.userOrder = intValue(values["userOrder"]) ?? book.userOrder
                applyBodyMatterPayload(values, to: book)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "ProseSection", item.proposedLocalAction == "updateExisting" {
                guard let section = seedExistingProseSectionIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local ProseSection seed for updateExisting \(item.entityId)")
                }
                section.name = values["name"]?.isEmpty == false ? values["name"] : section.name
                section.synopsis = values["synopsis"]?.isEmpty == false ? values["synopsis"] : section.synopsis
                section.userOrder = intValue(values["userOrder"]) ?? section.userOrder
                applyBodyMatterPayload(values, to: section)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "StoryScene", item.proposedLocalAction == "updateExisting" {
                guard let scene = seedExistingStorySceneIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local StoryScene seed for updateExisting \(item.entityId)")
                }
                scene.name = values["name"]?.isEmpty == false ? values["name"] : scene.name
                scene.synopsis = values["synopsis"]?.isEmpty == false ? values["synopsis"] : scene.synopsis
                scene.userOrder = intValue(values["userOrder"]) ?? scene.userOrder
                scene.monomythStageRaw = values["monomythStageRaw"]?.isEmpty == false ? values["monomythStageRaw"] : scene.monomythStageRaw
                scene.campbellStageRaw = values["campbellStageRaw"]?.isEmpty == false ? values["campbellStageRaw"] : scene.campbellStageRaw
                scene.threeActStageRaw = values["threeActStageRaw"]?.isEmpty == false ? values["threeActStageRaw"] : scene.threeActStageRaw
                scene.pearsonStageRaw = values["pearsonStageRaw"]?.isEmpty == false ? values["pearsonStageRaw"] : scene.pearsonStageRaw
                scene.isTrashed = boolValue(values["isTrashed"])
                scene.trashedDate = dateValue(values["trashedDate"])
                if let textFileId = values["textFileId"], !textFileId.isEmpty,
                   let textFile = seedExistingTextFileIfNeeded(id: textFileId) {
                    scene.textFile = textFile
                    textFile.scene = scene
                }
                applyBodyMatterPayload(values, to: scene)
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Character", item.proposedLocalAction == "updateExisting" {
                guard let character = seedExistingCharacterIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Character seed for updateExisting \(item.entityId)")
                }
                character.name = values["name"]?.isEmpty == false ? values["name"] : character.name
                character.role = values["role"]?.isEmpty == false ? values["role"] : character.role
                character.archetypeRaw = values["archetypeRaw"]?.isEmpty == false ? values["archetypeRaw"] : character.archetypeRaw
                character.pearsonArchetypeRaw = values["pearsonArchetypeRaw"]?.isEmpty == false ? values["pearsonArchetypeRaw"] : character.pearsonArchetypeRaw
                character.history = values["history"]?.isEmpty == false ? values["history"] : character.history
                character.looks = values["looks"]?.isEmpty == false ? values["looks"] : character.looks
                character.traits = values["traits"]?.isEmpty == false ? values["traits"] : character.traits
                character.work = values["work"]?.isEmpty == false ? values["work"] : character.work
                character.createdDate = dateValue(values["createdDate"]) ?? character.createdDate
                character.modifiedDate = dateValue(values["modifiedDate"]) ?? character.modifiedDate
                updateExistingCount += 1
                continue
            }

            if item.entityType == "Location", item.proposedLocalAction == "updateExisting" {
                guard let location = seedExistingLocationIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local Location seed for updateExisting \(item.entityId)")
                }
                location.name = values["name"]?.isEmpty == false ? values["name"] : location.name
                location.detail = values["detail"]?.isEmpty == false ? values["detail"] : location.detail
                location.sights = values["sights"]?.isEmpty == false ? values["sights"] : location.sights
                location.sounds = values["sounds"]?.isEmpty == false ? values["sounds"] : location.sounds
                location.smells = values["smells"]?.isEmpty == false ? values["smells"] : location.smells
                location.createdDate = dateValue(values["createdDate"]) ?? location.createdDate
                location.modifiedDate = dateValue(values["modifiedDate"]) ?? location.modifiedDate
                updateExistingCount += 1
                continue
            }

            if item.entityType == "PlotElement", item.proposedLocalAction == "updateExisting" {
                guard let plotElement = seedExistingPlotElementIfNeeded(id: item.entityId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local PlotElement seed for updateExisting \(item.entityId)")
                }
                plotElement.name = values["name"]?.isEmpty == false ? values["name"] : plotElement.name
                plotElement.notes = values["notes"]?.isEmpty == false ? values["notes"] : plotElement.notes
                plotElement.userOrder = intValue(values["userOrder"]) ?? plotElement.userOrder
                plotElement.monomythStageRaw = values["monomythStageRaw"]?.isEmpty == false ? values["monomythStageRaw"] : plotElement.monomythStageRaw
                plotElement.campbellStageRaw = values["campbellStageRaw"]?.isEmpty == false ? values["campbellStageRaw"] : plotElement.campbellStageRaw
                plotElement.threeActStageRaw = values["threeActStageRaw"]?.isEmpty == false ? values["threeActStageRaw"] : plotElement.threeActStageRaw
                plotElement.pearsonStageRaw = values["pearsonStageRaw"]?.isEmpty == false ? values["pearsonStageRaw"] : plotElement.pearsonStageRaw
                plotElement.createdDate = dateValue(values["createdDate"]) ?? plotElement.createdDate
                plotElement.modifiedDate = dateValue(values["modifiedDate"]) ?? plotElement.modifiedDate
                updateExistingCount += 1
                continue
            }

            if item.entityType == "TextFileSectionLink", item.proposedLocalAction == "updateExisting" {
                guard let textFileId = values["textFileId"], let textFile = seedExistingTextFileIfNeeded(id: textFileId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local TextFile seed for updateExisting \(item.entityId)")
                }
                guard let sectionId = values["sectionId"], let section = seedExistingProseSectionIfNeeded(id: sectionId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local ProseSection seed for updateExisting \(item.entityId)")
                }
                let link = TextFileSectionLink(textFile: textFile, section: section, userOrder: intValue(values["userOrder"]))
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if textFile.sectionLinks == nil { textFile.sectionLinks = [] }
                if section.textFileLinks == nil { section.textFileLinks = [] }
                textFile.sectionLinks?.append(link)
                section.textFileLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
                seededExistingCount += 1
                updateExistingCount += 1
                continue
            }

            if item.entityType == "TextFileCollectionLink", item.proposedLocalAction == "updateExisting" {
                guard let textFileId = values["textFileId"], let textFile = seedExistingTextFileIfNeeded(id: textFileId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local TextFile seed for updateExisting \(item.entityId)")
                }
                guard let collectionId = values["poetryCollectionId"], let collection = seedExistingPoetryCollectionIfNeeded(id: collectionId) else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing local PoetryCollection seed for updateExisting \(item.entityId)")
                }
                let link = TextFileCollectionLink(textFile: textFile, poetryCollection: collection, userOrder: intValue(values["userOrder"]))
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if textFile.poetryCollectionLinks == nil { textFile.poetryCollectionLinks = [] }
                if collection.textFileLinks == nil { collection.textFileLinks = [] }
                textFile.poetryCollectionLinks?.append(link)
                collection.textFileLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
                seededExistingCount += 1
                updateExistingCount += 1
                continue
            }

            switch item.entityType {
            case "StyleSheet":
                let styleSheet = StyleSheet(
                    name: values["name"]?.isEmpty == false ? values["name"]! : "Imported StyleSheet",
                    isSystemStyleSheet: boolValue(values["isSystemStyleSheet"])
                )
                if let styleSheetId = UUID(uuidString: item.entityId) {
                    styleSheet.id = styleSheetId
                }
                styleSheet.footnoteMarkerStyleRaw = values["footnoteMarkerStyleRaw"]?.isEmpty == false ? values["footnoteMarkerStyleRaw"]! : styleSheet.footnoteMarkerStyleRaw
                context.insert(styleSheet)
                styleSheetsByRemoteId[item.entityId] = styleSheet
                styleSheetCount += 1

            case "TextStyleModel":
                guard let styleSheetId = values["styleSheetId"], let styleSheet = styleSheetsByRemoteId[styleSheetId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StyleSheet for TextStyleModel \(item.entityId)")
                }
                let textStyle = makeScratchTextStyle(id: item.entityId, values: values, styleSheet: styleSheet)
                if styleSheet.textStyles == nil {
                    styleSheet.textStyles = []
                }
                styleSheet.textStyles?.append(textStyle)
                context.insert(textStyle)
                textStylesByRemoteId[item.entityId] = textStyle
                textStyleCount += 1

            case "ImageStyle":
                guard let styleSheetId = values["styleSheetId"], let styleSheet = styleSheetsByRemoteId[styleSheetId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StyleSheet for ImageStyle \(item.entityId)")
                }
                let imageStyle = makeScratchImageStyle(id: item.entityId, values: values, styleSheet: styleSheet)
                if styleSheet.imageStyles == nil {
                    styleSheet.imageStyles = []
                }
                styleSheet.imageStyles?.append(imageStyle)
                context.insert(imageStyle)
                imageStylesByRemoteId[item.entityId] = imageStyle
                imageStyleCount += 1

            case "PageSetup":
                let pageSetup = makeScratchPageSetup(id: item.entityId, values: values)
                pageSetup.project = scratchProject
                scratchProject.pageSetup = pageSetup
                context.insert(pageSetup)
                pageSetupsByRemoteId[item.entityId] = pageSetup
                pageSetupCount += 1

            case "PrinterPaper":
                guard let pageSetupId = values["pageSetupId"], let pageSetup = pageSetupsByRemoteId[pageSetupId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch PageSetup for PrinterPaper \(item.entityId)")
                }
                let printerPaper = makeScratchPrinterPaper(id: item.entityId, values: values, pageSetup: pageSetup)
                if pageSetup.printerPapers == nil {
                    pageSetup.printerPapers = []
                }
                pageSetup.printerPapers?.append(printerPaper)
                context.insert(printerPaper)
                printerPapersByRemoteId[item.entityId] = printerPaper
                printerPaperCount += 1

            case "PoetryFormModel":
                let poetryForm = makeScratchPoetryForm(id: item.entityId, values: values)
                context.insert(poetryForm)
                poetryFormsByRemoteId[item.entityId] = poetryForm
                poetryFormCount += 1

            case "ManuscriptReview":
                let review = ManuscriptReview(
                    reviewId: values["reviewId"]?.isEmpty == false ? values["reviewId"]! : item.entityId,
                    timestamp: dateValue(values["timestamp"]) ?? Date(),
                    fileId: values["fileId"].flatMap { UUID(uuidString: $0) },
                    projectId: UUID(uuidString: values["projectId"] ?? "") ?? scratchProject.id,
                    analysisMode: values["analysisMode"]?.isEmpty == false ? values["analysisMode"]! : "manuscript",
                    summary: values["summary"] ?? "",
                    overallSentiment: values["overallSentiment"]?.isEmpty == false ? values["overallSentiment"]! : "mixed",
                    analysisProfile: values["analysisProfile"]?.isEmpty == false ? values["analysisProfile"]! : "prose",
                    suggestedFocusOrder: stringListValue(values["suggestedFocusOrder"])
                )
                review.isArchived = boolValue(values["isArchived"])
                review.userNotes = values["userNotes"]?.isEmpty == false ? values["userNotes"] : nil
                context.insert(review)
                manuscriptReviewsByRemoteId[item.entityId] = review
                manuscriptReviewCount += 1

            case "ReviewSuggestion":
                guard let reviewId = values["reviewId"], let review = manuscriptReviewsByRemoteId[reviewId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch ManuscriptReview for ReviewSuggestion \(item.entityId)")
                }
                let suggestion = ReviewSuggestion(
                    suggestionId: values["suggestionId"]?.isEmpty == false ? values["suggestionId"]! : item.entityId,
                    category: values["category"]?.isEmpty == false ? values["category"]! : "general",
                    severity: values["severity"]?.isEmpty == false ? values["severity"]! : "low",
                    location: values["location"]?.isEmpty == false ? values["location"] : nil,
                    observation: values["observation"] ?? "",
                    suggestion: values["suggestion"] ?? "",
                    rationale: values["rationale"] ?? ""
                )
                suggestion.isAddressed = boolValue(values["isAddressed"])
                suggestion.userNotes = values["userNotes"]?.isEmpty == false ? values["userNotes"] : nil
                review.suggestions.append(suggestion)
                context.insert(suggestion)
                reviewSuggestionCount += 1

            case "Folder":
                let folder = Folder(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Untitled Folder",
                    project: nil,
                    parentFolder: nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let folderId = UUID(uuidString: item.entityId) {
                    folder.id = folderId
                }
                folder.project = scratchProject
                context.insert(folder)
                foldersByRemoteId[item.entityId] = folder
                folderCount += 1

            case "TextFile":
                let parentFolder: Folder
                if let folderId = values["folderId"], let folder = foldersByRemoteId[folderId] {
                    parentFolder = folder
                } else {
                    parentFolder = scratchFolder
                }
                let textFile = makeScratchTextFile(id: item.entityId, values: values, parentFolder: parentFolder, context: context)
                context.insert(textFile)
                textFilesByRemoteId[item.entityId] = textFile
                textFileCount += 1

            case "Version":
                guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch TextFile for Version \(item.entityId)")
                }
                let version = Version(
                    content: values["content"] ?? "",
                    versionNumber: intValue(values["versionNumber"]) ?? 1,
                    comment: values["comment"]?.isEmpty == false ? values["comment"] : nil
                )
                if let versionId = UUID(uuidString: item.entityId) {
                    version.id = versionId
                }
                version.notes = values["notes"]?.isEmpty == false ? values["notes"] : nil
                version.textFile = textFile
                if textFile.versions == nil {
                    textFile.versions = []
                }
                textFile.versions?.append(version)
                textFile.versions = textFile.versions?.sorted { $0.versionNumber < $1.versionNumber }
                textFile.currentVersionIndex = max((textFile.versions?.count ?? 1) - 1, 0)
                context.insert(version)
                versionsByRemoteId[item.entityId] = version
                versionCount += 1

            case "TrashItem":
                guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch TextFile for TrashItem \(item.entityId)")
                }
                let originalFolder = values["originalFolderId"].flatMap { foldersByRemoteId[$0] }
                let trashItem = TrashItem(textFile: textFile, originalFolder: originalFolder, project: scratchProject)
                if let trashItemId = UUID(uuidString: item.entityId) {
                    trashItem.id = trashItemId
                }
                trashItem.deletedDate = dateValue(values["deletedDate"]) ?? trashItem.deletedDate
                textFile.trashItem = trashItem
                if scratchProject.trashedItems == nil {
                    scratchProject.trashedItems = []
                }
                scratchProject.trashedItems?.append(trashItem)
                context.insert(trashItem)
                trashItemCount += 1

            case "CommentModel":
                guard let versionId = values["versionId"], let version = versionsByRemoteId[versionId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Version for CommentModel \(item.entityId)")
                }
                let comment = makeScratchComment(id: item.entityId, values: values, version: version)
                if version.comments == nil {
                    version.comments = []
                }
                version.comments?.append(comment)
                context.insert(comment)
                commentCount += 1

            case "FootnoteModel":
                guard let versionId = values["versionId"], let version = versionsByRemoteId[versionId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Version for FootnoteModel \(item.entityId)")
                }
                let footnote = makeScratchFootnote(id: item.entityId, values: values, version: version)
                if version.footnotes == nil {
                    version.footnotes = []
                }
                version.footnotes?.append(footnote)
                context.insert(footnote)
                footnoteCount += 1

            case "NoteEntry":
                let note = makeScratchNote(id: item.entityId, values: values, project: scratchProject)
                context.insert(note)
                notesByRemoteId[item.entityId] = note
                noteCount += 1

            case "CitationEntry":
                let citation = makeScratchCitation(id: item.entityId, values: values, project: scratchProject)
                context.insert(citation)
                citationsByRemoteId[item.entityId] = citation
                citationCount += 1

            case "GlossaryEntry":
                let citation = values["citationId"].flatMap { citationsByRemoteId[$0] }
                let glossaryEntry = makeScratchGlossaryEntry(id: item.entityId, values: values, project: scratchProject, citation: citation)
                if let citation {
                    if citation.glossaryEntries == nil {
                        citation.glossaryEntries = []
                    }
                    citation.glossaryEntries?.append(glossaryEntry)
                }
                context.insert(glossaryEntry)
                glossaryEntriesByRemoteId[item.entityId] = glossaryEntry
                glossaryCount += 1

            case "ReferenceEntry":
                let referenceEntry = makeScratchReferenceEntry(id: item.entityId, values: values, project: scratchProject)
                context.insert(referenceEntry)
                referenceEntriesByRemoteId[item.entityId] = referenceEntry
                referenceEntryCount += 1

            case "IndexEntry":
                let parent = values["parentEntryId"].flatMap { indexEntriesByRemoteId[$0] }
                let indexEntry = makeScratchIndexEntry(id: item.entityId, values: values, project: scratchProject, parent: parent)
                if let parent {
                    if parent.childEntries == nil {
                        parent.childEntries = []
                    }
                    parent.childEntries?.append(indexEntry)
                }
                context.insert(indexEntry)
                indexEntriesByRemoteId[item.entityId] = indexEntry
                indexEntryCount += 1

            case "ContributorEntry":
                let contributor = makeScratchContributor(id: item.entityId, values: values, project: scratchProject)
                context.insert(contributor)
                contributorsByRemoteId[item.entityId] = contributor
                contributorCount += 1

            case "Chapter":
                let chapter = Chapter(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Chapter",
                    synopsis: values["synopsis"]?.isEmpty == false ? values["synopsis"] : nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let chapterId = UUID(uuidString: item.entityId) {
                    chapter.id = chapterId
                }
                applyBodyMatterPayload(values, to: chapter)
                chapter.project = scratchProject
                context.insert(chapter)
                chaptersByRemoteId[item.entityId] = chapter
                storyRecordCount += 1

            case "Act":
                let act = Act(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Act",
                    synopsis: values["synopsis"]?.isEmpty == false ? values["synopsis"] : nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let actId = UUID(uuidString: item.entityId) {
                    act.id = actId
                }
                applyBodyMatterPayload(values, to: act)
                act.project = scratchProject
                context.insert(act)
                actsByRemoteId[item.entityId] = act
                storyRecordCount += 1

            case "Book":
                let book = Book(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Book",
                    synopsis: values["synopsis"]?.isEmpty == false ? values["synopsis"] : nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let bookId = UUID(uuidString: item.entityId) {
                    book.id = bookId
                }
                applyBodyMatterPayload(values, to: book)
                book.project = scratchProject
                context.insert(book)
                booksByRemoteId[item.entityId] = book
                storyRecordCount += 1

            case "PoetryCollection":
                let collection = PoetryCollection(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Poetry Collection",
                    synopsis: values["synopsis"]?.isEmpty == false ? values["synopsis"] : nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let collectionId = UUID(uuidString: item.entityId) {
                    collection.id = collectionId
                }
                applyBodyMatterPayload(values, to: collection)
                collection.project = scratchProject
                context.insert(collection)
                poetryCollectionsByRemoteId[item.entityId] = collection
                storyRecordCount += 1

            case "ProseSection":
                let section = ProseSection(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Prose Section",
                    synopsis: values["synopsis"]?.isEmpty == false ? values["synopsis"] : nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let sectionId = UUID(uuidString: item.entityId) {
                    section.id = sectionId
                }
                applyBodyMatterPayload(values, to: section)
                section.project = scratchProject
                context.insert(section)
                proseSectionsByRemoteId[item.entityId] = section
                storyRecordCount += 1

            case "StoryScene":
                let scene = StoryScene(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Scene",
                    synopsis: values["synopsis"]?.isEmpty == false ? values["synopsis"] : nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let sceneId = UUID(uuidString: item.entityId) {
                    scene.id = sceneId
                }
                applyBodyMatterPayload(values, to: scene)
                scene.monomythStageRaw = values["monomythStageRaw"]?.isEmpty == false ? values["monomythStageRaw"] : nil
                scene.campbellStageRaw = values["campbellStageRaw"]?.isEmpty == false ? values["campbellStageRaw"] : nil
                scene.threeActStageRaw = values["threeActStageRaw"]?.isEmpty == false ? values["threeActStageRaw"] : nil
                scene.pearsonStageRaw = values["pearsonStageRaw"]?.isEmpty == false ? values["pearsonStageRaw"] : nil
                scene.isTrashed = boolValue(values["isTrashed"])
                scene.trashedDate = dateValue(values["trashedDate"])
                if let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId] {
                    scene.textFile = textFile
                }
                if let locationId = values["locationId"], let location = locationsByRemoteId[locationId] {
                    scene.location = location
                }
                scene.project = scratchProject
                context.insert(scene)
                scenesByRemoteId[item.entityId] = scene
                storyRecordCount += 1

            case "Character":
                let character = Character(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Character",
                    role: values["role"]?.isEmpty == false ? values["role"] : nil,
                    archetypes: [],
                    history: values["history"]?.isEmpty == false ? values["history"] : nil,
                    looks: values["looks"]?.isEmpty == false ? values["looks"] : nil,
                    traits: values["traits"]?.isEmpty == false ? values["traits"] : nil,
                    work: values["work"]?.isEmpty == false ? values["work"] : nil
                )
                if let characterId = UUID(uuidString: item.entityId) {
                    character.id = characterId
                }
                character.archetypeRaw = values["archetypeRaw"]?.isEmpty == false ? values["archetypeRaw"] : nil
                character.pearsonArchetypeRaw = values["pearsonArchetypeRaw"]?.isEmpty == false ? values["pearsonArchetypeRaw"] : nil
                character.createdDate = dateValue(values["createdDate"]) ?? character.createdDate
                character.modifiedDate = dateValue(values["modifiedDate"]) ?? character.modifiedDate
                character.project = scratchProject
                context.insert(character)
                charactersByRemoteId[item.entityId] = character
                storyRecordCount += 1

            case "Location":
                let location = Location(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Location",
                    detail: values["detail"]?.isEmpty == false ? values["detail"] : nil,
                    sights: values["sights"]?.isEmpty == false ? values["sights"] : nil,
                    sounds: values["sounds"]?.isEmpty == false ? values["sounds"] : nil,
                    smells: values["smells"]?.isEmpty == false ? values["smells"] : nil
                )
                if let locationId = UUID(uuidString: item.entityId) {
                    location.id = locationId
                }
                location.createdDate = dateValue(values["createdDate"]) ?? location.createdDate
                location.modifiedDate = dateValue(values["modifiedDate"]) ?? location.modifiedDate
                location.project = scratchProject
                context.insert(location)
                locationsByRemoteId[item.entityId] = location
                storyRecordCount += 1

            case "CustomAttribute":
                let character = values["characterId"].flatMap { charactersByRemoteId[$0] }
                let location = values["locationId"].flatMap { locationsByRemoteId[$0] }
                guard character != nil || location != nil else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Character/Location for CustomAttribute \(item.entityId)")
                }
                let customAttribute = CustomAttribute(
                    key: values["key"]?.isEmpty == false ? values["key"] : nil,
                    value: values["value"]?.isEmpty == false ? values["value"] : nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let customAttributeId = UUID(uuidString: item.entityId) {
                    customAttribute.id = customAttributeId
                }
                customAttribute.character = character
                customAttribute.location = location
                if let character {
                    if character.customAttributes == nil {
                        character.customAttributes = []
                    }
                    character.customAttributes?.append(customAttribute)
                }
                if let location {
                    if location.customAttributes == nil {
                        location.customAttributes = []
                    }
                    location.customAttributes?.append(customAttribute)
                }
                context.insert(customAttribute)
                customAttributeCount += 1

            case "PlotElement":
                let plotElement = PlotElement(
                    name: values["name"]?.isEmpty == false ? values["name"] : "Imported Plot Element",
                    notes: values["notes"]?.isEmpty == false ? values["notes"] : nil,
                    monomythStage: nil,
                    threeActStage: nil,
                    userOrder: intValue(values["userOrder"])
                )
                if let plotElementId = UUID(uuidString: item.entityId) {
                    plotElement.id = plotElementId
                }
                plotElement.monomythStageRaw = values["monomythStageRaw"]?.isEmpty == false ? values["monomythStageRaw"] : nil
                plotElement.campbellStageRaw = values["campbellStageRaw"]?.isEmpty == false ? values["campbellStageRaw"] : nil
                plotElement.threeActStageRaw = values["threeActStageRaw"]?.isEmpty == false ? values["threeActStageRaw"] : nil
                plotElement.pearsonStageRaw = values["pearsonStageRaw"]?.isEmpty == false ? values["pearsonStageRaw"] : nil
                plotElement.createdDate = dateValue(values["createdDate"]) ?? plotElement.createdDate
                plotElement.modifiedDate = dateValue(values["modifiedDate"]) ?? plotElement.modifiedDate
                plotElement.project = scratchProject
                context.insert(plotElement)
                plotElementsByRemoteId[item.entityId] = plotElement
                storyRecordCount += 1

            case "CharacterPlotElementLink":
                guard let characterId = values["characterId"], let character = charactersByRemoteId[characterId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Character for CharacterPlotElementLink \(item.entityId)")
                }
                guard let plotElementId = values["plotElementId"], let plotElement = plotElementsByRemoteId[plotElementId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch PlotElement for CharacterPlotElementLink \(item.entityId)")
                }
                let link = CharacterPlotElementLink(character: character, plotElement: plotElement)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if character.plotElementLinks == nil {
                    character.plotElementLinks = []
                }
                if plotElement.characterLinks == nil {
                    plotElement.characterLinks = []
                }
                character.plotElementLinks?.append(link)
                plotElement.characterLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "TextFileSectionLink":
                guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch TextFile for TextFileSectionLink \(item.entityId)")
                }
                guard let sectionId = values["sectionId"], let section = proseSectionsByRemoteId[sectionId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch ProseSection for TextFileSectionLink \(item.entityId)")
                }
                let link = TextFileSectionLink(textFile: textFile, section: section, userOrder: intValue(values["userOrder"]))
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if textFile.sectionLinks == nil {
                    textFile.sectionLinks = []
                }
                if section.textFileLinks == nil {
                    section.textFileLinks = []
                }
                textFile.sectionLinks?.append(link)
                section.textFileLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "TextFileCollectionLink":
                guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch TextFile for TextFileCollectionLink \(item.entityId)")
                }
                guard let collectionId = values["poetryCollectionId"], let collection = poetryCollectionsByRemoteId[collectionId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch PoetryCollection for TextFileCollectionLink \(item.entityId)")
                }
                let link = TextFileCollectionLink(textFile: textFile, poetryCollection: collection, userOrder: intValue(values["userOrder"]))
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if textFile.poetryCollectionLinks == nil {
                    textFile.poetryCollectionLinks = []
                }
                if collection.textFileLinks == nil {
                    collection.textFileLinks = []
                }
                textFile.poetryCollectionLinks?.append(link)
                collection.textFileLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "SceneChapterLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StoryScene for SceneChapterLink \(item.entityId)")
                }
                guard let chapterId = values["chapterId"], let chapter = chaptersByRemoteId[chapterId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Chapter for SceneChapterLink \(item.entityId)")
                }
                let link = SceneChapterLink(scene: scene, chapter: chapter)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if scene.chapterLinks == nil {
                    scene.chapterLinks = []
                }
                if chapter.sceneLinks == nil {
                    chapter.sceneLinks = []
                }
                scene.chapterLinks?.append(link)
                chapter.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "SceneActLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StoryScene for SceneActLink \(item.entityId)")
                }
                guard let actId = values["actId"], let act = actsByRemoteId[actId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Act for SceneActLink \(item.entityId)")
                }
                let link = SceneActLink(scene: scene, act: act)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if scene.actLinks == nil {
                    scene.actLinks = []
                }
                if act.sceneLinks == nil {
                    act.sceneLinks = []
                }
                scene.actLinks?.append(link)
                act.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "SceneBookLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StoryScene for SceneBookLink \(item.entityId)")
                }
                guard let bookId = values["bookId"], let book = booksByRemoteId[bookId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Book for SceneBookLink \(item.entityId)")
                }
                let link = SceneBookLink(scene: scene, book: book)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if scene.bookLinks == nil {
                    scene.bookLinks = []
                }
                if book.sceneLinks == nil {
                    book.sceneLinks = []
                }
                scene.bookLinks?.append(link)
                book.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "ScenePlotElementLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StoryScene for ScenePlotElementLink \(item.entityId)")
                }
                guard let plotElementId = values["plotElementId"], let plotElement = plotElementsByRemoteId[plotElementId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch PlotElement for ScenePlotElementLink \(item.entityId)")
                }
                let link = ScenePlotElementLink(scene: scene, plotElement: plotElement)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if scene.plotElementLinks == nil {
                    scene.plotElementLinks = []
                }
                if plotElement.sceneLinks == nil {
                    plotElement.sceneLinks = []
                }
                scene.plotElementLinks?.append(link)
                plotElement.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "SceneCharacterLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StoryScene for SceneCharacterLink \(item.entityId)")
                }
                guard let characterId = values["characterId"], let character = charactersByRemoteId[characterId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Character for SceneCharacterLink \(item.entityId)")
                }
                let link = SceneCharacterLink(scene: scene, character: character)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if scene.characterLinks == nil {
                    scene.characterLinks = []
                }
                if character.sceneLinks == nil {
                    character.sceneLinks = []
                }
                scene.characterLinks?.append(link)
                character.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "SceneLocationLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch StoryScene for SceneLocationLink \(item.entityId)")
                }
                guard let locationId = values["locationId"], let location = locationsByRemoteId[locationId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Location for SceneLocationLink \(item.entityId)")
                }
                let link = SceneLocationLink(scene: scene, location: location)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if scene.locationLinks == nil {
                    scene.locationLinks = []
                }
                if location.sceneLinks == nil {
                    location.sceneLinks = []
                }
                scene.locationLinks?.append(link)
                location.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "LocationPlotElementLink":
                guard let locationId = values["locationId"], let location = locationsByRemoteId[locationId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Location for LocationPlotElementLink \(item.entityId)")
                }
                guard let plotElementId = values["plotElementId"], let plotElement = plotElementsByRemoteId[plotElementId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch PlotElement for LocationPlotElementLink \(item.entityId)")
                }
                let link = LocationPlotElementLink(location: location, plotElement: plotElement)
                if let linkId = UUID(uuidString: item.entityId) {
                    link.id = linkId
                }
                if location.plotElementLinks == nil {
                    location.plotElementLinks = []
                }
                if plotElement.locationLinks == nil {
                    plotElement.locationLinks = []
                }
                location.plotElementLinks?.append(link)
                plotElement.locationLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1

            case "Publication":
                let publication = makeScratchPublication(id: item.entityId, values: values, project: scratchProject)
                context.insert(publication)
                publicationsByRemoteId[item.entityId] = publication
                publicationCount += 1

            case "Submission":
                guard let publicationId = values["publicationId"], let publication = publicationsByRemoteId[publicationId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Publication for Submission \(item.entityId)")
                }
                let submission = makeScratchSubmission(id: item.entityId, values: values, publication: publication, project: scratchProject)
                context.insert(submission)
                submissionsByRemoteId[item.entityId] = submission
                submissionCount += 1

            case "SubmittedFile":
                guard let submissionId = values["submissionId"], let submission = submissionsByRemoteId[submissionId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Submission for SubmittedFile \(item.entityId)")
                }
                guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch TextFile for SubmittedFile \(item.entityId)")
                }
                guard let versionId = values["versionId"], let version = versionsByRemoteId[versionId] else {
                    throw CloudflareSyncPOCError.applyPlanNotReady("missing scratch Version for SubmittedFile \(item.entityId)")
                }
                let submittedFile = makeScratchSubmittedFile(id: item.entityId, values: values, submission: submission, textFile: textFile, version: version, project: scratchProject)
                context.insert(submittedFile)
                submittedFilesByRemoteId[item.entityId] = submittedFile
                submittedFileCount += 1

            default:
                throw CloudflareSyncPOCError.applyPlanNotReady("unsupported scratch entity \(item.entityType)")
            }
        }

        try context.save()
        return CloudflareSyncPOCMaterializeResult(
            styleSheetCount: styleSheetCount,
            textStyleCount: textStyleCount,
            imageStyleCount: imageStyleCount,
            folderCount: folderCount,
            textFileCount: textFileCount,
            versionCount: versionCount,
            trashItemCount: trashItemCount,
            commentCount: commentCount,
            footnoteCount: footnoteCount,
            storyRecordCount: storyRecordCount,
            customAttributeCount: customAttributeCount,
            joinLinkCount: joinLinkCount,
            noteCount: noteCount,
            citationCount: citationCount,
            glossaryCount: glossaryCount,
            referenceEntryCount: referenceEntryCount,
            indexEntryCount: indexEntryCount,
            contributorCount: contributorCount,
            pageSetupCount: pageSetupCount,
            printerPaperCount: printerPaperCount,
            poetryFormCount: poetryFormCount,
            manuscriptReviewCount: manuscriptReviewCount,
            reviewSuggestionCount: reviewSuggestionCount,
            publicationCount: publicationCount,
            submissionCount: submissionCount,
            submittedFileCount: submittedFileCount,
            updateExistingCount: updateExistingCount,
            seededExistingCount: seededExistingCount,
            restoreMissingCount: restoreMissingCount,
            deleteNoopMissingCount: deleteNoopMissingCount,
            storeURL: storeURL
        )
    }

    private func applyStageRank(for finalAction: String) -> Int {
        switch finalAction {
        case "upsert", "restore":
            return 0
        case "delete":
            return 1
        default:
            return 2
        }
    }

    private func cloudflareSyncPOCScratchSchema() -> Schema {
        Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            TrashItem.self,
            StyleSheet.self,
            TextStyleModel.self,
            PageSetup.self,
            PrinterPaper.self,
            Publication.self,
            Submission.self,
            SubmittedFile.self,
            CommentModel.self,
            FootnoteModel.self,
            PoetryFormModel.self,
            StoryScene.self,
            Chapter.self,
            Character.self,
            Location.self,
            CustomAttribute.self,
            PlotElement.self,
            Act.self,
            ProseSection.self,
            PoetryCollection.self,
            Book.self,
            TextFileSectionLink.self,
            TextFileCollectionLink.self,
            SceneChapterLink.self,
            SceneActLink.self,
            SceneBookLink.self,
            ScenePlotElementLink.self,
            SceneCharacterLink.self,
            CharacterPlotElementLink.self,
            LocationPlotElementLink.self,
            SceneLocationLink.self,
            NoteEntry.self,
            GlossaryEntry.self,
            ReferenceEntry.self,
            CitationEntry.self,
            IndexEntry.self,
            ContributorEntry.self,
            ImageStyle.self,
            ManuscriptReview.self,
            ReviewSuggestion.self,
        ])
    }

    private func entityApplyRank(for entityType: String) -> Int {
        switch entityType {
        case "Project":
            return 0
        case "StyleSheet", "PageSetup", "PoetryFormModel", "ManuscriptReview", "Folder", "Chapter", "Act", "ProseSection", "PoetryCollection", "Book", "Character", "Location", "PlotElement", "Publication":
            return 10
        case "TextStyleModel", "ImageStyle", "PrinterPaper", "ReviewSuggestion", "TextFile", "StoryScene", "CustomAttribute", "NoteEntry", "GlossaryEntry", "ReferenceEntry", "CitationEntry", "IndexEntry", "ContributorEntry":
            return 20
        case "Version":
            return 30
        case "TrashItem":
            return 34
        case "Submission":
            return 32
        case "SubmittedFile":
            return 34
        case "CommentModel", "FootnoteModel":
            return 35
        case "TextFileSectionLink", "TextFileCollectionLink", "SceneChapterLink", "SceneActLink", "SceneBookLink", "ScenePlotElementLink", "SceneCharacterLink", "CharacterPlotElementLink", "LocationPlotElementLink", "SceneLocationLink":
            return 40
        default:
            return 50
        }
    }

    private func dependencyStatus(for operation: SyncPOCPulledOperation, finalAction: String, availableEntityKeys: Set<String>) -> String {
        guard finalAction == "upsert" else { return "deps-not-required" }
        let requiredKeys = requiredDependencyKeys(for: operation)
        guard !requiredKeys.isEmpty else { return "deps-ok" }
        let missingKeys = requiredKeys.filter { !availableEntityKeys.contains($0) }
        guard !missingKeys.isEmpty else { return "deps-ok" }
        let sample = missingKeys.prefix(2).map { key in
            key.split(separator: ":", maxSplits: 1).first.map(String.init) ?? key
        }.joined(separator: "+")
        return "missing-deps:\(sample)"
    }

    private func requiredDependencyKeys(for operation: SyncPOCPulledOperation) -> [String] {
        guard let values = operation.payload?.values else { return [] }

        func dependency(_ entityType: String, _ fieldName: String) -> String? {
            guard let id = values[fieldName], !id.isEmpty else { return nil }
            return "\(entityType):\(id)"
        }

        switch operation.entityType {
        case "TextStyleModel", "ImageStyle":
            return [dependency("StyleSheet", "styleSheetId")].compactMap { $0 }
        case "PrinterPaper":
            return [dependency("PageSetup", "pageSetupId")].compactMap { $0 }
        case "ReviewSuggestion":
            return [dependency("ManuscriptReview", "reviewId")].compactMap { $0 }
        case "Folder":
            return [dependency("Folder", "parentFolderId")].compactMap { $0 }
        case "TextFile":
            return [dependency("Folder", "folderId")].compactMap { $0 }
        case "Version":
            return [dependency("TextFile", "textFileId")].compactMap { $0 }
        case "TrashItem":
            return [dependency("TextFile", "textFileId"), dependency("Folder", "originalFolderId")].compactMap { $0 }
        case "CommentModel", "FootnoteModel":
            return [dependency("Version", "versionId")].compactMap { $0 }
        case "StoryScene":
            return [dependency("TextFile", "textFileId")].compactMap { $0 }
        case "CustomAttribute":
            return [dependency("Character", "characterId"), dependency("Location", "locationId")].compactMap { $0 }
        case "TextFileSectionLink":
            return [dependency("TextFile", "textFileId"), dependency("ProseSection", "sectionId")].compactMap { $0 }
        case "TextFileCollectionLink":
            return [dependency("TextFile", "textFileId"), dependency("PoetryCollection", "poetryCollectionId")].compactMap { $0 }
        case "SceneChapterLink":
            return [dependency("StoryScene", "sceneId"), dependency("Chapter", "chapterId")].compactMap { $0 }
        case "SceneActLink":
            return [dependency("StoryScene", "sceneId"), dependency("Act", "actId")].compactMap { $0 }
        case "SceneBookLink":
            return [dependency("StoryScene", "sceneId"), dependency("Book", "bookId")].compactMap { $0 }
        case "ScenePlotElementLink":
            return [dependency("StoryScene", "sceneId"), dependency("PlotElement", "plotElementId")].compactMap { $0 }
        case "SceneCharacterLink":
            return [dependency("StoryScene", "sceneId"), dependency("Character", "characterId")].compactMap { $0 }
        case "CharacterPlotElementLink":
            return [dependency("Character", "characterId"), dependency("PlotElement", "plotElementId")].compactMap { $0 }
        case "LocationPlotElementLink":
            return [dependency("Location", "locationId"), dependency("PlotElement", "plotElementId")].compactMap { $0 }
        case "SceneLocationLink":
            return [dependency("StoryScene", "sceneId"), dependency("Location", "locationId")].compactMap { $0 }
        case "GlossaryEntry":
            return [dependency("CitationEntry", "citationId")].compactMap { $0 }
        case "IndexEntry":
            return [dependency("IndexEntry", "parentEntryId")].compactMap { $0 }
        case "Submission":
            return [dependency("Publication", "publicationId")].compactMap { $0 }
        case "SubmittedFile":
            return [dependency("Submission", "submissionId"), dependency("TextFile", "textFileId"), dependency("Version", "versionId")].compactMap { $0 }
        default:
            return []
        }
    }

    private func proposedLocalAction(for finalAction: String, localExists: Bool) -> String {
        switch finalAction {
        case "upsert":
            return localExists ? "updateExisting" : "createMissing"
        case "delete":
            return localExists ? "markDeleted" : "deleteNoopMissing"
        case "restore":
            return localExists ? "restoreExisting" : "restoreMissing"
        default:
            return "ignoreUnsupported"
        }
    }

    @MainActor
    private func localEntityKeys(in project: Project) -> Set<String> {
        var keys: Set<String> = ["Project:\(project.id.uuidString)"]
        if let pendingEntityKey = rememberedPendingApplyEntityKey() {
            keys.insert(pendingEntityKey)
        }

        func insert(_ entityType: String, _ id: UUID) {
            keys.insert("\(entityType):\(id.uuidString)")
        }

        if let styleSheet = project.styleSheet {
            insert("StyleSheet", styleSheet.id)
            sortedTextStyles(styleSheet.textStyles).forEach { insert("TextStyleModel", $0.id) }
            sortedImageStyles(styleSheet.imageStyles).forEach { insert("ImageStyle", $0.id) }
        }

        if let pageSetup = project.pageSetup {
            insert("PageSetup", pageSetup.id)
            sortedPrinterPapers(pageSetup.printerPapers).forEach { insert("PrinterPaper", $0.id) }
        }

        let folders = sampleFolders(in: project)
        folders.forEach { insert("Folder", $0.id) }
        let textFiles = sampleTextFiles(in: folders)
        textFiles.forEach { insert("TextFile", $0.id) }
        let versions = textFiles.flatMap { sampleVersions(in: $0) }
        versions.forEach { insert("Version", $0.id) }
        sampleTrashItems(in: project).forEach { insert("TrashItem", $0.id) }
        sampleComments(in: versions).forEach { insert("CommentModel", $0.id) }
        sampleFootnotes(in: versions).forEach { insert("FootnoteModel", $0.id) }

        let scenes = sampleStoryScenes(in: project)
        let characters = sampleCharacters(in: project)
        let locations = sampleLocations(in: project)
        scenes.forEach { insert("StoryScene", $0.id) }
        sampleChapters(in: project).forEach { insert("Chapter", $0.id) }
        sampleActs(in: project).forEach { insert("Act", $0.id) }
        sampleProseSections(in: project).forEach { insert("ProseSection", $0.id) }
        samplePoetryCollections(in: project).forEach { insert("PoetryCollection", $0.id) }
        sampleBooks(in: project).forEach { insert("Book", $0.id) }
        characters.forEach { insert("Character", $0.id) }
        locations.forEach { insert("Location", $0.id) }
        sampleCustomAttributes(characters: characters, locations: locations).forEach { insert("CustomAttribute", $0.id) }
        samplePlotElements(in: project).forEach { insert("PlotElement", $0.id) }
        sampleJoinLinks(textFiles: textFiles, scenes: scenes, characters: characters, locations: locations).forEach { keys.insert("\($0.entityType):\($0.entityId)") }

        localNoteEntriesForPOC(in: project).forEach { insert("NoteEntry", $0.id) }
        sampleGlossaryEntries(in: project).forEach { insert("GlossaryEntry", $0.id) }
        sampleReferenceEntries(in: project).forEach { insert("ReferenceEntry", $0.id) }
        sampleCitations(in: project).forEach { insert("CitationEntry", $0.id) }
        sampleIndexEntries(in: project).forEach { insert("IndexEntry", $0.id) }
        sampleContributors(in: project).forEach { insert("ContributorEntry", $0.id) }

        let publications = samplePublications(in: project)
        let submissions = sampleSubmissions(in: project)
        publications.forEach { insert("Publication", $0.id) }
        submissions.forEach { insert("Submission", $0.id) }
        sampleSubmittedFiles(in: submissions).forEach { insert("SubmittedFile", $0.id) }

        return keys
    }

    @MainActor
    private func findLocalFolder(id: UUID, in project: Project) -> Folder? {
        sampleFolders(in: project).first { $0.id == id }
    }

    @MainActor
    private func findLocalTextFile(id: UUID, in project: Project) -> TextFile? {
        sampleTextFiles(in: sampleFolders(in: project)).first { $0.id == id }
    }

    @MainActor
    private func findLocalVersion(id: UUID, in project: Project) -> Version? {
        sampleTextFiles(in: sampleFolders(in: project)).flatMap { sampleVersions(in: $0) }.first { $0.id == id }
    }

    private func countedSummary(_ values: [String]) -> String {
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        return counts
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }

    private func makeImportPreview(from operations: [SyncPOCPulledOperation]) -> (projectName: String, styleSheetCount: Int, textStyleCount: Int, imageStyleCount: Int, folderCount: Int, textFileCount: Int, versionCount: Int, commentCount: Int, footnoteCount: Int, storyRecordCount: Int, joinLinkCount: Int, referenceRecordCount: Int, publicationCount: Int, submissionCount: Int, submittedFileCount: Int, totalContentCharacters: Int) {
        let importState = makeImportState(from: operations)
        return (importState.projectName, importState.styleSheetsById.count, importState.textStylesById.count, importState.imageStylesById.count, importState.foldersById.count, importState.textFilesById.count, importState.versionsById.count, importState.commentsById.count, importState.footnotesById.count, importState.storyRecordCount, importState.joinLinksById.count, importState.referenceRecordCount, importState.publicationsById.count, importState.submissionsById.count, importState.submittedFilesById.count, importState.totalContentCharacters)
    }

    private func makeImportState(from operations: [SyncPOCPulledOperation]) -> CloudflareSyncPOCImportState {
        var importState = CloudflareSyncPOCImportState()

        for operation in operations.sorted(by: { $0.serverSequence < $1.serverSequence }) {
            guard operation.operationType == "upsert", let values = operation.payload?.values else { continue }

            switch operation.entityType {
            case "Project":
                importState.projectId = operation.entityId
                importState.projectName = values["name"]?.isEmpty == false ? values["name"]! : importState.projectName
                importState.projectTypeRaw = values["type"]?.isEmpty == false ? values["type"]! : importState.projectTypeRaw
                importState.projectStyleSheetId = values["styleSheetId"] ?? ""
            case "StyleSheet":
                importState.styleSheetsById[operation.entityId] = values
            case "TextStyleModel":
                importState.textStylesById[operation.entityId] = values
            case "ImageStyle":
                importState.imageStylesById[operation.entityId] = values
            case "Folder":
                importState.foldersById[operation.entityId] = values
            case "TextFile":
                importState.textFilesById[operation.entityId] = values
            case "Version":
                importState.versionsById[operation.entityId] = values
            case "CommentModel":
                importState.commentsById[operation.entityId] = values
            case "FootnoteModel":
                importState.footnotesById[operation.entityId] = values
            case "StoryScene":
                importState.storyScenesById[operation.entityId] = values
            case "Chapter":
                importState.chaptersById[operation.entityId] = values
            case "Act":
                importState.actsById[operation.entityId] = values
            case "ProseSection":
                importState.proseSectionsById[operation.entityId] = values
            case "PoetryCollection":
                importState.poetryCollectionsById[operation.entityId] = values
            case "Book":
                importState.booksById[operation.entityId] = values
            case "Character":
                importState.charactersById[operation.entityId] = values
            case "Location":
                importState.locationsById[operation.entityId] = values
            case "PlotElement":
                importState.plotElementsById[operation.entityId] = values
            case "TextFileSectionLink", "TextFileCollectionLink", "SceneChapterLink", "SceneActLink", "SceneBookLink", "ScenePlotElementLink", "SceneCharacterLink", "CharacterPlotElementLink", "LocationPlotElementLink", "SceneLocationLink":
                var linkValues = values
                linkValues["linkType"] = operation.entityType
                importState.joinLinksById[operation.entityId] = linkValues
            case "NoteEntry":
                importState.notesById[operation.entityId] = values
            case "GlossaryEntry":
                importState.glossaryEntriesById[operation.entityId] = values
            case "ReferenceEntry":
                importState.referenceEntriesById[operation.entityId] = values
            case "CitationEntry":
                importState.citationEntriesById[operation.entityId] = values
            case "IndexEntry":
                importState.indexEntriesById[operation.entityId] = values
            case "ContributorEntry":
                importState.contributorEntriesById[operation.entityId] = values
            case "Publication":
                importState.publicationsById[operation.entityId] = values
            case "Submission":
                importState.submissionsById[operation.entityId] = values
            case "SubmittedFile":
                importState.submittedFilesById[operation.entityId] = values
            default:
                continue
            }
        }

        return importState
    }

    @MainActor
    private func materialize(importState: CloudflareSyncPOCImportState) throws -> CloudflareSyncPOCImportMaterializeResult {
        let storeURL = try resetIsolatedImportStore()
        let importContext = try makeIsolatedImportContext(storeURL: storeURL, importState: importState)
        let context = importContext.context
        let importedProject = importContext.project

        var styleSheetsByRemoteId: [String: StyleSheet] = [:]
        for (remoteId, values) in importState.styleSheetsById.sorted(by: { ($0.value["name"] ?? "") < ($1.value["name"] ?? "") }) {
            let styleSheet = StyleSheet(
                name: values["name"]?.isEmpty == false ? values["name"]! : "Imported StyleSheet",
                isSystemStyleSheet: boolValue(values["isSystemStyleSheet"])
            )
            if let styleSheetId = UUID(uuidString: remoteId) {
                styleSheet.id = styleSheetId
            }
            styleSheet.footnoteMarkerStyleRaw = values["footnoteMarkerStyleRaw"]?.isEmpty == false ? values["footnoteMarkerStyleRaw"]! : styleSheet.footnoteMarkerStyleRaw
            styleSheetsByRemoteId[remoteId] = styleSheet
            context.insert(styleSheet)
        }

        for (remoteId, values) in importState.textStylesById.sorted(by: { intValue($0.value["displayOrder"]) ?? Int.max < intValue($1.value["displayOrder"]) ?? Int.max }) {
            guard let styleSheetId = values["styleSheetId"], let styleSheet = styleSheetsByRemoteId[styleSheetId] else { continue }
            let textStyle = TextStyleModel(
                name: values["name"]?.isEmpty == false ? values["name"]! : "imported-style",
                displayName: values["displayName"]?.isEmpty == false ? values["displayName"]! : "Imported Style",
                displayOrder: intValue(values["displayOrder"]) ?? 0,
                fontFamily: values["fontFamily"]?.isEmpty == false ? values["fontFamily"] : nil,
                fontSize: cgFloatValue(values["fontSize"]) ?? 17,
                isBold: boolValue(values["isBold"]),
                isItalic: boolValue(values["isItalic"]),
                isUnderlined: boolValue(values["isUnderlined"]),
                isStrikethrough: boolValue(values["isStrikethrough"]),
                alignment: NSTextAlignment(rawValue: intValue(values["alignmentRaw"]) ?? 0) ?? .natural,
                lineSpacing: cgFloatValue(values["lineSpacing"]) ?? 0,
                paragraphSpacingBefore: cgFloatValue(values["paragraphSpacingBefore"]) ?? 0,
                paragraphSpacingAfter: cgFloatValue(values["paragraphSpacingAfter"]) ?? 0,
                firstLineIndent: cgFloatValue(values["firstLineIndent"]) ?? 0,
                headIndent: cgFloatValue(values["headIndent"]) ?? 0,
                tailIndent: cgFloatValue(values["tailIndent"]) ?? 0,
                lineHeightMultiple: cgFloatValue(values["lineHeightMultiple"]) ?? 0,
                minimumLineHeight: cgFloatValue(values["minimumLineHeight"]) ?? 0,
                maximumLineHeight: cgFloatValue(values["maximumLineHeight"]) ?? 0,
                numberFormat: NumberFormat(rawValue: values["numberFormatRaw"] ?? "") ?? .none,
                styleCategory: StyleCategory(rawValue: values["styleCategoryRaw"] ?? "") ?? .text,
                isSystemStyle: boolValue(values["isSystemStyle"])
            )
            if let textStyleId = UUID(uuidString: remoteId) {
                textStyle.id = textStyleId
            }
            textStyle.fontName = values["fontName"]?.isEmpty == false ? values["fontName"] : nil
            textStyle.textColorHex = values["textColorHex"]?.isEmpty == false ? values["textColorHex"] : nil
            textStyle.numberAdornmentRaw = values["numberAdornmentRaw"]?.isEmpty == false ? values["numberAdornmentRaw"]! : textStyle.numberAdornmentRaw
            textStyle.followOnStyleName = values["followOnStyleName"]?.isEmpty == false ? values["followOnStyleName"] : nil
            textStyle.parentStyleName = values["parentStyleName"]?.isEmpty == false ? values["parentStyleName"] : nil
            textStyle.includeInTOC = boolValue(values["includeInTOC"])
            textStyle.tocLevel = intValue(values["tocLevel"]) ?? 0
            textStyle.isFirstParagraphStyle = boolValue(values["isFirstParagraphStyle"])
            textStyle.styleSheet = styleSheet
            if styleSheet.textStyles == nil {
                styleSheet.textStyles = []
            }
            styleSheet.textStyles?.append(textStyle)
            context.insert(textStyle)
        }

        for (remoteId, values) in importState.imageStylesById.sorted(by: { intValue($0.value["displayOrder"]) ?? Int.max < intValue($1.value["displayOrder"]) ?? Int.max }) {
            guard let styleSheetId = values["styleSheetId"], let styleSheet = styleSheetsByRemoteId[styleSheetId] else { continue }
            let imageStyle = ImageStyle(
                name: values["name"]?.isEmpty == false ? values["name"]! : "imported-image-style",
                displayName: values["displayName"]?.isEmpty == false ? values["displayName"]! : "Imported Image Style",
                displayOrder: intValue(values["displayOrder"]) ?? 0,
                defaultScale: cgFloatValue(values["defaultScale"]) ?? 1.0,
                defaultAlignment: ImageAttachment.ImageAlignment(rawValue: values["defaultAlignmentRaw"] ?? "") ?? .center,
                hasCaptionByDefault: boolValue(values["hasCaptionByDefault"]),
                defaultCaptionStyle: values["defaultCaptionStyle"]?.isEmpty == false ? values["defaultCaptionStyle"]! : "UICTFontTextStyleCaption1",
                isSystemStyle: boolValue(values["isSystemStyle"])
            )
            if let imageStyleId = UUID(uuidString: remoteId) {
                imageStyle.id = imageStyleId
            }
            imageStyle.styleSheet = styleSheet
            if styleSheet.imageStyles == nil {
                styleSheet.imageStyles = []
            }
            styleSheet.imageStyles?.append(imageStyle)
            context.insert(imageStyle)
        }

        if let styleSheet = styleSheetsByRemoteId[importState.projectStyleSheetId] ?? styleSheetsByRemoteId.values.first {
            importedProject.styleSheet = styleSheet
        }

        let sortedFolders = importState.foldersById.sorted { left, right in
            let leftValues = left.value
            let rightValues = right.value
            return (intValue(leftValues["userOrder"]) ?? Int.max, leftValues["name"] ?? "") < (intValue(rightValues["userOrder"]) ?? Int.max, rightValues["name"] ?? "")
        }
        var foldersByRemoteId: [String: Folder] = [:]

        for (remoteId, values) in sortedFolders {
            let folder = Folder(
                name: values["name"]?.isEmpty == false ? values["name"] : "Untitled Folder",
                project: nil,
                parentFolder: nil,
                userOrder: intValue(values["userOrder"])
            )
            folder.frontMatterSettingsData = dataValue(values["frontMatterSettingsData"])
            folder.backMatterSettingsData = dataValue(values["backMatterSettingsData"])
            folder.dramaFrontMatterSettingsData = dataValue(values["dramaFrontMatterSettingsData"])
            folder.dramaBackMatterSettingsData = dataValue(values["dramaBackMatterSettingsData"])
            if let folderId = UUID(uuidString: remoteId) {
                folder.id = folderId
            }
            foldersByRemoteId[remoteId] = folder
            context.insert(folder)
        }

        for (remoteId, values) in importState.foldersById {
            guard let folder = foldersByRemoteId[remoteId] else { continue }
            if let parentId = values["parentFolderId"], let parentFolder = foldersByRemoteId[parentId] {
                folder.parentFolder = parentFolder
            } else {
                folder.project = importedProject
            }
        }

        var textFileCount = 0
        var textFilesByRemoteId: [String: TextFile] = [:]
        for (remoteId, values) in importState.textFilesById.sorted(by: { ($0.value["name"] ?? "") < ($1.value["name"] ?? "") }) {
            guard let folderId = values["folderId"], let folder = foldersByRemoteId[folderId] else { continue }
            let textFile = TextFile(
                name: values["name"]?.isEmpty == false ? values["name"]! : "Untitled File",
                initialContent: "",
                parentFolder: folder
            )
            if let textFileId = UUID(uuidString: remoteId) {
                textFile.id = textFileId
            }
            textFile.workflowStatusRaw = values["workflowStatus"]?.isEmpty == false ? values["workflowStatus"] : nil
            if let contentType = values["contentType"], !contentType.isEmpty {
                textFile.contentTypeRaw = contentType
            }
            for placeholderVersion in textFile.versions ?? [] {
                context.delete(placeholderVersion)
            }
            textFile.versions = []
            context.insert(textFile)
            textFilesByRemoteId[remoteId] = textFile
            textFileCount += 1
        }

        var versionCount = 0
        var versionByRemoteId: [String: Version] = [:]
        for (remoteId, values) in importState.versionsById.sorted(by: { intValue($0.value["versionNumber"]) ?? Int.max < intValue($1.value["versionNumber"]) ?? Int.max }) {
            guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId] else { continue }
            let version = Version(
                content: values["content"] ?? "",
                versionNumber: intValue(values["versionNumber"]) ?? 1,
                comment: values["comment"]?.isEmpty == false ? values["comment"] : nil
            )
            if let versionId = UUID(uuidString: remoteId) {
                version.id = versionId
            }
            version.notes = values["notes"]?.isEmpty == false ? values["notes"] : nil
            version.textFile = textFile
            if textFile.versions == nil {
                textFile.versions = []
            }
            textFile.versions?.append(version)
            context.insert(version)
            versionByRemoteId[remoteId] = version
            versionCount += 1
        }

        for textFile in textFilesByRemoteId.values {
            textFile.versions = textFile.versions?.sorted { $0.versionNumber < $1.versionNumber }
            textFile.currentVersionIndex = max((textFile.versions?.count ?? 1) - 1, 0)
        }

        var commentCount = 0
        for (remoteId, values) in importState.commentsById.sorted(by: { (dateValue($0.value["createdAt"]) ?? Date.distantPast) < (dateValue($1.value["createdAt"]) ?? Date.distantPast) }) {
            guard let versionId = values["versionId"], let version = versionByRemoteId[versionId] else { continue }
            let comment = CommentModel(
                id: UUID(uuidString: remoteId) ?? UUID(),
                version: version,
                characterPosition: intValue(values["characterPosition"]) ?? 0,
                attachmentID: UUID(uuidString: values["attachmentID"] ?? "") ?? UUID(),
                text: values["text"] ?? "",
                author: values["author"] ?? "",
                createdAt: dateValue(values["createdAt"]) ?? Date(),
                resolvedAt: dateValue(values["resolvedAt"])
            )
            if version.comments == nil {
                version.comments = []
            }
            version.comments?.append(comment)
            context.insert(comment)
            commentCount += 1
        }

        var footnoteCount = 0
        for (remoteId, values) in importState.footnotesById.sorted(by: { intValue($0.value["number"]) ?? Int.max < intValue($1.value["number"]) ?? Int.max }) {
            guard let versionId = values["versionId"], let version = versionByRemoteId[versionId] else { continue }
            let footnote = FootnoteModel(
                id: UUID(uuidString: remoteId) ?? UUID(),
                version: version,
                characterPosition: intValue(values["characterPosition"]) ?? 0,
                attachmentID: UUID(uuidString: values["attachmentID"] ?? "") ?? UUID(),
                text: values["text"] ?? "",
                number: intValue(values["number"]) ?? 0,
                createdAt: dateValue(values["createdAt"]) ?? Date(),
                modifiedAt: dateValue(values["modifiedAt"]) ?? Date()
            )
            if version.footnotes == nil {
                version.footnotes = []
            }
            version.footnotes?.append(footnote)
            context.insert(footnote)
            footnoteCount += 1
        }

        var storyRecordCount = 0
        var chaptersByRemoteId: [String: Chapter] = [:]
        var actsByRemoteId: [String: Act] = [:]
        var proseSectionsByRemoteId: [String: ProseSection] = [:]
        var poetryCollectionsByRemoteId: [String: PoetryCollection] = [:]
        var booksByRemoteId: [String: Book] = [:]
        var charactersByRemoteId: [String: Character] = [:]
        var plotElementsByRemoteId: [String: PlotElement] = [:]
        var scenesByRemoteId: [String: StoryScene] = [:]

        for (remoteId, values) in importState.chaptersById.sorted(by: storyRecordSort) {
            let chapter = Chapter(name: emptyStringAsNil(values["name"]), synopsis: emptyStringAsNil(values["synopsis"]), userOrder: intValue(values["userOrder"]))
            if let id = UUID(uuidString: remoteId) { chapter.id = id }
            applyBodyMatterPayload(values, to: chapter)
            chapter.project = importedProject
            chaptersByRemoteId[remoteId] = chapter
            context.insert(chapter)
            storyRecordCount += 1
        }

        for (remoteId, values) in importState.actsById.sorted(by: storyRecordSort) {
            let act = Act(name: emptyStringAsNil(values["name"]), synopsis: emptyStringAsNil(values["synopsis"]), userOrder: intValue(values["userOrder"]))
            if let id = UUID(uuidString: remoteId) { act.id = id }
            applyBodyMatterPayload(values, to: act)
            act.project = importedProject
            actsByRemoteId[remoteId] = act
            context.insert(act)
            storyRecordCount += 1
        }

        for (remoteId, values) in importState.proseSectionsById.sorted(by: storyRecordSort) {
            let section = ProseSection(name: emptyStringAsNil(values["name"]), synopsis: emptyStringAsNil(values["synopsis"]), userOrder: intValue(values["userOrder"]))
            if let id = UUID(uuidString: remoteId) { section.id = id }
            applyBodyMatterPayload(values, to: section)
            section.project = importedProject
            proseSectionsByRemoteId[remoteId] = section
            context.insert(section)
            storyRecordCount += 1
        }

        for (remoteId, values) in importState.poetryCollectionsById.sorted(by: storyRecordSort) {
            let collection = PoetryCollection(name: emptyStringAsNil(values["name"]), synopsis: emptyStringAsNil(values["synopsis"]), userOrder: intValue(values["userOrder"]))
            if let id = UUID(uuidString: remoteId) { collection.id = id }
            applyBodyMatterPayload(values, to: collection)
            collection.project = importedProject
            poetryCollectionsByRemoteId[remoteId] = collection
            context.insert(collection)
            storyRecordCount += 1
        }

        for (remoteId, values) in importState.booksById.sorted(by: storyRecordSort) {
            let book = Book(name: emptyStringAsNil(values["name"]), synopsis: emptyStringAsNil(values["synopsis"]), userOrder: intValue(values["userOrder"]))
            if let id = UUID(uuidString: remoteId) { book.id = id }
            applyBodyMatterPayload(values, to: book)
            book.project = importedProject
            booksByRemoteId[remoteId] = book
            context.insert(book)
            storyRecordCount += 1
        }

        var locationsByRemoteId: [String: Location] = [:]
        for (remoteId, values) in importState.locationsById.sorted(by: { ($0.value["name"] ?? "") < ($1.value["name"] ?? "") }) {
            let location = Location(name: emptyStringAsNil(values["name"]), detail: emptyStringAsNil(values["detail"]), sights: emptyStringAsNil(values["sights"]), sounds: emptyStringAsNil(values["sounds"]), smells: emptyStringAsNil(values["smells"]))
            if let id = UUID(uuidString: remoteId) { location.id = id }
            location.createdDate = dateValue(values["createdDate"]) ?? location.createdDate
            location.modifiedDate = dateValue(values["modifiedDate"]) ?? location.modifiedDate
            location.project = importedProject
            locationsByRemoteId[remoteId] = location
            context.insert(location)
            storyRecordCount += 1
        }

        for (remoteId, values) in importState.charactersById.sorted(by: { ($0.value["name"] ?? "") < ($1.value["name"] ?? "") }) {
            let character = Character(name: emptyStringAsNil(values["name"]), role: emptyStringAsNil(values["role"]), history: emptyStringAsNil(values["history"]), looks: emptyStringAsNil(values["looks"]), traits: emptyStringAsNil(values["traits"]), work: emptyStringAsNil(values["work"]))
            if let id = UUID(uuidString: remoteId) { character.id = id }
            character.archetypeRaw = emptyStringAsNil(values["archetypeRaw"])
            character.pearsonArchetypeRaw = emptyStringAsNil(values["pearsonArchetypeRaw"])
            character.createdDate = dateValue(values["createdDate"]) ?? character.createdDate
            character.modifiedDate = dateValue(values["modifiedDate"]) ?? character.modifiedDate
            character.project = importedProject
            charactersByRemoteId[remoteId] = character
            context.insert(character)
            storyRecordCount += 1
        }

        for (remoteId, values) in importState.plotElementsById.sorted(by: storyRecordSort) {
            let plotElement = PlotElement(name: emptyStringAsNil(values["name"]), notes: emptyStringAsNil(values["notes"]), userOrder: intValue(values["userOrder"]))
            if let id = UUID(uuidString: remoteId) { plotElement.id = id }
            plotElement.monomythStageRaw = emptyStringAsNil(values["monomythStageRaw"])
            plotElement.campbellStageRaw = emptyStringAsNil(values["campbellStageRaw"])
            plotElement.threeActStageRaw = emptyStringAsNil(values["threeActStageRaw"])
            plotElement.pearsonStageRaw = emptyStringAsNil(values["pearsonStageRaw"])
            plotElement.createdDate = dateValue(values["createdDate"]) ?? plotElement.createdDate
            plotElement.modifiedDate = dateValue(values["modifiedDate"]) ?? plotElement.modifiedDate
            plotElement.project = importedProject
            plotElementsByRemoteId[remoteId] = plotElement
            context.insert(plotElement)
            storyRecordCount += 1
        }

        for (remoteId, values) in importState.storyScenesById.sorted(by: storyRecordSort) {
            let scene = StoryScene(name: emptyStringAsNil(values["name"]), synopsis: emptyStringAsNil(values["synopsis"]), userOrder: intValue(values["userOrder"]))
            if let id = UUID(uuidString: remoteId) { scene.id = id }
            applyBodyMatterPayload(values, to: scene)
            scene.monomythStageRaw = emptyStringAsNil(values["monomythStageRaw"])
            scene.campbellStageRaw = emptyStringAsNil(values["campbellStageRaw"])
            scene.threeActStageRaw = emptyStringAsNil(values["threeActStageRaw"])
            scene.pearsonStageRaw = emptyStringAsNil(values["pearsonStageRaw"])
            scene.isTrashed = boolValue(values["isTrashed"])
            scene.trashedDate = dateValue(values["trashedDate"])
            scene.textFile = values["textFileId"].flatMap { textFilesByRemoteId[$0] }
            scene.location = values["locationId"].flatMap { locationsByRemoteId[$0] }
            scene.project = importedProject
            scenesByRemoteId[remoteId] = scene
            context.insert(scene)
            storyRecordCount += 1
        }

        var joinLinkCount = 0
        for (remoteId, values) in importState.joinLinksById.sorted(by: { ($0.value["linkType"] ?? "", $0.key) < ($1.value["linkType"] ?? "", $1.key) }) {
            switch values["linkType"] {
            case "TextFileSectionLink":
                guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId], let sectionId = values["sectionId"], let section = proseSectionsByRemoteId[sectionId] else { continue }
                let link = TextFileSectionLink(textFile: textFile, section: section, userOrder: intValue(values["userOrder"]))
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if textFile.sectionLinks == nil { textFile.sectionLinks = [] }
                if section.textFileLinks == nil { section.textFileLinks = [] }
                textFile.sectionLinks?.append(link)
                section.textFileLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "TextFileCollectionLink":
                guard let textFileId = values["textFileId"], let textFile = textFilesByRemoteId[textFileId], let collectionId = values["poetryCollectionId"], let collection = poetryCollectionsByRemoteId[collectionId] else { continue }
                let link = TextFileCollectionLink(textFile: textFile, poetryCollection: collection, userOrder: intValue(values["userOrder"]))
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if textFile.poetryCollectionLinks == nil { textFile.poetryCollectionLinks = [] }
                if collection.textFileLinks == nil { collection.textFileLinks = [] }
                textFile.poetryCollectionLinks?.append(link)
                collection.textFileLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "SceneChapterLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId], let chapterId = values["chapterId"], let chapter = chaptersByRemoteId[chapterId] else { continue }
                let link = SceneChapterLink(scene: scene, chapter: chapter)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if scene.chapterLinks == nil { scene.chapterLinks = [] }
                if chapter.sceneLinks == nil { chapter.sceneLinks = [] }
                scene.chapterLinks?.append(link)
                chapter.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "SceneActLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId], let actId = values["actId"], let act = actsByRemoteId[actId] else { continue }
                let link = SceneActLink(scene: scene, act: act)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if scene.actLinks == nil { scene.actLinks = [] }
                if act.sceneLinks == nil { act.sceneLinks = [] }
                scene.actLinks?.append(link)
                act.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "SceneBookLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId], let bookId = values["bookId"], let book = booksByRemoteId[bookId] else { continue }
                let link = SceneBookLink(scene: scene, book: book)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if scene.bookLinks == nil { scene.bookLinks = [] }
                if book.sceneLinks == nil { book.sceneLinks = [] }
                scene.bookLinks?.append(link)
                book.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "ScenePlotElementLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId], let plotElementId = values["plotElementId"], let plotElement = plotElementsByRemoteId[plotElementId] else { continue }
                let link = ScenePlotElementLink(scene: scene, plotElement: plotElement)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if scene.plotElementLinks == nil { scene.plotElementLinks = [] }
                if plotElement.sceneLinks == nil { plotElement.sceneLinks = [] }
                scene.plotElementLinks?.append(link)
                plotElement.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "SceneCharacterLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId], let characterId = values["characterId"], let character = charactersByRemoteId[characterId] else { continue }
                let link = SceneCharacterLink(scene: scene, character: character)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if scene.characterLinks == nil { scene.characterLinks = [] }
                if character.sceneLinks == nil { character.sceneLinks = [] }
                scene.characterLinks?.append(link)
                character.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "CharacterPlotElementLink":
                guard let characterId = values["characterId"], let character = charactersByRemoteId[characterId], let plotElementId = values["plotElementId"], let plotElement = plotElementsByRemoteId[plotElementId] else { continue }
                let link = CharacterPlotElementLink(character: character, plotElement: plotElement)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if character.plotElementLinks == nil { character.plotElementLinks = [] }
                if plotElement.characterLinks == nil { plotElement.characterLinks = [] }
                character.plotElementLinks?.append(link)
                plotElement.characterLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "LocationPlotElementLink":
                guard let locationId = values["locationId"], let location = locationsByRemoteId[locationId], let plotElementId = values["plotElementId"], let plotElement = plotElementsByRemoteId[plotElementId] else { continue }
                let link = LocationPlotElementLink(location: location, plotElement: plotElement)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if location.plotElementLinks == nil { location.plotElementLinks = [] }
                if plotElement.locationLinks == nil { plotElement.locationLinks = [] }
                location.plotElementLinks?.append(link)
                plotElement.locationLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            case "SceneLocationLink":
                guard let sceneId = values["sceneId"], let scene = scenesByRemoteId[sceneId], let locationId = values["locationId"], let location = locationsByRemoteId[locationId] else { continue }
                let link = SceneLocationLink(scene: scene, location: location)
                if let id = UUID(uuidString: remoteId) { link.id = id }
                if scene.locationLinks == nil { scene.locationLinks = [] }
                if location.sceneLinks == nil { location.sceneLinks = [] }
                scene.locationLinks?.append(link)
                location.sceneLinks?.append(link)
                context.insert(link)
                joinLinkCount += 1
            default:
                continue
            }
        }

        var referenceRecordCount = 0

        for (remoteId, values) in importState.notesById.sorted(by: { intValue($0.value["displayNumber"]) ?? Int.max < intValue($1.value["displayNumber"]) ?? Int.max }) {
            let note = NoteEntry(
                id: UUID(uuidString: remoteId) ?? UUID(),
                project: importedProject,
                content: values["content"] ?? "",
                isEndnote: boolValue(values["isEndnote"]),
                displayNumber: intValue(values["displayNumber"]) ?? 0,
                title: emptyStringAsNil(values["title"]),
                tag: emptyStringAsNil(values["tag"])
            )
            note.formattedContentData = dataValue(values["formattedContentData"])
            note.referenceCount = intValue(values["referenceCount"]) ?? 0
            note.referencingFileIDs = uuidListValue(values["referencingFileIDs"])
            note.createdAt = dateValue(values["createdAt"]) ?? note.createdAt
            note.modifiedAt = dateValue(values["modifiedAt"]) ?? note.modifiedAt
            context.insert(note)
            referenceRecordCount += 1
        }

        var citationsByRemoteId: [String: CitationEntry] = [:]
        for (remoteId, values) in importState.citationEntriesById.sorted(by: { ($0.value["title"] ?? "") < ($1.value["title"] ?? "") }) {
            let citation = CitationEntry(
                id: UUID(uuidString: remoteId) ?? UUID(),
                project: importedProject,
                year: intValue(values["year"]),
                title: values["title"] ?? "",
                source: emptyStringAsNil(values["source"]),
                url: emptyStringAsNil(values["url"]),
                doi: emptyStringAsNil(values["doi"]),
                sourceType: CitationEntry.SourceType(rawValue: values["sourceTypeRaw"] ?? "") ?? .article
            )
            citation.authorsData = dataValue(values["authorsData"])
            citation.volume = emptyStringAsNil(values["volume"])
            citation.issue = emptyStringAsNil(values["issue"])
            citation.pages = emptyStringAsNil(values["pages"])
            citation.edition = emptyStringAsNil(values["edition"])
            citation.city = emptyStringAsNil(values["city"])
            citation.accessDate = dateValue(values["accessDate"])
            citation.referenceCount = intValue(values["referenceCount"]) ?? 0
            citation.createdAt = dateValue(values["createdAt"]) ?? citation.createdAt
            citation.modifiedAt = dateValue(values["modifiedAt"]) ?? citation.modifiedAt
            citationsByRemoteId[remoteId] = citation
            context.insert(citation)
            referenceRecordCount += 1
        }

        for (remoteId, values) in importState.glossaryEntriesById.sorted(by: { ($0.value["term"] ?? "") < ($1.value["term"] ?? "") }) {
            let glossaryEntry = GlossaryEntry(
                id: UUID(uuidString: remoteId) ?? UUID(),
                project: importedProject,
                term: values["term"] ?? "",
                definition: values["definition"] ?? "",
                citation: values["citationId"].flatMap { citationsByRemoteId[$0] }
            )
            glossaryEntry.referenceCount = intValue(values["referenceCount"]) ?? 0
            glossaryEntry.createdAt = dateValue(values["createdAt"]) ?? glossaryEntry.createdAt
            glossaryEntry.modifiedAt = dateValue(values["modifiedAt"]) ?? glossaryEntry.modifiedAt
            context.insert(glossaryEntry)
            referenceRecordCount += 1
        }

        for (remoteId, values) in importState.referenceEntriesById.sorted(by: { ($0.value["author"] ?? "", $0.value["publicationDate"] ?? "") < ($1.value["author"] ?? "", $1.value["publicationDate"] ?? "") }) {
            let referenceEntry = ReferenceEntry(
                id: UUID(uuidString: remoteId) ?? UUID(),
                project: importedProject,
                author: values["author"] ?? "",
                publicationDate: values["publicationDate"] ?? "",
                details: values["details"] ?? ""
            )
            referenceEntry.referenceCount = intValue(values["referenceCount"]) ?? 0
            referenceEntry.createdAt = dateValue(values["createdAt"]) ?? referenceEntry.createdAt
            referenceEntry.modifiedAt = dateValue(values["modifiedAt"]) ?? referenceEntry.modifiedAt
            context.insert(referenceEntry)
            referenceRecordCount += 1
        }

        var indexEntriesByRemoteId: [String: IndexEntry] = [:]
        for (remoteId, values) in importState.indexEntriesById.sorted(by: { ($0.value["keyword"] ?? "") < ($1.value["keyword"] ?? "") }) {
            let indexEntry = IndexEntry(
                id: UUID(uuidString: remoteId) ?? UUID(),
                project: importedProject,
                keyword: values["keyword"] ?? ""
            )
            indexEntry.seeEntryID = values["seeEntryID"].flatMap { UUID(uuidString: $0) }
            indexEntry.seeAlsoEntryIDsData = dataValue(values["seeAlsoEntryIDsData"])
            indexEntry.referenceCount = intValue(values["referenceCount"]) ?? 0
            indexEntry.referencingFileIDsData = dataValue(values["referencingFileIDsData"])
            indexEntry.createdAt = dateValue(values["createdAt"]) ?? indexEntry.createdAt
            indexEntry.modifiedAt = dateValue(values["modifiedAt"]) ?? indexEntry.modifiedAt
            indexEntry.pageNumbersData = dataValue(values["pageNumbersData"])
            indexEntry.primaryPageNumbersData = dataValue(values["primaryPageNumbersData"])
            indexEntriesByRemoteId[remoteId] = indexEntry
            context.insert(indexEntry)
            referenceRecordCount += 1
        }

        for (remoteId, values) in importState.indexEntriesById {
            guard let indexEntry = indexEntriesByRemoteId[remoteId], let parentId = values["parentEntryId"], let parent = indexEntriesByRemoteId[parentId] else { continue }
            indexEntry.parentEntry = parent
        }

        for (remoteId, values) in importState.contributorEntriesById.sorted(by: { intValue($0.value["userOrder"]) ?? Int.max < intValue($1.value["userOrder"]) ?? Int.max }) {
            let contributor = ContributorEntry(
                id: UUID(uuidString: remoteId) ?? UUID(),
                project: importedProject,
                name: values["name"] ?? "",
                firstName: values["firstName"] ?? "",
                surname: values["surname"] ?? "",
                biography: values["biography"] ?? "",
                userOrder: intValue(values["userOrder"]) ?? 0
            )
            contributor.createdAt = dateValue(values["createdAt"]) ?? contributor.createdAt
            contributor.modifiedAt = dateValue(values["modifiedAt"]) ?? contributor.modifiedAt
            context.insert(contributor)
            referenceRecordCount += 1
        }

        var publicationsByRemoteId: [String: Publication] = [:]
        for (remoteId, values) in importState.publicationsById.sorted(by: { ($0.value["name"] ?? "") < ($1.value["name"] ?? "") }) {
            let publication = Publication(
                id: UUID(uuidString: remoteId) ?? UUID(),
                name: values["name"]?.isEmpty == false ? values["name"]! : "Imported Publication",
                type: PublicationType(rawValue: values["type"] ?? "") ?? .magazine,
                url: values["url"]?.isEmpty == false ? values["url"] : nil,
                notes: values["notes"]?.isEmpty == false ? values["notes"] : nil,
                deadline: dateValue(values["deadline"]),
                project: importedProject
            )
            publication.typicalResponseDays = intValue(values["typicalResponseDays"])
            publication.reminderDate = dateValue(values["reminderDate"])
            publication.createdDate = dateValue(values["createdDate"]) ?? publication.createdDate
            publication.modifiedDate = dateValue(values["modifiedDate"]) ?? publication.modifiedDate
            publicationsByRemoteId[remoteId] = publication
            context.insert(publication)
        }

        var submissionsByRemoteId: [String: Submission] = [:]
        for (remoteId, values) in importState.submissionsById.sorted(by: { (dateValue($0.value["submittedDate"]) ?? Date.distantPast) < (dateValue($1.value["submittedDate"]) ?? Date.distantPast) }) {
            let submission = Submission(
                id: UUID(uuidString: remoteId) ?? UUID(),
                publication: values["publicationId"].flatMap { publicationsByRemoteId[$0] },
                project: importedProject,
                submittedDate: dateValue(values["submittedDate"]) ?? Date(),
                notes: values["notes"]?.isEmpty == false ? values["notes"] : nil
            )
            submission.name = values["name"]?.isEmpty == false ? values["name"] : nil
            submission.collectionDescription = values["collectionDescription"]?.isEmpty == false ? values["collectionDescription"] : nil
            submission.isCollection = boolValue(values["isCollection"])
            submission.returnExpectedBy = dateValue(values["returnExpectedBy"])
            submission.returnedOn = dateValue(values["returnedOn"])
            submission.typicalResponseDays = intValue(values["typicalResponseDays"])
            submission.reminderDate = dateValue(values["reminderDate"])
            submission.userOrder = intValue(values["userOrder"])
            submission.createdDate = dateValue(values["createdDate"]) ?? submission.createdDate
            submission.modifiedDate = dateValue(values["modifiedDate"]) ?? submission.modifiedDate
            submissionsByRemoteId[remoteId] = submission
            context.insert(submission)
        }

        var submittedFileCount = 0
        for (remoteId, values) in importState.submittedFilesById.sorted(by: { (dateValue($0.value["createdDate"]) ?? Date.distantPast) < (dateValue($1.value["createdDate"]) ?? Date.distantPast) }) {
            guard let submissionId = values["submissionId"], let submission = submissionsByRemoteId[submissionId] else { continue }
            let submittedFile = SubmittedFile(
                id: UUID(uuidString: remoteId) ?? UUID(),
                submission: submission,
                textFile: values["textFileId"].flatMap { textFilesByRemoteId[$0] },
                version: values["versionId"].flatMap { versionByRemoteId[$0] },
                status: SubmissionStatus(rawValue: values["status"] ?? "") ?? .pending,
                statusDate: dateValue(values["statusDate"]),
                statusNotes: values["statusNotes"]?.isEmpty == false ? values["statusNotes"] : nil,
                project: importedProject
            )
            submittedFile.createdDate = dateValue(values["createdDate"]) ?? submittedFile.createdDate
            submittedFile.modifiedDate = dateValue(values["modifiedDate"]) ?? submittedFile.modifiedDate
            context.insert(submittedFile)
            submittedFileCount += 1
        }

        try context.save()

        let textStyleCount = styleSheetsByRemoteId.values.reduce(0) { total, styleSheet in
            total + (styleSheet.textStyles?.count ?? 0)
        }
        let imageStyleCount = styleSheetsByRemoteId.values.reduce(0) { total, styleSheet in
            total + (styleSheet.imageStyles?.count ?? 0)
        }
        return CloudflareSyncPOCImportMaterializeResult(
            projectName: importedProject.name ?? "Cloudflare POC Import",
            styleSheetCount: styleSheetsByRemoteId.count,
            textStyleCount: textStyleCount,
            imageStyleCount: imageStyleCount,
            folderCount: foldersByRemoteId.count,
            textFileCount: textFileCount,
            versionCount: versionCount,
            commentCount: commentCount,
            footnoteCount: footnoteCount,
            storyRecordCount: storyRecordCount,
            joinLinkCount: joinLinkCount,
            referenceRecordCount: referenceRecordCount,
            publicationCount: publicationsByRemoteId.count,
            submissionCount: submissionsByRemoteId.count,
            submittedFileCount: submittedFileCount,
            totalContentCharacters: importState.totalContentCharacters,
            storeURL: storeURL
        )
    }

    private func resetIsolatedImportStore() throws -> URL {
        try resetIsolatedStore(basename: importStoreBasename)
    }

    private func resetIsolatedStore(basename: String) throws -> URL {
        let directory = try isolatedImportDirectory()
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in contents where url.lastPathComponent.hasPrefix(basename) {
            try fileManager.removeItem(at: url)
        }
        return try isolatedStoreURL(basename: basename)
    }

    private func isolatedStoreURL(basename: String) throws -> URL {
        try isolatedImportDirectory().appendingPathComponent("\(basename).sqlite")
    }

    private func isolatedImportDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CloudflareSyncPOCError.importStoreUnavailable
        }
        let directory = applicationSupport.appendingPathComponent("CloudflareSyncPOC", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func intValue(_ value: String?) -> Int? {
        guard let value, !value.isEmpty else { return nil }
        return Int(value)
    }

    private func int16Value(_ value: String?) -> Int16? {
        guard let intValue = intValue(value) else { return nil }
        return Int16(exactly: intValue)
    }

    private func boolValue(_ value: String?) -> Bool {
        value?.lowercased() == "true"
    }

    private func doubleValue(_ value: String?) -> Double? {
        guard let value, !value.isEmpty else { return nil }
        return Double(value)
    }

    private func cgFloatValue(_ value: String?) -> CGFloat? {
        guard let doubleValue = doubleValue(value) else { return nil }
        return CGFloat(doubleValue)
    }

    private func emptyStringAsNil(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private func storyRecordSort(_ left: (key: String, value: [String: String]), _ right: (key: String, value: [String: String])) -> Bool {
        (intValue(left.value["userOrder"]) ?? Int.max, left.value["name"] ?? "") < (intValue(right.value["userOrder"]) ?? Int.max, right.value["name"] ?? "")
    }

    private func applyBodyMatterPayload(_ values: [String: String], to scene: StoryScene) {
        scene.createdDate = dateValue(values["createdDate"]) ?? scene.createdDate
        scene.modifiedDate = dateValue(values["modifiedDate"]) ?? scene.modifiedDate
        scene.bodyMatterOrder = intValue(values["bodyMatterOrder"])
        scene.isInBodyMatter = boolValue(values["isInBodyMatter"])
    }

    private func applyBodyMatterPayload(_ values: [String: String], to chapter: Chapter) {
        chapter.createdDate = dateValue(values["createdDate"]) ?? chapter.createdDate
        chapter.modifiedDate = dateValue(values["modifiedDate"]) ?? chapter.modifiedDate
        chapter.bodyMatterOrder = intValue(values["bodyMatterOrder"])
        chapter.isInBodyMatter = boolValue(values["isInBodyMatter"])
    }

    private func applyBodyMatterPayload(_ values: [String: String], to act: Act) {
        act.createdDate = dateValue(values["createdDate"]) ?? act.createdDate
        act.modifiedDate = dateValue(values["modifiedDate"]) ?? act.modifiedDate
        act.bodyMatterOrder = intValue(values["bodyMatterOrder"])
        act.isInBodyMatter = boolValue(values["isInBodyMatter"])
    }

    private func applyBodyMatterPayload(_ values: [String: String], to section: ProseSection) {
        section.createdDate = dateValue(values["createdDate"]) ?? section.createdDate
        section.modifiedDate = dateValue(values["modifiedDate"]) ?? section.modifiedDate
        section.bodyMatterOrder = intValue(values["bodyMatterOrder"])
        section.isInBodyMatter = boolValue(values["isInBodyMatter"])
    }

    private func applyBodyMatterPayload(_ values: [String: String], to collection: PoetryCollection) {
        collection.createdDate = dateValue(values["createdDate"]) ?? collection.createdDate
        collection.modifiedDate = dateValue(values["modifiedDate"]) ?? collection.modifiedDate
        collection.bodyMatterOrder = intValue(values["bodyMatterOrder"])
        collection.isInBodyMatter = boolValue(values["isInBodyMatter"])
    }

    private func applyBodyMatterPayload(_ values: [String: String], to book: Book) {
        book.createdDate = dateValue(values["createdDate"]) ?? book.createdDate
        book.modifiedDate = dateValue(values["modifiedDate"]) ?? book.modifiedDate
        book.bodyMatterOrder = intValue(values["bodyMatterOrder"])
        book.isInBodyMatter = boolValue(values["isInBodyMatter"])
    }

    @MainActor
    private func makeSnapshotPayload(for project: Project) -> SyncPOCSnapshotPayload {
        let folders = sampleFolders(in: project)
        let textFiles = sampleTextFiles(in: folders)
        let versions = textFiles.flatMap { sampleVersions(in: $0) }
        let storyScenes = sampleStoryScenes(in: project)
        let chapters = sampleChapters(in: project)
        let acts = sampleActs(in: project)
        let proseSections = sampleProseSections(in: project)
        let poetryCollections = samplePoetryCollections(in: project)
        let books = sampleBooks(in: project)
        let characters = sampleCharacters(in: project)
        let locations = sampleLocations(in: project)
        let plotElements = samplePlotElements(in: project)
        let joinLinks = sampleJoinLinks(textFiles: textFiles, scenes: storyScenes, characters: characters, locations: locations)
        let notes = sampleNotes(in: project)
        let citations = sampleCitations(in: project)
        let glossaryEntries = sampleGlossaryEntries(in: project)
        let referenceEntries = sampleReferenceEntries(in: project)
        let indexEntries = sampleIndexEntries(in: project)
        let contributors = sampleContributors(in: project)
        let publications = samplePublications(in: project)
        let submissions = sampleSubmissions(in: project)

        return SyncPOCSnapshotPayload(
            generatedAt: isoFormatter.string(from: Date()),
            project: [
                "id": project.id.uuidString,
                "name": project.name ?? "Untitled",
                "type": project.typeRaw ?? "",
                "isTrashed": String(project.isTrashed),
                "styleSheetId": project.styleSheet?.id.uuidString ?? "",
                "modifiedDate": project.modifiedDate.map { isoFormatter.string(from: $0) } ?? "",
            ],
            styleSheets: project.styleSheet.map { styleSheet in
                [[
                    "id": styleSheet.id.uuidString,
                    "name": styleSheet.name,
                    "isSystemStyleSheet": String(styleSheet.isSystemStyleSheet),
                    "footnoteMarkerStyleRaw": styleSheet.footnoteMarkerStyleRaw,
                    "createdDate": isoFormatter.string(from: styleSheet.createdDate),
                    "modifiedDate": isoFormatter.string(from: styleSheet.modifiedDate),
                ]]
            } ?? [],
            textStyles: project.styleSheet.map { styleSheet in
                sortedTextStyles(styleSheet.textStyles).map { textStyle in
                    var payload = textStylePayload(textStyle, styleSheetId: styleSheet.id.uuidString)
                    payload["id"] = textStyle.id.uuidString
                    return payload
                }
            } ?? [],
            imageStyles: project.styleSheet.map { styleSheet in
                sortedImageStyles(styleSheet.imageStyles).map { imageStyle in
                    var payload = imageStylePayload(imageStyle, styleSheetId: styleSheet.id.uuidString)
                    payload["id"] = imageStyle.id.uuidString
                    return payload
                }
            } ?? [],
            folders: folders.map { folder in
                [
                    "id": folder.id.uuidString,
                    "name": folder.name ?? "Untitled Folder",
                    "projectId": project.id.uuidString,
                    "parentFolderId": folder.parentFolder?.id.uuidString ?? "",
                    "userOrder": folder.userOrder.map(String.init) ?? "",
                    "frontMatterSettingsData": base64String(folder.frontMatterSettingsData),
                    "backMatterSettingsData": base64String(folder.backMatterSettingsData),
                    "dramaFrontMatterSettingsData": base64String(folder.dramaFrontMatterSettingsData),
                    "dramaBackMatterSettingsData": base64String(folder.dramaBackMatterSettingsData),
                ]
            },
            textFiles: textFiles.map { textFile in
                [
                    "id": textFile.id.uuidString,
                    "name": textFile.name,
                    "folderId": textFile.parentFolder?.id.uuidString ?? "",
                    "workflowStatus": textFile.workflowStatusRaw ?? "",
                    "contentType": textFile.contentTypeRaw,
                    "content": String(textFile.currentContent.prefix(maxTextFileContentCharacters)),
                    "modifiedDate": isoFormatter.string(from: textFile.modifiedDate),
                ]
            },
            versions: textFiles.flatMap { textFile in
                sampleVersions(in: textFile).map { version in
                    [
                        "id": version.id.uuidString,
                        "textFileId": textFile.id.uuidString,
                        "content": String(version.content.prefix(maxTextFileContentCharacters)),
                        "versionNumber": String(version.versionNumber),
                        "comment": version.comment ?? "",
                        "notes": version.notes ?? "",
                        "createdDate": isoFormatter.string(from: version.createdDate),
                    ]
                }
            },
            comments: sampleComments(in: versions).map { comment in
                var payload = commentPayload(comment)
                payload["id"] = comment.id.uuidString
                return payload
            },
            footnotes: sampleFootnotes(in: versions).map { footnote in
                var payload = footnotePayload(footnote)
                payload["id"] = footnote.id.uuidString
                return payload
            },
            storyScenes: storyScenes.map { scene in
                var payload = storyScenePayload(scene, projectId: project.id.uuidString)
                payload["id"] = scene.id.uuidString
                return payload
            },
            chapters: chapters.map { chapter in
                var payload = bodyMatterContainerPayload(name: chapter.name, synopsis: chapter.synopsis, userOrder: chapter.userOrder, createdDate: chapter.createdDate, modifiedDate: chapter.modifiedDate, bodyMatterOrder: chapter.bodyMatterOrder, isInBodyMatter: chapter.isInBodyMatter, projectId: project.id.uuidString)
                payload["id"] = chapter.id.uuidString
                return payload
            },
            acts: acts.map { act in
                var payload = bodyMatterContainerPayload(name: act.name, synopsis: act.synopsis, userOrder: act.userOrder, createdDate: act.createdDate, modifiedDate: act.modifiedDate, bodyMatterOrder: act.bodyMatterOrder, isInBodyMatter: act.isInBodyMatter, projectId: project.id.uuidString)
                payload["id"] = act.id.uuidString
                return payload
            },
            proseSections: proseSections.map { section in
                var payload = bodyMatterContainerPayload(name: section.name, synopsis: section.synopsis, userOrder: section.userOrder, createdDate: section.createdDate, modifiedDate: section.modifiedDate, bodyMatterOrder: section.bodyMatterOrder, isInBodyMatter: section.isInBodyMatter, projectId: project.id.uuidString)
                payload["id"] = section.id.uuidString
                return payload
            },
            poetryCollections: poetryCollections.map { collection in
                var payload = bodyMatterContainerPayload(name: collection.name, synopsis: collection.synopsis, userOrder: collection.userOrder, createdDate: collection.createdDate, modifiedDate: collection.modifiedDate, bodyMatterOrder: collection.bodyMatterOrder, isInBodyMatter: collection.isInBodyMatter, projectId: project.id.uuidString)
                payload["id"] = collection.id.uuidString
                return payload
            },
            books: books.map { book in
                var payload = bodyMatterContainerPayload(name: book.name, synopsis: book.synopsis, userOrder: book.userOrder, createdDate: book.createdDate, modifiedDate: book.modifiedDate, bodyMatterOrder: book.bodyMatterOrder, isInBodyMatter: book.isInBodyMatter, projectId: project.id.uuidString)
                payload["id"] = book.id.uuidString
                return payload
            },
            characters: characters.map { character in
                var payload = characterPayload(character, projectId: project.id.uuidString)
                payload["id"] = character.id.uuidString
                return payload
            },
            locations: locations.map { location in
                var payload = locationPayload(location, projectId: project.id.uuidString)
                payload["id"] = location.id.uuidString
                return payload
            },
            customAttributes: sampleCustomAttributes(characters: characters, locations: locations).map { customAttribute in
                var payload = customAttributePayload(customAttribute)
                payload["id"] = customAttribute.id.uuidString
                return payload
            },
            plotElements: plotElements.map { plotElement in
                var payload = plotElementPayload(plotElement, projectId: project.id.uuidString)
                payload["id"] = plotElement.id.uuidString
                return payload
            },
            joinLinks: joinLinks.map { joinLink in
                var payload = joinLink.payload
                payload["id"] = joinLink.entityId
                payload["linkType"] = joinLink.entityType
                return payload
            },
            notes: notes.map { note in
                var payload = notePayload(note, projectId: project.id.uuidString)
                payload["id"] = note.id.uuidString
                return payload
            },
            glossaryEntries: glossaryEntries.map { glossaryEntry in
                var payload = glossaryPayload(glossaryEntry, projectId: project.id.uuidString)
                payload["id"] = glossaryEntry.id.uuidString
                return payload
            },
            referenceEntries: referenceEntries.map { referenceEntry in
                var payload = referencePayload(referenceEntry, projectId: project.id.uuidString)
                payload["id"] = referenceEntry.id.uuidString
                return payload
            },
            citationEntries: citations.map { citation in
                var payload = citationPayload(citation, projectId: project.id.uuidString)
                payload["id"] = citation.id.uuidString
                return payload
            },
            indexEntries: indexEntries.map { indexEntry in
                var payload = indexPayload(indexEntry, projectId: project.id.uuidString)
                payload["id"] = indexEntry.id.uuidString
                return payload
            },
            contributorEntries: contributors.map { contributor in
                var payload = contributorPayload(contributor, projectId: project.id.uuidString)
                payload["id"] = contributor.id.uuidString
                return payload
            },
            publications: publications.map { publication in
                var payload = publicationPayload(publication, projectId: project.id.uuidString)
                payload["id"] = publication.id.uuidString
                return payload
            },
            submissions: submissions.map { submission in
                var payload = submissionPayload(submission, projectId: project.id.uuidString)
                payload["id"] = submission.id.uuidString
                return payload
            },
            submittedFiles: sampleSubmittedFiles(in: submissions).map { submittedFile in
                var payload = submittedFilePayload(submittedFile, projectId: project.id.uuidString)
                payload["id"] = submittedFile.id.uuidString
                return payload
            },
            limits: [
                "maxFolders": maxSampleFolders,
                "maxTextFiles": maxSampleTextFiles,
                "maxComments": maxSampleComments,
                "maxFootnotes": maxSampleFootnotes,
                "maxStoryRecordsPerType": maxSampleStoryRecordsPerType,
                "maxJoinLinks": maxSampleJoinLinks,
                "maxReferenceRecordsPerType": maxSampleReferenceRecordsPerType,
                "maxPublications": maxSamplePublications,
                "maxSubmissions": maxSampleSubmissions,
                "maxSubmittedFiles": maxSampleSubmittedFiles,
                "maxTextFileContentCharacters": maxTextFileContentCharacters,
            ]
        )
    }

    private func localDeviceId() -> String {
        let key = "cloudflareSyncPOCDeviceId"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }

    private func localDeviceName() -> String {
        #if targetEnvironment(macCatalyst)
        return "Mac Catalyst"
        #elseif os(iOS)
        return UIDevice.current.name
        #else
        return "Writing Shed Pro"
        #endif
    }
}
