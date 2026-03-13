import SwiftUI
import SwiftData

struct FolderDetailView: View {
    @Bindable var folder: Folder
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var editedName: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var subfolderCount: Int = 0
    @State private var fileCount: Int = 0
    
    init(folder: Folder) {
        self.folder = folder
        _editedName = State(initialValue: folder.name ?? "")
    }
    
    var body: some View {
        Form {
            Section(NSLocalizedString("folderDetail.nameSection", comment: "Name section header")) {
                TextField(NSLocalizedString("folderDetail.folderName", comment: "Folder name field"), text: $editedName)
                    .accessibilityLabel(NSLocalizedString("folderDetail.folderNameAccessibility", comment: "Folder name accessibility"))
                    .onSubmit {
                        validateAndUpdateName()
                    }
            }
            
            Section {
                if subfolderCount > 0 && fileCount > 0 {
                    // Show both subfolders and files
                    HStack {
                        Text(NSLocalizedString("folderDetail.subfolders", comment: "Subfolders label"))
                        Spacer()
                        Text("\(subfolderCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(NSLocalizedString("folderDetail.files", comment: "Files label"))
                        Spacer()
                        Text("\(fileCount)")
                            .foregroundStyle(.secondary)
                    }
                } else if subfolderCount > 0 {
                    // Show only subfolders
                    HStack {
                        Text(NSLocalizedString("folderDetail.subfolders", comment: "Subfolders label"))
                        Spacer()
                        Text("\(subfolderCount)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Show only files (or both at 0)
                    HStack {
                        Text(NSLocalizedString("folderDetail.files", comment: "Files label"))
                        Spacer()
                        Text("\(fileCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(NSLocalizedString("folderDetail.delete", comment: "Delete button"), systemImage: "trash")
                }
                .accessibilityLabel(NSLocalizedString("folderDetail.deleteAccessibility", comment: "Delete folder accessibility"))
            }
        }
        .navigationTitle(NSLocalizedString("folderDetail.title", comment: "Folder details title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("folderDetail.done", comment: "Done button")) {
                    validateAndUpdateName()
                }
            }
        }
        .alert(NSLocalizedString("folderDetail.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("folderDetail.ok", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            String(format: NSLocalizedString("folderDetail.deleteConfirmationTitle", comment: "Delete confirmation title"), folder.name ?? ""),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("folderDetail.deleteButton", comment: "Delete button"), role: .destructive) {
                deleteFolder()
            }
            Button(NSLocalizedString("folderDetail.cancel", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(deleteConfirmationMessage)
        }
        .task {
            subfolderCount = folder.folders?.count ?? 0
            fileCount = folder.textFiles?.count ?? 0
        }
    }
    
    private var deleteConfirmationMessage: String {
        
        if subfolderCount > 0 && fileCount > 0 {
            // Has both subfolders and files
            return String(format: NSLocalizedString("folderDetail.deleteWarningWithBoth", comment: "Delete warning with subfolders and files"),
                         subfolderCount, fileCount)
        } else if subfolderCount > 0 {
            // Has only subfolders
            return String(format: NSLocalizedString("folderDetail.deleteWarningWithSubfolders", comment: "Delete warning with subfolders"),
                         subfolderCount)
        } else if fileCount > 0 {
            // Has only files
            return String(format: NSLocalizedString("folderDetail.deleteWarningWithFiles", comment: "Delete warning with files"),
                         fileCount)
        } else {
            // Empty folder
            return NSLocalizedString("folderDetail.deleteWarning", comment: "Delete warning")
        }
    }
    
    private func validateAndUpdateName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't update if name hasn't changed
        guard trimmedName != folder.name else { return }
        
        // Validate name
        do {
            try NameValidator.validateFolderName(trimmedName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            editedName = folder.name ?? ""
            return
        }
        
        // Check uniqueness within parent folder or project
        if let project = folder.project {
            if !UniquenessChecker.isFolderNameUnique(trimmedName, in: project, parentFolder: folder.parentFolder, excludingFolder: folder) {
                errorMessage = NSLocalizedString("folderDetail.duplicateName", comment: "Duplicate folder name error")
                showErrorAlert = true
                editedName = folder.name ?? ""
                return
            }
        }
        
        // Update name
        folder.name = trimmedName
    }
    
    private func deleteFolder() {
        modelContext.delete(folder)
        dismiss()
    }
}
