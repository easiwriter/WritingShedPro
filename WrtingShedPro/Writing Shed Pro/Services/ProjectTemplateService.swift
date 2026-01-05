import Foundation
import SwiftData

/// Service responsible for generating default folder templates when a project is created.
/// Creates a type-specific folder structure based on the project type (Poetry, Prose, Drama).
struct ProjectTemplateService {
    
    // MARK: - Public Interface
    
    /// Creates the complete default folder structure for a project.
    /// - Parameters:
    ///   - project: The project to create folders for
    ///   - modelContext: The SwiftData model context for persistence
    static func createDefaultFolders(for project: Project, in modelContext: ModelContext) {
        var foldersToAdd: [Folder] = []
        
        // Create all folders as direct children of the project (flat structure)
        
        // 1. Create type-specific folders
        let typeFolders = createTypeFolders(for: project, in: modelContext)
        foldersToAdd.append(contentsOf: typeFolders)
        
        // 2. Create Publications folders (only for non-generalPurpose projects)
        if project.type != .generalPurpose {
            let publicationsFolders = createPublicationsFolders(for: project, in: modelContext)
            foldersToAdd.append(contentsOf: publicationsFolders)
        }
        
        // 3. Create Trash folder
        let trashFolder = createTrashFolder(for: project, in: modelContext)
        foldersToAdd.append(trashFolder)
        
        // Insert all folders into context
        for folder in foldersToAdd {
            modelContext.insert(folder)
        }
        
        // Explicitly save the context to ensure all relationships are persisted
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Successfully created folder structure for project: \(project.name ?? "Unknown")")
            #endif
            #if DEBUG
            print("📁 Total folders created: \(foldersToAdd.count)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error saving folder structure: \(error)")
            #endif
        }
    }
    
    // MARK: - Folder Creation Methods
    
    /// Creates all type-specific folders for a project (flat structure)
    private static func createTypeFolders(for project: Project, in modelContext: ModelContext) -> [Folder] {
        let folderKeys: [String]
        
        switch project.type {
        case .generalPurpose:
            folderKeys = ["folder.folders"]
            
        case .poetry:
            folderKeys = [
                "folder.all",
                "folder.draft",
                "folder.ready",
                "folder.collections",
                "folder.submissions",
                "folder.setAside", 
                "folder.published",
                "folder.research"
            ]
            
        case .fiction:
            // Fiction folder structure based on fiction class (Novel vs Short Fiction)
            let baseFolders = [
                "folder.manuscript",
                "folder.characters",
                "folder.locations",
                "folder.plot",
                "folder.research"
            ]
            
            // Add structure folder based on fiction class
            if project.fictionClass == .novel {
                // Novel uses chapters containing scenes
                folderKeys = ["folder.chapters"] + baseFolders
            } else {
                // Short Fiction uses scenes directly (no chapters)
                folderKeys = ["folder.scenes"] + baseFolders
            }
            
        case .drama:
            // Drama folder structure - to be defined in spec 023
            folderKeys = [
                "folder.all",
                "folder.draft",
                "folder.ready",
                "folder.setAside",
                "folder.research"
            ]
        }
        
        return folderKeys.map { key in
            let name = NSLocalizedString(key, comment: "Default folder name")
            return Folder(name: name, project: project)
        }
    }
    
    /// Creates all publications-related folders for a project (flat structure)
    private static func createPublicationsFolders(for project: Project, in modelContext: ModelContext) -> [Folder] {
        let folderKeys: [String]
        
        switch project.type {
        case .generalPurpose:
            folderKeys = [] // No publications for general purpose projects
            
        case .poetry:
            folderKeys = [
                "folder.magazines",
                "folder.competitions", 
                "folder.commissions",
                "folder.other"
            ]
            
        case .fiction, .drama:
            // Publications structure - to be defined in specs 022/023
            folderKeys = [
                "folder.competitions",
                "folder.commissions", 
                "folder.other"
            ]
        }
        
        return folderKeys.map { key in
            let name = NSLocalizedString(key, comment: "Publications folder name")
            return Folder(name: name, project: project)
        }
    }
    
    /// Creates the Trash folder
    private static func createTrashFolder(for project: Project, in modelContext: ModelContext) -> Folder {
        let name = NSLocalizedString("folder.trash", comment: "Trash folder name")
        return Folder(name: name, project: project)
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
