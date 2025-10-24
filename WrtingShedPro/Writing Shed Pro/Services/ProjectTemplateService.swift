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
        // Create type-specific folder and trash folder for all projects
        let typeFolder = createTypeSpecificFolder(for: project, in: modelContext)
        let trashFolder = createTrashFolder(for: project, in: modelContext)
        
        var foldersToAdd = [typeFolder, trashFolder]
        
        // Only create Publications folder for non-blank projects
        if project.type != .blank {
            let publicationsFolder = createPublicationsFolder(for: project, in: modelContext)
            foldersToAdd.append(publicationsFolder)
            modelContext.insert(publicationsFolder)
            // Create subfolders for publications folder
            createPublicationsSubfolders(in: publicationsFolder, project: project, modelContext: modelContext)
        }
        
        // Insert folders into context
        modelContext.insert(typeFolder)
        modelContext.insert(trashFolder)
        
        // Explicitly add folders to project's folders array
        if project.folders == nil {
            project.folders = []
        }
        project.folders?.append(contentsOf: foldersToAdd)
        
        // Create subfolders for type-specific folder
        createTypeSubfolders(in: typeFolder, project: project, modelContext: modelContext)
    }
    
    // MARK: - Top-Level Folders
    
    /// Creates the type-specific root folder (Your Poetry/Your Prose/Your Drama)
    private static func createTypeSpecificFolder(for project: Project, in modelContext: ModelContext) -> Folder {
        let typeName = (project.type ?? ProjectType.blank).typeFolderName
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
    
    /// Creates all subfolders within the type-specific folder (e.g., "YOUR POETRY")
    private static func createTypeSubfolders(in parentFolder: Folder, project: Project, modelContext: ModelContext) {
        let subfolderNames: [String]
        
        switch project.type {
        case .blank:
            subfolderNames = ["All"]
            
        case .poetry, .shortStory:
            subfolderNames = [
                "All",
                "Draft",
                "Ready",
                "Set Aside", 
                "Published",
                "Collections",
                "Submissions",
                "Research"
            ]
            
        case .novel:
            subfolderNames = [
                "Novel",
                "Chapters",
                "Scenes",
                "Characters",
                "Locations",
                "Set Aside",
                "Research"
            ]
            
        case .script:
            subfolderNames = [
                "Script",
                "Acts",
                "Scenes", 
                "Characters",
                "Locations",
                "Set Aside",
                "Published",
                "Submissions",
                "Research"
            ]
        }
        
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
        let subfolderNames: [String]
        
        switch project.type {
        case .blank:
            subfolderNames = [] // No publications for blank projects
            
        case .poetry, .shortStory:
            subfolderNames = [
                "Magazines",
                "Competitions", 
                "Commissions",
                "Other"
            ]
            
        case .novel, .script:
            subfolderNames = [
                "Competitions",
                "Commissions", 
                "Other"
            ]
        }
        
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
    /// Returns the localized display name for this project type
    var localizedName: String {
        switch self {
        case .blank:
            return NSLocalizedString("projectType.blank", comment: "Blank project type")
        case .novel:
            return NSLocalizedString("projectType.novel", comment: "Novel project type")
        case .poetry:
            return NSLocalizedString("projectType.poetry", comment: "Poetry project type")
        case .script:
            return NSLocalizedString("projectType.script", comment: "Script project type")
        case .shortStory:
            return NSLocalizedString("projectType.shortStory", comment: "Short Story project type")
        }
    }
    
    /// Returns the localized folder name for this project type
    var typeFolderName: String {
        switch self {
        case .blank:
            return "BLANK"
        case .novel:
            return "YOUR NOVEL"
        case .poetry:
            return "YOUR POETRY"
        case .script:
            return "YOUR SCRIPT"
        case .shortStory:
            return "YOUR STORIES"
        }
    }
}
