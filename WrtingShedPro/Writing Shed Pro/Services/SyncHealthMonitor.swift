import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - SyncHealthState

/// Represents the current sync health shown in Settings.
enum SyncHealthState: String, CaseIterable {
    case healthy
    case syncing
    case degraded
    case stalled
    case recovering
    case blocked

    var displayText: String {
        switch self {
        case .healthy:    return NSLocalizedString("sync.status.healthy", comment: "Sync healthy")
        case .syncing:    return NSLocalizedString("sync.status.syncing", comment: "Sync in progress")
        case .degraded:   return NSLocalizedString("sync.status.degraded", comment: "Sync catching up")
        case .stalled:    return NSLocalizedString("sync.status.stalled", comment: "Sync delayed")
        case .recovering: return NSLocalizedString("sync.status.recovering", comment: "Sync restoring")
        case .blocked:    return NSLocalizedString("sync.status.blocked", comment: "Sync blocked")
        }
    }

    var iconName: String {
        switch self {
        case .healthy:    return "checkmark.circle.fill"
        case .syncing:    return "arrow.triangle.2.circlepath"
        case .degraded:   return "exclamationmark.triangle.fill"
        case .stalled:    return "exclamationmark.triangle.fill"
        case .recovering: return "arrow.clockwise"
        case .blocked:    return "xmark.octagon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .healthy:    return .green
        case .syncing:    return .blue
        case .degraded:   return .yellow
        case .stalled:    return .orange
        case .recovering: return .blue
        case .blocked:    return .red
        }
    }
}

// MARK: - SyncHealthMonitor

/// Lightweight sync status for the Ensembles-backed app.
@Observable
@MainActor
final class SyncHealthMonitor {

    // MARK: - Observable State

    /// Current sync health.
    private(set) var healthState: SyncHealthState = .healthy

    /// Timestamp of the last local save (set by WriteCoalescer after flush).
    private(set) var lastLocalChangeTime: Date?

    /// Last successful sync observed or requested by the app.
    private(set) var lastSuccessfulExportTime: Date?

    /// When the current stall was first detected.
    private(set) var stallDetectedAt: Date?

    /// Number of recovery attempts for the current stall episode.
    private(set) var recoveryAttempts: Int = 0

    // MARK: - Configuration

    // MARK: - Private

    private var modelContainer: ModelContainer?

    // MARK: - Init

    init(modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer
    }

    // MARK: - Public API

    /// Called by WriteCoalescer after each successful flush.
    func recordLocalChange() {
        lastLocalChangeTime = Date()
        transition(to: .syncing)
    }

    /// Called after a successful sync request completes.
    func recordExportSuccess() {
        lastSuccessfulExportTime = Date()
        if stallDetectedAt != nil {
            stallDetectedAt = nil
            recoveryAttempts = 0
            #if DEBUG
            print("✅ [SyncHealthMonitor] Stall cleared — export succeeded")
            #endif
        }
        transition(to: .healthy)
    }

    /// Called after a sync request reports a failure.
    func recordExportFailure(isBlocking: Bool) {
        if isBlocking {
            stallDetectedAt = Date()
            transition(to: .blocked)
        } else if healthState != .blocked {
            transition(to: .degraded)
        }
    }

    /// Evaluate current sync health.
    func checkHealth() {
        if let currentActivity = Write_App.activeEnsemblesContainer?.currentActivity,
           String(describing: currentActivity) != "none" {
            transition(to: .syncing)
            return
        }

        if let modelContainer {
            _ = Write_App.recordFirstEnsemblesDataAvailableIfNeeded(
                modelContainer: modelContainer,
                reason: "sync health check"
            )
        }

        if Write_App.activeEnsemblesContainer != nil,
           !Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch {
            transition(to: .degraded)
            return
        }

        if let modelContainer {
            let context = ModelContext(modelContainer)
            let projectCount = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
            let folderCount = (try? context.fetchCount(FetchDescriptor<Folder>())) ?? 0
            let fileCount = (try? context.fetchCount(FetchDescriptor<TextFile>())) ?? 0
            let publicationCount = (try? context.fetchCount(FetchDescriptor<Publication>())) ?? 0

            if projectCount == 0 && (folderCount > 0 || fileCount > 0 || publicationCount > 0) {
                transition(to: .degraded)
                return
            }
        }

        transition(to: .healthy)
    }

    // MARK: - Private

    private func transition(to newState: SyncHealthState) {
        guard healthState != newState else { return }
        #if DEBUG
        print("🔄 [SyncHealthMonitor] \(healthState.rawValue) → \(newState.rawValue)")
        #endif
        healthState = newState
    }
}
