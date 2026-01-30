import Foundation
import SwiftData

/// Service for migrating existing data to support new features
/// Run once at app startup to update existing projects
class MigrationService {
    
    
    /// Run all pending migrations
    /// - Parameter context: The model context to use for migrations
    static func runMigrations(context: ModelContext) {
        cleanupOrphanedFolders(context: context)
        migrateManuscriptSubfolders(context: context)
    }
    
    /// CRITICAL: Run this BEFORE any views load to prevent crashes from invalidated folder objects
    /// Called from Write_App immediately after ModelContainer creation
    static func cleanupOrphanedFoldersEarly(context: ModelContext) {
        #if DEBUG
        print("🧹 [MigrationService] Early cleanup: Checking for orphaned folder references...")
        #endif
        
        // Fetch all folders directly - this uses the database, not relationships
        let descriptor = FetchDescriptor<Folder>()
        guard let allFolders = try? context.fetch(descriptor) else {
            #if DEBUG
            print("❌ [MigrationService] Failed to fetch folders for cleanup")
            #endif
            return
        }
        
        #if DEBUG
        print("🧹 [MigrationService] Found \(allFolders.count) total folders in database")
        #endif
        
        var cleanedCount = 0
        // DISABLED: Don't delete orphaned folders - they may be waiting for CloudKit relationship sync
        // var deletedCount = 0
        
        for folder in allFolders {
            // Check if folder has both project AND parentFolder set (should only have one)
            if folder.project != nil && folder.parentFolder != nil {
                #if DEBUG
                print("🔧 Fixing folder '\(folder.name ?? "unnamed")' - removing project reference (is a subfolder)")
                #endif
                folder.project = nil
                cleanedCount += 1
            }
            
            // DISABLED: This was deleting folders before CloudKit synced their relationships!
            // With CloudKit, a folder entity might sync before its project relationship,
            // causing it to appear "orphaned" when it's actually just waiting for sync.
            // if folder.project == nil && folder.parentFolder == nil {
            //     #if DEBUG
            //     print("🗑️ Deleting orphaned folder '\(folder.name ?? "unnamed")'")
            //     #endif
            //     context.delete(folder)
            //     deletedCount += 1
            // }
            
            #if DEBUG
            // Log folder relationship status for debugging
            if folder.project == nil && folder.parentFolder == nil {
                print("⚠️ [MigrationService] Folder '\(folder.name ?? "unnamed")' has no project or parent (possible CloudKit sync delay)")
            }
            #endif
        }
        
        if cleanedCount > 0 {
            try? context.save()
            #if DEBUG
            print("✅ [MigrationService] Early cleanup: Fixed \(cleanedCount) folders with dual relationships")
            #endif
        } else {
            #if DEBUG
            print("✅ [MigrationService] Early cleanup: No orphaned folders found")
            #endif
        }
    }
    
    /// Clean up folders with invalidated/orphaned relationships
    /// This fixes crashes caused by accessing deleted folder objects
    private static func cleanupOrphanedFolders(context: ModelContext) {
        // Just call the early cleanup - it's the same logic
        cleanupOrphanedFoldersEarly(context: context)
    }
    
    /// Feature 029: Add Front Matter, Body, Back Matter subfolders to existing Manuscript folders
    /// - Parameter context: The model context
    private static func migrateManuscriptSubfolders(context: ModelContext) {
        #if DEBUG
        print("🔄 [MigrationService] Starting manuscript subfolders migration...")
        #endif

        // Fetch all projects
        let descriptor = FetchDescriptor<Project>()
        guard let projects = try? context.fetch(descriptor) else {
            #if DEBUG
            print("❌ [MigrationService] Failed to fetch projects")
            #endif
            return
        }

        var migratedCount = 0

        for project in projects {
            // Find Manuscript folder
            guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }) else {
                continue
            }

            // Determine the correct body folder name for this project type
            // Uses "All" prefix to distinguish from root-level content folders
            let bodyFolderName: String
            switch project.type {
            case .drama:
                bodyFolderName = "All Acts"
            case .poetry:
                bodyFolderName = "All Poems"
            case .prose:
                bodyFolderName = "All Sections"
            case .fiction:
                // Use fictionClass to determine folder name
                bodyFolderName = project.fictionClass == .shortFiction ? "All Stories" : "All Chapters"
            }

            // Check which subfolders already exist
            let existingSubfolders = manuscriptFolder.folders ?? []
            let requiredNames: Set<String> = ["Front Matter", bodyFolderName, "Back Matter"]
            let existingNames = Set(existingSubfolders.compactMap { $0.name })
            let missingNames = requiredNames.subtracting(existingNames)
            
            // Delete any "Body" folder if it exists (we now use project-type-specific names with "All" prefix)
            // Also delete any wrong body type folders (old names without "All" prefix)
            let oldBodyFolderNames: Set<String> = ["Body", "Acts", "Poems", "Sections", "Chapters", "Stories"]
            let allBodyFolderNames: Set<String> = ["All Acts", "All Poems", "All Sections", "All Chapters", "All Stories"]
            let wrongBodyFolders = existingSubfolders.filter { folder in
                guard let name = folder.name else { return false }
                // Delete if it's an old body folder name OR wrong "All X" name for this project
                if oldBodyFolderNames.contains(name) { return true }
                return allBodyFolderNames.contains(name) && name != bodyFolderName
            }
            
            for folder in wrongBodyFolders {
                #if DEBUG
                print("  ↳ Deleting wrong body folder '\(folder.name ?? "")' from \(project.name ?? "Untitled")")
                #endif
                context.delete(folder)
            }

            if missingNames.isEmpty && wrongBodyFolders.isEmpty {
                #if DEBUG
                print("  ↳ Skipping \(project.name ?? "Untitled") - all manuscript subfolders exist")
                #endif
                continue
            }
            
            // If we deleted folders but nothing is missing, still count as migrated
            if missingNames.isEmpty && !wrongBodyFolders.isEmpty {
                migratedCount += 1
                continue
            }

            // Define correct order: Front Matter = 0, Body = 1, Back Matter = 2
            let orderedSubfolders: [(name: String, order: Int)] = [
                ("Front Matter", 0),
                (bodyFolderName, 1),
                ("Back Matter", 2)
            ]
            
            // Add only missing subfolders with correct userOrder
            for (name, order) in orderedSubfolders where missingNames.contains(name) {
                // Subfolders should NOT have project set - they get linked via parentFolder only
                let subfolder = Folder(name: name, project: nil)
                subfolder.parentFolder = manuscriptFolder
                subfolder.userOrder = order
                if manuscriptFolder.folders == nil {
                    manuscriptFolder.folders = []
                }
                manuscriptFolder.folders?.append(subfolder)
                context.insert(subfolder)
            }
            
            // Also fix userOrder on existing subfolders to ensure correct order
            for subfolder in existingSubfolders {
                if subfolder.name == "Front Matter" {
                    subfolder.userOrder = 0
                } else if subfolder.name == bodyFolderName {
                    subfolder.userOrder = 1
                } else if subfolder.name == "Back Matter" {
                    subfolder.userOrder = 2
                }
            }
            
            migratedCount += 1
            #if DEBUG
            print("  ↳ Added missing manuscript subfolders to \(project.name ?? "Untitled"): \(missingNames.sorted().joined(separator: ", "))")
            #endif
        }

        #if DEBUG
        print("✅ [MigrationService] Manuscript subfolders migration complete. Migrated \(migratedCount) projects.")
        #endif
    }
        
    // (Migration flag code removed; migration is now always idempotent and project-aware)
}
