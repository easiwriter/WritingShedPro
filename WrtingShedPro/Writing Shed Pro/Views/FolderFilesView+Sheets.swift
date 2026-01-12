import SwiftUI
import UniformTypeIdentifiers

extension FolderFilesView {
    
    /// Apply all sheet and alert modifiers to the view
    @ViewBuilder
    func applySheets<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $showMoveDestinationPicker) {
                moveDestinationSheet
            }
            .sheet(isPresented: $showSearchView) {
                MultiFileSearchView(folder: folder, files: sortedFiles)
            }
            .sheet(isPresented: $showAddFileSheet) {
                AddFileSheet(
                    isPresented: $showAddFileSheet,
                    parentFolder: folder,
                    existingFiles: folder.textFiles ?? []
                )
            }
            .sheet(isPresented: $showAddFolderSheet) {
                addFolderSheet
            }
            .sheet(isPresented: $showSubmissionPicker) {
                submissionPickerSheet
            }
            .sheet(isPresented: $showCollectionPicker) {
                collectionPickerSheet
            }
            .sheet(isPresented: $showRenamePicker) {
                renamePickerSheet
            }
            .sheet(isPresented: $showFolderMoveDestinationPicker) {
                folderMoveDestinationSheet
            }
            .sheet(isPresented: $showStatusPicker) {
                statusPickerSheet
            }
    }
    
    @ViewBuilder
    var moveDestinationSheet: some View {
        if let project = folder.project {
            NavigationStack {
                MoveDestinationPicker(
                    project: project,
                    currentFolder: folder,
                    filesToMove: filesToMove,
                    onDestinationSelected: { destination in
                        moveFiles(to: destination)
                    },
                    onCancel: {
                        showMoveDestinationPicker = false
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    var addFolderSheet: some View {
        if let project = folder.project {
            AddFolderSheet(
                isPresented: $showAddFolderSheet,
                project: project,
                parentFolder: folder,
                existingFolders: sortedSubfolders
            )
        }
    }
    
    @ViewBuilder
    var submissionPickerSheet: some View {
        if let project = folder.project {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: filesToSubmit,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name in
                        createSubmission(for: publication, name: name)
                        showSubmissionPicker = false
                    },
                    onCancel: {
                        showSubmissionPicker = false
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    var collectionPickerSheet: some View {
        if let project = folder.project {
            NavigationStack {
                CollectionPickerView(
                    project: project,
                    filesToAddToCollection: filesToAddToCollection,
                    collectionsToAddToPublication: nil,
                    mode: .addFilesToCollection,
                    onCollectionSelected: { collection in
                        addFilesToCollection(collection)
                        showCollectionPicker = false
                    },
                    onCancel: {
                        showCollectionPicker = false
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    var renamePickerSheet: some View {
        if let file = filesToRename.first {
            NavigationStack {
                RenameFileModal(
                    file: file,
                    filesInFolder: sortedFiles,
                    onRename: { newName in
                        renameFile(newName: newName)
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    var folderMoveDestinationSheet: some View {
        if let project = folder.project {
            FolderMoveDestinationPicker(
                project: project,
                currentFolder: folder,
                folderToMove: folderToMove,
                filesToMove: [],
                onDestinationSelected: { destination in
                    if let folderMoving = folderToMove {
                        moveSubfolder(folderMoving, to: destination)
                    }
                    showFolderMoveDestinationPicker = false
                },
                onCancel: {
                    showFolderMoveDestinationPicker = false
                }
            )
        }
    }
    
    @ViewBuilder
    var statusPickerSheet: some View {
        WorkflowStatusPickerSheet(
            files: filesToChangeStatus,
            onStatusSelected: { newStatus in
                changeFilesStatus(filesToChangeStatus, to: newStatus)
                showStatusPicker = false
            },
            onCancel: {
                showStatusPicker = false
            }
        )
    }
}
