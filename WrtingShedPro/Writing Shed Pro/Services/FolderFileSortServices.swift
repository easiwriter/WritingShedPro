import Foundation

// MARK: - Folder Sort Service

enum FolderSortOrder: String, CaseIterable {
    case byName = "name"
    case byCreationDate = "creationDate"
    case byItemCount = "itemCount"
}

struct FolderSortService {
    static func sort(_ folders: [Folder], by order: FolderSortOrder) -> [Folder] {
        switch order {
        case .byName:
            return folders.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .byCreationDate:
            return folders.sorted { ($0.id.uuidString) < ($1.id.uuidString) } // Approximate creation order
        case .byItemCount:
            return folders.sorted { 
                let count1 = $0.files?.count ?? 0
                let count2 = $1.files?.count ?? 0
                return count1 > count2
            }
        }
    }
    
    static func sortOptions() -> [SortOption<FolderSortOrder>] {
        [
            SortOption(.byName, title: NSLocalizedString("sort.byName", comment: "Sort by name")),
            SortOption(.byCreationDate, title: NSLocalizedString("sort.byCreationDate", comment: "Sort by creation date")),
            SortOption(.byItemCount, title: NSLocalizedString("sort.byItemCount", comment: "Sort by item count"))
        ]
    }
}

// MARK: - File Sort Service

enum FileSortOrder: String, CaseIterable {
    case byName = "name"
    case byCreationDate = "creationDate"
    case bySize = "size"
}

struct FileSortService {
    static func sort(_ files: [File], by order: FileSortOrder) -> [File] {
        switch order {
        case .byName:
            return files.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .byCreationDate:
            return files.sorted { ($0.id.uuidString) < ($1.id.uuidString) } // Approximate creation order
        case .bySize:
            return files.sorted { 
                let size1 = $0.content?.count ?? 0
                let size2 = $1.content?.count ?? 0
                return size1 > size2
            }
        }
    }
    
    static func sortOptions() -> [SortOption<FileSortOrder>] {
        [
            SortOption(.byName, title: NSLocalizedString("sort.byName", comment: "Sort by name")),
            SortOption(.byCreationDate, title: NSLocalizedString("sort.byCreationDate", comment: "Sort by creation date")),
            SortOption(.bySize, title: NSLocalizedString("sort.bySize", comment: "Sort by size"))
        ]
    }
}