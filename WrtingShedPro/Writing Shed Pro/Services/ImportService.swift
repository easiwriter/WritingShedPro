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
    
    private static let legacyImportAllowedKey = "legacyImportAllowed"
    private static let oldHasPerformedImportKey = "hasPerformedImport" // Legacy key for migration
    
    // MARK: - Public API
    
    /// Check if import should be performed
    /// Returns true if:
    /// 1. legacyImportAllowed == true (defaults to true on first launch)
    /// 2. Legacy database exists at expected location
    func shouldPerformImport() -> Bool {
        // iOS: Skip import check entirely (database not accessible due to sandboxing)
        #if !targetEnvironment(macCatalyst) && !os(macOS)
        print("[ImportService] iOS: Import check skipped (database not accessible)")
        return false
        #else
        
        // Migrate old flag if it exists
        migrateOldImportFlag()
        
        // Default to true if key doesn't exist (first launch)
        let importAllowed = UserDefaults.standard.object(forKey: Self.legacyImportAllowedKey) as? Bool ?? true
        
        // Import not allowed (already completed)
        if !importAllowed {
            print("[ImportService] Import not allowed (already performed)")
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
        #endif
    }
    
    /// Execute the import process
    /// - Parameter modelContext: The SwiftData ModelContext to save imported data
    /// - Returns: True if import succeeded, false if failed
    func executeImport(modelContext: ModelContext) async -> Bool {
        print("[ImportService] Starting import...")
        
        do {
            // First, delete all previously imported legacy projects (for re-import)
            try deleteLegacyProjects(modelContext: modelContext)
            
            // Disconnect any existing connection to clear cached Core Data objects
            legacyService.disconnect()
            
            // Connect to legacy database with fresh context
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
            
            // Disconnect from legacy database to free resources
            legacyService.disconnect()
            
            // Disallow future imports (set to false) unless manually re-enabled
            UserDefaults.standard.set(false, forKey: Self.legacyImportAllowedKey)
            print("[ImportService] Set legacyImportAllowed = false")
            
            return true
            
        } catch {
            print("[ImportService] Import failed: \(error.localizedDescription)")
            errorHandler.addError(error.localizedDescription)
            
            // Disconnect from legacy database even on failure
            legacyService.disconnect()
            
            // Do NOT set legacyImportAllowed flag on failure
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
        print("[ImportService] getLegacyDatabaseURL called")
        // First, try auto-detection
        let autoDetected = attemptAutoDetect()
        if let url = autoDetected {
            print("[ImportService] Auto-detect found database: \(url)")
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
        // iOS: Cannot auto-detect legacy database due to app sandboxing
        // Each app runs in its own container and cannot access other apps' directories
        // Users should rely on CloudKit sync from Mac where import works automatically
        
        guard let supportDir = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            print("[ImportService] Could not get application support directory")
            return nil
        }
        
        // Check if user has manually placed database in this app's directory
        for filename in possibleFilenames {
            // Check root of Application Support
            let rootURL = supportDir.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: rootURL.path) {
                print("[ImportService] Found legacy database at: \(rootURL.path)")
                return rootURL
            }
            
            // Check Documents directory (more accessible via Files app)
            if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let docURL = documentsDir.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: docURL.path) {
                    print("[ImportService] Found legacy database in Documents: \(docURL.path)")
                    return docURL
                }
            }
        }
        
        print("[ImportService] Legacy database not found on iOS")
        print("[ImportService] Note: iOS cannot access old app's sandbox. Use CloudKit sync from Mac.")
        return nil
        #endif
    }
    
    // MARK: - Re-import Support (Development Only)
    
    /// Delete all projects marked as legacy (for re-import during development)
    /// This preserves user-created projects while allowing fresh import of legacy data
    private func deleteLegacyProjects(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate<Project> { project in
                project.statusRaw == "legacy"
            }
        )
        
        let legacyProjects = try modelContext.fetch(descriptor)
        
        guard !legacyProjects.isEmpty else {
            print("[ImportService] No legacy projects to delete")
            return
        }
        
        print("[ImportService] Deleting \(legacyProjects.count) legacy projects for re-import...")
        
        for project in legacyProjects {
            modelContext.delete(project)
        }
        
        // Save deletions before starting import
        try modelContext.save()
        print("[ImportService] Deleted \(legacyProjects.count) legacy projects successfully")
    }
    
    /// Migrate old hasPerformedImport flag to new legacyImportAllowed flag
    /// This prevents duplicate imports when upgrading from previous version
    private func migrateOldImportFlag() {
        let defaults = UserDefaults.standard
        
        // Check if we've already migrated
        if defaults.object(forKey: Self.legacyImportAllowedKey) != nil {
            return // Already using new flag, nothing to migrate
        }
        
        // Check if old flag exists
        if defaults.bool(forKey: Self.oldHasPerformedImportKey) {
            // Old app had completed import, so disallow new import
            defaults.set(false, forKey: Self.legacyImportAllowedKey)
            print("[ImportService] Migrated hasPerformedImport=true → legacyImportAllowed=false")
        }
        // If old flag doesn't exist or is false, leave new flag as default (true for first launch)
    }
    
    // MARK: - Smart Import Helpers
    
    /// Execute selective import of specific legacy projects
    /// - Parameters:
    ///   - projectsToImport: Array of legacy project data to import
    ///   - modelContext: The SwiftData ModelContext to save imported data
    /// - Returns: True if import succeeded, false if failed
    func executeSelectiveImport(projectsToImport: [LegacyProjectData], modelContext: ModelContext) async -> Bool {
        print("[ImportService] Starting selective import of \(projectsToImport.count) projects...")
        
        do {
            // Disconnect any existing connection to clear cached Core Data objects
            legacyService.disconnect()
            
            // Connect to legacy database with fresh context
            try legacyService.connect()
            print("[ImportService] Connected to legacy database")
            
            // Create import engine
            let engine = LegacyImportEngine(
                legacyService: legacyService,
                mapper: DataMapper(legacyService: legacyService, errorHandler: errorHandler),
                errorHandler: errorHandler,
                progressTracker: progressTracker
            )
            
            // Import only selected projects (using the new selective import method)
            try engine.executeSelectiveImport(projectsToImport: projectsToImport, modelContext: modelContext)
            print("[ImportService] Selective import completed successfully")
            
            // Disconnect from legacy database to free resources
            legacyService.disconnect()
            
            return true
            
        } catch {
            print("[ImportService] Selective import failed: \(error.localizedDescription)")
            errorHandler.addError(error.localizedDescription)
            
            // Disconnect from legacy database even on failure
            legacyService.disconnect()
            
            return false
        }
    }
    
    /// Check if legacy database exists (for showing import options)
    func legacyDatabaseExists() -> Bool {
        #if !targetEnvironment(macCatalyst) && !os(macOS)
        return false // iOS can't access legacy database
        #else
        
        guard let databaseURL = getLegacyDatabaseURL() else {
            return false
        }
        
        return FileManager.default.fileExists(atPath: databaseURL.path)
        #endif
    }
    
    /// Clean project name by removing timestamp data after <>
    private func cleanProjectName(_ name: String) -> String {
        if let range = name.range(of: "<>") {
            return String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return name
    }
    
    /// Get list of legacy projects that haven't been imported yet
    /// - Parameter modelContext: SwiftData context to check against existing projects
    /// - Returns: Array of legacy project data that hasn't been imported
    func getUnimportedProjects(modelContext: ModelContext) -> [LegacyProjectData] {
        guard legacyDatabaseExists() else {
            print("[ImportService] Legacy database not found")
            return []
        }
        
        do {
            // Connect to legacy database
            try legacyService.connect()
            
            // Fetch all legacy projects
            let legacyProjects = try legacyService.fetchProjects()
            
            // Fetch all existing SwiftData projects that were imported from legacy database
            let descriptor = FetchDescriptor<Project>(
                predicate: #Predicate { $0.statusRaw == "legacy" }
            )
            let importedLegacyProjects = try modelContext.fetch(descriptor)
            
            // Filter out projects that have already been imported
            // Clean names (remove <> timestamp suffix) for comparison
            let importedNames = Set(importedLegacyProjects.compactMap { project -> String? in
                guard let name = project.name else { return nil }
                return cleanProjectName(name).lowercased()
            })
            
            let unimported = legacyProjects.filter { legacy in
                let cleanName = cleanProjectName(legacy.name).lowercased()
                // Exclude projects with empty names (phantom/corrupted entries)
                let hasName = !cleanName.trimmingCharacters(in: .whitespaces).isEmpty
                return hasName && !importedNames.contains(cleanName)
            }
            
            print("[ImportService] Found \(legacyProjects.count) legacy projects, \(importedLegacyProjects.count) already imported, \(unimported.count) available for import")
            
            // Disconnect
            legacyService.disconnect()
            
            return unimported
            
        } catch {
            print("[ImportService] Error checking unimported projects: \(error)")
            legacyService.disconnect()
            return []
        }
    }
    
    /// Count displayable legacy projects (excluding "No Projects" placeholder)
    func getDisplayableProjectCount(_ projects: [LegacyProjectData]) -> Int {
        projects.filter { project in
            cleanProjectName(project.name).lowercased() != "no projects"
        }.count
    }
}

