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
    
    static func isFileNameUnique(_ name: String, in folder: Folder) -> Bool {
        let files = folder.files ?? []
        return !files.contains { ($0.name ?? "").caseInsensitiveCompare(name) == .orderedSame }
    }
}
