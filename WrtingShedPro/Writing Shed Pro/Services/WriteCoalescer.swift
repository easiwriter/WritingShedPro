import Foundation
import Observation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Centralised save coalescer that batches `modelContext.save()` calls.
///
/// Callers invoke `requestSave()` instead of saving directly. The coalescer
/// waits for an idle window (`flushDelay`, default 2 s) before performing a
/// single save. This dramatically reduces CloudKit export operations during
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

    // MARK: - Configuration

    /// Idle threshold before flushing (seconds).
    let flushDelay: TimeInterval

    /// Multiplier applied to `flushDelay` when CloudKit is rate-limited.
    /// Reduces save frequency to avoid deepening the rate-limit storm.
    let rateLimitDelayMultiplier: TimeInterval = 3.0

    /// The effective delay, accounting for active rate-limit state.
    private var effectiveDelay: TimeInterval {
        if CloudKitSyncThrottler.shared.isRateLimited {
            return flushDelay * rateLimitDelayMultiplier
        }
        return flushDelay
    }

    /// Optional health monitor — notified after each successful flush.
    var syncHealthMonitor: SyncHealthMonitor?

    // MARK: - Private

    private let modelContext: ModelContext
    // @ObservationIgnored so deinit can invalidate/clean up
    @ObservationIgnored private var flushTimer: Timer?
    @ObservationIgnored private var diagnosticTimer: Timer?

    /// Interval for periodic diagnostic logging (seconds). 0 disables.
    private let diagnosticInterval: TimeInterval = 300 // 5 minutes

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
    }

    deinit {
        flushTimer?.invalidate()
        diagnosticTimer?.invalidate()
        #if canImport(UIKit)
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
    }

    // MARK: - Public API

    /// Request a coalesced save. Resets the flush timer each time it is called
    /// so that rapid successive requests produce a single save.
    func requestSave() {
        requestCount += 1
        pendingSave = true
        resetTimer()
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
        pendingSave = false
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

    #if DEBUG
    private func logDiagnostics() {
        guard saveCount > lastDiagnosticSaveCount else { return } // skip if idle
        let ratio = saveCount > 0 ? Double(requestCount) / Double(saveCount) : 0
        let rateLimited = CloudKitSyncThrottler.shared.isRateLimited
        print("📊 [WriteCoalescer] requests=\(requestCount) saves=\(saveCount) ratio=\(String(format: "%.1f", ratio)):1 pending=\(pendingSave) rateLimited=\(rateLimited)")
        lastDiagnosticSaveCount = saveCount
    }
    #endif
}
