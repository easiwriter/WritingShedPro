import SwiftUI
import SwiftData

struct AddFileSheet: View {
    @Binding var isPresented: Bool
    let parentFolder: Folder
    let existingFiles: [File]
    
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
            errorMessage = NSLocalizedString("addFile.duplicateName", comment: "Duplicate file name error")
            showErrorAlert = true
            return
        }
        
        // Create file
        let newFile = File(name: fileName, content: "")
        newFile.parentFolder = parentFolder
        modelContext.insert(newFile)
        
        // Add to parent folder's files array
        if parentFolder.files == nil {
            parentFolder.files = []
        }
        parentFolder.files?.append(newFile)
        
        isPresented = false
    }
}
