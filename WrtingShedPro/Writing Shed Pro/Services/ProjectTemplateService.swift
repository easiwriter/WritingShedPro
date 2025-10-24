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
        // Create three top-level folders (they add themselves to project.folders in their init)
        let typeFolder = createTypeSpecificFolder(for: project, in: modelContext)
        let publicationsFolder = createPublicationsFolder(for: project, in: modelContext)
        let trashFolder = createTrashFolder(for: project, in: modelContext)
        
        // Insert all top-level folders into context
        modelContext.insert(typeFolder)
        modelContext.insert(publicationsFolder)
        modelContext.insert(trashFolder)
        
        // Create subfolders for type-specific folder
        createTypeSubfolders(in: typeFolder, project: project, modelContext: modelContext)
        
        // Create subfolders for publications folder
        createPublicationsSubfolders(in: publicationsFolder, project: project, modelContext: modelContext)
    }
    
    // MARK: - Top-Level Folders
    
    /// Creates the type-specific root folder (Your Poetry/Your Prose/Your Drama)
    private static func createTypeSpecificFolder(for project: Project, in modelContext: ModelContext) -> Folder {
        let typeName = (project.type ?? ProjectType.prose).typeFolderName
        let folder = Folder(name: typeName, project: project, parentFolder: nil)
        return folder
    }
    
    /// Creates the Publications folder
    private static func createPublicationsFolder(for project: Project, in modelContext: ModelContext) -> Folder {
        return Folder(name: "Publications", project: project)
    }
    
    /// Creates the Trash folder
    private static func createTrashFolder(for project: Project, in modelContext: ModelContext) -> Folder {
        return Folder(name: "Trash", project: project)
    }
    
    // MARK: - Type-Specific Subfolders
    
    /// Creates all subfolders within the type-specific folder (e.g., "Your Poetry")
    private static func createTypeSubfolders(in parentFolder: Folder, project: Project, modelContext: ModelContext) {
        let subfolderNames = [
            "All",
            "Draft",
            "Ready",
            "Set Aside",
            "Published",
            "Collections",
            "Submissions",
            "Research"
        ]
        
        for name in subfolderNames {
            let subfolder = Folder(name: name, parentFolder: parentFolder)
            modelContext.insert(subfolder)
            if parentFolder.folders == nil {
                parentFolder.folders = []
            }
            parentFolder.folders?.append(subfolder)
        }
    }
    
    // MARK: - Publications Subfolders
    
    /// Creates all subfolders within the Publications folder
    private static func createPublicationsSubfolders(in parentFolder: Folder, project: Project, modelContext: ModelContext) {
        let subfolderNames = [
            "Magazines",
            "Competitions",
            "Commissions",
            "Other"
        ]
        
        for name in subfolderNames {
            let subfolder = Folder(name: name, parentFolder: parentFolder)
            modelContext.insert(subfolder)
            if parentFolder.folders == nil {
                parentFolder.folders = []
            }
            parentFolder.folders?.append(subfolder)
        }
    }
}

// MARK: - ProjectType Extension

extension ProjectType {
    /// Returns the localized folder name for this project type
    var typeFolderName: String {
        switch self {
        case .poetry:
            return "Your Poetry"
        case .prose:
            return "Your Prose"
        case .drama:
            return "Your Drama"
        }
    }
}
