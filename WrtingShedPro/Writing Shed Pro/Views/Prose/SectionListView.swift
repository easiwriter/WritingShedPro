//
//  SectionListView.swift
//  Writing Shed Pro
//
//  Prose Section management - Sections contain text files
//

import SwiftUI
import SwiftData

/// List view showing all sections for a Prose project
struct SectionListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddSection = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedSectionIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showRenameSheet = false
    @State private var sectionToRename: ProseSection?
    @State private var newSectionName: String = ""
    
    // MARK: - Computed
    
    private var sortedSections: [ProseSection] {
        (project.sections ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedSections: [ProseSection] {
        sortedSections.filter { selectedSectionIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedSectionIDs.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedSections.isEmpty {
                emptyState
            } else {
                sectionList
            }
        }
        .navigationTitle(NSLocalizedString("prose.sections.title", comment: "Sections"))
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
                    showAddSection = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("prose.sections.add", comment: "Add section"))
                .disabled(isEditMode)
                
                // Edit/Done button
                if !sortedSections.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedSectionIDs.removeAll()
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
        .sheet(isPresented: $showAddSection) {
            AddSectionSheet(project: project)
        }
        .alert(
            selectedSections.count == 1 
                ? NSLocalizedString("prose.sections.deleteConfirm.title", comment: "Delete section?")
                : String(format: NSLocalizedString("prose.sections.deleteMultiple.title", comment: "Delete sections?"), selectedSections.count),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSelectedSections()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            if selectedSections.count == 1, let section = selectedSections.first {
                Text(String(format: NSLocalizedString("prose.sections.deleteConfirm.message", comment: "Delete message"), section.name ?? ""))
            } else {
                Text(NSLocalizedString("prose.sections.deleteMultiple.message", comment: "Files in these sections will be unassigned but not deleted."))
            }
        }
        .alert(NSLocalizedString("prose.section.rename.title", comment: "Rename Section"), isPresented: $showRenameSheet) {
            TextField(NSLocalizedString("prose.section.title", comment: "Title"), text: $newSectionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                sectionToRename = nil
                newSectionName = ""
            }
            Button(NSLocalizedString("button.rename", comment: "Rename")) {
                if let section = sectionToRename {
                    renameSection(section, to: newSectionName)
                }
                sectionToRename = nil
                newSectionName = ""
            }
            .disabled(newSectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedSectionIDs.removeAll()
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Rename button (only for single selection)
        if selectedSections.count == 1 {
            Button {
                if let section = selectedSections.first {
                    sectionToRename = section
                    newSectionName = section.name ?? ""
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
                String(format: NSLocalizedString("prose.sections.deleteCount", comment: "Delete count"), selectedSections.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedSections.isEmpty)
    }
    
    // MARK: - Section List
    
    private var sectionList: some View {
        List(selection: $selectedSectionIDs) {
            ForEach(sortedSections) { section in
                if isEditMode {
                    SectionRowView(section: section)
                } else {
                    NavigationLink {
                        ProseFilesView(project: project, section: section)
                    } label: {
                        SectionRowView(section: section)
                    }
                }
            }
            .onMove(perform: moveSections)
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
            
            Text(NSLocalizedString("prose.sections.empty.title", comment: "No sections"))
                .font(.headline)
            
            Text(NSLocalizedString("prose.sections.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddSection = true
            } label: {
                Label(NSLocalizedString("prose.sections.add", comment: "Add section"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteSelectedSections() {
        for section in selectedSections {
            // Unassign files from section (don't delete them)
            if let textFiles = section.textFiles {
                for file in textFiles {
                    file.section = nil
                }
            }
            modelContext.delete(section)
        }
        
        try? modelContext.save()
        selectedSectionIDs.removeAll()
        renumberSections()
        exitEditMode()
    }
    
    private func renameSection(_ section: ProseSection, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        section.name = trimmedName
        section.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func moveSections(from source: IndexSet, to destination: Int) {
        var sections = sortedSections
        sections.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, section) in sections.enumerated() {
            section.userOrder = index
        }
        
        try? modelContext.save()
    }
    
    private func renumberSections() {
        for (index, section) in sortedSections.enumerated() {
            section.userOrder = index
        }
        try? modelContext.save()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
}

// MARK: - Section Row View

struct SectionRowView: View {
    let section: ProseSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Section number
                if let userOrder = section.userOrder {
                    Text(String(format: NSLocalizedString("prose.section.number", comment: "Section X"), userOrder + 1))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled"))
                .font(.headline)
            
            // Synopsis preview
            if let synopsis = section.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // File count
            let fileCount = section.textFiles?.count ?? 0
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text(String(format: NSLocalizedString("prose.section.fileCount", comment: "File count"), fileCount))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
