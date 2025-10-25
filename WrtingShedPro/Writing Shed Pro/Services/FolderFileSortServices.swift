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
    case byModifiedDate = "modifiedDate"
    case byUserOrder = "userOrder"
}

struct FileSortService {
    static func sort(_ files: [File], by order: FileSortOrder) -> [File] {
        switch order {
        case .byName:
            return files.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        case .byCreationDate:
            return files.sorted { $0.createdDate > $1.createdDate }
        case .byModifiedDate:
            return files.sorted { $0.modifiedDate > $1.modifiedDate }
        case .byUserOrder:
            return files.sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
        }
    }
    
    static func sortOptions() -> [SortOption<FileSortOrder>] {
        [
            SortOption(.byName, title: NSLocalizedString("folderList.sortByName", comment: "Sort by name")),
            SortOption(.byCreationDate, title: NSLocalizedString("folderList.sortByCreated", comment: "Sort by created date")),
            SortOption(.byModifiedDate, title: NSLocalizedString("folderList.sortByModified", comment: "Sort by modified date")),
            SortOption(.byUserOrder, title: NSLocalizedString("contentView.sortByUserOrder", comment: "Sort by user's order"))
        ]
    }
}