import Foundation
import SwiftUI

extension FolderFilesView {
    // Helper: Whether headers or footers are enabled in this folder's project
    var headersOrFootersEnabled: Bool {
        guard let pageSetup = folder.project?.pageSetup else { return false }
        return pageSetup.hasHeaders || pageSetup.hasFooters
    }

    var isContentFolder: Bool {
        FolderCapabilityService.isContentFolder(folder)
    }

    var isProseProject: Bool {
        folder.project?.type == .prose
    }

    var isPoetryProject: Bool {
        folder.project?.type == .poetry
    }

    var isMatterFolder: Bool {
        folder.isFrontMatterFolder || folder.isBackMatterFolder
    }

    var allFiles: [TextFile] {
        let folderID: UUID = folder.id
        return allTextFiles.filter { (file: TextFile) -> Bool in file.parentFolder?.id == folderID }
    }

    func fileCount(for status: WorkflowStatus?) -> Int {
        if let status = status {
            return allFiles.filter { $0.workflowStatus == status }.count
        } else {
            return allFiles.count
        }
    }

    var sortedFiles: [TextFile] {
        // Sort Matter folders by userOrder to maintain standard manuscript order
        if isMatterFolder {
            let sorted = allFiles.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            // Pin cover files: front cover always first, back cover always last
            var nonCovers = sorted.filter { !$0.isCoverFile }
            let frontCover = sorted.first(where: { $0.isCoverFile && $0.name == FrontMatterItem.frontCover.fileName })
            let backCover = sorted.first(where: { $0.isCoverFile && $0.name == BackMatterItem.backCover.fileName })
            if let fc = frontCover { nonCovers.insert(fc, at: 0) }
            if let bc = backCover { nonCovers.append(bc) }
            return nonCovers
        }
        // Content folders: always sort by userOrder (matches manuscript assembly and TOC order)
        // Secondary sort by name when userOrder is equal (e.g. new files not yet reordered)
        if isContentFolder {
            let sorted = allFiles.sorted {
                let order0 = $0.userOrder ?? Int.max
                let order1 = $1.userOrder ?? Int.max
                if order0 != order1 {
                    return order0 < order1
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            if let filter = statusFilter {
                return sorted.filter { $0.workflowStatus == filter }
            }
            return sorted
        }
        return allFiles
    }

    var supportsSubmissions: Bool {
        isContentFolder
    }

    /// Collection groups for displaying poems arranged by collection (Poetry content folders only)
    var poetryCollectionGroups: [CollectionGroup]? {
        guard isPoetryProject && isContentFolder else { return nil }
        guard let collections = folder.project?.poetryCollections, !collections.isEmpty else { return nil }
        
        let currentFiles = Set(sortedFiles.map { $0.id })
        var groups: [CollectionGroup] = []
        
        // Sort collections by userOrder, then by name
        let sortedCollections = collections.sorted {
            let order0 = $0.userOrder ?? Int.max
            let order1 = $1.userOrder ?? Int.max
            if order0 != order1 { return order0 < order1 }
            return ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        }
        
        for collection in sortedCollections {
            let collectionFiles = (collection.textFiles ?? [])
                .filter { currentFiles.contains($0.id) }
                .sorted {
                    let order0 = $0.userOrder ?? Int.max
                    let order1 = $1.userOrder ?? Int.max
                    if order0 != order1 { return order0 < order1 }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            if !collectionFiles.isEmpty {
                groups.append(CollectionGroup(
                    id: collection.id.uuidString,
                    name: collection.name ?? NSLocalizedString("poetry.collection.unnamed", comment: "Unnamed"),
                    files: collectionFiles
                ))
            }
        }
        
        // Add unassigned poems
        let assignedFileIDs = Set(groups.flatMap { $0.files.map { $0.id } })
        let unassignedFiles = sortedFiles.filter { !assignedFileIDs.contains($0.id) }
        if !unassignedFiles.isEmpty {
            groups.append(CollectionGroup(
                id: "__unassigned__",
                name: NSLocalizedString("poetry.collection.unassigned", comment: "Unassigned"),
                files: unassignedFiles
            ))
        }
        
        return groups.isEmpty ? nil : groups
    }

    var isMixedContentFolder: Bool {
        FolderCapabilityService.canAddSubfolder(to: folder) && FolderCapabilityService.canAddFile(to: folder)
    }

    var sortedSubfolders: [Folder] {
        FolderSortService.sort(folder.folders ?? [], by: folderSortOrder)
    }

    var sortedMixedFiles: [TextFile] {
        let allFiles = folder.textFiles ?? []
        var seenIDs = Set<UUID>()
        let uniqueFiles = allFiles.filter { file in
            if seenIDs.contains(file.id) {
                #if DEBUG
                print("⚠️ [FolderFilesView] Duplicate file detected: \(file.name) (ID: \(file.id))")
                #endif
                return false
            }
            seenIDs.insert(file.id)
            return true
        }
        return FileSortService.sort(uniqueFiles, by: fileSortOrder)
    }

    var isEditMode: Bool {
        editMode == .active
    }

    var selectedFiles: [TextFile] {
        sortedFiles.filter { selectedFileIDs.contains($0.id) }
    }

    var selectedFolders: [Folder] {
        sortedSubfolders.filter { selectedFolderIDs.contains($0.id) }
    }

    var showMixedContentToolbar: Bool {
        isEditMode && (!selectedFileIDs.isEmpty || !selectedFolderIDs.isEmpty)
    }
}
