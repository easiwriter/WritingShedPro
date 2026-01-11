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

            // Check which subfolders already exist
            let existingSubfolders = manuscriptFolder.folders ?? []
            let requiredNames: Set<String> = ["Front Matter", "Body", "Back Matter"]
            let existingNames = Set(existingSubfolders.compactMap { $0.name })
            let missingNames = requiredNames.subtracting(existingNames)

            if missingNames.isEmpty {
                #if DEBUG
                print("  ↳ Skipping \(project.name ?? "Untitled") - all manuscript subfolders exist")
                #endif
                continue
            }

            // Add only missing subfolders
            for (index, name) in missingNames.enumerated() {
                let subfolder = Folder(name: name, project: project)
                subfolder.parentFolder = manuscriptFolder
                subfolder.userOrder = index
                manuscriptFolder.folders?.append(subfolder)
                context.insert(subfolder)
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
