import SwiftUI
import SwiftData

struct FileDetailView: View {
    @Bindable var file: TextFile
    
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var editedName: String = ""
    @State private var editedContent: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    
    init(file: TextFile) {
        self.file = file
        _editedName = State(initialValue: file.name)
        _editedContent = State(initialValue: file.currentVersion?.content ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Name field
            TextField(NSLocalizedString("fileDetail.fileName", comment: "File name field"), text: $editedName)
                .textFieldStyle(.roundedBorder)
                .padding()
                .accessibilityLabel(NSLocalizedString("fileDetail.fileNameAccessibility", comment: "File name accessibility"))
                .onSubmit {
                    validateAndUpdateName()
                }
            
            Divider()
            
            // Content editor
            TextEditor(text: $editedContent)
                .padding(.horizontal)
                .accessibilityLabel(NSLocalizedString("fileDetail.contentAccessibility", comment: "File content accessibility"))
                .onChange(of: editedContent) { oldValue, newValue in
                    file.currentVersion?.updateContent(newValue)
                }
        }
        .navigationTitle(NSLocalizedString("fileDetail.title", comment: "File details title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("fileDetail.done", comment: "Done button")) {
                    validateAndUpdateName()
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(NSLocalizedString("fileDetail.deleteAccessibility", comment: "Delete file accessibility"))
            }
        }
        .alert(NSLocalizedString("fileDetail.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("fileDetail.ok", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            String(format: NSLocalizedString("fileDetail.deleteConfirmationTitle", comment: "Delete confirmation title"), file.name),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("fileDetail.deleteButton", comment: "Delete button"), role: .destructive) {
                deleteFile()
            }
            Button(NSLocalizedString("fileDetail.cancel", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("fileDetail.deleteWarning", comment: "Delete warning"))
        }
    }
    
    private func validateAndUpdateName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't update if name hasn't changed
        guard trimmedName != file.name else { return }
        
        // Validate name
        do {
            try NameValidator.validateFileName(trimmedName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            editedName = file.name
            return
        }
        
        // Check uniqueness in parent folder (against both active and deleted files)
        if let parentFolder = file.parentFolder {
            // Check if name is unique (excluding current file being renamed)
            if !UniquenessChecker.isFileNameUnique(trimmedName, in: parentFolder) {
                // Only reject if it's a different file
                if !(parentFolder.textFiles ?? []).contains(where: { $0.id == file.id && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
                    // Determine if conflict is with active file or trashed file
                    let conflict = UniquenessChecker.getFileNameConflict(trimmedName, in: parentFolder)
                    if conflict == "trash" {
                        errorMessage = NSLocalizedString("fileDetail.duplicateNameInTrash", comment: "File with this name exists in Trash")
                    } else {
                        errorMessage = NSLocalizedString("fileDetail.duplicateName", comment: "Duplicate file name error")
                    }
                    showErrorAlert = true
                    editedName = file.name
                    return
                }
            }
        }
        
        // Update name
        file.name = trimmedName
    }
    
    private func deleteFile() {
        modelContext.delete(file)
        dismiss()
    }
}
