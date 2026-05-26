//
//  CloudKitSyncThrottler.swift
//  Writing Shed Pro
//
//  Created by Copilot on 01/02/2026.
//
//  Throttles CloudKit sync notifications to prevent rapid-fire UI updates
//  that can dismiss menus and disrupt user interactions.
//

import Foundation
import Combine
import CoreData
import Observation
import CloudKit

struct CloudKitEventLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: String
    let phase: String
    let status: String
    let message: String
}

/// Manages CloudKit sync notifications to prevent UI disruption during burst sync activity.
/// 
/// When CloudKit syncs many records rapidly, each change can trigger SwiftUI view updates.
/// This causes menus to dismiss, sheets to close, and other disruptive behavior.
/// 
/// This throttler:
/// 1. Coalesces rapid notifications into a single "burst" period
/// 2. Provides `isSyncing` state so views can defer non-critical updates
/// 3. Automatically clears the syncing state after a quiet period
@Observable
final class CloudKitSyncThrottler {
    /// Shared singleton instance
    static let shared = CloudKitSyncThrottler()
    
    /// True when CloudKit is actively syncing (receiving rapid notifications)
    /// Views can use this to defer UI updates that might disrupt user interaction
    private(set) var isSyncing = false
    
    /// Number of sync events in the current burst
    private(set) var syncEventCount = 0
    
    /// Cumulative count of ALL sync events since app launch (never reset).
    /// Used by the fresh-install waiting loop to detect whether ANY data arrived.
    private(set) var totalSyncEventCount = 0
    
    /// Tracks whether an import event has completed (successfully or with error).
    /// Remains false if the import started but never received an endDate.
    private(set) var importCompleted = false
    
    /// Tracks whether the most recent import succeeded.
    private(set) var importSucceeded = false

    /// True while a CloudKit import event is currently in progress.
    private(set) var importInProgress = false
    private(set) var importStartTime: Date?

    /// Tracks whether an export event has completed successfully.
    /// Remains false while rate-limited retries are ongoing.
    private(set) var exportCompleted = false

    /// Tracks whether the most recent export succeeded.
    private(set) var exportSucceeded = false

    /// True while a CloudKit export event is currently in progress.
    private(set) var exportInProgress = false
    private(set) var exportStartTime: Date?

    /// Timestamp of the last successful CloudKit export. Used by
    /// SyncHealthMonitor to detect stalls (gap between local changes and
    /// successful exports).
    private(set) var lastSuccessfulExportTime: Date?
    
    /// Time of the last sync notification
    private(set) var lastSyncTime: Date?

    /// Most recent observed CloudKit-related activity. This includes both
    /// mirroring events and store-change notifications and is safer for watchdog
    /// timing than `lastSyncTime` alone.
    private(set) var lastObservedActivityTime: Date?

    /// Most recent CloudKit import/export/setup events for diagnostics UI.
    /// Bounded list to avoid unbounded memory growth.
    private(set) var recentCloudKitEvents: [CloudKitEventLogEntry] = []

    /// Maximum number of event rows retained in memory.
    private let maxRecentEventCount = 60
    
    /// When non-nil, CloudKit is rate-limited and we should NOT fire additional
    /// zone fetch or nudge operations until this date has passed.
    /// Set from the CKError retry-after hint when we detect rate limiting.
    private(set) var rateLimitedUntil: Date?

    /// Optional health monitor — notified on export success for stall detection.
    var syncHealthMonitor: SyncHealthMonitor?

    /// Consecutive CloudKit export rate-limit failures (error 6 or 7). Used to
    /// apply exponential backoff so the watchdog doesn't pile on nudges while
    /// CloudKit is still rejecting exports.
    private(set) var consecutiveExportRateLimits = 0

    /// Consecutive CloudKit import transport failures (for example CKErrorDomain=4,
    /// NSURLErrorDomain=-1017). While this is non-zero we apply exponential backoff
    /// to all voluntary manual sync kicks.
    private(set) var consecutiveImportNetworkFailures = 0

