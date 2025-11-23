//
//  CollectionPickerView.swift
//  Writing Shed Pro
//
//  Feature 008c: Collections Management System
//  Allows selection of collections for bulk file/collection operations
//

import SwiftUI
import SwiftData

/// View for selecting a collection and performing bulk operations
/// Mirrors the SubmissionPickerView pattern for consistency
struct CollectionPickerView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    let filesToAddToCollection: [TextFile]?
    let collectionsToAddToPublication: [Submission]?
    let mode: CollectionPickerMode
    let onCollectionSelected: (Submission) -> Void
    let onCancel: () -> Void
    
    @Query private var allSubmissions: [Submission]
    @State private var showingNewCollectionSheet = false
    
    enum CollectionPickerMode {
        case addFilesToCollection  // From Ready folder
        case addCollectionsToPublication  // From Collections view
    }
    
    // Filter submissions to get only Collections for this project
    private var projectCollections: [Submission] {
        allSubmissions.filter { submission in
            submission.publication == nil && submission.project?.id == project.id
        }
        .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    private var pickerTitle: String {
        switch mode {
        case .addFilesToCollection:
            return "Add to Collection"
        case .addCollectionsToPublication:
            return "Add to Publication"
        }
    }
    
    var body: some View {
        List {
            // New Collection button section
            Section {
                Button(action: { showingNewCollectionSheet = true }) {
                    Label("collections.button.add", systemImage: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel(Text("accessibility.add.collection"))
            }
            
            // Existing collections
            if !projectCollections.isEmpty {
                Section {
                    ForEach(projectCollections) { collection in
                        Button(action: {
                            onCollectionSelected(collection)
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(collection.name ?? "Untitled Collection")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    if let submittedFiles = collection.submittedFiles {
                                        Text(String(format: NSLocalizedString("collections.files.count", comment: "Files in collection"), submittedFiles.count))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.collection.select", comment: "Select collection"), collection.name ?? "Untitled")))
                    }
                } header: {
                    Text("collections.existing.title")
                }
            } else {
                // Empty state
                Section {
                    ContentUnavailableView {
                        Label("collections.empty.title", systemImage: "folder")
                    } description: {
                        Text("collections.empty.message")
                    }
                }
            }
        }
        .navigationTitle(pickerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    onCancel()
                }
            }
        }
        .sheet(isPresented: $showingNewCollectionSheet) {
            NavigationStack {
                NewCollectionForBulkOperationView(
                    project: project,
                    filesToAdd: filesToAddToCollection,
                    collectionsToAdd: collectionsToAddToPublication,
                    mode: mode,
                    onCollectionCreated: { collection in
                        showingNewCollectionSheet = false
                        onCollectionSelected(collection)
                    },
                    onCancel: {
                        showingNewCollectionSheet = false
                    }
                )
            }
        }
    }
}

/// View for creating a new collection during bulk operation flow
struct NewCollectionForBulkOperationView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    let filesToAdd: [TextFile]?
    let collectionsToAdd: [Submission]?
    let mode: CollectionPickerView.CollectionPickerMode
    let onCollectionCreated: (Submission) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                TextField("collections.form.name.placeholder", text: $name)
                    .accessibilityLabel(Text("collections.form.name.label"))
            } header: {
                Text("collections.form.name.label")
            }
            
            // Show what will be added to the collection
            if let filesToAdd = filesToAdd, !filesToAdd.isEmpty {
                Section {
                    ForEach(filesToAdd, id: \.id) { file in
                        Text(file.name)
                            .font(.body)
                    }
                } header: {
                    Text(String(format: NSLocalizedString("collections.files.selected", comment: "Files selected"), filesToAdd.count))
                }
            } else if let collectionsToAdd = collectionsToAdd, !collectionsToAdd.isEmpty {
                Section {
                    ForEach(collectionsToAdd, id: \.id) { collection in
                        Text(collection.name ?? "Untitled Collection")
                            .font(.body)
                    }
                } header: {
                    Text(String(format: NSLocalizedString("collections.collections.selected", comment: "Collections selected"), collectionsToAdd.count))
                }
            }
        }
        .navigationTitle("collections.new.quick.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("error.title", isPresented: $showingError) {
            Button("button.ok", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    onCancel()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("collections.button.create") {
                    createCollection()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    private func createCollection() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = NSLocalizedString(
                "collections.error.emptyName",
                comment: "Error message for empty collection name"
            )
            showingError = true
            return
        }
        
        // Create new Submission (Collection)
        let newCollection = Submission(
            publication: nil,
            project: project
        )
        newCollection.name = trimmedName
        
        modelContext.insert(newCollection)
        
        do {
            try modelContext.save()
            onCollectionCreated(newCollection)
        } catch {
            errorMessage = NSLocalizedString(
                "collections.error.saveFailed",
                comment: "Error message when saving collection failed"
            )
            showingError = true
        }
    }
}
