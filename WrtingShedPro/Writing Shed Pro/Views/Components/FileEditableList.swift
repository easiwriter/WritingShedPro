import SwiftUI
import SwiftData

/// A specialized EditableList for File items within a folder
struct FileEditableList: View {
    @Environment(\.modelContext) private var modelContext
    let folder: Folder
    @State private var selectedSortOrder: FileSortOrder
    @State private var isEditMode = false
    @State private var showDeleteConfirmation = false
    @State private var filesToDelete: IndexSet?
    @State private var showAddFileSheet = false
    
    // Get files from the folder
    private var files: [File] {
        folder.files ?? []
    }
    
    // Sort and display state
    private var sortedFiles: [File] {
        FileSortService.sort(files, by: selectedSortOrder)
    }
    
    init(folder: Folder, initialSort: FileSortOrder = .byName) {
        self.folder = folder
        self._selectedSortOrder = State(initialValue: initialSort)
    }
    
    var body: some View {
        List {
            ForEach(sortedFiles) { file in
                NavigationLink(destination: FileEditView(file: file)) {
                    FileRowView(file: file)
                }
            }
            .onDelete(perform: deleteFiles)
            .onMove(perform: isEditMode ? moveFiles : nil)
        }
        .navigationTitle(folder.name ?? "Files")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        .onAppear {
            initializeUserOrderIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Sort Menu
                    Menu {
                        ForEach(FileSortService.sortOptions(), id: \.order) { option in
                            Button(action: {
                                selectedSortOrder = option.order
                            }) {
                                HStack {
                                    Text(option.title)
                                    if selectedSortOrder == option.order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel(NSLocalizedString("folderList.sortAccessibility", comment: "Sort files"))
                    
                    // Add file button (only if folder allows it)
                    if FolderCapabilityService.canAddFile(to: folder) {
                        Button(action: { showAddFileSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(NSLocalizedString("folderList.addFile", comment: "Add file"))
                    }
                    
                    // Edit Button
                    Button(isEditMode ? NSLocalizedString("folderList.done", comment: "Done") : NSLocalizedString("folderList.edit", comment: "Edit")) {
                        withAnimation {
                            isEditMode.toggle()
                        }
                    }
                    .disabled(files.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showAddFileSheet) {
            AddFileSheet(
                isPresented: $showAddFileSheet,
                parentFolder: folder,
                existingFiles: files
            )
        }
        .onChange(of: files.isEmpty) { _, isEmpty in
            if isEmpty && isEditMode {
                withAnimation {
                    isEditMode = false
                }
            }
        }
        .confirmationDialog(
            NSLocalizedString("fileList.deleteFile.title", comment: "Delete File?"),
            isPresented: $showDeleteConfirmation,
            presenting: filesToDelete,
            actions: { _ in
                Button(NSLocalizedString("contentView.delete", comment: "Delete"), role: .destructive) {
                    confirmDeleteFiles()
                }
                Button(NSLocalizedString("contentView.cancel", comment: "Cancel"), role: .cancel) {
                    filesToDelete = nil
                }
            },
            message: { offsets in
                let count = offsets.count
                if count == 1 {
                    let fileName = sortedFiles[offsets.first ?? 0].name ?? NSLocalizedString("file.untitled", comment: "Untitled File")
                    return Text(String(format: NSLocalizedString("fileList.deleteConfirmOne", comment: "Delete file confirmation"), fileName))
                } else {
                    return Text(String(format: NSLocalizedString("fileList.deleteFile.message", comment: "Delete multiple files"), count))
                }
            }
        )
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        filesToDelete = offsets
        showDeleteConfirmation = true
    }
    
    private func initializeUserOrderIfNeeded() {
        // Ensure all existing files have a userOrder
        let filesNeedingOrder = files.filter { $0.userOrder == nil }
        if !filesNeedingOrder.isEmpty {
            for (index, file) in files.enumerated() {
                if file.userOrder == nil {
                    file.userOrder = index
                }
            }
            try? modelContext.save()
        }
    }
    
    private func confirmDeleteFiles() {
        guard let offsets = filesToDelete else { return }
        for index in offsets {
            let file = sortedFiles[index]
            modelContext.delete(file)
        }
        try? modelContext.save()
        filesToDelete = nil
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        // If not in User's Order mode, automatically switch to it when user drags
        if selectedSortOrder != .byUserOrder {
            selectedSortOrder = .byUserOrder
        }
        
        guard let sourceIndex = source.first else { return }
        let destIndex = destination
        
        // If dropping in same position, do nothing
        if destIndex == sourceIndex {
            return
        }
        
        let currentFiles = sortedFiles
        
        if sourceIndex > destIndex {
            // Moving item up the list - shift items down to make room
            let baseOrder = currentFiles[destIndex].userOrder ?? destIndex
            for i in destIndex..<sourceIndex {
                let currentOrder = currentFiles[i].userOrder ?? i
                currentFiles[i].userOrder = currentOrder + 1
            }
            currentFiles[sourceIndex].userOrder = baseOrder
        } else {
            // Moving item down the list - shift items up to fill gap
            for i in sourceIndex + 1..<destIndex {
                let currentOrder = currentFiles[i].userOrder ?? i
                currentFiles[i].userOrder = currentOrder - 1
            }
            currentFiles[sourceIndex].userOrder = destIndex - 1
        }
        
        // Save the changes
        try? modelContext.save()
    }
}

/// Helper view for displaying individual file items
struct FileRowView: View {
    let file: File
    
    var body: some View {
        Text(file.name ?? NSLocalizedString("folderList.untitledFile", comment: "Untitled File"))
            .font(.body)
            .padding(.vertical, 4)
    }
}