    /// Consecutive CloudKit import failures of any kind. When this reaches
    /// `maxConsecutiveImportFailuresBeforeReset`, the throttler automatically
    /// schedules a database reset on next launch so that a fresh zone import
    /// can recover records whose change tokens were advanced past.
    private(set) var consecutiveImportFailures = 0

    /// After this many consecutive import failures, auto-schedule a database reset.
    private let maxConsecutiveImportFailuresBeforeReset = 3

    /// True when an automatic sync reset has been scheduled for next launch.
    private(set) var autoResetScheduled = false

    /// When non-nil, manual sync kicks (zone fetch/nudge) should be paused until this date
    /// to avoid request storms while CloudKit is retrying failed imports.
    private(set) var manualKickPausedUntil: Date?
    
    /// True when we are currently within a rate-limit backoff window.
    /// All voluntary sync operations (forceCloudKitImport, nudge, safety-net)
    /// should check this before firing.
    var isRateLimited: Bool {
        guard let until = rateLimitedUntil else { return false }
        return Date() < until
    }

    /// True when voluntary/manual sync kicks should be paused due to repeated
    /// transport-level import failures.
    var isManualKickPaused: Bool {
        guard let until = manualKickPausedUntil else { return false }
        return Date() < until
    }

    /// True while the CloudKit mirroring delegate is actively importing/exporting.
    /// Proactive app-driven operations should avoid running during this window.
    var hasActiveCloudKitEvent: Bool {
        clearStaleInProgressEventsIfNeeded()
        return importInProgress || exportInProgress
    }

    var mostRecentActivityTime: Date? {
        [lastObservedActivityTime, lastSyncTime, importStartTime, exportStartTime]
            .compactMap { $0 }
            .max()
    }

    /// Maximum time we trust a single CloudKit event to remain "in-progress"
    /// without receiving an ending event. If this is exceeded, we treat it as
    /// stale and unblock watchdog recovery nudges.
    private let maxInProgressEventAge: TimeInterval = 600

    /// Secondary stale detection for wedged sessions: if an in-progress event
    /// has been open for at least this long AND there has been no CloudKit
    /// activity for `minInProgressInactivityForClear`, clear it proactively.
    private let minInProgressAgeForInactivityClear: TimeInterval = 120
    private let minInProgressInactivityForClear: TimeInterval = 90

    /// Longer timeout after a sync database reset, since full zone re-imports
    /// can take 15-30 minutes for large databases.
    private let maxInProgressEventAgeAfterReset: TimeInterval = 1800

    /// Set to true after a mirroring reset; cleared after the first successful import.
    /// While true, the stale-timeout uses `maxInProgressEventAgeAfterReset`.
    private(set) var isPostReset: Bool = false
    
