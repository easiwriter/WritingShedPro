import Foundation
import Observation
import SwiftUI

// MARK: - SyncHealthState

/// Represents the current health of CloudKit sync.
enum SyncHealthState: String, CaseIterable {
    case healthy
    case syncing
    case degraded
    case stalled
    case recovering

    var displayText: String {
        switch self {
        case .healthy:    return NSLocalizedString("sync.status.healthy", comment: "Sync healthy")
        case .syncing:    return NSLocalizedString("sync.status.syncing", comment: "Sync in progress")
        case .degraded:   return NSLocalizedString("sync.status.degraded", comment: "Sync catching up")
        case .stalled:    return NSLocalizedString("sync.status.stalled", comment: "Sync delayed")
        case .recovering: return NSLocalizedString("sync.status.recovering", comment: "Sync restoring")
        }
    }

    var iconName: String {
        switch self {
        case .healthy:    return "checkmark.circle.fill"
        case .syncing:    return "arrow.triangle.2.circlepath"
        case .degraded:   return "exclamationmark.triangle.fill"
        case .stalled:    return "exclamationmark.triangle.fill"
        case .recovering: return "arrow.clockwise"
        }
    }

    var iconColor: Color {
        switch self {
        case .healthy:    return .green
        case .syncing:    return .blue
        case .degraded:   return .yellow
        case .stalled:    return .orange
        case .recovering: return .blue
        }
    }
}

// MARK: - SyncHealthMonitor

/// Detects CloudKit sync stalls and orchestrates progressive recovery.
///
/// Runs a periodic health check (every 60 s) comparing the timestamp of the
/// last local save against the last successful CloudKit export. If the gap
/// exceeds a configured threshold the monitor flags a stall and begins
/// progressive recovery (wait → wait → schedule database reset).
@Observable
@MainActor
final class SyncHealthMonitor {

    // MARK: - Observable State

    /// Current sync health.
    private(set) var healthState: SyncHealthState = .healthy

    /// Timestamp of the last local save (set by WriteCoalescer after flush).
    private(set) var lastLocalChangeTime: Date?

    /// Mirror of CloudKitSyncThrottler.lastSuccessfulExportTime for gap calculation.
    private(set) var lastSuccessfulExportTime: Date?

    /// When the current stall was first detected.
    private(set) var stallDetectedAt: Date?

    /// Number of recovery attempts for the current stall episode.
    private(set) var recoveryAttempts: Int = 0

    // MARK: - Configuration

    /// Seconds between periodic health checks.
    private let checkInterval: TimeInterval

    /// Gap (seconds) between local change and export before state becomes degraded.
    private let degradedThreshold: TimeInterval

    /// Gap (seconds) before state becomes stalled.
    private let stalledThreshold: TimeInterval

    // MARK: - Private

    private let throttler: CloudKitSyncThrottler
    @ObservationIgnored private var healthTimer: Timer?

    // MARK: - Init

    init(
        throttler: CloudKitSyncThrottler = .shared,
        checkInterval: TimeInterval = 60,
        degradedThreshold: TimeInterval = 300,   // 5 minutes
        stalledThreshold: TimeInterval = 600     // 10 minutes
    ) {
        self.throttler = throttler
        self.checkInterval = checkInterval
        self.degradedThreshold = degradedThreshold
        self.stalledThreshold = stalledThreshold
        startPeriodicCheck()
    }

    deinit {
        healthTimer?.invalidate()
    }

    // MARK: - Public API

    /// Called by WriteCoalescer after each successful flush.
    func recordLocalChange() {
        lastLocalChangeTime = Date()
    }

    /// Called when CloudKitSyncThrottler reports a successful export.
    func recordExportSuccess() {
        lastSuccessfulExportTime = Date()
        // Successful export resets any stall episode.
        if stallDetectedAt != nil {
            stallDetectedAt = nil
            recoveryAttempts = 0
            #if DEBUG
            print("✅ [SyncHealthMonitor] Stall cleared — export succeeded")
            #endif
        }
        checkHealth()
    }

    /// Evaluate current sync health based on time gaps.
    func checkHealth() {
        // If the throttler is actively syncing, report that.
        if throttler.isSyncing {
            transition(to: .syncing)
            return
        }

        // No local changes recorded yet — nothing to stall on.
        guard let localTime = lastLocalChangeTime else {
            transition(to: .healthy)
            return
        }

        // Use throttler's live value.
        let exportTime = throttler.lastSuccessfulExportTime ?? lastSuccessfulExportTime

        let gap: TimeInterval
        if let exportTime {
            gap = localTime.timeIntervalSince(exportTime)
        } else {
            // Never had a successful export — measure from local change.
            gap = Date().timeIntervalSince(localTime)
        }

        // No gap or export is newer than local change → healthy.
        if gap <= 0 {
            transition(to: .healthy)
            return
        }

        if gap >= stalledThreshold {
            if stallDetectedAt == nil {
                stallDetectedAt = Date()
            }
            if healthState != .recovering {
                transition(to: .stalled)
            }
            attemptRecovery()
        } else if gap >= degradedThreshold {
            transition(to: .degraded)
        } else {
            transition(to: .healthy)
        }
    }

    // MARK: - Private

    private func startPeriodicCheck() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkHealth()
            }
        }
    }

    private func attemptRecovery() {
        recoveryAttempts += 1
        transition(to: .recovering)

        #if DEBUG
        print("🔄 [SyncHealthMonitor] Recovery attempt \(recoveryAttempts)")
        #endif

        switch recoveryAttempts {
        case 1:
            // Attempt 1: Just wait — stall may self-resolve within 2 min.
            #if DEBUG
            print("⏳ [SyncHealthMonitor] Attempt 1: waiting for self-resolution")
            #endif
        case 2:
            // Attempt 2: Wait longer (another check cycle).
            #if DEBUG
            print("⏳ [SyncHealthMonitor] Attempt 2: continuing to wait")
            #endif
        default:
            // Attempt 3+: Schedule database reset on next launch.
            #if DEBUG
            print("🔄 [SyncHealthMonitor] Attempt \(recoveryAttempts): scheduling DB reset")
            #endif
            throttler.scheduleAutoResetIfNeeded()
        }
    }

    private func transition(to newState: SyncHealthState) {
        guard healthState != newState else { return }
        #if DEBUG
        print("🔄 [SyncHealthMonitor] \(healthState.rawValue) → \(newState.rawValue)")
        #endif
        healthState = newState
    }
}
