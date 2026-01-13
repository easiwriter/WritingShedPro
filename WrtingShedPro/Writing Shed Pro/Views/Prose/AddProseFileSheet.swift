//
//  AddProseFileSheet.swift
//  Writing Shed Pro
//
//  Sheet for adding a new text file to a Prose project
//

import SwiftUI
import SwiftData

struct AddProseFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    
    @State private var fileName = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    /// Get the Prose folder for this project
    private var proseFolder: Folder? {
        project.folders?.first { $0.name == "Prose" }
    }
    
    var body: some View {
        NavigationView {
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
            .navigationTitle(NSLocalizedString("prose.files.add.title", comment: "Add File"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addFile()
                    }
                    .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(NSLocalizedString("addFile.error", comment: "Error"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func addFile() {
        guard let folder = proseFolder else {
            errorMessage = "Prose folder not found"
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
        if !UniquenessChecker.isFileNameUnique(fileName, in: folder) {
            let conflict = UniquenessChecker.getFileNameConflict(fileName, in: folder)
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
            parentFolder: folder
        )
        
        // Set initial workflow status
        newFile.workflowStatus = .draft
        
        modelContext.insert(newFile)
        
        do {
            try modelContext.save()
            ReviewManager.shared.recordSignificantEvent()
        } catch {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }
        
        dismiss()
    }
}
