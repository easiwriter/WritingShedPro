import Foundation
import SwiftData

/// Service for migrating existing data to support new features
/// Run once at app startup to update existing projects
class MigrationService {
    
    
    /// Run all pending migrations
    /// - Parameter context: The model context to use for migrations
    static func runMigrations(context: ModelContext) {
        migrateManuscriptSubfolders(context: context)
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
                let subfolder = Folder(name: name, project: project)
                subfolder.parentFolder = manuscriptFolder
                subfolder.userOrder = order
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
