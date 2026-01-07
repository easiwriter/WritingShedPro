import Foundation
import SwiftData

/// Service responsible for generating default folder templates when a project is created.
/// Creates a type-specific folder structure based on the project type (Poetry, Fiction, Drama).
///
/// Updated architecture: Workflow status (Draft, Ready, etc.) is now a property on TextFile,
/// not separate folders. Content folders are: Poems (Poetry), Scenes (Fiction), Scripts (Drama).
struct ProjectTemplateService {
    
    // MARK: - Public Interface
    
    /// Creates the complete default folder structure for a project.
    /// Folders are created with userOrder to ensure consistent display ordering.
    /// - Parameters:
    ///   - project: The project to create folders for
    ///   - modelContext: The SwiftData model context for persistence
    static func createDefaultFolders(for project: Project, in modelContext: ModelContext) {
        // Get all folder keys in the correct order for this project type
        let orderedFolderKeys = getOrderedFolderKeys(for: project)
        
        // Create folders with sequential userOrder
        for (index, key) in orderedFolderKeys.enumerated() {
            let name = NSLocalizedString(key, comment: "Folder name")
            let folder = Folder(name: name, project: project, userOrder: index)
            modelContext.insert(folder)
        }
        
        // Explicitly save the context to ensure all relationships are persisted
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Successfully created folder structure for project: \(project.name ?? "Unknown")")
            print("📁 Total folders created: \(orderedFolderKeys.count)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error saving folder structure: \(error)")
            #endif
        }
    }
    
    // MARK: - Folder Order Configuration
    
    /// Returns all folder keys in the correct display order for a project type
    /// Note: Workflow status (Draft, Ready, Submitted, Set Aside, Published) is now
    /// a property on TextFile, not separate folders.
    private static func getOrderedFolderKeys(for project: Project) -> [String] {
        switch project.type {
        case .generalPurpose:
            return [
                "folder.folders",
                "folder.trash"
            ]
            
        case .poetry:
            // Poetry: Content → Collections → Submissions → Manuscript → Research → Publications → Trash
            return [
                // Content folder (replaces Draft/Ready/etc)
                "folder.poems",
                "folder.collections",
                "folder.submissions",
                "folder.manuscript",
                // Support
                "folder.research",
                // Publications
                "folder.magazines",
                "folder.competitions",
                "folder.commissions",
                "folder.other",
                // System
                "folder.trash"
            ]
            
        case .fiction:
            // Fiction: Content + Entity → Collections → Submissions → Research → Publications → Trash
            var keys = [
                // Content folder (replaces Draft/Ready/etc)
                "folder.scenes",
                // Entity folders
                "folder.characters",
                "folder.locations",
                "folder.chapters",
                "folder.plot",
                "folder.manuscript",
                // Collections and Submissions
                "folder.collections",
                "folder.submissions",
                // Support
                "folder.research"
            ]
            
            // Publications based on fiction class
            if project.fictionClass == .novel {
                // Novel: Publishers, Agents, Other
                keys.append(contentsOf: [
                    "folder.publishers",
                    "folder.agents",
                    "folder.other"
                ])
            } else {
                // Short Fiction: Magazines, Competitions, Agents, Publishers, Other
                keys.append(contentsOf: [
                    "folder.magazines",
                    "folder.competitions",
                    "folder.agents",
                    "folder.publishers",
                    "folder.other"
                ])
            }
            
            // System
            keys.append("folder.trash")
            return keys
            
        case .drama:
            // Drama: Content → Collections → Submissions → Research → Publications → Trash
            return [
                // Content folder (replaces Draft/Ready/etc)
                "folder.scripts",
                // Collections and Submissions
                "folder.collections",
                "folder.submissions",
                // Support
                "folder.research",
                // Publications
                "folder.competitions",
                "folder.commissions",
                "folder.other",
                // System
                "folder.trash"
            ]
        }
    }
}

// MARK: - ProjectType Extension

extension ProjectType {
    /// Returns the localized display name for this project type
    var localizedName: String {
        switch self {
        case .generalPurpose:
            return NSLocalizedString("projectType.generalPurpose", comment: "General Purpose project type")
        case .poetry:
            return NSLocalizedString("projectType.poetry", comment: "Poetry project type")
        case .fiction:
            return NSLocalizedString("projectType.fiction", comment: "Fiction project type")
        case .drama:
            return NSLocalizedString("projectType.drama", comment: "Drama project type")
        }
    }
}
