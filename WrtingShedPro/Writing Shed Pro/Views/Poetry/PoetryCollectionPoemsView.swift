//
//  PoetryCollectionPoemsView.swift
//  Writing Shed Pro
//
//  Feature 036: Detail view for a PoetryCollection
//  Shows poems assigned to this collection, supports add/remove/reorder
//

import SwiftUI
import SwiftData

/// View for displaying and managing poems within a poetry collection
struct PoetryCollectionPoemsView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    @Bindable var collection: PoetryCollection
    
    // MARK: - State
    
    @State private var showAddPoemsSheet = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var showRemoveConfirmation = false
    
    // MARK: - Computed
    
    private var sortedFiles: [TextFile] {
        (collection.textFiles ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedFiles: [TextFile] {
        sortedFiles.filter { selectedFileIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedFileIDs.isEmpty
    }
    
    /// Available poems: ready-status poems from Poems folder not yet in this collection
    private var availablePoems: [TextFile] {
        let poemsFolder = project.folders?.first { $0.name == "Poems" }
        let allPoems = poemsFolder?.textFiles ?? []
        let assignedIDs = Set((collection.textFiles ?? []).map { $0.id })
        return allPoems.filter { $0.workflowStatus == .ready && !assignedIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedFiles.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
        .navigationTitle(collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled"))
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
                    showAddPoemsSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("poetry.collection.addPoems", comment: "Add poems"))
                .disabled(availablePoems.isEmpty || isEditMode)
                
                // Edit/Done button
                if !sortedFiles.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedFileIDs.removeAll()
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
        .sheet(isPresented: $showAddPoemsSheet) {
            addPoemsSheet
        }
        .alert(
            selectedFiles.count == 1
                ? NSLocalizedString("poetry.collection.removeConfirm.title", comment: "Remove from collection?")
                : String(format: NSLocalizedString("poetry.collection.removeMultiple.title", comment: "Remove poems?"), selectedFiles.count),
            isPresented: $showRemoveConfirmation
        ) {
            Button(NSLocalizedString("button.remove", comment: "Remove"), role: .destructive) {
                removeSelectedFiles()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("poetry.collection.removeConfirm.message", comment: "Poems will be unassigned from this collection but not deleted."))
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedFileIDs.removeAll()
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        Spacer()
        
        // Remove button (unassign from collection)
        Button(role: .destructive) {
            showRemoveConfirmation = true
        } label: {
            Label(
                String(format: NSLocalizedString("poetry.collection.removeCount", comment: "Remove count"), selectedFiles.count),
                systemImage: "minus.circle"
            )
        }
        .disabled(selectedFiles.isEmpty)
    }
    
    // MARK: - File List
    
    private var fileList: some View {
        List(selection: $selectedFileIDs) {
            ForEach(sortedFiles) { file in
                Group {
                    if isEditMode {
                        PoemRowView(file: file)
                    } else {
                        NavigationLink {
                            FileEditView(file: file)
                        } label: {
                            PoemRowView(file: file)
                        }
                    }
                }
            }
            .onMove(perform: moveFiles)
            .onDelete(perform: deleteFiles)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("poetry.collection.empty.title", comment: "No Poems"))
                .font(.headline)
            
            Text(NSLocalizedString("poetry.collection.empty.message", comment: "Add poems with 'ready' status to this collection."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if !availablePoems.isEmpty {
                Button {
                    showAddPoemsSheet = true
                } label: {
                    Label(NSLocalizedString("poetry.collection.addPoems", comment: "Add Poems"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Add Poems Sheet
    
    @ViewBuilder
    private var addPoemsSheet: some View {
        NavigationStack {
            List {
                ForEach(availablePoems) { file in
                    Button {
                        addPoemToCollection(file)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.blue)
                            Text(file.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("poetry.collection.addPoems.title", comment: "Add Poems"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        showAddPoemsSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addPoemToCollection(_ file: TextFile) {
        file.poetryCollection = collection
        let nextOrder = (sortedFiles.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
        file.userOrder = nextOrder
        collection.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func removeSelectedFiles() {
        for file in selectedFiles {
            file.poetryCollection = nil
        }
        collection.modifiedDate = Date()
        try? modelContext.save()
        selectedFileIDs.removeAll()
        editMode = .inactive
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = sortedFiles[index]
            file.poetryCollection = nil
        }
        collection.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        var files = sortedFiles
        files.move(fromOffsets: source, toOffset: destination)
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        collection.modifiedDate = Date()
        try? modelContext.save()
    }
}

// MARK: - Poem Row View

struct PoemRowView: View {
    let file: TextFile
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                
                if let version = file.currentVersion {
                    let charCount = version.content.count
                    Text(String(format: NSLocalizedString("poetry.collection.charCount", comment: "%d characters"), charCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
