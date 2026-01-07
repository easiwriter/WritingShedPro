//
//  RenameCollectionModal.swift
//  Writing Shed Pro
//
//  Created on 6 December 2025.
//  Feature: Collection rename functionality
//

import SwiftUI
import SwiftData

/// View that presents an alert for renaming a collection
/// This uses an alert with TextField which sizes correctly on all platforms
struct RenameCollectionModal: View {
    // MARK: - Properties
    
    /// The collection being renamed
    let collection: Submission
    
    /// All collections in the current project (for duplicate detection)
    let collectionsInProject: [Submission]
    
    /// Callback when rename is confirmed
    let onRename: (String) -> Void
    
    /// Dismisses the modal
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    
    @State private var newName: String = ""
    @State private var showDuplicateWarning = false
    
    // MARK: - Body
    
    var body: some View {
        Color.clear
            .alert("collectionsView.rename.title", isPresented: .constant(true)) {
                TextField("collectionsView.rename.placeholder", text: $newName)
                    .onAppear {
                        newName = collection.name ?? ""
                    }
                
                Button("collectionsView.rename.cancel", role: .cancel) {
                    dismiss()
                }
                
                Button("collectionsView.rename.confirm") {
                    handleRename()
                }
                .disabled(!canRename)
            } message: {
                Text("collectionsView.rename.prompt")
            }
            .alert("collectionsView.rename.duplicateTitle", isPresented: $showDuplicateWarning) {
                Button("collectionsView.rename.duplicateConfirm", role: .destructive) {
                    confirmRename()
                }
                Button("collectionsView.rename.duplicateCancel", role: .cancel) { }
            } message: {
                Text("collectionsView.rename.duplicateMessage")
            }
    }
    
    // MARK: - Computed Properties
    
    private var canRename: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty && newName != collection.name
    }
    
    // MARK: - Private Methods
    
    /// Check for duplicates and show warning if found
    private func handleRename() {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        
        // Check if a collection with this name already exists in the project
        let hasDuplicate = collectionsInProject.contains { otherCollection in
            otherCollection.id != collection.id &&
            (otherCollection.name ?? "").lowercased() == trimmedName.lowercased()
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
        collection.name = trimmedName
        collection.modifiedDate = Date()
        onRename(trimmedName)
        dismiss()
    }
}
