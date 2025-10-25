import Foundation

enum SortOrder {
    case byName
    case byCreationDate
    case byModifiedDate
    case byUserOrder
}

struct ProjectSortService {
    static func sortProjects(_ projects: [Project], by order: SortOrder) -> [Project] {
        switch order {
        case .byName:
            return projects.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
        case .byCreationDate:
            return projects.sorted { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
        case .byModifiedDate:
            return projects.sorted { ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast) }
        case .byUserOrder:
            return projects.sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
        }
    }
    
    /// Updates userOrder for projects based on their new positions after drag-and-drop
    static func updateUserOrder(for projects: [Project], movedFromOffsets: IndexSet, toOffset: Int) -> [Project] {
        var reorderedProjects = projects
        reorderedProjects.move(fromOffsets: movedFromOffsets, toOffset: toOffset)
        
        // Update userOrder property for all projects based on new positions
        for (index, project) in reorderedProjects.enumerated() {
            project.userOrder = index
        }
        
        return reorderedProjects
    }
    
    static func sortOptions() -> [SortOption<SortOrder>] {
        [
            SortOption(.byName, title: NSLocalizedString("contentView.sortByName", comment: "Sort by name")),
            SortOption(.byCreationDate, title: NSLocalizedString("contentView.sortByDate", comment: "Sort by creation date")),
            SortOption(.byModifiedDate, title: NSLocalizedString("contentView.sortByModified", comment: "Sort by modified date")),
            SortOption(.byUserOrder, title: NSLocalizedString("contentView.sortByUserOrder", comment: "Sort by user's order"))
        ]
    }
}
