//
//  ImportErrorHandler.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
import SwiftData

/// Handles errors and warnings during import with rollback capability
class ImportErrorHandler {
    
    // MARK: - Properties
    
    private(set) var warnings: [String] = []
    private(set) var errors: [String] = []
    private var startTime: Date = Date()
    
    // MARK: - Public Methods
    
    /// Add a warning message
    func addWarning(_ message: String) {
        warnings.append(message)
        print("⚠️ Warning: \(message)")
    }
    
    /// Add an error message
    func addError(_ message: String) {
        errors.append(message)
        print("❌ Error: \(message)")
    }
    
    /// Check if any fatal errors occurred
    var isFatal: Bool {
        !errors.isEmpty
    }
    
    /// Get count of warnings
    var warningCount: Int {
        warnings.count
    }
    
    /// Get count of errors
    var errorCount: Int {
        errors.count
    }
    
    /// Generate import report
    func generateReport(
        successCount: Int,
        failureCount: Int = 0
    ) -> ImportReport {
        let duration = Date().timeIntervalSince(startTime)
        
        return ImportReport(
            successCount: successCount,
            failureCount: failureCount,
            warningCount: warningCount,
            errorCount: errorCount,
            warnings: warnings,
            errors: errors,
            duration: duration,
            isFatal: isFatal
        )
    }
    
    /// Reset error state
    func reset() {
        warnings = []
        errors = []
        startTime = Date()
    }
    
    // MARK: - Rollback
    
    /// Rollback all changes to ModelContext
    /// - Parameter modelContext: The SwiftData ModelContext to rollback
    /// - Throws: ImportError if rollback fails
    func rollback(on modelContext: ModelContext) throws {
        do {
            // Undo all changes
            modelContext.undoManager?.undoNestedGroup()
        } catch {
            throw ImportError.rollbackFailed("Failed to rollback: \(error.localizedDescription)")
        }
    }
}

// MARK: - Import Report

/// Report of import results
struct ImportReport {
    let successCount: Int
    let failureCount: Int
    let warningCount: Int
    let errorCount: Int
    let warnings: [String]
    let errors: [String]
    let duration: TimeInterval
    let isFatal: Bool
    
    var summary: String {
        var summary = "Import Report\n"
        summary += "━━━━━━━━━━━━━━━━━━━━━\n"
        summary += "✅ Successful imports: \(successCount)\n"
        
        if failureCount > 0 {
            summary += "❌ Failed imports: \(failureCount)\n"
        }
        
        if warningCount > 0 {
            summary += "⚠️  Warnings: \(warningCount)\n"
        }
        
        if errorCount > 0 {
            summary += "🔴 Errors: \(errorCount)\n"
        }
        
        summary += String(format: "⏱️  Duration: %.1f seconds\n", duration)
        summary += "━━━━━━━━━━━━━━━━━━━━━\n"
        
        if !warnings.isEmpty {
            summary += "\n⚠️ Warnings:\n"
            for warning in warnings.prefix(5) {
                summary += "  • \(warning)\n"
            }
            if warnings.count > 5 {
                summary += "  ... and \(warnings.count - 5) more\n"
            }
        }
        
        if !errors.isEmpty {
            summary += "\n🔴 Errors:\n"
            for error in errors.prefix(5) {
                summary += "  • \(error)\n"
            }
            if errors.count > 5 {
                summary += "  ... and \(errors.count - 5) more\n"
            }
        }
        
        return summary
    }
    
    var detailedSummary: String {
        var summary = "Detailed Import Report\n"
        summary += "═════════════════════════════════\n\n"
        
        summary += "Summary\n"
        summary += "──────────────────────────────────\n"
        summary += "✅ Successful: \(successCount)\n"
        summary += "❌ Failed: \(failureCount)\n"
        summary += "⚠️  Warnings: \(warningCount)\n"
        summary += "🔴 Errors: \(errorCount)\n"
        summary += String(format: "⏱️  Duration: %.2f seconds\n", duration)
        summary += "Status: \(isFatal ? "FAILED" : "SUCCESS")\n"
        
        if !warnings.isEmpty {
            summary += "\n⚠️ Warnings (\(warnings.count))\n"
            summary += "──────────────────────────────────\n"
            for (index, warning) in warnings.enumerated() {
                summary += "\(index + 1). \(warning)\n"
            }
        }
        
        if !errors.isEmpty {
            summary += "\n🔴 Errors (\(errors.count))\n"
            summary += "──────────────────────────────────\n"
            for (index, error) in errors.enumerated() {
                summary += "\(index + 1). \(error)\n"
            }
        }
        
        summary += "\n═════════════════════════════════\n"
        return summary
    }
}

// MARK: - Import Statistics

extension ImportReport {
    
    /// Success rate as percentage
    var successRate: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 100 }
        return Double(successCount) / Double(total) * 100
    }
    
    /// Average time per successful import
    var timePerSuccess: TimeInterval {
        guard successCount > 0 else { return 0 }
        return duration / Double(successCount)
    }
    
    /// Human-readable duration string
    var durationString: String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1f seconds", duration)
        } else {
            let minutes = duration / 60
            let seconds = duration.truncatingRemainder(dividingBy: 60)
            return String(format: "%.1f min %.0f sec", minutes, seconds)
        }
    }
}
