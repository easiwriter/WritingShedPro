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

    /// Files belonging to this folder, accessed via the direct SwiftData relationship.
    /// Previously used @Query over ALL TextFiles (2167+) and filtered in Swift,
    /// causing 750-970ms re-fetches every ~1s during CloudKit sync WAL checkpoints.
    var allFiles: [TextFile] {
        (folder.textFiles ?? []).filter { !$0.isDeleted }
    }

    func fileCount(for status: WorkflowStatus?) -> Int {
        let files = deferredSortedFiles ?? []
        if let status = status {
            return files.filter { $0.workflowStatus == status }.count
        } else {
            return files.count
        }
    }

    var sortedFiles: [TextFile] {
        // Sort Matter folders by userOrder to maintain standard manuscript order
        if isMatterFolder {
            let visibleFiles: [TextFile]
            if folder.isFrontMatterFolder {
                if folder.isDramaProject {
                    let settings = folder.dramaFrontMatterSettings
                    visibleFiles = allFiles.filter { file in
                        guard let item = DramaFrontMatterItem(rawValue: file.name) else { return true }
                        return settings.isEnabled(item)
                    }
                } else {
                    let settings = folder.frontMatterSettings
                    visibleFiles = allFiles.filter { file in
                        guard let item = FrontMatterItem(rawValue: file.name) else { return true }
                        return settings.isEnabled(item)
                    }
                }
            } else if folder.isBackMatterFolder && !folder.isDramaProject {
                let settings = folder.backMatterSettings
                visibleFiles = allFiles.filter { file in
                    if file.isTableOfFiguresFile {
                        return settings.isEnabled(.tableOfFigures)
                    }
                    if let item = ManuscriptAssemblyService.generatedBackMatterType(for: file) {
                        return settings.isEnabled(item)
                    }
                    if file.isCoverFile && file.name == BackMatterItem.backCover.fileName {
                        return settings.isEnabled(.backCover)
                    }
                    return true
                }
            } else {
                visibleFiles = allFiles
            }

            let canonicalFiles = ManuscriptAssemblyService.canonicalMatterFiles(visibleFiles, in: folder)
            let sorted = canonicalFiles.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            let coverNames: Set<String> = [
                FrontMatterItem.frontCover.fileName,
                BackMatterItem.backCover.fileName
            ]

            func isCoverLike(_ file: TextFile) -> Bool {
                file.isCoverFile || coverNames.contains(file.name)
            }

            // Pin cover files: front cover always first, back cover always last
            var nonCovers = sorted.filter { !isCoverLike($0) }
            let frontCover = sorted.first(where: { isCoverLike($0) && $0.name == FrontMatterItem.frontCover.fileName })
            let backCover = sorted.first(where: { isCoverLike($0) && $0.name == BackMatterItem.backCover.fileName })
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
        poetryCollectionGroups(for: sortedFiles)
    }

    func poetryCollectionGroups(for visibleFiles: [TextFile]) -> [CollectionGroup]? {
        guard isPoetryProject && isContentFolder else { return nil }
        guard let collections = folder.project?.poetryCollections, !collections.isEmpty else { return nil }

        var groups: [CollectionGroup] = []

        let sortedCollections = collections.sorted(by: ContainerDisplayOrder.isOrdered)

        var membershipByCollectionID: [UUID: [TextFile]] = [:]
        var assignedVisibleFileIDs: Set<UUID> = []

        for file in visibleFiles {
            guard let collectionID = file.poetryCollection?.id else { continue }
            assignedVisibleFileIDs.insert(file.id)
            membershipByCollectionID[collectionID, default: []].append(file)
        }

        for collection in sortedCollections {
            let collectionFiles = membershipByCollectionID[collection.id] ?? []
            guard !collectionFiles.isEmpty else { continue }

            groups.append(CollectionGroup(
                id: collection.id.uuidString,
                name: collection.name ?? NSLocalizedString("poetry.collection.unnamed", comment: "Unnamed"),
                files: collectionFiles
            ))
        }

        // Add unassigned poems
        let unassignedFiles = visibleFiles.filter { !assignedVisibleFileIDs.contains($0.id) }
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
        let allFiles = (folder.textFiles ?? []).filter { !$0.isDeleted }
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
        (deferredSortedFiles ?? []).filter { selectedFileIDs.contains($0.id) }
    }

    var selectedFolders: [Folder] {
        sortedSubfolders.filter { selectedFolderIDs.contains($0.id) }
    }

    var showMixedContentToolbar: Bool {
        isEditMode && (!sortedMixedFiles.isEmpty || !sortedSubfolders.isEmpty)
    }
}
