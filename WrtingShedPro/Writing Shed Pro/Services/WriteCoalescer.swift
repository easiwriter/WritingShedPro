import Foundation
import Observation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

enum EnsemblesSaveGateError: LocalizedError {
    case syncBusy(reason: String, attached: Bool, activity: String)

    var errorDescription: String? {
        switch self {
        case let .syncBusy(reason, attached, activity):
            return "Save deferred because Ensembles is not idle (reason=\(reason), attached=\(attached), activity=\(activity))"
        }
    }
}

enum EnsemblesSaveGate {
    private static func canBypassFirstSyncForUserImport(reason: String, activity: String) -> Bool {
        guard reason.hasPrefix("json-import-") else { return false }
        return activity.lowercased() == "none"
    }

    static func isInStartupAttachGracePeriod() -> Bool {
        guard let activatedAt = Write_App.activeEnsemblesContainerActivatedAt else { return false }
        return Date().timeIntervalSince(activatedAt) < Write_App.minimumEnsemblesStartupWriteDelay
    }

    static func canSaveAfterFirstSuccessfulSync() -> Bool {
        guard Write_App.activeEnsemblesContainer != nil else { return true }
        return Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch
    }

    static func canSaveNow(reason: String) -> Bool {
        guard let ensemblesContainer = Write_App.activeEnsemblesContainer else {
            return true
        }

        let activity = String(describing: ensemblesContainer.currentActivity)
        guard Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch else {
            if canBypassFirstSyncForUserImport(reason: reason, activity: activity) {
                let message = "⚠️ [EnsemblesSaveGate] Allowing user import save before first successful sync because Ensembles is idle reason=\(reason) attached=\(ensemblesContainer.isAttached)"
                #if DEBUG
                print(message)
                #endif
                Task { @MainActor in Write_App.logToFile(message) }
                return true
            }

            let message = "⏳ [EnsemblesSaveGate] Blocked direct save before first successful sync this launch reason=\(reason) attached=\(ensemblesContainer.isAttached) activity=\(activity)"
            #if DEBUG
            print(message)
            #endif
            Task { @MainActor in Write_App.logToFile(message) }
            return false
        }

        return true
    }

    static func save(_ context: ModelContext, reason: String) throws {
        if let ensemblesContainer = Write_App.activeEnsemblesContainer, !canSaveNow(reason: reason) {
            throw EnsemblesSaveGateError.syncBusy(
                reason: reason,
                attached: ensemblesContainer.isAttached,
                activity: String(describing: ensemblesContainer.currentActivity)
            )
        }

        try context.save()
    }
}

/// Centralised save coalescer that batches `modelContext.save()` calls.
///
/// Callers invoke `requestSave()` instead of saving directly. The coalescer
/// waits for an idle window before performing a single save. The delay adapts
/// to editing activity: during rapid bursts the delay is extended to coalesce
/// more aggressively; once the user goes idle all pending changes flush
/// immediately. This reduces sync/export churn during intensive editing sessions.
@Observable
@MainActor
final class WriteCoalescer {

    /// Shared instance — set during app startup in Write_App.init().
    static var shared: WriteCoalescer!

    // MARK: - Observable State

    /// Whether a save has been requested but not yet flushed.
    private(set) var pendingSave: Bool = false

    /// Number of actual `modelContext.save()` calls executed.
    private(set) var saveCount: Int = 0

    /// Number of `requestSave()` calls received.
    private(set) var requestCount: Int = 0

    /// Timestamp of last successful flush.
    private(set) var lastFlushTime: Date?

    /// Current editing activity level, derived from request frequency.
    private(set) var editingActivity: EditingActivity = .idle

    // MARK: - Configuration

    /// Idle threshold before flushing (seconds).
    let flushDelay: TimeInterval

    /// Multiplier applied during burst editing (many requests in a short window).
    let burstDelayMultiplier: TimeInterval = 1.75

    /// Number of requests within `burstWindowDuration` to classify as a burst.
    let burstRequestThreshold: Int = 5

    /// Sliding window for counting burst activity (seconds).
    let burstWindowDuration: TimeInterval = 10.0

    /// Seconds of inactivity after the last request before an idle flush fires.
    let idleFlushThreshold: TimeInterval = 5.0

    /// The effective delay, accounting for editing activity.
    private var effectiveDelay: TimeInterval {
        var delay = flushDelay
        if editingActivity == .burst {
            delay *= burstDelayMultiplier
        }
        return delay
    }

    /// Optional health monitor — notified after each successful flush.
    var syncHealthMonitor: SyncHealthMonitor?

    // MARK: - Private

    private let modelContext: ModelContext
    // @ObservationIgnored so deinit can invalidate/clean up
    @ObservationIgnored private var flushTimer: Timer?
    @ObservationIgnored private var idleTimer: Timer?
    @ObservationIgnored private var diagnosticTimer: Timer?
    @ObservationIgnored private var unsignaledChangeTimer: Timer?

