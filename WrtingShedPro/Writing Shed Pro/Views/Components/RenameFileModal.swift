//
//  RenameFileModal.swift
//  Writing Shed Pro
//
//  Created on 3 December 2025.
//  Feature: File rename functionality
//

import SwiftUI
import SwiftData

/// Modal for renaming a single file with duplicate name detection
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
    @FocusState private var isNameFieldFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Instructions
                Text("fileList.rename.prompt")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                // Text input field
                TextField("fileList.rename.placeholder", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .onAppear {
                        newName = file.name
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isNameFieldFocused = true
                        }
                    }
                
                Spacer()
            }
            .padding()
            .navigationTitle("fileList.rename.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("fileList.rename.confirm") {
                        handleRename()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newName == file.name)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("fileList.rename.cancel") {
                        dismiss()
                    }
                }
            }
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
        dismiss()
    }
}
