import Foundation

/// Defines what operations are allowed on specific folders based on their name and purpose
struct FolderCapabilityService {
    
    /// Folders that can ONLY contain subfolders (no files allowed)
    /// These are organizational containers
    private static let subfolderOnlyFolders: Set<String> = [
        "Magazines", "Competitions", "Commissions", "Other",
        "Collections", "Submissions", "Chapters", "Acts"
    ]
    
    /// Folders that can contain BOTH subfolders and files
    /// These provide organizational flexibility
    private static let mixedCapabilityFolders: Set<String> = [
        "Draft", "Scenes", "Characters", "Locations"
    ]
    
    /// Folders that can ONLY contain files (no subfolders)
    /// All other template folders fall into this category
    private static let fileOnlyFolders: Set<String> = [
        "All", "Ready", "Set Aside", "Published", "Research",
        "Novel", "Script", "Trash"
    ]
    
    // MARK: - Capability Checks
    
    /// Determines if a folder can contain subfolders
    static func canAddSubfolder(to folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        
        // User-created folders (not template folders) can always contain subfolders
        if !isTemplateFolder(folderName) {
            return true
        }
        
        // Template folders can only contain subfolders if explicitly allowed
        return subfolderOnlyFolders.contains(folderName) || mixedCapabilityFolders.contains(folderName)
    }
    
    /// Determines if a folder can contain files
    static func canAddFile(to folder: Folder) -> Bool {
        guard let folderName = folder.name else { return false }
        
        // User-created folders (not template folders) can always contain files
        if !isTemplateFolder(folderName) {
            return true
        }
        
        // Template folders can only contain files if explicitly allowed
        return fileOnlyFolders.contains(folderName) || mixedCapabilityFolders.contains(folderName)
    }
    
    /// Determines if a folder is a root-level template folder (not user-created)
    static func isTemplateFolder(_ folderName: String) -> Bool {
        return subfolderOnlyFolders.contains(folderName) ||
               mixedCapabilityFolders.contains(folderName) ||
               fileOnlyFolders.contains(folderName)
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
