import Foundation

/// Defines what operations are allowed on specific folders based on their name and purpose
struct FolderCapabilityService {
    
    /// Folders that can ONLY contain subfolders (no files allowed)
    /// These are organizational containers for publications
    private static let subfolderOnlyFolders: Set<String> = [
        "Magazines", "Competitions", "Commissions", "Other", "Publishers", "Agents"
    ]
    
    /// Folders that can contain BOTH subfolders AND files
    /// These are flexible containers for General Purpose projects
    private static let mixedContentFolders: Set<String> = [
        "Folders"
    ]
    
    /// Folders that show publications instead of regular content
    /// These are special views into the publication system
    private static let publicationFolders: Set<String> = [
        // Note: Publication folders are also subfolder-only folders
        // The publication UI appears when viewing their subfolders
    ]
    
    /// Folders that can ONLY contain files (no subfolders)
    /// Users can manually add files to these folders
    /// Updated: Poems, Scenes, Scripts are the new content folders (replacing Draft)
    private static let fileOnlyFolders: Set<String> = [
        "Files", "Research",
        // New content folders (workflow status is now on TextFile)
        "Poems", "Scenes", "Scripts"
    ]
    
    /// Folders that receive content from elsewhere (no manual additions)
    /// These folders are populated automatically by the system
    /// Updated: Removed workflow folders (Draft, Ready, etc.) - workflow is now on TextFile
    private static let readOnlyFolders: Set<String> = [
        "Collections", "Trash", "Manuscript",
        // Entity folders for Fiction (managed via their own views)
        "Characters", "Locations", "Chapters", "Plot"
    ]
    
    // MARK: - Capability Checks
    
    /// Determines if a folder can contain subfolders
    static func canAddSubfolder(to folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        
        // Mixed content folders can contain subfolders
        if mixedContentFolders.contains(folderName) {
            return true
        }
        
        // User-created folders inside "Folders" can also contain subfolders
        if let parentFolder = folder.parentFolder,
           let parentName = parentFolder.name,
           mixedContentFolders.contains(parentName) || isUserCreatedFolder(folder) {
            return true
        }
        
        // Recursively check if this is a descendant of a mixed content folder
        if isDescendantOfMixedContentFolder(folder) {
            return true
        }
        
        // Template folders can only contain subfolders if explicitly allowed
        if isTemplateFolder(folderName) {
            return subfolderOnlyFolders.contains(folderName)
        }
        
        // User-created folders cannot contain subfolders (unless under Folders)
        return false
    }
    
    /// Determines if a folder can contain files
    static func canAddFile(to folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        
        // Read-only folders cannot have files added manually
        if readOnlyFolders.contains(folderName) {
            return false
        }
        
        // Mixed content folders can contain files
        if mixedContentFolders.contains(folderName) {
            return true
        }
        
        // Descendants of mixed content folders can contain files
        if isDescendantOfMixedContentFolder(folder) {
            return true
        }
        
        // Template folders can only contain files if explicitly allowed
        if isTemplateFolder(folderName) {
            return fileOnlyFolders.contains(folderName)
        }
        
        // User-created folders can always contain files
        return true
    }
    
    /// Determines if this is a content folder (Poems, Scenes, Scripts)
    /// These folders use workflow status filtering
    static func isContentFolder(_ folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        return ["Poems", "Scenes", "Scripts"].contains(folderName)
    }
    
    /// Determines if a folder is a root-level template folder (not user-created)
    static func isTemplateFolder(_ folderName: String) -> Bool {
        return subfolderOnlyFolders.contains(folderName) ||
               fileOnlyFolders.contains(folderName) ||
               readOnlyFolders.contains(folderName) ||
               mixedContentFolders.contains(folderName)
    }
    
    /// Determines if a folder is user-created (not a template folder)
    static func isUserCreatedFolder(_ folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        return !isTemplateFolder(folderName)
    }
    
    /// Determines if a folder is a descendant of a mixed content folder
    private static func isDescendantOfMixedContentFolder(_ folder: Folder) -> Bool {
        var current = folder.parentFolder
        while let parent = current {
            if let parentName = parent.name, mixedContentFolders.contains(parentName) {
                return true
            }
            // Also check if parent is user-created under mixed content
            if isUserCreatedFolder(parent) {
                current = parent.parentFolder
            } else {
                current = parent.parentFolder
            }
        }
        return false
    }
    
    /// Returns a user-friendly message explaining why an operation is not allowed
    static func disallowedOperationMessage(for folder: Folder, operation: FolderOperation) -> String {
        guard let folderName = folder.name else {
            return NSLocalizedString("folder.error.unnamed", comment: "Cannot perform operation on unnamed folder")
        }
        
        switch operation {
        case .addSubfolder:
            return String(format: NSLocalizedString("folder.error.noSubfolders", comment: "Cannot add subfolders to this folder"), folderName)
        case .addFile:
            return String(format: NSLocalizedString("folder.error.noFiles", comment: "Cannot add files to this folder"), folderName)
        }
    }
    
    enum FolderOperation {
        case addSubfolder
        case addFile
    }
}
