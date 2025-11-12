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
    /// If not found, prompt user to select it manually
    private func getLegacyDatabaseURL() -> URL? {
        // First, try auto-detection
        let autoDetected = attemptAutoDetect()
        if let url = autoDetected {
            return url
        }
        
        // Auto-detection failed - try showing file picker
        // Note: This is async, so we'll return nil here and handle the picker in the UI
        print("[ImportService] Auto-detection failed, user will need to select database manually")
        return nil
    }
    
    /// Attempt to auto-detect the legacy database location
    private func attemptAutoDetect() -> URL? {
        // The legacy Writing Shed app on macOS uses bundle ID: com.writing-shed.osx-writing-shed
        // Filename: Writing-Shed.sqlite
        // Note: May be in sandbox container (App Store) or regular Application Support
        
        let possibleFilenames = ["Writing-Shed.sqlite"]
        let legacyBundleIDs = [
            "com.writing-shed.osx-writing-shed",  // Official macOS Writing Shed
            "com.appworks.WriteBang"               // Developer's test build
        ]
        let fileManager = FileManager.default
        
        #if targetEnvironment(macCatalyst) || os(macOS)
        // For Mac: Check both sandboxed and non-sandboxed locations
        let userName = NSUserName()
        
        // Try all combinations: sandboxed first, then non-sandboxed
        for bundleID in legacyBundleIDs {
            for filename in possibleFilenames {
                // Check sandboxed location first (App Store apps)
                let sandboxedPath = "/Users/\(userName)/Library/Containers/\(bundleID)/Data/Library/Application Support/\(bundleID)/\(filename)"
                if fileManager.fileExists(atPath: sandboxedPath) {
                    print("[ImportService] Found legacy database at (sandboxed): \(sandboxedPath)")
                    return URL(fileURLWithPath: sandboxedPath)
                }
                
                // Check non-sandboxed location
                let normalPath = "/Users/\(userName)/Library/Application Support/\(bundleID)/\(filename)"
                if fileManager.fileExists(atPath: normalPath) {
                    print("[ImportService] Found legacy database at: \(normalPath)")
                    return URL(fileURLWithPath: normalPath)
                }
            }
        }
        
        // Log what we looked for
        print("[ImportService] Legacy database not found. Checked paths:")
        for bundleID in legacyBundleIDs {
            for filename in possibleFilenames {
                print("[ImportService]   - /Users/\(userName)/Library/Containers/\(bundleID)/Data/Library/Application Support/\(bundleID)/\(filename)")
                print("[ImportService]   - /Users/\(userName)/Library/Application Support/\(bundleID)/\(filename)")
            }
        }
        return nil
        
        #else
        // iOS: Use application support directory (sandboxed)
        guard let supportDir = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            print("[ImportService] Could not get application support directory")
            return nil
        }
        
        // iOS bundle ID: www.writing-shed.comuk.Writing-Shed
        let iosBundleID = "www.writing-shed.comuk.Writing-Shed"
        
        for filename in possibleFilenames {
            let databaseURL = supportDir
                .appendingPathComponent(iosBundleID, isDirectory: true)
                .appendingPathComponent(filename, isDirectory: false)
            
            if fileManager.fileExists(atPath: databaseURL.path) {
                print("[ImportService] Found legacy database at: \(databaseURL.path)")
                return databaseURL
            }
        }
        
        print("[ImportService] Legacy database not found in iOS sandbox at:")
        for filename in possibleFilenames {
            let databaseURL = supportDir
                .appendingPathComponent(iosBundleID, isDirectory: true)
                .appendingPathComponent(filename, isDirectory: false)
            print("[ImportService]   - \(databaseURL.path)")
        }
        return nil
        #endif
    }
    
    /// TEMPORARY: Reset import state and delete all projects for re-import testing
    func resetForReimport(modelContext: ModelContext) throws {
        print("[ImportService] Resetting import state...")
        
        // Delete all projects (cascade delete will handle related entities)
        let descriptor = FetchDescriptor<Project>()
        let allProjects = try modelContext.fetch(descriptor)
        print("[ImportService] Found \(allProjects.count) projects to delete")
        
        for project in allProjects {
            modelContext.delete(project)
        }
        
        // Save deletions immediately with error handling
        do {
            try modelContext.save()
            print("[ImportService] Deleted \(allProjects.count) projects successfully")
        } catch {
            print("[ImportService] Error saving deletions: \(error)")
            throw error
        }
        
        // Reset import flag
        UserDefaults.standard.set(false, forKey: Self.hasPerformedImportKey)
        print("[ImportService] Reset hasPerformedImport = false")
    }
}
