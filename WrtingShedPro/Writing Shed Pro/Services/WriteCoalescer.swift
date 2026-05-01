import Foundation
import Observation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Centralised save coalescer that batches `modelContext.save()` calls.
///
/// Callers invoke `requestSave()` instead of saving directly. The coalescer
/// waits for an idle window before performing a single save. The delay adapts
/// to editing activity: during rapid bursts the delay is extended to coalesce
/// more aggressively; once the user goes idle all pending changes flush
/// immediately. This dramatically reduces CloudKit export operations during
/// intensive editing sessions.
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

    /// Multiplier applied to `flushDelay` when CloudKit is rate-limited.
    /// Reduces save frequency to avoid deepening the rate-limit storm.
    let rateLimitDelayMultiplier: TimeInterval = 3.0

    /// Multiplier applied during burst editing (many requests in a short window).
    let burstDelayMultiplier: TimeInterval = 1.75

    /// Number of requests within `burstWindowDuration` to classify as a burst.
    let burstRequestThreshold: Int = 5

    /// Sliding window for counting burst activity (seconds).
    let burstWindowDuration: TimeInterval = 10.0

    /// Seconds of inactivity after the last request before an idle flush fires.
    let idleFlushThreshold: TimeInterval = 5.0

    /// The effective delay, accounting for editing activity and rate-limit state.
    private var effectiveDelay: TimeInterval {
        var delay = flushDelay
        if editingActivity == .burst {
            delay *= burstDelayMultiplier
        }
        if CloudKitSyncThrottler.shared.isRateLimited {
            delay *= rateLimitDelayMultiplier
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

    /// Interval for periodic diagnostic logging (seconds). 0 disables.
    private let diagnosticInterval: TimeInterval = 300 // 5 minutes

    /// Safety-net interval to detect local model mutations that did not call
    /// `requestSave()` and still need to be persisted/exported.
    private let unsignaledChangeCheckInterval: TimeInterval = 20

    /// Snapshot of `saveCount` at last diagnostic log, used to detect activity.
    private var lastDiagnosticSaveCount: Int = 0

    #if canImport(UIKit)
    /// Observation token for `willResignActiveNotification`.
    @ObservationIgnored private var resignActiveObserver: NSObjectProtocol?
    #endif

    // MARK: - Init

    /// - Parameters:
    ///   - modelContext: The main `ModelContext` to save.
    ///   - flushDelay: Seconds to wait before flushing (default 2.0).
    init(modelContext: ModelContext, flushDelay: TimeInterval = 2.0) {
        self.modelContext = modelContext
        self.flushDelay = flushDelay

        #if canImport(UIKit)
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
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
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
    }

    // MARK: - Public API

    /// Request a coalesced save. Resets the flush timer each time it is called
    /// so that rapid successive requests produce a single save. The flush
    /// delay adapts based on editing activity (burst vs. normal).
    func requestSave() {
        requestCount += 1
        pendingSave = true
        updateEditingActivity()
        resetTimer()
        resetIdleTimer()
    }

    /// Immediately save if there are pending changes. Safe to call multiple
    /// times — no-op when nothing is pending.
    func flush() {
        guard pendingSave else { return }
        flushTimer?.invalidate()
        flushTimer = nil
        executeSave()
    }

    /// Cancel any pending save without flushing.
    func cancelPending() {
        flushTimer?.invalidate()
        flushTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil
        pendingSave = false
        editingActivity = .idle
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
        recentRequestTimes.append(now)

        // Trim timestamps outside the burst window.
        let windowStart = now.addingTimeInterval(-burstWindowDuration)
        recentRequestTimes.removeAll { $0 < windowStart }

        if recentRequestTimes.count >= burstRequestThreshold {
            editingActivity = .burst
        } else {
            editingActivity = .active
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
        pendingSave = false
        do {
            try modelContext.save()
            saveCount += 1
            lastFlushTime = Date()
            syncHealthMonitor?.recordLocalChange()
            #if DEBUG
            print("💾 [WriteCoalescer] Saved (request #\(requestCount), save #\(saveCount))")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [WriteCoalescer] Save failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Catch writes that mutated models but forgot to request a save.
    /// This keeps local DB and CloudKit export queue from silently stalling.
    private func checkForUnsignaledChanges() {
        guard !pendingSave else { return }
        guard modelContext.hasChanges else { return }

        #if DEBUG
        print("⚠️ [WriteCoalescer] Detected unsignaled model changes — scheduling coalesced save")
        #endif

        requestSave()
    }

    #if DEBUG
    private func logDiagnostics() {
        guard saveCount > lastDiagnosticSaveCount else { return } // skip if idle
        let ratio = saveCount > 0 ? Double(requestCount) / Double(saveCount) : 0
        let rateLimited = CloudKitSyncThrottler.shared.isRateLimited
        print("📊 [WriteCoalescer] requests=\(requestCount) saves=\(saveCount) ratio=\(String(format: "%.1f", ratio)):1 pending=\(pendingSave) activity=\(editingActivity.rawValue) rateLimited=\(rateLimited)")
        lastDiagnosticSaveCount = saveCount
    }
    #endif
}
