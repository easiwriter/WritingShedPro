import Foundation

/// Defines what operations are allowed on specific folders based on their name and purpose
struct FolderCapabilityService {
    
    /// Folders that can ONLY contain subfolders (no files allowed)
    /// These are organizational containers
    private static let subfolderOnlyFolders: Set<String> = [
        "Chapters", "Acts", "Magazines", "Competitions", "Commissions", "Other"
    ]
    
    /// Folders that show publications instead of regular content
    /// These are special views into the publication system
    private static let publicationFolders: Set<String> = [
        // Note: Publication folders are also subfolder-only folders
        // The publication UI appears when viewing their subfolders
    ]
    
    /// Folders that can ONLY contain files (no subfolders)
    /// Users can manually add files to these folders
    private static let fileOnlyFolders: Set<String> = [
        "Files", "Draft", "Research", "Scenes", "Characters", "Locations"
    ]
    
    /// Folders that receive content from elsewhere (no manual additions)
    /// These folders are populated automatically by the system
    private static let readOnlyFolders: Set<String> = [
        "All", "Ready", "Collections", "Set Aside", "Published", "Trash", "Novel", "Script"
    ]
    
    // MARK: - Capability Checks
    
    /// Determines if a folder can contain subfolders
    static func canAddSubfolder(to folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        
        // Template folders can only contain subfolders if explicitly allowed
        if isTemplateFolder(folderName) {
            return subfolderOnlyFolders.contains(folderName)
        }
        
        // User-created folders cannot contain subfolders
        return false
    }
    
    /// Determines if a folder can contain files
    static func canAddFile(to folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        
        // Read-only folders cannot have files added manually
        if readOnlyFolders.contains(folderName) {
            return false
        }
        
        // Template folders can only contain files if explicitly allowed
        if isTemplateFolder(folderName) {
            return fileOnlyFolders.contains(folderName)
        }
        
        // User-created folders can always contain files
        return true
    }
    
    /// Determines if a folder is a root-level template folder (not user-created)
    static func isTemplateFolder(_ folderName: String) -> Bool {
        return subfolderOnlyFolders.contains(folderName) ||
               fileOnlyFolders.contains(folderName) ||
               readOnlyFolders.contains(folderName)
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
