//
//  PoetryCollectionsView.swift
//  Writing Shed Pro
//
//  Feature 036: Poetry-specific collections management
//  Lists and manages PoetryCollection objects for a Poetry project
//

import SwiftUI
import SwiftData

/// List view showing all poetry collections for a Poetry project
struct PoetryCollectionsView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddCollection = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedCollectionIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showRenameSheet = false
    @State private var collectionToRename: PoetryCollection?
    @State private var newCollectionName: String = ""
    
    // MARK: - Computed
    
    private var sortedCollections: [PoetryCollection] {
        (project.poetryCollections ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedCollections: [PoetryCollection] {
        sortedCollections.filter { selectedCollectionIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedCollectionIDs.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedCollections.isEmpty {
                emptyState
            } else {
                collectionList
            }
        }
        .navigationTitle(NSLocalizedString("poetry.collections.title", comment: "Collections"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAddCollection = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("poetry.collections.add", comment: "Add collection"))
                .disabled(isEditMode)
                
                // Edit/Done button
                if !sortedCollections.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedCollectionIDs.removeAll()
                            } else {
                                editMode = .active
                            }
                        }
                    } label: {
                        Text(isEditMode ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
                    }
                }
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .sheet(isPresented: $showAddCollection) {
            AddPoetryCollectionSheet(project: project)
        }
        .alert(
            selectedCollections.count == 1
                ? NSLocalizedString("poetry.collections.deleteConfirm.title", comment: "Delete collection?")
                : String(format: NSLocalizedString("poetry.collections.deleteMultiple.title", comment: "Delete collections?"), selectedCollections.count),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSelectedCollections()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            if selectedCollections.count == 1, let collection = selectedCollections.first {
                Text(String(format: NSLocalizedString("poetry.collections.deleteConfirm.message", comment: "Delete message"), collection.name ?? ""))
            } else {
                Text(NSLocalizedString("poetry.collections.deleteMultiple.message", comment: "Poems in these collections will be unassigned but not deleted."))
            }
        }
        .alert(NSLocalizedString("poetry.collection.rename.title", comment: "Rename Collection"), isPresented: $showRenameSheet) {
            TextField(NSLocalizedString("poetry.collection.name", comment: "Name"), text: $newCollectionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                collectionToRename = nil
                newCollectionName = ""
            }
            Button(NSLocalizedString("button.rename", comment: "Rename")) {
                if let collection = collectionToRename {
                    renameCollection(collection, to: newCollectionName)
                }
                collectionToRename = nil
                newCollectionName = ""
            }
            .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedCollectionIDs.removeAll()
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Rename button (only for single selection)
        if selectedCollections.count == 1 {
            Button {
                if let collection = selectedCollections.first {
                    collectionToRename = collection
                    newCollectionName = collection.name ?? ""
                    showRenameSheet = true
                }
            } label: {
                Label(NSLocalizedString("button.rename", comment: "Rename"), systemImage: "pencil")
            }
        }
        
        Spacer()
        
        // Delete button
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(
                String(format: NSLocalizedString("poetry.collections.deleteCount", comment: "Delete count"), selectedCollections.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedCollections.isEmpty)
    }
    
    // MARK: - Collection List
    
    private var collectionList: some View {
        List(selection: $selectedCollectionIDs) {
            ForEach(sortedCollections) { collection in
                Group {
                    if isEditMode {
                        CollectionRowView(collection: collection)
                    } else {
                        NavigationLink {
                            PoetryCollectionPoemsView(project: project, collection: collection)
                        } label: {
                            CollectionRowView(collection: collection)
                        }
                    }
                }
                .onDrag {
                    return NSItemProvider(object: collection.id.uuidString as NSString)
                }
            }
            .onMove(perform: moveCollections)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("poetry.collections.empty.title", comment: "No Collections"))
                .font(.headline)
            
            Text(NSLocalizedString("poetry.collections.empty.message", comment: "Create collections to group your poems for manuscript assembly."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddCollection = true
            } label: {
                Label(NSLocalizedString("poetry.collections.add", comment: "Add Collection"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Actions
    
    private func deleteSelectedCollections() {
        for collection in selectedCollections {
            // Unassign poems first (don't delete them)
            for file in collection.textFiles ?? [] {
                file.poetryCollection = nil
            }
            // Remove from Body Matter if included
            collection.isInBodyMatter = false
            collection.bodyMatterOrder = nil
            
            modelContext.delete(collection)
        }
        
        try? modelContext.save()
        selectedCollectionIDs.removeAll()
        editMode = .inactive
    }
    
    private func renameCollection(_ collection: PoetryCollection, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        collection.name = trimmed
        collection.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func moveCollections(from source: IndexSet, to destination: Int) {
        var collections = sortedCollections
        collections.move(fromOffsets: source, toOffset: destination)
        for (index, collection) in collections.enumerated() {
            collection.userOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Collection Row View

struct CollectionRowView: View {
    let collection: PoetryCollection
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled"))
                    .font(.body)
                
                HStack(spacing: 8) {
                    let fileCount = collection.textFiles?.count ?? 0
                    Text(String(format: NSLocalizedString("poetry.collection.poemCount", comment: "%d poems"), fileCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if collection.isInBodyMatter {
                        Text(NSLocalizedString("poetry.collection.inBodyMatter", comment: "In Body Matter"))
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
