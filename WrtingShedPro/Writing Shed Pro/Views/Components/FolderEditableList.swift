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
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Custom Edit Button
                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation {
                        isEditMode.toggle()
                    }
                }
                .disabled(folders.isEmpty)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                // Sort Menu
                Menu {
                    ForEach(FolderSortService.sortOptions(), id: \.order) { option in
                        Button(action: {
                            selectedSortOrder = option.order
                        }) {
                            Label(option.title, systemImage: selectedSortOrder == option.order ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
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
            "Delete Folders",
            isPresented: $showDeleteConfirmation,
            presenting: foldersToDelete,
            actions: { _ in
                Button("Delete", role: .destructive) {
                    confirmDeleteFolders()
                }
                Button("Cancel", role: .cancel) {
                    foldersToDelete = nil
                }
            },
            message: { offsets in
                let count = offsets.count
                if count == 1 {
                    let folderName = sortedFolders[offsets.first ?? 0].name ?? "Untitled Folder"
                    return Text("Are you sure you want to delete \"\(folderName)\"? This will also delete all files and subfolders. This action cannot be undone.")
                } else {
                    return Text("Are you sure you want to delete \(count) folders? This will also delete all files and subfolders. This action cannot be undone.")
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
                let fileCount = folder.files?.count ?? 0
                if fileCount > 0 {
                    Text("\(fileCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
}