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
            
            // Create Manuscript subfolders (Feature 029)
            if key == "folder.manuscript" {
                createManuscriptSubfolders(in: folder, context: modelContext)
            }
        }
        
        Task { @MainActor in
            WriteCoalescer.shared?.requestSave(reason: "project-template-default-folders")
            WriteCoalescer.shared?.flush()
        }
        #if DEBUG
        print("✅ Created folder structure for project: \(project.name ?? "Unknown")")
        print("📁 Total folders created: \(orderedFolderKeys.count)")
        #endif
    }
    
    // MARK: - Manuscript Subfolders (Feature 029)
    
    /// Creates the standard subfolders within the Manuscript folder.
    /// The Body folder is named according to project type:
    /// - Drama: Acts
    /// - Poetry: Poems
    /// - Prose: Sections
    /// - Fiction (Novel): Chapters
    /// - Fiction (Short Fiction): Stories
    /// - Parameters:
    ///   - manuscriptFolder: The parent Manuscript folder
    ///   - context: SwiftData model context for persistence
    static func createManuscriptSubfolders(in manuscriptFolder: Folder, context: ModelContext) {
        guard manuscriptFolder.project != nil else { return }
        
        // Check if subfolders already exist (avoid creating duplicates)
        let existingSubfolders = manuscriptFolder.folders ?? []
        if !existingSubfolders.isEmpty {
            #if DEBUG
            print("📁 Manuscript subfolders already exist, skipping creation")
            #endif
            return
        }
        
        // Determine the body folder name based on project type
        let bodyFolderName = "Body Matter"
        
        let subfolderNames = [
            NSLocalizedString("folder.frontMatter", comment: "Front Matter"),
            bodyFolderName,
            NSLocalizedString("folder.backMatter", comment: "Back Matter")
        ]
        
        for (index, name) in subfolderNames.enumerated() {
            // Subfolders should NOT have project set - they get linked via parentFolder only
            let subfolder = Folder(
                name: name,
                project: nil,
                userOrder: index
            )
            subfolder.parentFolder = manuscriptFolder
            if manuscriptFolder.folders == nil {
                manuscriptFolder.folders = []
            }
            manuscriptFolder.folders?.append(subfolder)
            context.insert(subfolder)
        }
        
        #if DEBUG
        print("📁 Created Manuscript subfolders: Front Matter, \(bodyFolderName), Back Matter")
        #endif
    }
    
    // MARK: - Folder Order Configuration
    
    /// Returns all folder keys in the correct display order for a project type
    /// Note: Workflow status (Draft, Ready, Submitted, Set Aside, Published) is now
    /// a property on TextFile, not separate folders.
    private static func getOrderedFolderKeys(for project: Project) -> [String] {
        switch project.type {
        case .prose:
            return [
                // Section 1: Story Structure
                "folder.manuscript",
                "folder.sections",
                "folder.prose",
                // Section 2: Organization & Support
                "folder.submissions",
                "folder.research",
                // Section 3: Publications
                "folder.magazines",
                "folder.competitions",
                "folder.publishers",
                "folder.agents",
                "folder.other",
                // Section 4: System
                "folder.trash"
            ]
            
        case .poetry:
            // Manuscript, Poems // Collections, Submissions, Research // Magazines, Competitions, Other // Trash
            return [
                // Section 1: Primary Content
                "folder.manuscript",
                "folder.poems",
                // Section 2: Organization & Support
                "folder.collections",
                "folder.submissions",
                "folder.research",
                // Section 3: Publications
                "folder.magazines",
                "folder.competitions",
                "folder.publishers",
                "folder.agents",
                "folder.other",
                // Section 4: System
                "folder.trash"
            ]
            
        case .fiction:
            // Novel: Manuscript, Chapters, Scenes, Characters, Locations, Plot // Collections, Submissions, Research // Publishers, Agents, Other // Trash
            // Short: Manuscript, Stories, Scenes, Characters, Locations, Plot // Collections, Submissions, Research // Magazines, Competitions, Other // Trash
            // Verse Novel: Manuscript, Books, Episodes, Characters, Locations, Plot // Collections, Submissions, Research // Publishers, Agents, Other // Trash
            var keys = [
                // Section 1: Story Structure
                "folder.manuscript"
            ]
            
            // Chapters only for novels
            if project.fictionClass == .novel {
                keys.append("folder.chapters")
            }
            
            // Stories only for short fiction
            if project.fictionClass == .shortFiction {
                keys.append("folder.stories")
            }
            
            // Books for verse novel
            if project.fictionClass == .verseNovel {
                keys.append("folder.books")
            }
            
            // Scenes for novel/short fiction, Episodes for verse novel
            if project.fictionClass == .verseNovel {
                keys.append("folder.episodes")
            } else {
                keys.append("folder.scenes")
            }
            
            keys.append(contentsOf: [
                "folder.characters",
                "folder.locations",
                "folder.plot",
                // Section 2: Organization & Support
                "folder.submissions",
                "folder.research"
            ])
            
            keys.append(contentsOf: [
                // Section 3: Publications
                "folder.magazines",
                "folder.competitions",
                "folder.publishers",
                "folder.agents",
                "folder.other"
            ])
            
            // System
            keys.append("folder.trash")
            return keys
            
        case .drama:
            // Manuscript, Acts, Scenes, Characters, Locations, Plot // Collections, Submissions, Research // Publishers, Agents, Other // Trash
            return [
                // Section 1: Story Structure
                "folder.manuscript",
                "folder.acts",
                "folder.scenes",
                "folder.characters",
                "folder.locations",
                "folder.plot",
                // Section 2: Organization & Support
                "folder.submissions",
                "folder.research",
                // Section 3: Publications
                "folder.magazines",
                "folder.competitions",
                "folder.publishers",
                "folder.agents",
                "folder.other",
                // Section 4: System
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
        case .prose:
            return NSLocalizedString("projectType.prose", comment: "Prose project type")
        case .poetry:
            return NSLocalizedString("projectType.poetry", comment: "Poetry project type")
        case .fiction:
            return NSLocalizedString("projectType.fiction", comment: "Fiction project type")
        case .drama:
            return NSLocalizedString("projectType.drama", comment: "Drama project type")
        }
    }
}
