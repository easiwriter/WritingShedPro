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
    
    /// Show container assignment dialog
    @State private var showContainerAssignment = false
    @State private var filesToAssign: [TextFile] = []
    
    /// Show workflow status picker
    @State private var showStatusPicker = false
    
    /// Workflow status filter (nil = show all)
    @State private var statusFilter: WorkflowStatus? = nil
    
    /// Rename state
    @State private var showRenameSheet = false
    @State private var fileToRename: TextFile?
    
    /// File details state
    @State private var showFileDetails = false
    @State private var fileForDetails: TextFile?
    
    /// Export state
    @State private var showExportMenu = false
    @State private var filesToExport: [TextFile] = []
    @State private var showExportSaveDialog = false
    @State private var exportFormat: ExportFormat = .rtf
    @State private var exportData: Data?
    @State private var exportFilename: String = ""
    @State private var showExportImageWarning = false
    @State private var pendingExportAction: (() -> Void)?
    
    /// Copy to Project state
    @State private var showCopyToProject = false
    @State private var showCopyResult = false
    @State private var copyResultMessage = ""
    @State private var copyResultIsError = false
    
    /// Search state
    @State private var showSearchView = false
    
    /// Import state
    @State private var showImportPicker = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    
    /// Submission state
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    
    /// Header/Footer editor state
    @State private var showHeaderFooterEditor = false
    @State private var showHeaderFooterWarning = false
    
    @State private var headerLeft: String = ""
    @State private var headerCenter: String = ""
    @State private var headerRight: String = ""
    @State private var footerLeft: String = ""
    @State private var footerCenter: String = ""
    @State private var footerRight: String = ""
    @State private var headerInsertTarget: HeaderFooterField = .left
    @State private var footerInsertTarget: HeaderFooterField = .left
    @State private var showHeaderElementPicker = false
    @State private var showFooterElementPicker = false
    
    /// Collapsible section state - tracks which sections are expanded
    @State private var expandedSections: Set<String> = []
    
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
        var result: [TextFile] = allFiles
        
        // Sort by userOrder for drag-to-reorder, with name as secondary sort
        result = result.sorted { (a: TextFile, b: TextFile) -> Bool in
            let order0: Int = a.userOrder ?? Int.max
            let order1: Int = b.userOrder ?? Int.max
            if order0 != order1 {
                return order0 < order1
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        
        // Apply workflow status filter if set
        if let filter = statusFilter {
            result = result.filter { (file: TextFile) -> Bool in file.workflowStatus == filter }
        }
        
        return result
    }
    
    /// Count files by workflow status
    private func fileCount(for status: WorkflowStatus?) -> Int {
        if let status = status {
            return allFiles.filter { (file: TextFile) -> Bool in file.workflowStatus == status }.count
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
    
    /// Helper struct for grouping files by section
    private struct SectionGroup: Identifiable {
        let id: String
        let name: String
        let files: [TextFile]
        
        var count: Int { files.count }
    }
    
    /// Group files by their section name (only when not viewing a specific section)
    private var sectionGroups: [SectionGroup] {
        guard section == nil else { return [] }  // Don't group when viewing a section
        
        var groups: [String: [TextFile]] = [:]
        var unassignedFiles: [TextFile] = []
        
        for file in sortedFiles {
            if let sectionName = file.section?.name {
                groups[sectionName, default: []].append(file)
            } else {
                unassignedFiles.append(file)
            }
        }
        
        // Build result with assigned sections first (sorted by name), then unassigned
        var result: [SectionGroup] = groups.keys.sorted().map { name in
            SectionGroup(id: name, name: name, files: groups[name]!)
        }
        
        // Add unassigned files at the end if any
        if !unassignedFiles.isEmpty {
            let unassignedLabel = NSLocalizedString("prose.section.unassigned", comment: "Unassigned")
            result.append(SectionGroup(id: "__unassigned__", name: unassignedLabel, files: unassignedFiles))
        }
        
        return result
    }
    
    /// Whether to show collapsible sections (only when there are assigned sections and not viewing a specific section)
    private var useSections: Bool {
        section == nil && sectionGroups.count > 1
    }
    
    // MARK: - Body
    
    var body: some View {
        mainContent
            .sheet(isPresented: $showAddFile) {
                AddProseFileSheet(project: project)
            }
            .sheet(isPresented: $showSectionPicker) {
                sectionPickerSheet
            }
            .sheet(isPresented: $showStatusPicker) {
                statusPickerSheet
            }
            .sheet(isPresented: $showRenameSheet) {
                renameSheet
            }
            .sheet(isPresented: $showFileDetails) {
                detailsSheet
            }
            .sheet(isPresented: $showSearchView) {
                if let folder = proseFolder {
                    MultiFileSearchView(folder: folder, files: sortedFiles)
                }
            }
            .sheet(isPresented: $showHeaderFooterEditor) {
                headerFooterSheet
            }
            .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
                TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                    newSubmissionName = ""
                }
                Button(NSLocalizedString("button.create", comment: "Create")) {
                    createSubmissionFromFiles(name: newSubmissionName)
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
            .sheet(isPresented: $showContainerAssignment) {
                ContainerAssignmentView.forProseSections(
                    project: project,
                    selectedFiles: filesToAssign,
                    modelContext: modelContext
                )
            }
            .alert(NSLocalizedString("headerFooter.notEnabled.title", comment: "Headers & Footers Not Enabled"), isPresented: $showHeaderFooterWarning) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("headerFooter.notEnabled.message", comment: "Enable headers or footers in Page Setup in your project's settings before editing their content."))
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.rtf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .alert(NSLocalizedString("import.error.title", comment: "Import Failed"), isPresented: $showImportError) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
            .confirmationDialog(
                NSLocalizedString("export.dialog.title", comment: "Export Format"),
                isPresented: $showExportMenu,
                titleVisibility: .visible
            ) {
                exportDialogButtons
            }
            .alert(NSLocalizedString("export.imageWarning.title", comment: "Images Not Included"), isPresented: $showExportImageWarning) {
                Button(NSLocalizedString("export.imageWarning.continue", comment: "Continue")) {
                    pendingExportAction?()
                    pendingExportAction = nil
                }
                Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                    pendingExportAction = nil
                }
            } message: {
                Text(NSLocalizedString("export.imageWarning.message", comment: "Images will not be included"))
            }
            .fileExporter(
                isPresented: $showExportSaveDialog,
                document: ExportDocument(
                    data: exportData ?? Data(),
                    filename: exportFilename,
                    contentType: contentTypeForFormat(exportFormat)
                ),
                contentType: contentTypeForFormat(exportFormat),
                defaultFilename: exportFilename,
                onCompletion: handleExportResult
            )
            .sheet(isPresented: $showCopyToProject) {
                CopyToProjectPickerView(
                    sourceProject: project,
                    filesToCopy: filesToExport,
                    onProjectSelected: { destinationProject in
                        showCopyToProject = false
                        copyFilesToProject(filesToExport, destination: destinationProject)
                        filesToExport = []
                    },
                    onCancel: {
                        showCopyToProject = false
                        filesToExport = []
                    }
                )
            }
            .alert(
                copyResultIsError
                    ? NSLocalizedString("copyToProject.error.title", comment: "Copy Failed")
                    : NSLocalizedString("copyToProject.success.title", comment: "Files Copied"),
                isPresented: $showCopyResult
            ) {
                Button(NSLocalizedString("button.ok", comment: "OK")) { }
            } message: {
                Text(copyResultMessage)
            }
            .confirmationDialog(
                deleteConfirmationTitle,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                deleteDialogButtons
            } message: {
                Text(NSLocalizedString("fileList.deleteConfirmation.messageEnhanced", comment: "Delete moves to trash, Delete Forever is permanent"))
            }
            .onChange(of: editMode) { _, newValue in
                if newValue == .active {
                    // Clear status filter so all items are available for container assignment
                    statusFilter = nil
                } else if newValue == .inactive {
                    selectedFileIDs.removeAll()
                }
            }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
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
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                toolbarTrailingContent
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
    }
    
    // MARK: - Toolbar Trailing Content
    
    @ViewBuilder
    private var toolbarTrailingContent: some View {
        // Expand/Collapse all button (only when using sections and not in edit mode)
        if useSections && !isEditMode {
            expandCollapseButton
        }
        
        // Search button (only when files exist and not in edit mode)
        if !sortedFiles.isEmpty && !isEditMode {
            Button {
                showSearchView = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel(NSLocalizedString("search.accessibility", comment: "Search files"))
            .help(NSLocalizedString("search.help", comment: "Search and replace across all files"))
        }
        
        #if targetEnvironment(macCatalyst)
        // Import button (only when not in section view and not in edit mode) - Mac only
        if section == nil && !isEditMode {
            Button {
                showImportPicker = true
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .accessibilityLabel(NSLocalizedString("import.accessibility", comment: "Import document"))
            .help(NSLocalizedString("import.help", comment: "Import Word or Markdown document"))
        }
        
        // Header/Footer editor button - Mac only
        if !isEditMode {
            Button {
                if headersOrFootersEnabled {
                    showHeaderFooterEditor = true
                } else {
                    showHeaderFooterWarning = true
                }
            } label: {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
            }
            .accessibilityLabel(NSLocalizedString("headerFooter.accessibility", comment: "Edit headers and footers"))
            .help(NSLocalizedString("headerFooter.help", comment: "Edit page headers and footers"))
            .foregroundStyle(headersOrFootersEnabled ? Color.accentColor : Color.secondary)
        }
        #endif
        
        // Add file button (hidden when viewing a section's files)
        if section == nil && !isEditMode {
            Button {
                showAddFile = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(NSLocalizedString("prose.files.add", comment: "Add file"))
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
        
        #if !targetEnvironment(macCatalyst)
        // On iPhone/iPad, show import and header/footer in overflow menu (rightmost)
        if !isEditMode {
            Menu {
                if section == nil {
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import document", systemImage: "square.and.arrow.down")
                    }
                }
                Button {
                    if headersOrFootersEnabled {
                        showHeaderFooterEditor = true
                    } else {
                        showHeaderFooterWarning = true
                    }
                } label: {
                    Label("Edit headers and footers", systemImage: "rectangle.and.pencil.and.ellipsis")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        #endif
    }
    
    /// Whether headers or footers are enabled for this project
    private var headersOrFootersEnabled: Bool {
        guard let pageSetup = project.pageSetup else { return false }
        return pageSetup.hasHeaders || pageSetup.hasFooters
    }
    
    /// Available elements for header/footer insertion
    private var headerFooterElements: [String] {
        ["Page Number", "Total Pages", "Date", "Time", "Title", "Author"]
    }
    
    // MARK: - Sheet Content
    
    @ViewBuilder
    private var sectionPickerSheet: some View {
        SectionPickerSheet(
            project: project,
            selectedFiles: Array(selectedFiles),
            onAssign: { section in
                assignFilesToSection(Array(selectedFiles), section: section)
                showSectionPicker = false
                exitEditMode()
            },
            onCancel: {
                showSectionPicker = false
            }
        )
    }
    
    @ViewBuilder
    private var statusPickerSheet: some View {
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
    
    @ViewBuilder
    private var renameSheet: some View {
        if let file = fileToRename {
            RenameFileModal(
                file: file,
                filesInFolder: sortedFiles,
                onRename: { newName in
                    renameFile(file, to: newName)
                }
            )
        }
    }
    
    @ViewBuilder
    private var detailsSheet: some View {
        if let file = fileForDetails {
            FileDetailsSheet(file: file)
        }
    }
    
    @ViewBuilder
    private var headerFooterSheet: some View {
        HeaderFooterDialog(
            headerEnabled: project.pageSetup?.hasHeaders ?? false,
            footerEnabled: project.pageSetup?.hasFooters ?? false,
            headerLeft: $headerLeft,
            headerCenter: $headerCenter,
            headerRight: $headerRight,
            footerLeft: $footerLeft,
            footerCenter: $footerCenter,
            footerRight: $footerRight,
            headerInsertTarget: $headerInsertTarget,
            footerInsertTarget: $footerInsertTarget,
            showHeaderElementPicker: $showHeaderElementPicker,
            showFooterElementPicker: $showFooterElementPicker,
            headerFooterElements: headerFooterElements,
            onCancel: { showHeaderFooterEditor = false },
            onSave: {
                if let pageSetup = project.pageSetup {
                    pageSetup.headerLeft = headerLeft
                    pageSetup.headerCenter = headerCenter
                    pageSetup.headerRight = headerRight
                    pageSetup.footerLeft = footerLeft
                    pageSetup.footerCenter = footerCenter
                    pageSetup.footerRight = footerRight
                    try? modelContext.save()
                }
                showHeaderFooterEditor = false
            }
        )
        .onAppear {
            initializeHeaderFooterFields()
        }
    }
    
    // MARK: - Dialog Content
    
    private var deleteConfirmationTitle: String {
        filesToDelete.count == 1
            ? NSLocalizedString("fileList.deleteFile.title", comment: "Delete file?")
            : String(format: NSLocalizedString("fileList.deleteFiles.title", comment: "Delete files?"), filesToDelete.count)
    }
    
    @ViewBuilder
    private var exportDialogButtons: some View {
        Button {
            showExportMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCopyToProject = true
            }
        } label: {
            Label(NSLocalizedString("export.copyToProject", comment: "Copy to Project…"), systemImage: "doc.on.doc")
        }
        Button(ExportFormat.pdf.localizedName) {
            exportFiles(filesToExport, format: .pdf)
        }
        Button(ExportFormat.rtf.localizedName) {
            let files = filesToExport
            pendingExportAction = { [self] in exportFiles(files, format: .rtf) }
            showImageWarningAfterDelay()
        }
        Button(ExportFormat.html.localizedName) {
            exportFiles(filesToExport, format: .html)
        }
        Button(ExportFormat.word.localizedName) {
            exportFiles(filesToExport, format: .word)
        }
        Button(ExportFormat.markdown.localizedName) {
            let files = filesToExport
            pendingExportAction = { [self] in exportFiles(files, format: .markdown) }
            showImageWarningAfterDelay()
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            filesToExport = []
        }
    }
    
    private func showImageWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showExportImageWarning = true
        }
    }
    
    @ViewBuilder
    private var deleteDialogButtons: some View {
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
        
        // Add to Section button (main file list only)
        if section == nil {
            Button {
                filesToAssign = selectedFiles
                showContainerAssignment = true
            } label: {
                Label(
                    NSLocalizedString("prose.files.addToSection", comment: "Add to Section"),
                    systemImage: "doc.text"
                )
            }
        }
        
        // Add to submission button
        if !selectedFiles.isEmpty {
            Button {
                showSubmissionNamePrompt = true
            } label: {
                Label(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"), systemImage: "tray.and.arrow.down")
            }
        }
        
        // Export button
        if !selectedFiles.isEmpty {
            Button {
                filesToExport = selectedFiles
                showExportMenu = true
            } label: {
                Label(NSLocalizedString("fileList.export", comment: "Export files"), systemImage: "square.and.arrow.up")
            }
        }
        
        // Print button
        Button {
            printSelectedFiles()
        } label: {
            Label(NSLocalizedString("fileList.print", comment: "Print"), systemImage: "printer")
        }
        .disabled(selectedFiles.isEmpty)
        
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
            if useSections {
                // Show collapsible sections grouped by section name
                ForEach(sectionGroups) { group in
                    Section {
                        // Only show files if section is expanded
                        if expandedSections.contains(group.id) {
                            ForEach(group.files) { file in
                                fileRow(for: file)
                            }
                        }
                    } header: {
                        sectionHeader(for: group)
                    }
                }
            } else {
                // Flat list (when viewing a specific section or no section assignments)
                ForEach(sortedFiles) { file in
                    fileRow(for: file)
                        .onDrag {
                            return NSItemProvider(object: file.id.uuidString as NSString)
                        }
                }
                .onMove(perform: moveFiles)
            }
        }
        .listStyle(.plain)
        .onChange(of: editMode) { _, newValue in
            if useSections {
                if newValue == .active {
                    // Expand all sections when entering edit mode for easier multi-select
                    expandedSections = Set(sectionGroups.map { $0.id })
                }
            }
        }
        .onAppear {
            // Start with all sections expanded
            if useSections && expandedSections.isEmpty {
                expandedSections = Set(sectionGroups.map { $0.id })
            }
        }
    }
    
    /// Section header with name, count, and expand/collapse functionality
    @ViewBuilder
    private func sectionHeader(for group: SectionGroup) -> some View {
        let isExpanded = expandedSections.contains(group.id)
        
        Button {
            withAnimation {
                if expandedSections.contains(group.id) {
                    expandedSections.remove(group.id)
                } else {
                    expandedSections.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Disclosure indicator
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(width: 20)
                
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                
                Text(group.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("(\(group.count))")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(group.name), \(group.count) files"))
        .accessibilityHint(Text(isExpanded ? 
            NSLocalizedString("section.collapse.hint", comment: "Tap to collapse section") : 
            NSLocalizedString("section.expand.hint", comment: "Tap to expand section")))
    }
    
    /// Expand/Collapse all button for section view
    @ViewBuilder
    private var expandCollapseButton: some View {
        let allExpanded = expandedSections.count == sectionGroups.count
        
        Button {
            withAnimation {
                if allExpanded {
                    // Collapse all
                    expandedSections.removeAll()
                } else {
                    // Expand all
                    expandedSections = Set(sectionGroups.map { $0.id })
                }
            }
        } label: {
            Image(systemName: allExpanded ? "chevron.up.circle" : "chevron.down.circle")
        }
        .accessibilityLabel(Text(allExpanded ?
            NSLocalizedString("fileList.collapseAll", comment: "Collapse all sections") :
            NSLocalizedString("fileList.expandAll", comment: "Expand all sections")))
        .help(allExpanded ?
            NSLocalizedString("fileList.collapseAll", comment: "Collapse all sections") :
            NSLocalizedString("fileList.expandAll", comment: "Expand all sections"))
    }
    
    @ViewBuilder
    private func fileRow(for file: TextFile) -> some View {
        HStack {
            if isEditMode {
                FileRowView(file: file)
            } else {
                NavigationLink {
                    FileEditView(file: file)
                } label: {
                    FileRowView(file: file)
                }
            }
            
            // Ellipsis menu (only in normal mode)
            if !isEditMode {
                fileOptionsMenu(for: file)
            }
        }
    }
    
    @ViewBuilder
    private func fileOptionsMenu(for file: TextFile) -> some View {
        Menu {
            // File Details
            Button {
                fileForDetails = file
                showFileDetails = true
            } label: {
                Label(NSLocalizedString("fileList.details", comment: "Details"), systemImage: "info.circle")
            }
            
            Divider()
            
            // Rename
            Button {
                fileToRename = file
                showRenameSheet = true
            } label: {
                Label(NSLocalizedString("fileList.rename", comment: "Rename"), systemImage: "pencil")
            }
            
            // Export
            Button {
                filesToExport = [file]
                showExportMenu = true
            } label: {
                Label(NSLocalizedString("fileList.export", comment: "Export"), systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    
    private func createSubmissionFromFiles(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check for duplicate submission name in this project
        let projectID = project.id
        var duplicateCheck = FetchDescriptor<Submission>(predicate: #Predicate<Submission> { submission in
            submission.name == trimmedName && submission.project?.id == projectID && submission.isCollection == false
        })
        duplicateCheck.fetchLimit = 1
        if let count = try? modelContext.fetchCount(duplicateCheck), count > 0 {
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
        
        for file in selectedFiles {
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
        
        try? modelContext.save()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        exitEditMode()
    }
    
    private func prepareDelete(_ files: [TextFile]) {
        filesToDelete = files
        showDeleteConfirmation = true
    }
    
    private func printSelectedFiles() {
        guard !selectedFiles.isEmpty else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else { return }
        
        PrintService.printFiles(
            selectedFiles,
            project: project,
            context: modelContext,
            from: viewController
        ) { _, _ in }
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
            // Clean up index references before deleting
            FileMoveService.cleanupIndexReferences(for: file, context: modelContext)
            modelContext.delete(file)
        }
        try? modelContext.save()
    }
    
    private func renameFile(_ file: TextFile, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        file.name = trimmedName
        file.modifiedDate = Date()
        
        try? modelContext.save()
        
        fileToRename = nil
        showRenameSheet = false
    }
    
    private func exportFiles(_ files: [TextFile], format: ExportFormat) {
        self.exportFormat = format
        guard !files.isEmpty else { return }
        
        var attributedStrings: [NSAttributedString] = []
        
        for file in files {
            guard let version = file.currentVersion else { continue }
            var content: NSAttributedString
            if let formatted = version.attributedContent {
                content = formatted
            } else if !version.content.isEmpty {
                content = NSAttributedString(
                    string: version.content,
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
            } else {
                continue
            }
            
            if file.isMarkdown && format != .markdown && format != .plainText {
                if let rendered = try? MarkdownImportService.importMarkdown(from: content.string, styleSheet: file.project?.styleSheet) {
                    content = rendered
                }
            }
            
            attributedStrings.append(content)
        }
        
        guard !attributedStrings.isEmpty else {
            filesToExport = []
            return
        }
        
        // Single file: direct export
        if attributedStrings.count == 1, let firstFile = files.first {
            performSingleFileExport(format: format, content: attributedStrings[0], filename: firstFile.name)
            filesToExport = []
            return
        }
        
        // Multiple files: combined export
        let filename = project.name ?? "Export"
        
        Task {
            do {
                let data: Data
                switch format {
                case .pdf:
                    let assembled = NSMutableAttributedString()
                    var isFirst = true
                    for attrStr in attributedStrings {
                        if !isFirst {
                            assembled.append(NSAttributedString(string: "\u{000C}"))
                        }
                        isFirst = false
                        assembled.append(attrStr)
                    }
                    let manuscriptContent = ManuscriptContent(
                        attributedString: assembled,
                        sections: [],
                        fileOffsets: [:],
                        frontMatterFileCount: 0,
                        frontMatterCharacterLength: 0,
                        assembledFootnotes: []
                    )
                    guard let pdfData = PrintService.generatePDF(
                        from: manuscriptContent,
                        project: project,
                        pageSetup: project.pageSetup,
                        context: modelContext
                    ) else { return }
                    data = pdfData
                case .rtf:
                    data = try WordDocumentService.exportMultipleToRTF(attributedStrings, filename: filename)
                case .html:
                    data = try HTMLExportService.exportMultipleToHTMLData(attributedStrings, filename: filename)
                case .word:
                    let exportService = DOCXExportService(modelContext: modelContext)
                    data = try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                case .markdown:
                    data = try MarkdownExportService.exportMultipleToMarkdownData(attributedStrings, filename: filename)
                default:
                    return
                }
                
                await MainActor.run {
                    exportData = data
                    exportFilename = "\(filename).\(format.fileExtension)"
                    showExportSaveDialog = true
                }
            } catch {
                #if DEBUG
                await MainActor.run {
                    print("❌ [ProseListView] Multi-file export failed: \(error)")
                }
                #endif
            }
        }
        
        filesToExport = []
    }
    
    private func performSingleFileExport(format: ExportFormat, content: NSAttributedString, filename: String) {
        do {
            switch format {
            case .pdf:
                let assembled = NSMutableAttributedString()
                assembled.append(content)
                let manuscriptContent = ManuscriptContent(
                    attributedString: assembled,
                    sections: [],
                    fileOffsets: [:],
                    frontMatterFileCount: 0,
                    frontMatterCharacterLength: 0,
                    assembledFootnotes: []
                )
                guard let pdfData = PrintService.generatePDF(
                    from: manuscriptContent,
                    project: project,
                    pageSetup: project.pageSetup,
                    context: modelContext
                ) else { return }
                exportData = pdfData
            case .rtf:
                exportData = try WordDocumentService.exportToRTF(content, filename: filename)
            case .html:
                exportData = try HTMLExportService.exportToHTMLData(content, filename: filename)
            case .word:
                let exportService = DOCXExportService(modelContext: modelContext)
                exportData = try exportService.exportToDOCX(content, filename: filename)
            case .markdown:
                exportData = try MarkdownExportService.exportToMarkdownData(content, filename: filename)
            default:
                return
            }
            
            exportFilename = "\(filename).\(format.fileExtension)"
            showExportSaveDialog = true
        } catch {
            #if DEBUG
            print("❌ [ProseListView] Single export failed: \(error)")
            #endif
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            #if DEBUG
            print("📤 [ProseListView] Export successful: \(url)")
            #endif
        case .failure(let error):
            #if DEBUG
            print("📤 [ProseListView] Export failed: \(error)")
            #endif
            importErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed") + ": \(error.localizedDescription)"
            showImportError = true
        }
        
        // Reset export state
        exportData = nil
        exportFilename = ""
    }
    
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .rtf:
            return .rtf
        case .html:
            return .html
        // EPUB only supported for manuscript export
        case .epub:
            return UTType(filenameExtension: "epub") ?? .data
        case .word:
            return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        case .pdf:
            return .pdf
        case .plainText:
            return .plainText
        case .fountain:
            return UTType(filenameExtension: "fountain") ?? .plainText
        case .finalDraft:
            return UTType(filenameExtension: "fdx") ?? .xml
        }
    }
    
    // MARK: - Copy to Project
    
    private func copyFilesToProject(_ files: [TextFile], destination: Project) {
        guard !files.isEmpty else { return }
        
        let sourceFolderName = proseFolder?.name ?? "Prose"
        let destinationFolder = findMatchingFolder(in: destination, named: sourceFolderName)
        
        guard let destFolder = destinationFolder else {
            copyResultMessage = String(format: NSLocalizedString("copyToProject.error.noFolder", comment: "No matching folder found"), sourceFolderName, destination.name ?? "")
            copyResultIsError = true
            showCopyResult = true
            return
        }
        
        var usedNames = Set((destFolder.textFiles ?? []).map { $0.name })
        var copiedCount = 0
        let maxSceneOrder = (destination.type == .fiction || destination.type == .drama)
            ? (destination.scenes ?? []).filter({ !$0.isTrashed }).compactMap(\.userOrder).max() ?? -1
            : 0
        
        for file in files {
            guard let currentVersion = file.currentVersion else { continue }
            
            let uniqueName = generateUniqueName(for: file.name, usedNames: usedNames)
            usedNames.insert(uniqueName)
            
            let newFile = TextFile(
                name: uniqueName,
                initialContent: currentVersion.content,
                parentFolder: destFolder,
                poetryFormId: file.poetryFormId,
                poetryFormName: file.poetryFormName
            )
            
            newFile.workflowStatusRaw = file.workflowStatusRaw
            newFile.contentTypeRaw = file.contentTypeRaw
            
            if let formattedData = currentVersion.formattedContent,
               let newVersion = newFile.currentVersion {
                newVersion.formattedContent = formattedData
            }
            
            if let refMetadata = currentVersion.referenceMetadataData,
               let newVersion = newFile.currentVersion {
                newVersion.referenceMetadataData = refMetadata
            }
            
            let maxOrder = (destFolder.textFiles ?? []).compactMap { $0.userOrder }.max() ?? -1
            newFile.userOrder = maxOrder + 1 + copiedCount
            
            modelContext.insert(newFile)
            
            // For Fiction/Drama projects, create a StoryScene linked to the TextFile
            if destination.type == .fiction || destination.type == .drama {
                let scene = StoryScene(name: uniqueName, userOrder: maxSceneOrder + 1 + copiedCount)
                scene.project = destination
                scene.textFile = newFile
                modelContext.insert(scene)
            }
            
            copiedCount += 1
        }
        
        do {
            try modelContext.save()
            let format = copiedCount == 1
                ? NSLocalizedString("copyToProject.success.single", comment: "1 file copied")
                : NSLocalizedString("copyToProject.success.multiple", comment: "%d files copied")
            copyResultMessage = String(format: format, copiedCount) + " " + String(format: NSLocalizedString("copyToProject.success.destination", comment: "to project"), destination.name ?? "")
            copyResultIsError = false
            showCopyResult = true
        } catch {
            copyResultMessage = NSLocalizedString("copyToProject.error.saveFailed", comment: "Save failed") + ": \(error.localizedDescription)"
            copyResultIsError = true
            showCopyResult = true
        }
    }
    
    private func findMatchingFolder(in project: Project, named sourceName: String) -> Folder? {
        guard let folders = project.folders else { return nil }
        if let match = folders.first(where: { $0.name == sourceName }) {
            return match
        }
        let contentFolderNames: Set<String> = ["Poems", "Scenes", "Stories", "Episodes", "Scripts", "Sections", "Prose"]
        if let contentFolder = folders.first(where: { contentFolderNames.contains($0.name ?? "") }) {
            return contentFolder
        }
        return folders.first(where: { FolderCapabilityService.canAddFile(to: $0) })
    }
    
    private func generateUniqueName(for name: String, usedNames: Set<String>) -> String {
        if !usedNames.contains(name) { return name }
        var counter = 2
        while counter <= 1000 {
            let candidate = "\(name) \(counter)"
            if !usedNames.contains(candidate) { return candidate }
            counter += 1
        }
        return "\(name) \(UUID().uuidString.prefix(6))"
    }
    
    private func assignFilesToSection(_ files: [TextFile], section: ProseSection?) {
        // Find the current max userOrder in the target section so new files go to the end
        let existingMaxOrder: Int
        if let section = section {
            let sectionFiles: [TextFile] = (proseFolder?.textFiles ?? []).filter { (file: TextFile) -> Bool in file.section?.id == section.id && file.trashItem == nil }
            existingMaxOrder = sectionFiles.compactMap(\.userOrder).max() ?? -1
        } else {
            existingMaxOrder = -1
        }
        
        for (index, file) in files.enumerated() {
            file.section = section
            // Place at end of section's file list
            file.userOrder = existingMaxOrder + 1 + index
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
    
    // MARK: - Import Functions
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Check file extension to determine import method
            let fileExtension = url.pathExtension.lowercased()
            
            if fileExtension == "md" || fileExtension == "markdown" {
                handleMarkdownImport(url: url)
            } else {
                handleWordImport(url: url)
            }
            
        case .failure(let error):
            importErrorMessage = "Failed to access file: \(error.localizedDescription)"
            showImportError = true
        }
    }
    
    private func handleMarkdownImport(url: URL) {
        guard let folder = proseFolder else {
            importErrorMessage = NSLocalizedString("import.error.noFolder", comment: "No Prose folder found")
            showImportError = true
            return
        }
        
        do {
            let styleSheet = project.styleSheet
            let attributedString = try MarkdownImportService.importMarkdown(from: url, styleSheet: styleSheet)
            let plainText = attributedString.string
            let filename = url.deletingPathExtension().lastPathComponent
            
            let rtfData = try? attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            
            let file = TextFile(name: filename, initialContent: "", parentFolder: folder)
            file.workflowStatus = .draft
            
            if let firstVersion = file.versions?.first {
                firstVersion.content = plainText
                firstVersion.formattedContent = rtfData
            }
            
            file.modifiedDate = Date()
            modelContext.insert(file)
            
            do {
                try modelContext.save()
                modelContext.processPendingChanges()
                
                #if DEBUG
                print("✅ [ProseListView] Imported Markdown '\(filename)' successfully")
                #endif
                
            } catch {
                modelContext.delete(file)
                importErrorMessage = "Failed to save imported file: \(error.localizedDescription)"
                showImportError = true
            }
            
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
    
    private func handleWordImport(url: URL) {
        guard let folder = proseFolder else {
            importErrorMessage = NSLocalizedString("import.error.noFolder", comment: "No Prose folder found")
            showImportError = true
            return
        }
        
        do {
            let (plainText, rtfData, filename) = try WordDocumentService.importWordDocument(from: url)
            
            let file = TextFile(name: filename, initialContent: "", parentFolder: folder)
            file.workflowStatus = .draft
            
            if let firstVersion = file.versions?.first {
                firstVersion.content = plainText
                firstVersion.formattedContent = rtfData
            }
            
            file.modifiedDate = Date()
            modelContext.insert(file)
            
            do {
                try modelContext.save()
                modelContext.processPendingChanges()
                
                #if DEBUG
                print("✅ [ProseListView] Imported Word '\(filename)' successfully")
                #endif
                
            } catch {
                modelContext.delete(file)
                importErrorMessage = "Failed to save imported file: \(error.localizedDescription)"
                showImportError = true
            }
            
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
    
    // MARK: - Header/Footer Initialization
    
    private func initializeHeaderFooterFields() {
        if let pageSetup = project.pageSetup {
            headerLeft = pageSetup.headerLeft ?? ""
            headerCenter = pageSetup.headerCenter ?? ""
            headerRight = pageSetup.headerRight ?? ""
            footerLeft = pageSetup.footerLeft ?? ""
            footerCenter = pageSetup.footerCenter ?? ""
            footerRight = pageSetup.footerRight ?? ""
        }
    }
}

// MARK: - File Row View

private struct FileRowView: View {
    let file: TextFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(file.name.isEmpty ? NSLocalizedString("prose.untitled", comment: "Untitled") : file.name)
                    .font(.body)
                
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
                        .font(.footnote)
                    Text(section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled"))
                        .font(.footnote)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
