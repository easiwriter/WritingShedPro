import SwiftUI
import SwiftData

struct AddFileSheet: View {
    @Binding var isPresented: Bool
    let parentFolder: Folder
    let existingFiles: [TextFile]
    
    @State private var fileName = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(NSLocalizedString("addFile.fileName", comment: "File name field"), text: $fileName)
                        .accessibilityLabel(NSLocalizedString("addFile.fileNameAccessibility", comment: "File name accessibility"))
                        .onSubmit {
                            if !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                addFile()
                            }
                        }
                }
            }
            .navigationTitle(NSLocalizedString("addFile.title", comment: "Add file title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("addFile.cancel", comment: "Cancel button")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("addFile.add", comment: "Add button")) {
                        addFile()
                    }
                    .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(NSLocalizedString("addFile.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("addFile.ok", comment: "OK button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addFile() {
        // Check if folder allows files
        guard FolderCapabilityService.canAddFile(to: parentFolder) else {
            errorMessage = FolderCapabilityService.disallowedOperationMessage(for: parentFolder, operation: .addFile)
            showErrorAlert = true
            return
        }
        
        // Validate file name
        do {
            try NameValidator.validateFileName(fileName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Check uniqueness
        if !UniquenessChecker.isFileNameUnique(fileName, in: parentFolder) {
            // Determine if conflict is with active file or trashed file
            let conflict = UniquenessChecker.getFileNameConflict(fileName, in: parentFolder)
            if conflict == "trash" {
                errorMessage = NSLocalizedString("addFile.duplicateNameInTrash", comment: "File with this name exists in Trash")
            } else {
                errorMessage = NSLocalizedString("addFile.duplicateName", comment: "Duplicate file name error")
            }
            showErrorAlert = true
            return
        }
        
        // Create TextFile
        let newFile = TextFile(
            name: fileName,
            initialContent: "",
            parentFolder: parentFolder
        )
        modelContext.insert(newFile)
        
        // Save context to ensure relationships are updated immediately
        // This prevents duplicate name issues when quickly creating multiple files
        do {
            try modelContext.save()
            
            // Record significant event for review prompts
            ReviewManager.shared.recordSignificantEvent()
        } catch {
            #if DEBUG
            print("Error saving new file: \(error)")
            #endif
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }
        
        isPresented = false
    }
}