    /// Record that CloudKit returned a rate-limit or service-unavailable error.
    /// `retryAfterSeconds` comes from the CKError userInfo.
    /// Applies exponential backoff on repeated failures: server retryAfter,
    /// then 60s, 120s, 240s ... capped at 15 minutes.
    func recordRateLimit(retryAfter retryAfterSeconds: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.consecutiveExportRateLimits += 1
            let exponent = max(0, self.consecutiveExportRateLimits - 1)
            let exponentialPause = min(retryAfterSeconds * pow(2.0, Double(exponent)), 900.0)
            let pause = max(retryAfterSeconds + 5.0, exponentialPause)
            let until = Date().addingTimeInterval(pause)
            self.rateLimitedUntil = until
            #if DEBUG
            print("⏳ [CloudKitSyncThrottler] Rate-limited until \(until) (backoff \(Int(pause))s, consecutive=\(self.consecutiveExportRateLimits))")
            #endif
        }
    }
    
    /// Clear the rate-limit flag (called after a successful sync event)
    func clearRateLimit() {
        if rateLimitedUntil != nil || consecutiveExportRateLimits > 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.rateLimitedUntil = nil
                self.consecutiveExportRateLimits = 0
                #if DEBUG
                print("✅ [CloudKitSyncThrottler] Rate-limit cleared (was consecutive=\(self.consecutiveExportRateLimits))")
                #endif
            }
        }
    }

    /// Record a CloudKit import transport failure and pause manual kicks
    /// with exponential backoff: 30s, 60s, 120s ... capped at 15 minutes.
    func recordImportTransportFailure() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.consecutiveImportNetworkFailures += 1
            let exponent = max(0, self.consecutiveImportNetworkFailures - 1)
            let pause = min(30.0 * pow(2.0, Double(exponent)), 900.0)
            let until = Date().addingTimeInterval(pause)

            if let existing = self.manualKickPausedUntil, existing > until {
                return
            }

            self.manualKickPausedUntil = until
            #if DEBUG
            print("⏳ [CloudKitSyncThrottler] Manual CloudKit kicks paused for \(Int(pause))s after import transport failures (count=\(self.consecutiveImportNetworkFailures))")
            #endif
        }
    }

    /// Clear import transport failure backoff after a successful import.
    func clearImportTransportFailureBackoff() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let hadBackoff = self.consecutiveImportNetworkFailures > 0 || self.manualKickPausedUntil != nil
            self.consecutiveImportNetworkFailures = 0
            self.manualKickPausedUntil = nil
            #if DEBUG
            if hadBackoff {
                print("✅ [CloudKitSyncThrottler] Import transport backoff cleared")
            }
            #endif
        }
    }

    /// When consecutive import failures exceed the threshold, automatically
    /// schedule a database reset on next launch so the app re-imports the
    /// full CloudKit zone from scratch (fresh server change token).
    func scheduleAutoResetIfNeeded() {
        guard consecutiveImportFailures >= maxConsecutiveImportFailuresBeforeReset else { return }
        guard !autoResetScheduled else { return }
        
        UserDefaults.standard.set(true, forKey: "resetSyncOnNextLaunch")
        autoResetScheduled = true
        appendCloudKitEvent(
            type: "recovery",
            phase: "scheduled",
            status: "auto-reset",
            message: "Database reset scheduled after \(consecutiveImportFailures) consecutive import failures. Quit and relaunch to apply."
        )
        #if DEBUG
        print("🔄 [CloudKitSyncThrottler] Auto-scheduled database reset after \(consecutiveImportFailures) consecutive import failures")
        #endif
    }

    /// Clears the auto-reset flag without performing the reset.
    /// Called when a successful import proves recovery is no longer needed.
    func cancelAutoResetIfScheduled() {
        guard autoResetScheduled else { return }
        UserDefaults.standard.removeObject(forKey: "resetSyncOnNextLaunch")
        autoResetScheduled = false
        #if DEBUG
        print("✅ [CloudKitSyncThrottler] Auto-reset cancelled — import succeeded")
        #endif
    }

    
    /// Duration to wait after last sync event before clearing isSyncing
    /// This gives time for all related changes to propagate
    private let quietPeriod: TimeInterval = 1.5
    
    /// Minimum number of rapid events to trigger "syncing" state
    /// Single isolated events don't trigger the syncing state
    private let burstThreshold = 3
    
    /// Time window to consider events as part of a "burst"
    private let burstWindow: TimeInterval = 0.5
    
    /// Timer to clear syncing state after quiet period
    private var quietTimer: Timer?

    /// Periodic watchdog that clears stale in-progress CloudKit events even
    /// when no caller is actively polling `hasActiveCloudKitEvent`.
    private var staleEventCleanupTimer: Timer?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Subject for sync events
    private let syncEventSubject = PassthroughSubject<Void, Never>()
    
    private init() {
        setupNotificationObservers()
        setupBurstDetection()
        setupCloudKitEventTracking()
        setupMirroringResetTracking()
        setupStaleEventCleanupTimer()
    }
    
    /// Pending event count accumulated on background threads, flushed to main periodically
    private var _pendingEventCount: Int = 0
    private let _pendingLock = NSLock()
    /// Whether a main-queue flush is already scheduled
    private var _flushScheduled = false
    
    /// Sets up observers for CloudKit-related notifications
    private func setupNotificationObservers() {
        // NSPersistentStoreRemoteChangeNotification - primary CloudKit sync notification
        // Use .main queue to avoid flooding the main thread with individual dispatches.
        // The coalescing below batches rapid-fire notifications.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.coalescedSyncEvent()
        }
        
        // NSPersistentStoreCoordinatorStoresDidChangeNotification - store changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreCoordinatorStoresDidChangeNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.coalescedSyncEvent()
        }
    }
    
    /// Sets up Combine pipeline to detect bursts of sync activity
    private func setupBurstDetection() {
        // Collect events and detect bursts
        syncEventSubject
            .collect(.byTime(DispatchQueue.main, .milliseconds(Int(burstWindow * 1000))))
            .sink { [weak self] events in
                guard let self = self else { return }
                if events.count >= self.burstThreshold && !self.isSyncing {
                    self.enterSyncingState()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Accumulate sync events and flush to main thread in batches.
    /// CloudKit can fire hundreds of notifications per second during a bulk sync.
    /// Each individual dispatch_async to main adds overhead; coalescing avoids this.
    private func coalescedSyncEvent() {
        _pendingLock.lock()
        _pendingEventCount += 1
        let needsSchedule = !_flushScheduled
        if needsSchedule { _flushScheduled = true }
        _pendingLock.unlock()
        
        if needsSchedule {
            DispatchQueue.main.async { [weak self] in
                self?.flushPendingEvents()
            }
        }
    }
    
    /// Flush accumulated sync events on the main thread in a single pass
    private func flushPendingEvents() {
        _pendingLock.lock()
        let count = _pendingEventCount
        _pendingEventCount = 0
        _flushScheduled = false
        _pendingLock.unlock()
        
        guard count > 0 else { return }
        
        syncEventCount += count
        totalSyncEventCount += count
        lastSyncTime = Date()
        lastObservedActivityTime = lastSyncTime
        
        // Send a single burst event to the detector (represents the whole batch)
        syncEventSubject.send()
        
        // Reset quiet timer - we're still receiving events
        resetQuietTimer()
        
        #if DEBUG
        if syncEventCount % 10 == 0 || syncEventCount <= 3 {
            print("🔄 [CloudKitSyncThrottler] Sync events +\(count) (total: \(totalSyncEventCount)), isSyncing: \(isSyncing)")
        }
        #endif
    }
    
    /// Transitions to syncing state
    private func enterSyncingState() {
        guard !isSyncing else { return }
        isSyncing = true
        
        #if DEBUG
        print("🔄 [CloudKitSyncThrottler] Entered syncing state (burst detected)")
        #endif
    }
    
    /// Resets the quiet timer that will eventually clear the syncing state
    private func resetQuietTimer() {
        quietTimer?.invalidate()
        quietTimer = Timer.scheduledTimer(withTimeInterval: quietPeriod, repeats: false) { [weak self] _ in
            self?.exitSyncingState()
        }
    }
    
    /// Transitions out of syncing state after quiet period
    private func exitSyncingState() {
        guard isSyncing else { return }
        isSyncing = false
        
        #if DEBUG
        print("✅ [CloudKitSyncThrottler] Exited syncing state after \(syncEventCount) events")
        #endif
        
        // Reset event count for next burst
        syncEventCount = 0
    }
    
    /// Manually reset the throttler (useful for testing or forced refresh)
    func reset() {
        quietTimer?.invalidate()
        quietTimer = nil
        isSyncing = false
        syncEventCount = 0
        importInProgress = false
        exportInProgress = false
        importStartTime = nil
        exportStartTime = nil
        importCompleted = false
        importSucceeded = false
        exportCompleted = false
        exportSucceeded = false
        lastSuccessfulExportTime = nil
        rateLimitedUntil = nil
        consecutiveExportRateLimits = 0
        consecutiveImportNetworkFailures = 0
        manualKickPausedUntil = nil
        lastSyncTime = nil
        lastObservedActivityTime = nil
        isPostReset = false
        recentCloudKitEvents = []
    }

    /// Run stale import/export cleanup periodically so a missing `ended` event
    /// cannot wedge the app forever.
    private func setupStaleEventCleanupTimer() {
        staleEventCleanupTimer?.invalidate()
        staleEventCleanupTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.clearStaleInProgressEventsIfNeeded()
        }
    }

    func clearRecentCloudKitEvents() {
        recentCloudKitEvents = []
    }

    /// Clear only the transport-failure backoff state, leaving event history and
    /// in-progress flags intact. Use this for an explicit user-initiated "try again"
    /// without wiping all observable UI state.
    func resetBackoffState() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.consecutiveExportRateLimits = 0
            self.consecutiveImportNetworkFailures = 0
            self.manualKickPausedUntil = nil
            self.rateLimitedUntil = nil
            #if DEBUG
            print("✅ [CloudKitSyncThrottler] Backoff state cleared by user action")
            #endif
        }
    }
    
    /// Track CloudKit import/export events via NSPersistentCloudKitContainer notifications
    private func setupCloudKitEventTracking() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self,
                  let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            
            DispatchQueue.main.async {
                let typeLabel: String
                switch event.type {
                case .setup:
                    typeLabel = "setup"
                    let phase = event.endDate == nil ? "started" : "ended"
                    let status = event.endDate == nil ? "in-progress" : (event.succeeded ? "success" : "failed")
                    let message = event.error?.localizedDescription ?? ""
                    self.appendCloudKitEvent(
                        type: typeLabel,
                        phase: phase,
                        status: status,
                        message: message
                    )
                case .import:
                    typeLabel = "import"
                    if event.endDate == nil {
                        self.markImportStarted()
                        self.appendCloudKitEvent(
                            type: typeLabel,
                            phase: "started",
                            status: "in-progress",
                            message: ""
                        )
                    } else {
                        self.importInProgress = false
                        self.importStartTime = nil
                        self.importCompleted = true
                        self.importSucceeded = event.succeeded
                        let errorMessage = self.detailedErrorMessage(event.error)
                        self.appendCloudKitEvent(
                            type: typeLabel,
                            phase: "ended",
                            status: event.succeeded ? "success" : "failed",
                            message: errorMessage
                        )
                        // Clear transport-failure backoff on success
                        if event.succeeded {
                            self.clearImportTransportFailureBackoff()
                            self.consecutiveImportFailures = 0
                            self.cancelAutoResetIfScheduled()
                            if self.isPostReset {
                                self.isPostReset = false
                                #if DEBUG
                                print("✅ [CloudKitSyncThrottler] Post-reset import succeeded, resuming normal stale timeout")
                                #endif
                            }
                        } else {
                            self.consecutiveImportFailures += 1
                            #if DEBUG
                            print("⚠️ [CloudKitSyncThrottler] Import failure #\(self.consecutiveImportFailures) — \(self.detailedErrorMessage(event.error))")
                            #endif
                            self.scheduleAutoResetIfNeeded()
                            // Detect transport failures for backoff
                            let nsError = event.error as? NSError
                            let errorDomain = nsError?.domain ?? ""
                            let errorCode = nsError?.code ?? -1
                            let underlying = nsError?.userInfo[NSUnderlyingErrorKey] as? NSError
                            let isTransportFailure = (errorDomain == "CKErrorDomain" && errorCode == 4)
                                || (underlying?.domain == NSURLErrorDomain && underlying?.code == -1017)
                            if isTransportFailure {
                                self.recordImportTransportFailure()
                            }
                        }
                        #if DEBUG
                        print("🔄 [CloudKitSyncThrottler] Import completed: succeeded=\(event.succeeded)")
                        #endif
                    }
                case .export:
                    typeLabel = "export"
                    if event.endDate == nil {
                        self.markExportStarted()
                        self.appendCloudKitEvent(
                            type: typeLabel,
                            phase: "started",
                            status: "in-progress",
                            message: ""
                        )
                    } else {
                        self.exportInProgress = false
                        self.exportStartTime = nil
                        if event.succeeded {
                            self.exportCompleted = true
                            self.exportSucceeded = true
                            self.lastSuccessfulExportTime = Date()
                            self.syncHealthMonitor?.recordExportSuccess()
                        } else {
                            self.exportSucceeded = false
                        }
                        let errorMessage = self.detailedErrorMessage(event.error)
                        self.appendCloudKitEvent(
                            type: typeLabel,
                            phase: "ended",
                            status: event.succeeded ? "success" : "failed",
                            message: errorMessage
                        )
                        // Clear rate-limit on success; detect rate-limit on failure
                        if event.succeeded {
                            self.clearRateLimit()
                        } else {
                            let nsError = event.error as? NSError
                            let errorDomain = nsError?.domain ?? ""
                            let errorCode = nsError?.code ?? -1
                            let isRateLimited = (errorDomain == "CKErrorDomain" && (errorCode == 6 || errorCode == 7))
                            if isRateLimited {
                                let retryAfter = (nsError?.userInfo["CKRetryAfter"] as? Double)
                                    ?? (nsError?.userInfo["retryAfter"] as? Double)
                                    ?? 30.0
                                self.recordRateLimit(retryAfter: retryAfter)
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
    }

    /// Track mirroring reset notifications and clear stale in-progress flags.
    /// In some failure paths (for example change token expiration), CoreData may reset
    /// mirroring state without delivering a normal import/export end event.
    private func setupMirroringResetTracking() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSCloudKitMirroringDelegateWillResetSyncNotificationName"),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleMirroringReset(notification: notification, phase: "will-reset")
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSCloudKitMirroringDelegateDidResetSyncNotificationName"),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleMirroringReset(notification: notification, phase: "did-reset")
        }
    }

    private func handleMirroringReset(notification: Notification, phase: String) {
        DispatchQueue.main.async {
            let reasonValue = notification.userInfo?["NSCloudKitMirroringDelegateResetReasonKey"]
            let reasonText = String(describing: reasonValue ?? "unknown")

            let hadActiveEvent = self.importInProgress || self.exportInProgress
            self.importInProgress = false
            self.exportInProgress = false
            self.importStartTime = nil
            self.exportStartTime = nil
            self.isPostReset = true

            self.appendCloudKitEvent(
                type: "mirroring",
                phase: phase,
                status: "reset",
                message: reasonText
            )

            #if DEBUG
            if hadActiveEvent {
                print("🔄 [CloudKitSyncThrottler] Mirroring reset (\(phase)) cleared stale in-progress flags. reason=\(reasonText)")
            } else {
                print("🔄 [CloudKitSyncThrottler] Mirroring reset (\(phase)). reason=\(reasonText)")
            }
            #endif
        }
    }

    /// Clear stale import/export "in-progress" flags that never received a matching end event.
    /// This can happen when CloudKit mirroring gets wedged after transport/token failures.
    private func clearStaleInProgressEventsIfNeeded() {
        guard Thread.isMainThread else { return }

        let now = Date()
        var cleared: [String] = []
        let staleAge = isPostReset ? maxInProgressEventAgeAfterReset : maxInProgressEventAge
        let lastActivity = lastObservedActivityTime ?? lastSyncTime

        if importInProgress,
           let started = importStartTime {
            let eventAge = now.timeIntervalSince(started)
            let inactivity = now.timeIntervalSince(lastActivity ?? started)
            let shouldClearForAge = eventAge > staleAge
            let shouldClearForInactivity = !isPostReset &&
                eventAge > minInProgressAgeForInactivityClear &&
                inactivity > minInProgressInactivityForClear

            if shouldClearForAge || shouldClearForInactivity {
            importInProgress = false
            importStartTime = nil
            importCompleted = true
            importSucceeded = false
            consecutiveImportFailures += 1
            appendCloudKitEvent(
                type: "import",
                phase: "timeout",
                status: "stale-cleared",
                message: "No end event (age=\(Int(eventAge))s, inactivity=\(Int(inactivity))s) — consecutiveImportFailures=\(consecutiveImportFailures)"
            )
            scheduleAutoResetIfNeeded()
            cleared.append("import")
            }
        }

        if exportInProgress,
           let started = exportStartTime {
            let eventAge = now.timeIntervalSince(started)
            let inactivity = now.timeIntervalSince(lastActivity ?? started)
            let shouldClearForAge = eventAge > staleAge
            let shouldClearForInactivity = !isPostReset &&
                eventAge > minInProgressAgeForInactivityClear &&
                inactivity > minInProgressInactivityForClear

            if shouldClearForAge || shouldClearForInactivity {
            exportInProgress = false
            exportStartTime = nil
            appendCloudKitEvent(
                type: "export",
                phase: "timeout",
                status: "stale-cleared",
                message: "No end event (age=\(Int(eventAge))s, inactivity=\(Int(inactivity))s)"
            )
            cleared.append("export")
            }
        }

        if !cleared.isEmpty {
            // Record the timeout itself as recent activity so the watchdog doesn't
            // interpret the session as idle since the distant past.
            lastObservedActivityTime = now
            #if DEBUG
            print("⚠️ [CloudKitSyncThrottler] Cleared stale in-progress event(s): \(cleared.joined(separator: ", "))")
            #endif
        }
    }

    private func appendCloudKitEvent(type: String, phase: String, status: String, message: String) {
        lastObservedActivityTime = Date()
        recentCloudKitEvents.insert(
            CloudKitEventLogEntry(
                timestamp: Date(),
                type: type,
                phase: phase,
                status: status,
                message: message
            ),
            at: 0
        )

        if recentCloudKitEvents.count > maxRecentEventCount {
            recentCloudKitEvents.removeLast(recentCloudKitEvents.count - maxRecentEventCount)
        }
    }

    private func detailedErrorMessage(_ error: Error?) -> String {
        guard let nsError = error as NSError? else { return "" }

        var details: [String] = []
        details.append("\(nsError.domain) code=\(nsError.code)")

        if !nsError.localizedDescription.isEmpty {
            details.append(nsError.localizedDescription)
        }

        // CKPartialErrorsByItemIDKey — individual record/zone errors
        if let partialByItem = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError],
           !partialByItem.isEmpty {
            details.append("partialErrors=\(partialByItem.count)")
            // Show first 3 distinct error codes
            var errorCodes: [String: Int] = [:]
            for (_, itemError) in partialByItem {
                let key = "\(itemError.domain):\(itemError.code)"
                errorCodes[key, default: 0] += 1
            }
            let summary = errorCodes.sorted(by: { $0.value > $1.value })
                .prefix(3)
                .map { "\($0.key)(x\($0.value))" }
                .joined(separator: ", ")
            details.append("errorBreakdown=[\(summary)]")
            if let first = partialByItem.first {
                details.append("firstItem=\(first.key)")
                let firstErr = first.value
                details.append("firstError=\(firstErr.domain):\(firstErr.code)")
                // Dig into first partial error's underlying
                if let firstUnderlying = firstErr.userInfo[NSUnderlyingErrorKey] as? NSError {
                    details.append("firstUnderlying=\(firstUnderlying.domain):\(firstUnderlying.code) \(firstUnderlying.localizedDescription)")
                }
            }
        }

        // NSDetailedErrorsKey — Core Data batch validation errors
        if let detailedErrors = nsError.userInfo["NSDetailedErrors"] as? [NSError], !detailedErrors.isEmpty {
            details.append("detailedErrors=\(detailedErrors.count)")
            if let first = detailedErrors.first {
                details.append("firstDetailed=\(first.domain):\(first.code) \(first.localizedDescription)")
            }
        }

        // NSUnderlyingErrorKey — walk up to 3 levels deep
        var current: NSError? = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        var depth = 0
        while let u = current, depth < 3 {
            let prefix = depth == 0 ? "underlying" : "underlying\(depth+1)"
            details.append("\(prefix)=\(u.domain):\(u.code)")
            if !u.localizedDescription.isEmpty && u.localizedDescription != nsError.localizedDescription {
                details.append(u.localizedDescription)
            }
            // Check for partial errors inside underlying too
            if let nestedPartial = u.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError],
               !nestedPartial.isEmpty {
                details.append("\(prefix).partialErrors=\(nestedPartial.count)")
                var nestedCodes: [String: Int] = [:]
                for (_, itemError) in nestedPartial {
                    let key = "\(itemError.domain):\(itemError.code)"
                    nestedCodes[key, default: 0] += 1
                }
                let nestedSummary = nestedCodes.sorted(by: { $0.value > $1.value })
                    .prefix(3)
                    .map { "\($0.key)(x\($0.value))" }
                    .joined(separator: ", ")
                details.append("\(prefix).breakdown=[\(nestedSummary)]")
                if let first = nestedPartial.first {
                    details.append("\(prefix).firstItem=\(first.key)")
                    details.append("\(prefix).firstError=\(first.value.domain):\(first.value.code) \(first.value.localizedDescription)")
                }
            }
            current = u.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }

        // Dump all userInfo keys if we still only have domain+code (no details extracted)
        if details.count <= 2 {
            let keys = nsError.userInfo.keys.map { "\($0)" }.sorted()
            if !keys.isEmpty {
                details.append("userInfoKeys=[\(keys.joined(separator: ", "))]")
            }
        }

        return details.joined(separator: " | ")
    }

    private func markImportStarted(now: Date = Date()) {
        lastObservedActivityTime = now
        importCompleted = false
        importSucceeded = false
        if !importInProgress {
            importInProgress = true
            importStartTime = now
            return
        }

        if importStartTime == nil {
            importStartTime = now
        }
    }

    private func markExportStarted(now: Date = Date()) {
        lastObservedActivityTime = now
        exportCompleted = false
        exportSucceeded = false
        if !exportInProgress {
            exportInProgress = true
            exportStartTime = now
            return
        }

        if exportStartTime == nil {
            exportStartTime = now
        }
    }
    
    deinit {
        quietTimer?.invalidate()
        staleEventCleanupTimer?.invalidate()
        cancellables.removeAll()
    }
}