    /// Timestamps of recent `requestSave()` calls for burst detection.
    @ObservationIgnored private var recentRequestTimes: [Date] = []

    /// Last live editor activity, including changes that have not yet requested a save.
    @ObservationIgnored private var lastEditingActivityDate: Date?

    /// Interval for periodic diagnostic logging (seconds). 0 disables.
    private let diagnosticInterval: TimeInterval = 300 // 5 minutes

    /// Disabled: `ModelContext.hasChanges` can be set by SwiftData @Transient
    /// cache mutations, so saving from this timer creates idle WAL churn.
    private let unsignaledChangeCheckInterval: TimeInterval = 0

    /// Back off pending save retries while Ensembles is merging so we don't keep
    /// waking Core Data during heavy checkpoint/vacuum maintenance.
    private let minimumSyncDeferralDelay: TimeInterval = 2.0
    private let maximumSyncDeferralDelay: TimeInterval = 30.0
    @ObservationIgnored private var syncDeferralDelay: TimeInterval = 2.0

    #if DEBUG
    private var lastSaveRequestSource: String?
    private var lastSaveTraceLogTime: Date = .distantPast
    private var lastDeferredForSyncLogTime: Date = .distantPast
    #endif

    /// Snapshot of `saveCount` at last diagnostic log, used to detect activity.
    private var lastDiagnosticSaveCount: Int = 0

    #if canImport(UIKit)
    /// Observation token for `didEnterBackgroundNotification`.
    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?
    #endif

    // MARK: - Init

