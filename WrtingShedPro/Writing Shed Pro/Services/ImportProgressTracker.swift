//
//  ImportProgressTracker.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
import Observation

/// Observable progress tracker for import UI binding
@Observable
class ImportProgressTracker {
    
    // MARK: - Properties
    
    var totalItems: Int = 0
    var processedItems: Int = 0
    var currentPhase: String = "Initializing..."
    var currentItem: String = ""
    var isComplete: Bool = false
    var hasError: Bool = false
    var errorMessage: String = ""
    
    private let startTime: Date = Date()
    
    // MARK: - Computed Properties
    
    /// Percentage of items processed (0-100)
    var percentComplete: Double {
        guard totalItems > 0 else { return 0 }
        return min(Double(processedItems) / Double(totalItems) * 100, 100)
    }
    
    /// Estimated time remaining in seconds
    var estimatedTimeRemaining: TimeInterval {
        guard processedItems > 0 else { return 0 }
        let elapsedTime = Date().timeIntervalSince(startTime)
        let timePerItem = elapsedTime / Double(processedItems)
        let itemsRemaining = totalItems - processedItems
        return timePerItem * Double(itemsRemaining)
    }
    
    /// Formatted string of estimated time remaining
    var timeRemainingString: String {
        let seconds = estimatedTimeRemaining
        if seconds < 1 {
            return "Less than 1 second"
        } else if seconds < 60 {
            return String(format: "%.0f seconds", seconds)
        } else {
            let minutes = seconds / 60
            return String(format: "%.1f minutes", minutes)
        }
    }
    
    /// Elapsed time since start
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    /// Formatted string of elapsed time
    var elapsedTimeString: String {
        let seconds = elapsedTime
        if seconds < 1 {
            return "< 1s"
        } else if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else {
            let minutes = seconds / 60
            let secs = seconds.truncatingRemainder(dividingBy: 60)
            return String(format: "%.1fm %.0fs", minutes, secs)
        }
    }
    
    /// Items per second
    var itemsPerSecond: Double {
        let elapsed = elapsedTime
        guard elapsed > 0 else { return 0 }
        return Double(processedItems) / elapsed
    }
    
    // MARK: - Public Methods
    
    /// Initialize tracking with total item count
    func setTotal(_ count: Int) {
        self.totalItems = count
        self.processedItems = 0
    }
    
    /// Mark one item as processed
    func incrementProcessed() {
        processedItems = min(processedItems + 1, totalItems)
    }
    
    /// Mark multiple items as processed
    func incrementProcessed(by count: Int) {
        processedItems = min(processedItems + count, totalItems)
    }
    
    /// Set current phase
    func setPhase(_ phase: String) {
        self.currentPhase = phase
        print("📍 \(phase)")
    }
    
    /// Set current item being processed
    func setCurrentItem(_ item: String) {
        self.currentItem = item
    }
    
    /// Mark as complete
    func markComplete() {
        self.isComplete = true
        self.processedItems = totalItems
        print("✅ Import complete")
    }
    
    /// Mark as errored
    func markError(_ message: String) {
        self.hasError = true
        self.errorMessage = message
        print("❌ Import error: \(message)")
    }
    
    /// Reset progress
    func reset() {
        totalItems = 0
        processedItems = 0
        currentPhase = "Initializing..."
        currentItem = ""
        isComplete = false
        hasError = false
        errorMessage = ""
    }
    
    /// Get current status string for display
    var statusString: String {
        if hasError {
            return "Error: \(errorMessage)"
        } else if isComplete {
            return "Complete"
        } else {
            return "\(currentPhase) - \(processedItems)/\(totalItems)"
        }
    }
}

// MARK: - Progress Update Helper

struct ProgressUpdate {
    let phase: String
    let currentItem: String?
    let processedCount: Int
    let totalCount: Int
    
    var percentComplete: Double {
        guard totalCount > 0 else { return 0 }
        return Double(processedCount) / Double(totalCount) * 100
    }
}
