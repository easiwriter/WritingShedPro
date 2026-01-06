//
//  ProjectFolderMigrationService.swift
//  Writing Shed Pro
//
//  Created by AI Assistant on 2026-01-05.
//  Handles migration of folder structures for existing projects when new folders are added.
//

import Foundation
import SwiftData

/// Service responsible for adding missing folders to existing projects when folder structure changes.
/// Uses versioned migration to track which updates have been applied.
struct ProjectFolderMigrationService {
    
    // MARK: - Migration Version
    
    private static let migrationVersionKey = "projectFolderMigrationVersion"
    private static let currentMigrationVersion = 2  // Version 2: Fix folder ordering for all projects
    
    // MARK: - Public Methods
    
    /// Check if folder migration is needed and perform it for all projects
    /// Call this on app launch after ModelContainer is ready
    /// - Parameter modelContext: The SwiftData context to use
    static func migrateIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        
        #if DEBUG
        print("[ProjectFolderMigration] Checking migration: lastVersion=\(lastVersion), currentVersion=\(currentMigrationVersion)")
        #endif
        
        if lastVersion < currentMigrationVersion {
            performMigration(from: lastVersion, to: currentMigrationVersion, modelContext: modelContext)
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
            
            #if DEBUG
            print("[ProjectFolderMigration] Migration complete, updated to version \(currentMigrationVersion)")
            #endif
        } else {
            #if DEBUG
            print("[ProjectFolderMigration] No migration needed")
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private static func performMigration(from oldVersion: Int, to newVersion: Int, modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] Performing migration from version \(oldVersion) to \(newVersion)")
        #endif
        
        // Version 1: Add Manuscript folder to existing Poetry projects
        if oldVersion < 1 {
            addManuscriptFolderToPoetryProjects(modelContext: modelContext)
        }
        
        // Version 2: Fix folder ordering for all projects
        if oldVersion < 2 {
            fixFolderOrderingForAllProjects(modelContext: modelContext)
        }
        
        // Future migrations go here:
        // if oldVersion < 3 { ... }
        
        do {
            try modelContext.save()
            #if DEBUG
            print("[ProjectFolderMigration] ✅ Migration saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to save migration: \(error)")
            #endif
        }
    }
    
    /// Version 1 Migration: Add Manuscript folder to existing Poetry projects that don't have one
    private static func addManuscriptFolderToPoetryProjects(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V1: Adding Manuscript folder to Poetry projects...")
        #endif
        
        // Fetch all Poetry projects
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.typeRaw == "poetry" }
        )
        
        do {
            let poetryProjects = try modelContext.fetch(descriptor)
            
            #if DEBUG
            print("[ProjectFolderMigration] Found \(poetryProjects.count) Poetry projects to check")
            #endif
            
            let manuscriptName = NSLocalizedString("folder.manuscript", comment: "Manuscript folder name")
            
            for project in poetryProjects {
                // Check if Manuscript folder already exists
                let hasManuscript = project.folders?.contains { $0.name == manuscriptName } ?? false
                
                if !hasManuscript {
                    // Create Manuscript folder
                    let manuscriptFolder = Folder(name: manuscriptName, project: project)
                    modelContext.insert(manuscriptFolder)
                    
                    #if DEBUG
                    print("[ProjectFolderMigration] Added Manuscript folder to project: \(project.name ?? "Untitled")")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to fetch Poetry projects: \(error)")
            #endif
        }
    }
    
    /// Version 2 Migration: Fix folder ordering for all existing projects
    private static func fixFolderOrderingForAllProjects(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V2: Fixing folder ordering for all projects...")
        #endif
        
        let descriptor = FetchDescriptor<Project>()
        
        do {
            let allProjects = try modelContext.fetch(descriptor)
            
            #if DEBUG
            print("[ProjectFolderMigration] Found \(allProjects.count) projects to fix folder ordering")
            #endif
            
            for project in allProjects {
                fixFolderOrdering(for: project)
            }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to fetch projects: \(error)")
            #endif
        }
    }
    
    /// Fix folder ordering for a single project based on the expected order
    private static func fixFolderOrdering(for project: Project) {
        guard let folders = project.folders else { return }
        
        // Get the expected folder order for this project type
        let expectedOrder = getExpectedFolderOrder(for: project)
        
        // Create a lookup of folder name to expected order index
        var orderLookup: [String: Int] = [:]
        for (index, key) in expectedOrder.enumerated() {
            let name = NSLocalizedString(key, comment: "Folder name")
            orderLookup[name] = index
        }
        
        // Assign userOrder to each folder based on expected order
        for folder in folders where folder.parentFolder == nil {  // Only top-level folders
            if let name = folder.name, let expectedIndex = orderLookup[name] {
                folder.userOrder = expectedIndex
            } else {
                // Unknown folder - put at end
                folder.userOrder = expectedOrder.count + 100
            }
        }
        
        #if DEBUG
        print("[ProjectFolderMigration] Fixed folder ordering for project: \(project.name ?? "Untitled")")
        #endif
    }
    
    /// Returns the expected folder order keys for a project type
    private static func getExpectedFolderOrder(for project: Project) -> [String] {
        switch project.type {
        case .generalPurpose:
            return ["folder.folders", "folder.trash"]
            
        case .poetry:
            return [
                "folder.all", "folder.draft", "folder.ready", "folder.submissions",
                "folder.setAside", "folder.published", "folder.collections", "folder.manuscript",
                "folder.research",
                "folder.magazines", "folder.competitions", "folder.commissions", "folder.other",
                "folder.trash"
            ]
            
        case .fiction:
            var keys = [
                "folder.all", "folder.draft", "folder.ready", "folder.submissions", "folder.setAside",
                "folder.characters", "folder.locations", "folder.chapters", "folder.plot",
                "folder.research"
            ]
            if project.fictionClass == .novel {
                keys.append(contentsOf: ["folder.publishers", "folder.agents", "folder.other"])
            } else {
                keys.append(contentsOf: ["folder.magazines", "folder.competitions", "folder.agents", "folder.publishers", "folder.other"])
            }
            keys.append("folder.trash")
            return keys
            
        case .drama:
            return [
                "folder.all", "folder.draft", "folder.ready", "folder.setAside",
                "folder.research",
                "folder.competitions", "folder.commissions", "folder.other",
                "folder.trash"
            ]
        }
    }
    
    /// Utility: Add a folder to a project if it doesn't already exist
    /// - Parameters:
    ///   - folderKey: The localization key for the folder name (e.g., "folder.manuscript")
    ///   - project: The project to add the folder to
    ///   - modelContext: The SwiftData context
    /// - Returns: True if folder was added, false if it already existed
    @discardableResult
    static func addFolderIfMissing(folderKey: String, to project: Project, modelContext: ModelContext) -> Bool {
        let folderName = NSLocalizedString(folderKey, comment: "Folder name")
        
        let exists = project.folders?.contains { $0.name == folderName } ?? false
        
        if !exists {
            let folder = Folder(name: folderName, project: project)
            modelContext.insert(folder)
            return true
        }
        
        return false
    }
}