    /// - Parameters:
    ///   - modelContext: The main `ModelContext` to save.
    ///   - flushDelay: Seconds to wait before flushing (default 2.0).
    init(modelContext: ModelContext, flushDelay: TimeInterval = 2.0) {
        self.modelContext = modelContext
        self.flushDelay = flushDelay

        #if canImport(UIKit)
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.flush()
            }
        }

        #endif

        // Periodic diagnostic logging
        #if DEBUG
        if diagnosticInterval > 0 {
            diagnosticTimer = Timer.scheduledTimer(withTimeInterval: diagnosticInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.logDiagnostics()
                }
            }
        }
        #endif

        if unsignaledChangeCheckInterval > 0 {
            unsignaledChangeTimer = Timer.scheduledTimer(withTimeInterval: unsignaledChangeCheckInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.checkForUnsignaledChanges()
                }
            }
        }
    }

    deinit {
        flushTimer?.invalidate()
        idleTimer?.invalidate()
        diagnosticTimer?.invalidate()
        unsignaledChangeTimer?.invalidate()
        #if canImport(UIKit)
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
    }

    // MARK: - Public API

    /// Request a coalesced save. Resets the flush timer each time it is called
    /// so that rapid successive requests produce a single save. The flush
    /// delay adapts based on editing activity (burst vs. normal).
    func requestSave(reason: String = "requestSave", file: StaticString = #fileID, line: UInt = #line) {
        requestCount += 1
        pendingSave = true
        #if DEBUG
        lastSaveRequestSource = "\(reason) @ \(file):\(line)"
        #endif
        updateEditingActivity()
        resetTimer()
        resetIdleTimer()
    }

    /// Record live editor input without scheduling a save.
    /// This lets other UI paths defer nonessential refresh work while typing is active.
    func noteEditingActivity() {
        lastEditingActivityDate = Date()
    }

    func hasRecentEditingActivity(within interval: TimeInterval) -> Bool {
        guard let lastEditingActivityDate else { return false }
        return Date().timeIntervalSince(lastEditingActivityDate) < interval
    }

    /// Immediately save if there are pending changes. Safe to call multiple
    /// times — no-op when nothing is pending.
    func flush() {
        guard pendingSave else { return }
        flushTimer?.invalidate()
        flushTimer = nil
        executeSave()
    }

    /// Compatibility wrapper for older `try modelContext.save()` call sites.
    /// It keeps existing `do/catch` shapes valid while routing saves through
    /// the Ensembles-aware deferral logic in `executeSave()`.
    func requestSaveAndFlush(reason: String = "requestSaveAndFlush") throws {
        requestSave(reason: reason)
        try flushOrThrow(reason: reason)
    }

    /// Immediately save and report failures to callers that need a definitive
    /// result before updating UI state, such as destructive actions.
    func flushOrThrow(reason: String = "flushOrThrow") throws {
        flushTimer?.invalidate()
        flushTimer = nil

        if let ensemblesContainer = Write_App.activeEnsemblesContainer,
           !EnsemblesSaveGate.canSaveNow(reason: reason) {
            throw EnsemblesSaveGateError.syncBusy(
                reason: reason,
                attached: ensemblesContainer.isAttached,
                activity: String(describing: ensemblesContainer.currentActivity)
            )
        }

        resetSyncDeferralDelay()
        pendingSave = false
        guard modelContext.hasChanges else {
            return
        }

        try modelContext.save()
        saveCount += 1
        lastFlushTime = Date()
        syncHealthMonitor?.recordLocalChange()
        #if DEBUG
        let now = Date()
        if now.timeIntervalSince(lastSaveTraceLogTime) >= 2 {
            print("💾 [WriteCoalescer] saved source=\(reason) activity=\(editingActivity.rawValue) requests=\(requestCount) saves=\(saveCount)")
            lastSaveTraceLogTime = now
        }
        #endif
    }

    /// Cancel any pending save without flushing.
    func cancelPending() {
        flushTimer?.invalidate()
        flushTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil
        pendingSave = false
        editingActivity = .idle
        resetSyncDeferralDelay()
    }

    // MARK: - Activity Tracking

    /// Editing activity levels used to adapt save scheduling.
    enum EditingActivity: String {
        /// No recent requests — user is not editing.
        case idle
        /// Normal editing pace.
        case active
        /// Rapid-fire changes — coalesce more aggressively.
        case burst
    }

    private func updateEditingActivity() {
        let now = Date()
        lastEditingActivityDate = now
        recentRequestTimes.append(now)

        // Trim timestamps outside the burst window.
        let windowStart = now.addingTimeInterval(-burstWindowDuration)
        recentRequestTimes.removeAll { $0 < windowStart }

        let newActivity: EditingActivity = recentRequestTimes.count >= burstRequestThreshold ? .burst : .active
        if editingActivity != newActivity {
            editingActivity = newActivity
        }
    }

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleFlushThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleIdleTimeout()
            }
        }
    }

    private func handleIdleTimeout() {
        idleTimer = nil
        editingActivity = .idle
        recentRequestTimes.removeAll()
        // User stopped editing — flush anything still pending.
        flush()
    }

    // MARK: - Private

    private func resetTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: effectiveDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.executeSave()
            }
        }
    }

    private func executeSave() {
        if deferSaveIfEnsemblesBusy() {
            return
        }

        resetSyncDeferralDelay()
        pendingSave = false
        guard modelContext.hasChanges else {
            return
        }
        do {
            try modelContext.save()
            saveCount += 1
            lastFlushTime = Date()
            syncHealthMonitor?.recordLocalChange()
            #if DEBUG
            let now = Date()
            if now.timeIntervalSince(lastSaveTraceLogTime) >= 2 {
                print("💾 [WriteCoalescer] saved source=\(lastSaveRequestSource ?? "unknown") activity=\(editingActivity.rawValue) requests=\(requestCount) saves=\(saveCount)")
                lastSaveTraceLogTime = now
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ [WriteCoalescer] modelContext.save() failed: \(error)")
            #endif
        }
    }

    private func deferSaveIfEnsemblesBusy() -> Bool {
        guard pendingSave,
              let ensemblesContainer = Write_App.activeEnsemblesContainer else {
            return false
        }

        let activity = String(describing: ensemblesContainer.currentActivity)
        guard !EnsemblesSaveGate.canSaveAfterFirstSuccessfulSync() else {
            return false
        }

        let retryDelay = syncDeferralDelay
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.executeSave()
            }
        }
        syncDeferralDelay = min(syncDeferralDelay * 2, maximumSyncDeferralDelay)

        #if DEBUG
        let now = Date()
        if now.timeIntervalSince(lastDeferredForSyncLogTime) >= 10 {
            let firstSyncComplete = Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch
            let message = "⏳ [WriteCoalescer] Deferred save while Ensembles unavailable firstSync=\(firstSyncComplete) attached=\(ensemblesContainer.isAttached) activity=\(activity) retryIn=\(String(format: "%.0f", retryDelay))s source=\(lastSaveRequestSource ?? "unknown")"
            print(message)
            Write_App.logToFile(message)
            lastDeferredForSyncLogTime = now
        }
        #endif
        return true
    }

    private func resetSyncDeferralDelay() {
        syncDeferralDelay = minimumSyncDeferralDelay
    }

    /// Diagnostic only. Do not auto-save arbitrary `hasChanges` here: SwiftData
    /// may report changes after @Transient cache reads, which are not persistent edits.
    private func checkForUnsignaledChanges() {
        guard !pendingSave else { return }
        guard modelContext.hasChanges else { return }

        #if DEBUG
        print("⚠️ [WriteCoalescer] unsignaled modelContext changes detected while idle; not auto-saving")
        #endif
    }

    #if DEBUG
    private func logDiagnostics() {
        guard saveCount > lastDiagnosticSaveCount else { return } // skip if idle
        let ratio = saveCount > 0 ? Double(requestCount) / Double(saveCount) : 0
        print("📊 [WriteCoalescer] requests=\(requestCount) saves=\(saveCount) ratio=\(String(format: "%.1f", ratio)):1 pending=\(pendingSave) activity=\(editingActivity.rawValue)")
        lastDiagnosticSaveCount = saveCount
    }
    #endif
}
