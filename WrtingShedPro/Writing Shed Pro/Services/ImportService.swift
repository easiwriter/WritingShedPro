//
//  ImportService.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
import SwiftData

/// High-level service for managing legacy database imports
/// Handles the complete import workflow including:
/// - Checking if import has been performed
/// - Verifying legacy database exists
/// - Executing import with progress tracking
/// - Error reporting and rollback
class ImportService {
    
    // MARK: - Properties
    
    private let legacyService = LegacyDatabaseService()
    private let errorHandler = ImportErrorHandler()
    private let progressTracker = ImportProgressTracker()
    
    private static let hasPerformedImportKey = "hasPerformedImport"
    
    // MARK: - Public API
    
    /// Check if import should be performed
    /// Returns true if:
    /// 1. hasPerformedImport == false
    /// 2. Legacy database exists at expected location
    func shouldPerformImport() -> Bool {
        let hasPerformed = UserDefaults.standard.bool(forKey: Self.hasPerformedImportKey)
        
        // Already imported
        if hasPerformed {
            print("[ImportService] Import already performed")
            return false
        }
        
        // Check if legacy database exists
        guard let databaseURL = getLegacyDatabaseURL() else {
            print("[ImportService] Legacy database URL could not be determined")
            return false
        }
        
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: databaseURL.path)
        print("[ImportService] Legacy database exists: \(exists) at \(databaseURL.path)")
        
        return exists
    }
    
    /// Execute the import process
    /// - Parameter modelContext: The SwiftData ModelContext to save imported data
    /// - Returns: True if import succeeded, false if failed
    func executeImport(modelContext: ModelContext) async -> Bool {
        print("[ImportService] Starting import...")
        
        do {
            // Connect to legacy database
            try legacyService.connect()
            print("[ImportService] Connected to legacy database")
            
            // Create import engine
            let engine = LegacyImportEngine(
                legacyService: legacyService,
                mapper: DataMapper(legacyService: legacyService, errorHandler: errorHandler),
                errorHandler: errorHandler,
                progressTracker: progressTracker
            )
            
            // Execute import
            try engine.executeImport(modelContext: modelContext)
            print("[ImportService] Import completed successfully")
            
            // Mark import as performed only if successful
            UserDefaults.standard.set(true, forKey: Self.hasPerformedImportKey)
            print("[ImportService] Set hasPerformedImport = true")
            
            return true
            
        } catch {
            print("[ImportService] Import failed: \(error.localizedDescription)")
            errorHandler.addError(error.localizedDescription)
            
            // Do NOT set hasPerformedImport flag on failure
            // User can retry on next app launch
            
            return false
        }
    }
    
    /// Get the import error report if import failed
    /// Returns nil if import succeeded or hasn't been attempted
    func getErrorReport() -> String? {
        // For now, we don't have a successCount from the import
        // This will be updated in Phase 2 when we track successful imports
        // For this version, just check if there are errors
        
        if errorHandler.isFatal {
            // Generate report with placeholder success count
            let report = errorHandler.generateReport(successCount: 0)
            return report.summary
        }
        
        return nil
    }
    
    /// Get progress tracker for UI binding
    func getProgressTracker() -> ImportProgressTracker {
        return progressTracker
    }
    
    // MARK: - Private Helpers
    
    /// Get the URL for the legacy database
    private func getLegacyDatabaseURL() -> URL? {
        // The legacy database was created by "Writing Shed" app
        // Bundle IDs for different platforms:
        // - Mac (Catalyst): www.writing-shed.comuk.Writing-Shed or com.writing-shed.osx-writing-shed
        // - iOS: www.writing-shed.comuk.Writing-Shed
        
        // Check if running on Mac (including Catalyst)
        #if targetEnvironment(macCatalyst) || os(macOS)
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        
        // On Mac, check the home directory (not sandboxed path)
        let possibleBundleIDs = [
            "com.writing-shed.osx-writing-shed",  // Original Writing Shed
            "www.writing-shed.comuk.Writing-Shed" // iOS version used on Mac
        ]
        
        for bundleID in possibleBundleIDs {
            let libraryPath = homeDir + "/Library/Application Support/\(bundleID)/writeapp.sqlite"
            if fileManager.fileExists(atPath: libraryPath) {
                print("[ImportService] Found legacy database at: \(libraryPath)")
                return URL(fileURLWithPath: libraryPath)
            }
        }
        
        // No database found - report the paths we checked
        print("[ImportService] No legacy database found in:")
        for bundleID in possibleBundleIDs {
            let libraryPath = homeDir + "/Library/Application Support/\(bundleID)/writeapp.sqlite"
            print("[ImportService]   - \(libraryPath)")
        }
        
        // Return nil - no database exists
        return nil
        
        #else
        // iOS: Use application support directory (sandboxed)
        guard let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            print("[ImportService] Could not get application support directory")
            return nil
        }
        
        let fileManager = FileManager.default
        let possibleBundleIDs = [
            "www.writing-shed.comuk.Writing-Shed",  // Original Writing Shed
        ]
        
        for bundleID in possibleBundleIDs {
            let databaseURL = supportDir
                .appendingPathComponent(bundleID, isDirectory: true)
                .appendingPathComponent("writeapp.sqlite", isDirectory: false)
            
            if fileManager.fileExists(atPath: databaseURL.path) {
                print("[ImportService] Found legacy database at: \(databaseURL.path)")
                return databaseURL
            }
        }
        
        print("[ImportService] No legacy database found in application support")
        return nil
        #endif
    }
}
