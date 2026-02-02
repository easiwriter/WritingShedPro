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
import Observation

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
    
    /// Time of the last sync notification
    private(set) var lastSyncTime: Date?
    
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
    }
    
    /// Sets up observers for CloudKit-related notifications
    private func setupNotificationObservers() {
        // NSPersistentStoreRemoteChangeNotification - primary CloudKit sync notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: nil  // Receive on posting queue for speed
        ) { [weak self] _ in
            self?.handleSyncEvent()
        }
        
        // NSPersistentStoreCoordinatorStoresDidChangeNotification - store changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreCoordinatorStoresDidChangeNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleSyncEvent()
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
    
    /// Called when a sync notification is received
    private func handleSyncEvent() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.syncEventCount += 1
            self.lastSyncTime = Date()
            
            // Send to burst detector
            self.syncEventSubject.send()
            
            // Reset quiet timer - we're still receiving events
            self.resetQuietTimer()
            
            #if DEBUG
            if self.syncEventCount % 10 == 0 || self.syncEventCount <= 3 {
                print("🔄 [CloudKitSyncThrottler] Sync event #\(self.syncEventCount), isSyncing: \(self.isSyncing)")
            }
            #endif
        }
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
