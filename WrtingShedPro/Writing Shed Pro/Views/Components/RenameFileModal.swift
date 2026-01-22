//
//  RenameFileModal.swift
//  Writing Shed Pro
//
//  Created on 3 December 2025.
//  Feature: File rename functionality
//

import SwiftUI
import SwiftData

/// View that presents an alert for renaming a file
/// This uses an alert with TextField which sizes correctly on all platforms
struct RenameFileModal: View {
    // MARK: - Properties
    
    /// The file being renamed
    let file: TextFile
    
    /// All files in the current folder (for duplicate detection)
    let filesInFolder: [TextFile]
    
    /// Callback when rename is confirmed
    let onRename: (String) -> Void
    
    /// Dismisses the modal
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    
    @State private var newName: String = ""
    @State private var showDuplicateWarning = false
    @State private var showRenameAlert = true
    
    // MARK: - Body
    
    var body: some View {
        Color.clear
            .alert("fileList.rename.title", isPresented: $showRenameAlert) {
                TextField("fileList.rename.placeholder", text: $newName)
                    .onAppear {
                        newName = file.name
                    }
                
                Button("fileList.rename.cancel", role: .cancel) {
                    dismiss()
                }
                
                Button("fileList.rename.confirm") {
                    handleRename()
                }
                .disabled(!canRename)
            } message: {
                Text("fileList.rename.prompt")
            }
            .alert("fileList.rename.duplicateTitle", isPresented: $showDuplicateWarning) {
                Button("fileList.rename.duplicateConfirm", role: .destructive) {
                    confirmRename()
                }
                Button("fileList.rename.duplicateCancel", role: .cancel) { }
            } message: {
                Text("fileList.rename.duplicateMessage")
            }
    }
    
    // MARK: - Computed Properties
    
    private var canRename: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty && newName != file.name
    }
    
    // MARK: - Private Methods
    
    /// Check for duplicates and show warning if found
    private func handleRename() {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        
        // Check if a file with this name already exists in the folder
        let hasDuplicate = filesInFolder.contains { otherFile in
            otherFile.id != file.id &&
            otherFile.name.lowercased() == trimmedName.lowercased()
        }
        
        if hasDuplicate {
            showDuplicateWarning = true
        } else {
            confirmRename()
        }
    }
    
    /// Perform the actual rename
    private func confirmRename() {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        file.name = trimmedName
        onRename(trimmedName)
        showRenameAlert = false
        dismiss()
    }
}
