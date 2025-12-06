//
//  RenameCollectionModal.swift
//  Writing Shed Pro
//
//  Created on 6 December 2025.
//  Feature: Collection rename functionality
//

import SwiftUI
import SwiftData

/// Modal for renaming a single collection with duplicate name detection
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
    @FocusState private var isNameFieldFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Instructions
                Text("collectionsView.rename.prompt")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                // Text input field
                TextField("collectionsView.rename.placeholder", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .onAppear {
                        newName = collection.name ?? ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isNameFieldFocused = true
                        }
                    }
                
                Spacer()
            }
            .padding()
            .navigationTitle("collectionsView.rename.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("collectionsView.rename.confirm") {
                        handleRename()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newName == collection.name)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("collectionsView.rename.cancel") {
                        dismiss()
                    }
                }
            }
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
