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

    /// True while a CloudKit export event is currently in progress.
    private(set) var exportInProgress = false
    private(set) var exportStartTime: Date?
    
    /// Time of the last sync notification
    private(set) var lastSyncTime: Date?

    /// Most recent CloudKit import/export/setup events for diagnostics UI.
    /// Bounded list to avoid unbounded memory growth.
    private(set) var recentCloudKitEvents: [CloudKitEventLogEntry] = []

    /// Maximum number of event rows retained in memory.
    private let maxRecentEventCount = 60
    
    /// When non-nil, CloudKit is rate-limited and we should NOT fire additional
    /// zone fetch or nudge operations until this date has passed.
    /// Set from the CKError retry-after hint when we detect rate limiting.
    private(set) var rateLimitedUntil: Date?

    /// Consecutive CloudKit import transport failures (for example CKErrorDomain=4,
    /// NSURLErrorDomain=-1017). While this is non-zero we apply exponential backoff
    /// to all voluntary manual sync kicks.
    private(set) var consecutiveImportNetworkFailures = 0

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
        importInProgress || exportInProgress
    }
    
    /// Record that CloudKit returned a rate-limit or service-unavailable error.
    /// `retryAfterSeconds` comes from the CKError userInfo.
    func recordRateLimit(retryAfter retryAfterSeconds: Double) {
        let until = Date().addingTimeInterval(retryAfterSeconds + 5.0) // +5s buffer
        DispatchQueue.main.async { [weak self] in
            self?.rateLimitedUntil = until
            #if DEBUG
            print("⏳ [CloudKitSyncThrottler] Rate-limited until \(until) (backoff \(Int(retryAfterSeconds))s + 5s buffer)")
            #endif
        }
    }
    
    /// Clear the rate-limit flag (called after a successful sync event)
    func clearRateLimit() {
        if rateLimitedUntil != nil {
            DispatchQueue.main.async { [weak self] in
                self?.rateLimitedUntil = nil
                #if DEBUG
                print("✅ [CloudKitSyncThrottler] Rate-limit cleared")
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
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Subject for sync events
    private let syncEventSubject = PassthroughSubject<Void, Never>()
    
    private init() {
        setupNotificationObservers()
        setupBurstDetection()
        setupCloudKitEventTracking()
        setupMirroringResetTracking()
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
        lastSyncTime = nil
        recentCloudKitEvents = []
    }

    func clearRecentCloudKitEvents() {
        recentCloudKitEvents = []
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
                        self.importInProgress = true
                        self.importStartTime = Date()
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
                        self.appendCloudKitEvent(
                            type: typeLabel,
                            phase: "ended",
                            status: event.succeeded ? "success" : "failed",
                            message: event.error?.localizedDescription ?? ""
                        )
                        #if DEBUG
                        print("🔄 [CloudKitSyncThrottler] Import completed: succeeded=\(event.succeeded)")
                        #endif
                    }
                case .export:
                    typeLabel = "export"
                    if event.endDate == nil {
                        self.exportInProgress = true
                        self.exportStartTime = Date()
                        self.appendCloudKitEvent(
                            type: typeLabel,
                            phase: "started",
                            status: "in-progress",
                            message: ""
                        )
                    } else {
                        self.exportInProgress = false
                        self.exportStartTime = nil
                        self.appendCloudKitEvent(
                            type: typeLabel,
                            phase: "ended",
                            status: event.succeeded ? "success" : "failed",
                            message: event.error?.localizedDescription ?? ""
                        )
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

    private func appendCloudKitEvent(type: String, phase: String, status: String, message: String) {
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
    
    deinit {
        quietTimer?.invalidate()
        cancellables.removeAll()
    }
}

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
