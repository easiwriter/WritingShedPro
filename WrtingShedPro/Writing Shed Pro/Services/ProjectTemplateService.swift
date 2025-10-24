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
        
        // Create subfolders for type-specific folder
        createTypeSubfolders(in: typeFolder, project: project, modelContext: modelContext)
        
        // Explicitly save the context to ensure all relationships are persisted
        do {
            try modelContext.save()
            print("✅ Successfully created folder structure for project: \(project.name ?? "Unknown")")
            print("📁 Root folders count: \(project.folders?.count ?? 0)")
            print("📁 Type folder '\(typeFolder.name ?? "")' has \(typeFolder.folders?.count ?? 0) subfolders")
        } catch {
            print("❌ Error saving folder structure: \(error)")
        }
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
        let name = NSLocalizedString("folder.publications", comment: "Publications folder name")
        return Folder(name: name, project: project)
    }
    
    /// Creates the Trash folder
    private static func createTrashFolder(for project: Project, in modelContext: ModelContext) -> Folder {
        let name = NSLocalizedString("folder.trash", comment: "Trash folder name")
        return Folder(name: name, project: project)
    }
    
    // MARK: - Type-Specific Subfolders
    
    /// Creates all subfolders within the type-specific folder (e.g., "YOUR POETRY")
    private static func createTypeSubfolders(in parentFolder: Folder, project: Project, modelContext: ModelContext) {
        let subfolderKeys: [String]
        
        switch project.type {
        case .blank:
            subfolderKeys = ["folder.all"]
            
        case .poetry, .shortStory:
            subfolderKeys = [
                "folder.all",
                "folder.draft",
                "folder.ready",
                "folder.setAside", 
                "folder.published",
                "folder.collections",
                "folder.submissions",
                "folder.research"
            ]
            
        case .novel:
            subfolderKeys = [
                "folder.novel",
                "folder.chapters",
                "folder.scenes",
                "folder.characters",
                "folder.locations",
                "folder.setAside",
                "folder.research"
            ]
            
        case .script:
            subfolderKeys = [
                "folder.script",
                "folder.acts",
                "folder.scenes", 
                "folder.characters",
                "folder.locations",
                "folder.setAside",
                "folder.research"
            ]
        }
        
        for key in subfolderKeys {
            let name = NSLocalizedString(key, comment: "Default folder name")
            let subfolder = Folder(name: name, parentFolder: parentFolder)
            // Ensure the subfolder inherits the project reference from its parent
            subfolder.project = project
            modelContext.insert(subfolder)
        }
    }
    
    // MARK: - Publications Subfolders
    
    /// Creates all subfolders within the Publications folder
    private static func createPublicationsSubfolders(in parentFolder: Folder, project: Project, modelContext: ModelContext) {
        let subfolderKeys: [String]
        
        switch project.type {
        case .blank:
            subfolderKeys = [] // No publications for blank projects
            
        case .poetry, .shortStory:
            subfolderKeys = [
                "folder.magazines",
                "folder.competitions", 
                "folder.commissions",
                "folder.other"
            ]
            
        case .novel, .script:
            subfolderKeys = [
                "folder.competitions",
                "folder.commissions", 
                "folder.other"
            ]
        }
        
        for key in subfolderKeys {
            let name = NSLocalizedString(key, comment: "Publications folder name")
            let subfolder = Folder(name: name, parentFolder: parentFolder)
            // Ensure the subfolder inherits the project reference from its parent
            subfolder.project = project
            modelContext.insert(subfolder)
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
            return NSLocalizedString("projectFolder.blank", comment: "Blank project folder name")
        case .novel:
            return NSLocalizedString("projectFolder.yourNovel", comment: "Novel project folder name")
        case .poetry:
            return NSLocalizedString("projectFolder.yourPoetry", comment: "Poetry project folder name")
        case .script:
            return NSLocalizedString("projectFolder.yourScript", comment: "Script project folder name")
        case .shortStory:
            return NSLocalizedString("projectFolder.yourStories", comment: "Short Story project folder name")
        }
    }
}
