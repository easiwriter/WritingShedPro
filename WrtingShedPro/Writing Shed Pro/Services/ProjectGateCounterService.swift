import Foundation

/// Shared counting logic for free-tier entitlement gates.
/// Centralizing this avoids drift between project/file creation flows.
struct ProjectGateCounterService {

    /// Count active (non-trashed) projects of a specific type.
    static func activeProjectCount(ofType type: ProjectType, in projects: [Project]) -> Int {
        projects.filter { !$0.isTrashed && $0.type == type }.count
    }

    /// Count all active (non-trashed) files in a project, including nested folders.
    static func activeFileCount(in project: Project) -> Int {
        var count = 0

        func countInFolder(_ folder: Folder) {
            if let files = folder.files {
                count += files.filter { $0.trashItem == nil }.count
            }
            if let subfolders = folder.subfolders {
                for subfolder in subfolders {
                    countInFolder(subfolder)
                }
            }
        }

        if let folders = project.folders {
            for folder in folders {
                countInFolder(folder)
            }
        }

        return count
    }
}
