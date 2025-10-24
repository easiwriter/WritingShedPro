import Foundation

struct UniquenessChecker {
    static func isProjectNameUnique(_ name: String, in projects: [Project]) -> Bool {
        !projects.contains { ($0.name ?? "").caseInsensitiveCompare(name) == .orderedSame }
    }
    
    static func isFolderNameUnique(_ name: String, in parent: Folder) -> Bool {
        let folders = parent.folders ?? []
        return !folders.contains { ($0.name ?? "").caseInsensitiveCompare(name) == .orderedSame }
    }
    
    static func isFileNameUnique(_ name: String, in folder: Folder) -> Bool {
        let files = folder.files ?? []
        return !files.contains { ($0.name ?? "").caseInsensitiveCompare(name) == .orderedSame }
    }
}
