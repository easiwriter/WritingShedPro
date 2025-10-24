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
                HStack {
                    Text(NSLocalizedString("folderDetail.subfolders", comment: "Subfolders label"))
                    Spacer()
                    Text("\(folder.folders?.count ?? 0)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(NSLocalizedString("folderDetail.files", comment: "Files label"))
                    Spacer()
                    Text("\(folder.files?.count ?? 0)")
                        .foregroundStyle(.secondary)
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
    }
    
    private var deleteConfirmationMessage: String {
        let subfolderCount = folder.folders?.count ?? 0
        let fileCount = folder.files?.count ?? 0
        
        if subfolderCount > 0 || fileCount > 0 {
            return String(format: NSLocalizedString("folderDetail.deleteWarningWithContent", comment: "Delete warning with content"),
                         subfolderCount, fileCount)
        } else {
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
        
        // Check uniqueness in parent folder
        if let parentFolder = folder.parentFolder {
            // Get sibling folders (excluding current folder)
            let siblings = (parentFolder.folders ?? []).filter { $0.id != folder.id }
            if siblings.contains(where: { ($0.name ?? "").caseInsensitiveCompare(trimmedName) == .orderedSame }) {
                errorMessage = NSLocalizedString("folderDetail.duplicateName", comment: "Duplicate folder name error")
                showErrorAlert = true
                editedName = folder.name ?? ""
                return
            }
        } else {
            // Check uniqueness at root level (siblings in same project)
            if let project = folder.project {
                // This would require querying all root folders - simplified for now
                // In production, you'd fetch root folders and check uniqueness
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
