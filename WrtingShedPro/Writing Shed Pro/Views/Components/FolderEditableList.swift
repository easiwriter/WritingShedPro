import SwiftUI
import SwiftData

/// A specialized EditableList for Folder items
struct FolderEditableList: View {
    @Environment(\.modelContext) private var modelContext
    let folders: [Folder]
    let project: Project?
    @State private var selectedSortOrder: FolderSortOrder
    @State private var isEditMode = false
    @State private var showDeleteConfirmation = false
    @State private var foldersToDelete: IndexSet?
    
    // Sort and display state
    private var sortedFolders: [Folder] {
        FolderSortService.sort(folders, by: selectedSortOrder)
    }
    
    init(folders: [Folder], project: Project? = nil, initialSort: FolderSortOrder = .byName) {
        self.folders = folders
        self.project = project
        self._selectedSortOrder = State(initialValue: initialSort)
    }
    
    var body: some View {
        List {
            ForEach(sortedFolders) { folder in
                NavigationLink(destination: FolderDetailView(folder: folder)) {
                    FolderItemView(folder: folder, project: project)
                }
            }
            .onDelete(perform: deleteFolders)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Sort Menu
                    Menu {
                        ForEach(FolderSortService.sortOptions(), id: \.order) { option in
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
                    
                    // Edit Button
                    Button(isEditMode ? "Done" : "Edit") {
                        withAnimation {
                            isEditMode.toggle()
                        }
                    }
                    .disabled(folders.isEmpty)
                }
            }
        }
        .onChange(of: folders.isEmpty) { _, isEmpty in
            if isEmpty && isEditMode {
                withAnimation {
                    isEditMode = false
                }
            }
        }
        .confirmationDialog(
            Text("folderEditableList.deleteTitle"),
            isPresented: $showDeleteConfirmation,
            presenting: foldersToDelete,
            actions: { _ in
                Button("folderEditableList.delete", role: .destructive) {
                    confirmDeleteFolders()
                }
                Button("button.cancel", role: .cancel) {
                    foldersToDelete = nil
                }
            },
            message: { offsets in
                let count = offsets.count
                if count == 1 {
                    let folderName = sortedFolders[offsets.first ?? 0].name ?? NSLocalizedString("folderEditableList.untitled", comment: "Untitled Folder")
                    return Text(String(format: NSLocalizedString("folderEditableList.deleteSingleWarning", comment: "Delete single folder warning"), folderName))
                } else {
                    return Text(String(format: NSLocalizedString("folderEditableList.deleteMultipleWarning", comment: "Delete multiple folders warning"), count))
                }
            }
        )
    }
    
    private func deleteFolders(at offsets: IndexSet) {
        foldersToDelete = offsets
        showDeleteConfirmation = true
    }
    
    private func confirmDeleteFolders() {
        guard let offsets = foldersToDelete else { return }
        for index in offsets {
            let folder = sortedFolders[index]
            modelContext.delete(folder)
        }
        try? modelContext.save()
        foldersToDelete = nil
    }
}

/// Helper view for displaying individual folder items
struct FolderItemView: View {
    let folder: Folder
    let project: Project?
    
    @State private var fileCount: Int = 0
    
    private var folderIcon: String {
        guard let project = project else { return "folder" }
        
        let folderName = folder.name ?? ""
        
        switch project.type {
        case .novel:
            switch folderName {
            case NSLocalizedString("folder.chapters", comment: "Chapters"):
                return "document.on.document"
            case NSLocalizedString("folder.characters", comment: "Characters"):
                return "person.2"
            case NSLocalizedString("folder.worldBuilding", comment: "World Building"):
                return "globe"
            case NSLocalizedString("folder.research", comment: "Research"):
                return "magnifyingglass"
            case NSLocalizedString("folder.notes", comment: "Notes"):
                return "note.text"
            default:
                return "folder"
            }
        case .script:
            switch folderName {
            case NSLocalizedString("folder.scenes", comment: "Scenes"):
                return "theatermasks"
            case NSLocalizedString("folder.characters", comment: "Characters"):
                return "person.2"
            case NSLocalizedString("folder.research", comment: "Research"):
                return "magnifyingglass"
            case NSLocalizedString("folder.notes", comment: "Notes"):
                return "note.text"
            default:
                return "folder"
            }
        case .poetry:
            switch folderName {
            case NSLocalizedString("folder.poems", comment: "Poems"):
                return "text.quote"
            case NSLocalizedString("folder.drafts", comment: "Drafts"):
                return "doc.text"
            case NSLocalizedString("folder.inspiration", comment: "Inspiration"):
                return "lightbulb"
            default:
                return "folder"
            }
        default:
            return "folder"
        }
    }
    
    var body: some View {
        NavigationLink(destination: FolderDetailView(folder: folder)) {
            HStack {
                Image(systemName: folderIcon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(folder.name ?? NSLocalizedString("folder.untitled", comment: "Untitled Folder"))
                
                Spacer()
                
                // Show file count
                if fileCount > 0 {
                    Text("\(fileCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .task {
            fileCount = folder.textFiles?.count ?? 0
        }
    }
}
