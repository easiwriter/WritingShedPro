//
//  ProseListView.swift
//  Writing Shed Pro
//
//  List view for managing text files in Prose projects
//  Analogous to SceneListView for Fiction/Drama
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// List view showing text files for a Prose project
/// Supports:
/// - Workflow status filtering
/// - Edit mode with multi-select
/// - Assignment to Sections
struct ProseListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    /// Optional section - if provided, shows files for that section only
    let section: ProseSection?
    
    // MARK: - State
    
    @State private var showAddFile = false
    
    /// Edit mode binding
    @State private var editMode: EditMode = .inactive
    
    /// Selected file IDs for multi-select
    @State private var selectedFileIDs: Set<UUID> = []
    
    /// Delete confirmation dialog
    @State private var showDeleteConfirmation = false
    @State private var filesToDelete: [TextFile] = []
    
    /// Show section picker for assigning files to sections
    @State private var showSectionPicker = false
    
    /// Show workflow status picker
    @State private var showStatusPicker = false
    
    /// Workflow status filter (nil = show all)
    @State private var statusFilter: WorkflowStatus? = nil
    
    // MARK: - Init
    
    init(project: Project, section: ProseSection? = nil) {
        self.project = project
        self.section = section
    }
    
    // MARK: - Computed
    
    /// Get the Prose folder for this project
    private var proseFolder: Folder? {
        project.folders?.first { $0.name == "Prose" }
    }
    
    /// All files in the Prose folder (or section if provided)
    private var allFiles: [TextFile] {
        if let section = section {
            return (section.textFiles ?? []).filter { $0.trashItem == nil }
        }
        guard let folder = proseFolder else { return [] }
        return (folder.textFiles ?? []).filter { $0.trashItem == nil }
    }
    
    private var sortedFiles: [TextFile] {
        var result = allFiles
        
        // Sort by userOrder if in a section, otherwise alphabetically
        if section != nil {
            result = result.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        } else {
            result = result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        
        // Apply workflow status filter if set
        if let filter = statusFilter {
            result = result.filter { $0.workflowStatus == filter }
        }
        
        return result
    }
    
    /// Count files by workflow status
    private func fileCount(for status: WorkflowStatus?) -> Int {
        if let status = status {
            return allFiles.filter { $0.workflowStatus == status }.count
        }
        return allFiles.count
    }
    
    private var title: String {
        if let section = section {
            return section.name ?? NSLocalizedString("prose.files.title", comment: "Files")
        }
        return NSLocalizedString("prose.folder.title", comment: "Prose")
    }
    
    /// Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode == .active
    }
    
    /// Selected files based on selectedFileIDs
    private var selectedFiles: [TextFile] {
        sortedFiles.filter { selectedFileIDs.contains($0.id) }
    }
    
    /// Whether bottom toolbar should show
    private var showToolbar: Bool {
        isEditMode && !selectedFileIDs.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            workflowStatusFilter
            
            Group {
                if sortedFiles.isEmpty && statusFilter == nil {
                    emptyState
                } else if sortedFiles.isEmpty {
                    // Filtered but no results
                    ContentUnavailableView {
                        Label(NSLocalizedString("workflow.filter.noResults", comment: "No files"), systemImage: "doc.text")
                    } description: {
                        Text(NSLocalizedString("workflow.filter.noResultsHint", comment: "No files with this status"))
                    }
                } else {
                    fileList
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Add file button (hidden when viewing a section's files)
                if section == nil {
                    Button {
                        showAddFile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("prose.files.add", comment: "Add file"))
                    .disabled(editMode == .active)
                }
                
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
        .sheet(isPresented: $showAddFile) {
            AddProseFileSheet(project: project)
        }
        .sheet(isPresented: $showSectionPicker) {
            SectionPickerSheet(
                project: project,
                selectedFiles: selectedFiles.filter { $0.workflowStatus == .ready },
                onAssign: { section in
                    let readyFiles = selectedFiles.filter { $0.workflowStatus == .ready }
                    assignFilesToSection(readyFiles, section: section)
                    showSectionPicker = false
                    exitEditMode()
                },
                onCancel: {
                    showSectionPicker = false
                }
            )
        }
        .sheet(isPresented: $showStatusPicker) {
            WorkflowStatusPickerSheet(
                files: selectedFiles,
                onStatusSelected: { newStatus in
                    changeFilesStatus(selectedFiles, to: newStatus)
                    showStatusPicker = false
                    exitEditMode()
                },
                onCancel: {
                    showStatusPicker = false
                }
            )
        }
        .confirmationDialog(
            filesToDelete.count == 1
                ? NSLocalizedString("fileList.deleteFile.title", comment: "Delete file?")
                : String(format: NSLocalizedString("fileList.deleteFiles.title", comment: "Delete files?"), filesToDelete.count),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("fileList.delete", comment: "Move to Trash"), role: .destructive) {
                moveFilesToTrash(filesToDelete)
                filesToDelete = []
                exitEditMode()
            }
            Button(NSLocalizedString("fileList.deletePermanently", comment: "Delete Forever"), role: .destructive) {
                deleteFilesPermanently(filesToDelete)
                filesToDelete = []
                exitEditMode()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                filesToDelete = []
            }
        } message: {
            Text(NSLocalizedString("fileList.deleteConfirmation.messageEnhanced", comment: "Delete moves to trash, Delete Forever is permanent"))
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedFileIDs.removeAll()
            }
        }
    }
    
    // MARK: - Workflow Status Filter
    
    @ViewBuilder
    private var workflowStatusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                workflowStatusButton(nil, label: NSLocalizedString("workflow.filter.all", comment: "All"), count: fileCount(for: nil))
                
                ForEach(WorkflowStatus.allCases, id: \.self) { status in
                    workflowStatusButton(status, label: status.localizedName, count: fileCount(for: status))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private func workflowStatusButton(_ status: WorkflowStatus?, label: String, count: Int) -> some View {
        let isSelected = statusFilter == status
        
        Button {
            withAnimation {
                statusFilter = status
            }
        } label: {
            Text("\(label) (\(count))")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Change Status button
        Button {
            showStatusPicker = true
        } label: {
            Label(
                NSLocalizedString("fileList.changeStatus", comment: "Change status"),
                systemImage: "arrow.triangle.2.circlepath"
            )
        }
        .disabled(selectedFiles.isEmpty)
        
        // Add to Section button (main file list only, ready files only)
        if section == nil {
            let readyFiles = selectedFiles.filter { $0.workflowStatus == .ready }
            Button {
                showSectionPicker = true
            } label: {
                Label(
                    NSLocalizedString("prose.files.addToSection", comment: "Add to Section"),
                    systemImage: "doc.text"
                )
            }
            .disabled(readyFiles.isEmpty)
        }
        
        Spacer()
        
        Button(role: .destructive) {
            prepareDelete(selectedFiles)
        } label: {
            Label(
                String(format: NSLocalizedString("fileList.deleteCount", comment: "Delete count"), selectedFiles.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedFiles.isEmpty)
    }
    
    // MARK: - File List
    
    private var fileList: some View {
        List(selection: $selectedFileIDs) {
            ForEach(sortedFiles) { file in
                fileRow(for: file)
                    // Enable drag-to-reorder without edit mode (only when within a section)
                    .onDrag {
                        return NSItemProvider(object: file.id.uuidString as NSString)
                    }
            }
            .onMove(perform: section != nil ? moveFiles : nil)
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private func fileRow(for file: TextFile) -> some View {
        if isEditMode {
            FileRowView(file: file)
        } else {
            NavigationLink {
                FileEditView(file: file)
            } label: {
                FileRowView(file: file)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label(NSLocalizedString("prose.files.empty.title", comment: "No Files Yet"), systemImage: "doc.text")
        } description: {
            Text(NSLocalizedString("prose.files.empty.message", comment: "Add files to start writing"))
        } actions: {
            if section == nil {
                Button {
                    showAddFile = true
                } label: {
                    Text(NSLocalizedString("prose.files.add", comment: "Add File"))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Actions
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
            selectedFileIDs.removeAll()
        }
    }
    
    private func prepareDelete(_ files: [TextFile]) {
        filesToDelete = files
        showDeleteConfirmation = true
    }
    
    private func moveFilesToTrash(_ files: [TextFile]) {
        for file in files {
            guard let originalFolder = file.parentFolder else { continue }
            
            // Create TrashItem
            let trashItem = TrashItem(
                textFile: file,
                originalFolder: originalFolder,
                project: project
            )
            modelContext.insert(trashItem)
            
            // Remove from section if assigned
            file.section = nil
            file.modifiedDate = Date()
        }
        try? modelContext.save()
    }
    
    private func deleteFilesPermanently(_ files: [TextFile]) {
        for file in files {
            modelContext.delete(file)
        }
        try? modelContext.save()
    }
    
    private func assignFilesToSection(_ files: [TextFile], section: ProseSection?) {
        for file in files {
            file.section = section
        }
        try? modelContext.save()
    }
    
    private func changeFilesStatus(_ files: [TextFile], to newStatus: WorkflowStatus) {
        for file in files {
            file.workflowStatus = newStatus
        }
        try? modelContext.save()
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        var files = sortedFiles
        files.move(fromOffsets: source, toOffset: destination)
        
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        
        try? modelContext.save()
    }
}

// MARK: - File Row View

private struct FileRowView: View {
    let file: TextFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(file.name.isEmpty ? NSLocalizedString("prose.untitled", comment: "Untitled") : file.name)
                    .font(.headline)
                
                Spacer()
                
                // Workflow status indicator
                if let status = file.workflowStatus {
                    Text(status.localizedName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(status.color).opacity(0.2))
                        .foregroundColor(Color(status.color))
                        .clipShape(Capsule())
                }
            }
            
            // Section assignment
            if let section = file.section {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                    Text(section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled"))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
