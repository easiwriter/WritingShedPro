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
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddSection = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedSectionIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var sectionToEdit: ProseSection?
    
    /// Submission state
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    
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
        .toolbar {
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
        .sheet(item: $sectionToEdit) { section in
            EditContainerSheet(
                navigationTitle: NSLocalizedString("prose.section.rename.title", comment: "Rename Section"),
                nameLabel: NSLocalizedString("prose.section.title", comment: "Title"),
                synopsisLabel: NSLocalizedString("prose.section.synopsis", comment: "Synopsis"),
                synopsisFooter: NSLocalizedString("prose.section.synopsis.footer", comment: "Brief overview of the section"),
                initialName: section.name ?? "",
                initialSynopsis: section.synopsis ?? ""
            ) { updatedName, updatedSynopsis in
                updateSection(section, name: updatedName, synopsis: updatedSynopsis)
            }
        }
        .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                newSubmissionName = ""
            }
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createSubmissionFromSections(name: newSubmissionName)
                newSubmissionName = ""
            }
            .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(NSLocalizedString("submissions.name.message", comment: "Enter a name"))
        }
        .alert(NSLocalizedString("submissions.created.title", comment: "Submission Created"), isPresented: $showSubmissionCreated) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.created.message", comment: "Created message"), createdSubmissionName))
        }
        .alert(NSLocalizedString("submissions.duplicate.title", comment: "Duplicate Submission"), isPresented: $showDuplicateSubmission) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.duplicate.message", comment: "Duplicate message"), createdSubmissionName))
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
        // Add to submission button
        Button {
            showSubmissionNamePrompt = true
        } label: {
            Label(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"), systemImage: "tray.and.arrow.down")
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
                HStack {
                    if isEditMode {
                        SectionRowView(section: section)
                    } else {
                        NavigationLink {
                            ProseFilesView(project: project, section: section)
                        } label: {
                            SectionRowView(section: section)
                        }
                    }
                    
                    if !isEditMode {
                        Button {
                            sectionToEdit = section
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .imageScale(.large)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Enable drag-to-reorder without edit mode
                .onDrag {
                    return NSItemProvider(object: section.id.uuidString as NSString)
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
    
    private func updateSection(_ section: ProseSection, name: String, synopsis: String) {
        guard !name.isEmpty else { return }

        section.name = name
        section.synopsis = synopsis.isEmpty ? nil : synopsis
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
    
    private func createSubmissionFromSections(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check for duplicate
        let projectID = project.id
        var descriptor = FetchDescriptor<Submission>(predicate: #Predicate<Submission> { sub in
            sub.name == trimmedName && sub.project?.id == projectID && sub.isCollection == false
        })
        descriptor.fetchLimit = 1
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            createdSubmissionName = trimmedName
            showDuplicateSubmission = true
            return
        }
        
        let submission = Submission(
            project: project,
            submittedDate: Date()
        )
        submission.name = trimmedName
        submission.isCollection = false
        modelContext.insert(submission)
        
        // Link files from all selected sections
        for section in selectedSections {
            let files = (section.textFiles ?? []).filter { $0.trashItem == nil }
            for file in files {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: file.currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        try? modelContext.save()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        selectedSectionIDs.removeAll()
        exitEditMode()
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
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                // Section number
                if let userOrder = section.userOrder {
                    Text(String(format: NSLocalizedString("prose.section.number", comment: "Section X"), userOrder + 1))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled"))
                .font(.body)
                .fontWeight(.semibold)
            
            // Synopsis preview
            if let synopsis = section.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // File count
            let fileCount = section.textFiles?.count ?? 0
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.footnote)
                Text(String(format: NSLocalizedString("prose.section.fileCount", comment: "File count"), fileCount))
                    .font(.footnote)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
