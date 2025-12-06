import Foundation
import SwiftData

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
                let count1 = $0.textFiles?.count ?? 0
                let count2 = $1.textFiles?.count ?? 0
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
    static func sort(_ files: [TextFile], by order: FileSortOrder) -> [TextFile] {
        switch order {
        case .byName:
            return files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

// MARK: - Collection Sort Service

enum CollectionSortOrder: String, CaseIterable {
    case byUserOrder = "userOrder"
    case byName = "name"
    case byCreationDate = "creationDate"
    case byModifiedDate = "modifiedDate"
    case byFileCount = "fileCount"
}

struct CollectionSortService {
    static func sort(_ collections: [Submission], by order: CollectionSortOrder) -> [Submission] {
        switch order {
        case .byUserOrder:
            return collections.sorted { (c0: Submission, c1: Submission) -> Bool in
                let order1 = c0.userOrder ?? Int.max
                let order2 = c1.userOrder ?? Int.max
                return order1 < order2
            }
        case .byName:
            return collections.sorted { (c0: Submission, c1: Submission) -> Bool in
                (c0.name ?? "").localizedCaseInsensitiveCompare(c1.name ?? "") == .orderedAscending
            }
        case .byCreationDate:
            return collections.sorted { (c0: Submission, c1: Submission) -> Bool in
                c0.createdDate > c1.createdDate
            }
        case .byModifiedDate:
            return collections.sorted { (c0: Submission, c1: Submission) -> Bool in
                c0.modifiedDate > c1.modifiedDate
            }
        case .byFileCount:
            return collections.sorted { (c0: Submission, c1: Submission) -> Bool in
                let count1 = c0.submittedFiles?.count ?? 0
                let count2 = c1.submittedFiles?.count ?? 0
                return count1 > count2
            }
        }
    }
    
    static func sortOptions() -> [SortOption<CollectionSortOrder>] {
        [
            SortOption(.byUserOrder, title: NSLocalizedString("collections.sortByUserOrder", comment: "Sort by user order")),
            SortOption(.byName, title: NSLocalizedString("collections.sortByName", comment: "Sort by name")),
            SortOption(.byCreationDate, title: NSLocalizedString("collections.sortByCreated", comment: "Sort by created date")),
            SortOption(.byModifiedDate, title: NSLocalizedString("collections.sortByModified", comment: "Sort by modified date")),
            SortOption(.byFileCount, title: NSLocalizedString("collections.sortByFileCount", comment: "Sort by file count"))
        ]
    }
}