#if DEBUG
extension CloudKitSyncThrottler {
    /// Test hook: inject import in-progress state with a controlled start time.
    func _testSetImportInProgress(startedAt date: Date) {
        importInProgress = true
        importStartTime = date
    }

    /// Test hook: inject export in-progress state with a controlled start time.
    func _testSetExportInProgress(startedAt date: Date) {
        exportInProgress = true
        exportStartTime = date
    }

    /// Test hook: simulate receiving an import start event.
    func _testMarkImportStarted(at date: Date) {
        markImportStarted(now: date)
    }

    /// Test hook: simulate receiving an export start event.
    func _testMarkExportStarted(at date: Date) {
        markExportStarted(now: date)
    }
}
#endif

// MARK: - SwiftUI View Modifier

import SwiftUI

/// View modifier that can defer view updates during CloudKit sync bursts
struct SyncAwareModifier: ViewModifier {
    let throttler = CloudKitSyncThrottler.shared
    
    func body(content: Content) -> some View {
        content
            // The throttler's isSyncing state is available for child views
            .environment(\.isSyncing, throttler.isSyncing)
    }
}

/// Environment key for sync state
private struct IsSyncingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when CloudKit is actively syncing and views should defer non-critical updates
    var isSyncing: Bool {
        get { self[IsSyncingKey.self] }
        set { self[IsSyncingKey.self] = newValue }
    }
}

extension View {
    /// Makes this view aware of CloudKit sync state
    func syncAware() -> some View {
        modifier(SyncAwareModifier())
    }
}
