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

    var isGeneralPurposeProject: Bool {
        folder.project?.type == .generalPurpose
    }

    var allFiles: [TextFile] {
        allTextFiles.filter { $0.parentFolder?.id == folder.id }
    }

    func fileCount(for status: WorkflowStatus?) -> Int {
        if let status = status {
            return allFiles.filter { $0.workflowStatus == status }.count
        } else {
            return allFiles.count
        }
    }

    var sortedFiles: [TextFile] {
        if isContentFolder, let filter = statusFilter {
            return allFiles.filter { $0.workflowStatus == filter }
        }
        return allFiles
    }

    var supportsSubmissions: Bool {
        if isContentFolder {
            return statusFilter == .ready
        }
        return false
    }

    var supportsAddToCollection: Bool {
        return isContentFolder
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
