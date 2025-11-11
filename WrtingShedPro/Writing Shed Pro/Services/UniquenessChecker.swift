import Foundation

struct UniquenessChecker {
    static func isProjectNameUnique(_ name: String, in projects: [Project]) -> Bool {
        !projects.contains { ($0.name ?? "").caseInsensitiveCompare(name) == .orderedSame }
    }
    
    /// Check if folder name is unique within its parent context
    /// - For root-level folders (parentFolder == nil): checks uniqueness within project
    /// - For nested folders: checks uniqueness within parent folder
    /// - Parameters:
    ///   - name: The folder name to check
    ///   - project: The project containing the folder
    ///   - parentFolder: Optional parent folder (nil for root-level)
    ///   - excludingFolder: Optional folder to exclude from check (for rename operations)
    static func isFolderNameUnique(_ name: String, in project: Project, parentFolder: Folder? = nil, excludingFolder: Folder? = nil) -> Bool {
        let folders: [Folder]
        
        if let parentFolder = parentFolder {
            // Check uniqueness within parent folder's subfolders
            folders = parentFolder.folders ?? []
        } else {
            // Check uniqueness within project's root-level folders
            folders = project.folders ?? []
        }
        
        return !folders.contains { folder in
            // Exclude the folder being renamed
            if let excludingFolder = excludingFolder, folder.id == excludingFolder.id {
                return false
            }
            return (folder.name ?? "").caseInsensitiveCompare(name) == .orderedSame
        }
    }
    
    /// Check if file name is unique within a folder
    /// - Considers both active files and deleted files (in trash)
    /// - Parameters:
    ///   - name: The file name to check
    ///   - folder: The folder to check within
    static func isFileNameUnique(_ name: String, in folder: Folder) -> Bool {
        return getFileNameConflict(name, in: folder) == nil
    }
    
    /// Determine why a file name is not unique
    /// - Returns: nil if name is unique, "active" if file exists in folder, "trash" if file exists in trash
    /// - Parameters:
    ///   - name: The file name to check
    ///   - folder: The folder to check within
    static func getFileNameConflict(_ name: String, in folder: Folder) -> String? {
        // Check active files
        let files = folder.textFiles ?? []
        if files.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return "active"
        }
        
        // Check deleted files (in trash) from the same folder
        if let project = folder.project,
           let trashedItems = project.trashedItems {
            if trashedItems.contains(where: { trashItem in
                // Check if this trash item is from the same folder and has matching name
                trashItem.originalFolder?.id == folder.id &&
                (trashItem.textFile?.name ?? "").caseInsensitiveCompare(name) == .orderedSame
            }) {
                return "trash"
            }
        }
        
        return nil
    }
}
