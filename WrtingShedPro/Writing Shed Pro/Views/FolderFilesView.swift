//
//  FolderFilesView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature 008a Integration: Replaces FileEditableList with FileListView
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// View for displaying and managing files within a folder
/// Uses the new FileListView component with full file movement support
struct FolderFilesView: View {
    @Bindable var folder: Folder
    @Environment(\.modelContext) var modelContext
    
    // State for edit mode (shared with FileListView)
    @State var editMode: EditMode = .inactive
    
    // State for add file sheet
    @State var showAddFileSheet = false
    
    // State for add folder sheet (for mixed-content folders)
    @State var showAddFolderSheet = false
    
    // State for navigation
    @State var selectedFile: TextFile?
    @State var navigateToFile = false
    
    // State for submission
    @State var showSubmissionNamePrompt = false
    @State var newSubmissionName: String = ""
    @State var showSubmissionCreated = false
    @State var createdSubmissionName: String = ""
    @State var showDuplicateSubmission = false
    @State var filesToSubmit: [TextFile] = []
    
    // State for rename
    @State var showRenamePicker = false
    @State var filesToRename: [TextFile] = []
    
    // State for folder movement (for mixed-content folders)
    @State var showFolderMoveDestinationPicker = false
    @State var folderToMove: Folder?
    
    // State for multi-select in mixed content view
    @State var selectedFileIDs: Set<UUID> = []
    @State var selectedFolderIDs: Set<UUID> = []
    
    // State for sorting in mixed content view
    @State var fileSortOrder: FileSortOrder = .byName
    @State var folderSortOrder: FolderSortOrder = .byName
    
    // State for Word document import
    @State var showImportPicker = false
    @State var showImportError = false
    @State var importErrorMessage = ""
    
    // State for export
    @State var showExportMenu = false
    @State var showExportFolderMenu = false
    @State var showExportSaveDialog = false
    @State var filesToExport: [TextFile] = []
    @State var exportFormat: ExportFormat = .rtf
    @State var exportData: Data?
    @State var exportFilename: String = ""
    @State var exportCombinedContent: NSAttributedString?
    @State var exportAttributedStrings: [NSAttributedString] = []  // For HTML multi-file export
    @State var showExportImageWarning = false
    @State var pendingExportAction: (() -> Void)? = nil

    // State for Copy to Project
    @State var showCopyToProject = false
    @State var showCopyResult = false
    @State var copyResultMessage = ""
    @State var copyResultIsError = false
    
    // State for search
    @State var showSearchView = false
    
    // State for header/footer editor
    @State var showHeaderFooterEditor = false
    @State var showHeaderFooterWarning = false
    
    @State var headerLeft: String = ""
    @State var headerCenter: String = ""
    @State var headerRight: String = ""
    @State var footerLeft: String = ""
    @State var footerCenter: String = ""
    @State var footerRight: String = ""
    @State var headerInsertTarget: HeaderFooterField = .left
    @State var footerInsertTarget: HeaderFooterField = .left
    @State var showHeaderElementPicker = false
    @State var showFooterElementPicker = false
    
    // State for Front Matter / Back Matter settings dialogs
    @State var showFrontMatterSettings = false
    @State var showBackMatterSettings = false
    
    // State for upgrade prompt when export is blocked
    @State var upgradePromptReason: UpgradePromptReason?
    
    // Available elements for header/footer insertion
    var headerFooterElements: [String] {
        ["Page Number", "Total Pages", "Date", "Time", "Title", "Author"]
    }
    
    // State for permanent delete confirmation
    @State var showPermanentDeleteConfirmation = false
    @State var filesToPermanentlyDelete: [TextFile] = []
    
    // State for workflow status filtering (for Poems, Scenes, Scripts folders)
    @State var statusFilter: WorkflowStatus? = nil  // nil = show all
    
    // State for status change sheet
    @State var showStatusPicker = false
    @State var filesToChangeStatus: [TextFile] = []
    
    // State for file movement (Prose projects only)
    @State var showMoveDestinationPicker = false
    @State var filesToMove: [TextFile] = []
    
    // State for poetry collection picker (Poetry projects only)
    @State var showCollectionPicker = false
    @State var filesToAssignToCollection: [TextFile] = []
    
    // State for container assignment dialog (Poetry projects only)
    // Uses sheet(item:) pattern to avoid timing issues where filesToAssign
    // could be empty when the sheet content evaluates.
    @State var containerAssignmentFiles: ContainerAssignmentItem?
    
    /// Identifiable wrapper so we can use sheet(item:) which atomically
    /// provides the data AND triggers presentation in a single state write.
    struct ContainerAssignmentItem: Identifiable {
        let id = UUID()
        let files: [TextFile]
    }
    
    // State for collection grouping expand/collapse (shared with FileListView)
    @State var collectionExpandedSections: Set<String> = []
    
    /// Returns the number of TrashItem objects for this folder's project
    /// Uses the project's existing relationship instead of a broad @Query
    private var trashItemCount: Int {
        folder.project?.trashedItems?.count ?? 0
    }
    
    // Computed properties moved to FolderFilesView+Helpers.swift
    
    // MARK: - File List View (extracted to reduce body complexity)
    @ViewBuilder
    private var fileListSection: some View {
        // Back matter and front matter folders are read-only - no edit operations allowed
        let isReadOnly = folder.isBackMatterFolder || folder.isFrontMatterFolder
        
        FileListView(
            files: sortedFiles,
            onFileSelected: handleFileSelected,
            onMove: (isProseProject && !isReadOnly) ? handleMove : nil,
            onDelete: isReadOnly ? { _ in } : deleteFiles,
            onExport: isReadOnly ? nil : handleExport,
            onSubmit: fileListOnSubmit,
            onReorder: (!isReadOnly && isContentFolder) ? moveContentFiles : nil,
            onRename: (isReadOnly || (isPoetryProject && isContentFolder)) ? nil : handleRename,
            onDeletePermanently: isReadOnly ? { _ in } : deleteFilesPermanently,
            onChangeStatus: (isContentFolder && !isReadOnly) ? handleChangeStatus : nil,
            onAddToCollection: (isPoetryProject && isContentFolder && !isReadOnly) ? handleAddToCollection : nil,
            onManageContainers: (isPoetryProject && isContentFolder && !isReadOnly) ? { containerAssignmentFiles = ContainerAssignmentItem(files: selectedFiles) } : nil,
            onPrint: handlePrint,
            collectionGroups: poetryCollectionGroups,
            expandedCollections: $collectionExpandedSections
        )
    }
    
    private func handleFileSelected(_ file: TextFile) {
        selectedFile = file
        navigateToFile = true
    }
    
    private func handleMove(_ files: [TextFile]) {
        filesToMove = files
        showMoveDestinationPicker = true
    }
    
    private func handleExport(_ files: [TextFile]) {
        filesToExport = files
        showExportMenu = true
    }
    
    private func handleRename(_ files: [TextFile]) {
        // FileListView already renamed the file - just save the context
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving renamed file: \(error)")
            #endif
        }
    }
    
    private func handleChangeStatus(_ files: [TextFile]) {
        filesToChangeStatus = files
        showStatusPicker = true
    }
    
    private func handleAddToCollection(_ files: [TextFile]) {
        containerAssignmentFiles = ContainerAssignmentItem(files: files)
    }
    
    @ViewBuilder
    var navigationDestinationContent: some View {
        if let file = selectedFile {
            if let project = folder.resolvedProject, project.type == .drama,
               FolderCapabilityService.isContentFolder(folder) {
                DramaSceneEditorView(file: file, project: project)
            } else if file.isCoverFile {
                // Cover image files (Front Cover / Back Cover)
                CoverImageEditorView(file: file)
            } else if let project = folder.resolvedProject,
                      BackMatterGeneratedContentView.isGeneratedBackMatterFile(file) {
                // Feature 029: Show generated content for back matter files
                BackMatterGeneratedContentView(file: file, project: project)
            } else {
                FileEditView(file: file)
            }
        }
    }
    
    var body: some View {
        let nav = applyNavigationModifiers(mainContent)
        let sheets = applySheetModifiers(nav)
        let files = applyFileModifiers(sheets)
        let alerts = applyAlertModifiers(files)
        let dialogs = applyDialogModifiers(alerts)
        return dialogs.onAppear {
            initializeHeaderFooterFields()
        }
    }
    
    // MARK: - Main Content (extracted to reduce body complexity)
    
    @ViewBuilder
    private var mainContent: some View {
        if folder.name == "Trash" && trashItemCount == 0 {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                if isContentFolder {
                    workflowStatusFilter
                }
                Group {
                    if isMixedContentFolder {
                        mixedContentBody
                    } else if isMatterFolder && !sortedFiles.isEmpty {
                        matterFolderBody
                    } else if !sortedFiles.isEmpty {
                        VStack(spacing: 0) {
                            fileListSection
                        }
                    } else if isMatterFolder {
                        // Special empty state for Front/Back Matter folders
                        ContentUnavailableView {
                            Label("folderFiles.noFiles", systemImage: "doc.text")
                        } description: {
                            Text("folderFiles.noFiles.matterHint")
                        }
                    } else {
                        ContentUnavailableView {
                            Label("folderFiles.noFiles", systemImage: "doc.text")
                        } description: {
                            Text("folderFiles.noFiles.hint")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties for Callbacks
    
    private var fileListOnSubmit: (([TextFile]) -> Void)? {
        supportsSubmissions ? { files in
            filesToSubmit = files
            showSubmissionNamePrompt = true
        } : nil
    }
    
    // MARK: - Workflow Status Filter
    
    /// Segmented control for filtering files by workflow status
    @ViewBuilder
    private var workflowStatusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" option with count
                workflowStatusButton(nil, label: NSLocalizedString("workflow.filter.all", comment: "All"), count: fileCount(for: nil))
                
                // Individual status options with counts
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
        let statusColor: Color = status.map { Color($0.color) } ?? .primary
        
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                statusFilter = status
            }
        } label: {
            Text("\(label) (\(count))")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? statusColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(statusColor, lineWidth: isSelected ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Mixed Content View
    
    /// View for folders that support both subfolders and files
    @ViewBuilder
    private var mixedContentBody: some View {
        List {
            // Subfolders section
            if !sortedSubfolders.isEmpty {
                Section {
                    ForEach(sortedSubfolders) { subfolder in
                        mixedContentSubfolderRow(subfolder)
                            // Enable drag-to-reorder without edit mode
                            .onDrag {
                                return NSItemProvider(object: subfolder.id.uuidString as NSString)
                            }
                    }
                    .onMove(perform: moveSubfolders)
                } header: {
                    HStack {
                        Text(NSLocalizedString("folderFiles.subfoldersHeader", comment: "Subfolders section header"))
                        Spacer()
                        if !isEditMode {
                            folderSortMenu
                        }
                    }
                }
            }
            
            // Files section
            if !sortedMixedFiles.isEmpty {
                Section {
                    ForEach(sortedMixedFiles) { file in
                        mixedContentFileRow(file)
                            // Enable drag-to-reorder without edit mode
                            .onDrag {
                                return NSItemProvider(object: file.id.uuidString as NSString)
                            }
                    }
                    .onMove(perform: moveMixedFiles)
                } header: {
                    HStack {
                        Text(NSLocalizedString("folderFiles.filesHeader", comment: "Files section header"))
                        Spacer()
                        if !isEditMode {
                            fileSortMenu
                        }
                    }
                }
            }
            
            // Empty state when both are empty
            if sortedSubfolders.isEmpty && sortedMixedFiles.isEmpty {
                ContentUnavailableView {
                    Label(NSLocalizedString("folderFiles.emptyFolder", comment: "Empty folder"), systemImage: "folder")
                } description: {
                    Text(NSLocalizedString("folderFiles.emptyFolder.hint", comment: "Empty folder hint"))
                }
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            // Bottom toolbar for multi-select actions (only in edit mode)
            ToolbarItemGroup(placement: .bottomBar) {
                if showMixedContentToolbar {
                    mixedContentBottomToolbar
                }
            }
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .active {
                // Clear status filter so all items are available for selection
                statusFilter = nil
            } else if newValue == .inactive {
                // Clear selection when exiting edit mode
                selectedFileIDs.removeAll()
                selectedFolderIDs.removeAll()
            }
        }
    }
    
    // MARK: - Matter Folder View (Front Matter / Back Matter with drag-to-reorder)
    
    /// View for Front Matter and Back Matter folders with drag-to-reorder support
    @ViewBuilder
    private var matterFolderBody: some View {
        List {
            ForEach(sortedFiles) { file in
                matterFileRow(file)
                    .moveDisabled(file.isCoverFile)
            }
            .onMove(perform: moveMatterFiles)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    /// Row view for matter folder files
    private func matterFileRow(_ file: TextFile) -> some View {
        Button {
            selectedFile = file
            navigateToFile = true
        } label: {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    /// Reorder matter folder files
    /// Cover files (Front Cover / Back Cover) are pinned and cannot be moved
    private func moveMatterFiles(from source: IndexSet, to destination: Int) {
        var files = sortedFiles
        
        // Determine pinned boundaries
        let hasFrontCover = files.first?.isCoverFile == true
        let hasBackCover = files.last?.isCoverFile == true
        let firstMovable = hasFrontCover ? 1 : 0
        let lastMovable = hasBackCover ? files.count - 1 : files.count
        
        // Block if trying to move a cover file
        if source.contains(where: { files[$0].isCoverFile }) { return }
        
        // Clamp destination so nothing lands before front cover or after back cover
        let clampedDestination = max(firstMovable, min(destination, lastMovable))
        
        files.move(fromOffsets: source, toOffset: clampedDestination)
        
        // Update userOrder for all files
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving reordered matter files: \(error)")
            #endif
        }
    }
    

    
    /// Sort menu for folders section
    @ViewBuilder
    private var folderSortMenu: some View {
        Menu {
            ForEach(FolderSortService.sortOptions(), id: \.order) { option in
                Button {
                    folderSortOrder = option.order
                } label: {
                    HStack {
                        Text(option.title)
                        if folderSortOrder == option.order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Sort menu for files section
    @ViewBuilder
    private var fileSortMenu: some View {
        Menu {
            ForEach(FileSortService.sortOptions(), id: \.order) { option in
                Button {
                    fileSortOrder = option.order
                } label: {
                    HStack {
                        Text(option.title)
                        if fileSortOrder == option.order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Row for a subfolder in mixed content view - supports edit mode selection
    @ViewBuilder
    private func mixedContentSubfolderRow(_ subfolder: Folder) -> some View {
        HStack {
            // Selection circle in edit mode - tappable to toggle selection
            if isEditMode {
                Button {
                    toggleFolderSelection(subfolder)
                } label: {
                    Image(systemName: selectedFolderIDs.contains(subfolder.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedFolderIDs.contains(subfolder.id) ? .blue : .gray)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            
            // Main content - NavigationLink works in both modes
            NavigationLink(destination: FolderFilesView(folder: subfolder)) {
                Label(subfolder.name ?? NSLocalizedString("folderList.untitledFolder", comment: "Untitled folder"), systemImage: "folder")
            }
        }
        .contextMenu {
            Button {
                folderToMove = subfolder
                showFolderMoveDestinationPicker = true
            } label: {
                Label(NSLocalizedString("folderFiles.moveToFolder", comment: "Move to Folder"), systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteSubfolder(subfolder)
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isEditMode {
                Button(role: .destructive) {
                    deleteSubfolder(subfolder)
                } label: {
                    Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                }
            }
        }
    }
    
    /// Row for a file in mixed content view - supports edit mode selection
    @ViewBuilder
    private func mixedContentFileRow(_ file: TextFile) -> some View {
        HStack {
            // Selection circle in edit mode - tappable to toggle selection
            if isEditMode {
                Button {
                    toggleFileSelection(file)
                } label: {
                    Image(systemName: selectedFileIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedFileIDs.contains(file.id) ? .blue : .gray)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            
            // Main content - tappable for navigation
            Button {
                selectedFile = file
                navigateToFile = true
            } label: {
                HStack {
                    Label(file.name.isEmpty ? NSLocalizedString("folderFiles.untitledFile", comment: "Untitled file") : file.name, systemImage: "doc.text")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(file.workflowStatus.map { Color($0.color) } ?? .primary)
            
            // Ellipsis menu (only in normal mode)
            if !isEditMode {
                mixedContentFileOptionsMenu(for: file)
            } else {
                // Keep chevron for spacing consistency in edit mode
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .contextMenu {
            Button {
                filesToRename = [file]
                showRenamePicker = true
            } label: {
                Label(NSLocalizedString("fileList.rename", comment: "Rename"), systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteFiles([file])
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
            }
            
            Button(role: .destructive) {
                filesToPermanentlyDelete = [file]
                showPermanentDeleteConfirmation = true
            } label: {
                Label(NSLocalizedString("folderFiles.deletePermanently", comment: "Delete Forever"), systemImage: "trash.slash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isEditMode {
                Button(role: .destructive) {
                    deleteFiles([file])
                } label: {
                    Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                }
            }
        }
    }
    
    /// Options menu for a file in mixed content view (ellipsis button)
    @ViewBuilder
    private func mixedContentFileOptionsMenu(for file: TextFile) -> some View {
        Menu {
            Button {
                filesToRename = [file]
                showRenamePicker = true
            } label: {
                Label(NSLocalizedString("fileList.rename", comment: "Rename"), systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteFiles([file])
            } label: {
                Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
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
    
    /// Bottom toolbar for mixed content multi-select actions
    @ViewBuilder
    private var mixedContentBottomToolbar: some View {
        let totalSelected = selectedFileIDs.count + selectedFolderIDs.count
        let filesOnlySelected = !selectedFileIDs.isEmpty && selectedFolderIDs.isEmpty
        
        // Deselect all button
        Button {
            selectedFileIDs.removeAll()
            selectedFolderIDs.removeAll()
        } label: {
            Image(systemName: "circle.slash")
        }
        .disabled(totalSelected == 0)
        .accessibilityLabel(NSLocalizedString("fileList.deselectAll", comment: "Deselect all"))
        
        Spacer()
        
        // Add to submission button (only when files selected, no folders)
        if filesOnlySelected {
            Button {
                showSubmissionNamePrompt = true
            } label: {
                Image(systemName: "tray.and.arrow.down")
            }
            .accessibilityLabel(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"))
            
            Spacer()
        }
        
        // Print button (only when files selected)
        if filesOnlySelected {
            Button {
                printSelectedFiles()
            } label: {
                Image(systemName: "printer")
            }
            .accessibilityLabel(NSLocalizedString("fileList.print", comment: "Print"))
            
            Spacer()
        }
        
        // Trash button
        Button(role: .destructive) {
            // Delete selected files and folders
            for subfolder in selectedFolders {
                deleteSubfolder(subfolder)
            }
            deleteFiles(selectedFiles)
            selectedFileIDs.removeAll()
            selectedFolderIDs.removeAll()
            editMode = .inactive
        } label: {
            Image(systemName: "trash")
        }
        .disabled(totalSelected == 0)
        .accessibilityLabel(String(format: NSLocalizedString("fileList.deleteCount", comment: "Delete count"), totalSelected))
    }
    
    /// Toggle file selection
    private func toggleFileSelection(_ file: TextFile) {
        if selectedFileIDs.contains(file.id) {
            selectedFileIDs.remove(file.id)
        } else {
            selectedFileIDs.insert(file.id)
        }
    }
    
    /// Toggle folder selection
    private func toggleFolderSelection(_ folder: Folder) {
        if selectedFolderIDs.contains(folder.id) {
            selectedFolderIDs.remove(folder.id)
        } else {
            selectedFolderIDs.insert(folder.id)
        }
    }
    
    /// Move subfolders for drag-to-reorder (updates userOrder)
    private func moveSubfolders(from source: IndexSet, to destination: Int) {
        var folders = sortedSubfolders
        folders.move(fromOffsets: source, toOffset: destination)
        
        // Update userOrder for all folders
        for (index, folder) in folders.enumerated() {
            folder.userOrder = index
        }
        
        // Switch to user order sorting to show the new order
        folderSortOrder = .byUserOrder
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving folder order: \(error)")
            #endif
        }
    }
    
    /// Move files for drag-to-reorder (updates userOrder)
    private func moveMixedFiles(from source: IndexSet, to destination: Int) {
        var files = sortedMixedFiles
        files.move(fromOffsets: source, toOffset: destination)
        
        // Update userOrder for all files
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        
        // Switch to user order sorting to show the new order
        fileSortOrder = .byUserOrder
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving file order: \(error)")
            #endif
        }
    }
    
    /// Move content folder files for drag-to-reorder (updates userOrder)
    /// This controls the order files appear in the TOC and manuscript assembly
    private func moveContentFiles(from source: IndexSet, to destination: Int) {
        var files = sortedFiles
        files.move(fromOffsets: source, toOffset: destination)
        
        // Update userOrder for all files
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving reordered content files: \(error)")
            #endif
        }
    }
    
    /// Delete a single subfolder
    private func deleteSubfolder(_ subfolder: Folder) {
        modelContext.delete(subfolder)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error deleting subfolder: \(error)")
            #endif
        }
    }
    
    // MARK: - Actions
    
    func createSubmissionFromFiles(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let project = folder.project else { return }
        
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
        
        for file in filesToSubmit {
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
    }
    
    func addFilesToExistingSubmission(_ submission: Submission) {
        guard let project = folder.project else { return }
        let existingFileIDs = Set((submission.submittedFiles ?? []).compactMap { $0.textFile?.id })
        
        for file in filesToSubmit where !existingFileIDs.contains(file.id) {
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
        createdSubmissionName = submission.name ?? ""
        showSubmissionCreated = true
    }
    
    private func printSelectedFiles() {
        guard !selectedFiles.isEmpty, let project = folder.project else { return }
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
    
    private func handlePrint(_ files: [TextFile]) {
        guard !files.isEmpty, let project = folder.project else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else { return }
        
        PrintService.printFiles(
            files,
            project: project,
            context: modelContext,
            from: viewController
        ) { _, _ in }
    }
    
    private func deleteFiles(_ files: [TextFile]) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.deleteFiles(files)
        } catch {
            #if DEBUG
            print("Error deleting files: \(error)")
            #endif
            // TODO: Show error alert
        }
    }
    
    func deleteFilesPermanently(_ files: [TextFile]) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.deleteFilesPermanently(files)
        } catch {
            #if DEBUG
            print("Error permanently deleting files: \(error)")
            #endif
            // TODO: Show error alert
        }
    }
    
    /// Change the workflow status of files
    /// Also resets submission status when changing away from published
    func changeFilesStatus(_ files: [TextFile], to newStatus: WorkflowStatus) {
        for file in files {
            let wasPublished = file.workflowStatus == .published
            file.workflowStatus = newStatus
            
            // If changing away from published, reset any accepted submission records to pending
            if wasPublished && newStatus != .published {
                resetSubmissionStatus(for: file)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error changing file status: \(error)")
            #endif
        }
    }
    
    /// Reset submission status for a file when it's no longer published
    private func resetSubmissionStatus(for file: TextFile) {
        // Get all SubmittedFile records for this file
        let fileId = file.id
        let descriptor = FetchDescriptor<SubmittedFile>(
            predicate: #Predicate { submittedFile in
                submittedFile.textFile?.id == fileId
            }
        )
        
        do {
            let submittedFiles = try modelContext.fetch(descriptor)
            for submittedFile in submittedFiles {
                if submittedFile.status == .accepted {
                    submittedFile.status = .pending
                    submittedFile.statusDate = Date()
                }
            }
        } catch {
            #if DEBUG
            print("Error resetting submission status: \(error)")
            #endif
        }
    }
    
    /// Assign files to a poetry collection (or remove assignment if nil)
    func assignFilesToCollection(_ files: [TextFile], collection: PoetryCollection?) {
        for file in files {
            file.poetryCollection = collection
        }
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error assigning files to collection: \(error)")
            #endif
        }
        
        filesToAssignToCollection = []
    }
    
    /// Move files to a destination folder (Prose projects only)
    func moveFiles(to destination: Folder) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.moveFiles(filesToMove, to: destination)
            showMoveDestinationPicker = false
            filesToMove = []
        } catch {
            #if DEBUG
            print("Error moving files: \(error)")
            #endif
            // TODO: Show error alert
        }
    }
    
    /// Move a subfolder to a new destination folder
    func moveSubfolder(_ subfolder: Folder, to destination: Folder) {
        let service = FileMoveService(modelContext: modelContext)
        
        do {
            try service.moveFolder(subfolder, to: destination)
            folderToMove = nil
        } catch {
            #if DEBUG
            print("Error moving folder: \(error)")
            #endif
            // TODO: Show error alert
        }
    }
    
    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Check file extension to determine import method
            let fileExtension = url.pathExtension.lowercased()
            
            if fileExtension == "md" || fileExtension == "markdown" {
                // Import Markdown file
                handleMarkdownImport(url: url)
            } else {
                // Import Word/RTF document
                handleWordImport(url: url)
            }
            
        case .failure(let error):
            importErrorMessage = "Failed to access file: \(error.localizedDescription)"
            showImportError = true
        }
    }
    
    /// Handle importing a Markdown file
    private func handleMarkdownImport(url: URL) {
        do {
            // Get the project's stylesheet for style mapping
            let styleSheet = folder.project?.styleSheet
            
            // Import and convert the Markdown
            let attributedString = try MarkdownImportService.importMarkdown(from: url, styleSheet: styleSheet)
            let plainText = attributedString.string
            
            // Get filename without extension
            let filename = url.deletingPathExtension().lastPathComponent
            
            // Convert to RTF data for storage
            let rtfData = try? attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            
            // Create new text file
            let file = TextFile(name: filename, initialContent: "", parentFolder: folder)
            file.workflowStatus = .draft
            
            // Update the first version with imported content
            if let firstVersion = file.versions?.first {
                firstVersion.content = plainText
                firstVersion.formattedContent = rtfData
            }
            
            file.modifiedDate = Date()
            
            // Insert and save
            modelContext.insert(file)
            
            do {
                try modelContext.save()
                
                #if DEBUG
                print("✅ Imported Markdown '\(filename)' successfully")
                print("   File ID: \(file.id)")
                print("   Version count: \(file.versions?.count ?? 0)")
                #endif
                
                modelContext.processPendingChanges()
                
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
    
    /// Handle importing a Word/RTF document
    private func handleWordImport(url: URL) {
        do {
            let (plainText, rtfData, filename) = try WordDocumentService.importWordDocument(from: url)
            
            // Create new text file with initial empty content
            let file = TextFile(name: filename, initialContent: "", parentFolder: folder)
            
            // Set default workflow status for imported files
            file.workflowStatus = .draft
            
            // Update the first version with imported content
            if let firstVersion = file.versions?.first {
                firstVersion.content = plainText
                firstVersion.formattedContent = rtfData
            }
            
            file.modifiedDate = Date()
            
            // Insert and save immediately
            modelContext.insert(file)
            
            do {
                try modelContext.save()
                
                #if DEBUG
                print("✅ Imported '\(filename)' successfully")
                print("   File ID: \(file.id)")
                print("   Version count: \(file.versions?.count ?? 0)")
                #endif
                
                // CRITICAL: Process pending changes to avoid "store went missing" error
                modelContext.processPendingChanges()
                
            } catch {
                // If save fails, remove the file from context
                modelContext.delete(file)
                importErrorMessage = "Failed to save imported file: \(error.localizedDescription)"
                showImportError = true
            }
            
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
    
    // Uses ExportFormat from ManuscriptModels.swift
    
    private func exportCompleteFolder() {
        // Collect all file contents as separate attributed strings (for HTML)
        var attributedStrings: [NSAttributedString] = []
        
        // Also create combined content for RTF/EPUB
        let combinedContent = NSMutableAttributedString()
        
        for (index, file) in sortedFiles.enumerated() {
            guard let version = file.currentVersion,
                  var attributedString = version.attributedContent else {
                continue
            }
            
            // For markdown files, render markdown to rich text for combined export
            if file.isMarkdown {
                do {
                    let styleSheet = file.project?.styleSheet
                    attributedString = try MarkdownImportService.importMarkdown(from: attributedString.string, styleSheet: styleSheet)
                    #if DEBUG
                    print("📝 FolderFilesView: Rendered markdown to rich text for '\(file.name)'")
                    #endif
                } catch {
                    #if DEBUG
                    print("⚠️ FolderFilesView: Failed to render markdown for '\(file.name)': \(error)")
                    #endif
                    // Fall through with raw markdown text if rendering fails
                }
            }
            
            #if DEBUG
            // Check if this attributed string contains images
            var imageCount = 0
            attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, _, _ in
                if value is ImageAttachment {
                    imageCount += 1
                }
            }
            #if DEBUG
            print("📄 FolderFilesView: File \(index + 1) '\(file.name)' has \(imageCount) images in attributedContent")
            #endif
            #endif
            
            // Store individual attributed string for HTML export
            attributedStrings.append(attributedString)
            
            // Don't add title heading - the content already has it
            // Just add the file content directly
            combinedContent.append(attributedString)
            
            // Add page break after each file (including last file) for RTF/EPUB
            let pageBreak = NSAttributedString(string: "\u{000C}")
            combinedContent.append(pageBreak)
        }
        
        // Store both formats for export
        exportAttributedStrings = attributedStrings
        exportCombinedContent = combinedContent
        // Use the project name for the exported file, not the folder name
        exportFilename = folder.project?.name ?? folder.name ?? "Project"
        
        // Show format selection dialog
        showExportFolderMenu = true
    }
    
    func exportCombinedFolder(format: ExportFormat) {
        // Check entitlement for export
        if let projectType = folder.project?.type {
            if !EntitlementManager.shared.canExport(projectType: projectType) {
                upgradePromptReason = .exportBlocked(projectType: projectType)
                return
            }
        }
        
        // ALWAYS print, not just in DEBUG
        #if DEBUG
        print("📁 exportCombinedFolder() called with format: \(format)")
        #endif
        #if DEBUG
        print("📁 exportAttributedStrings count: \(exportAttributedStrings.count)")
        #endif
        #if DEBUG
        print("📁 exportCombinedContent length: \(exportCombinedContent?.length ?? 0)")
        #endif
        
        // Set the export format
        self.exportFormat = format
        
        guard let combinedContent = exportCombinedContent else {
            #if DEBUG
            print("❌ exportCombinedContent is nil!")
            #endif
            return
        }
        
        // Perform the actual export
        performCombinedExport(format: format, content: combinedContent)
    }
    
    func performCombinedExport(format: ExportFormat, content: NSAttributedString) {
        // Run export in background to keep UI responsive
        Task {
            do {
                #if DEBUG
                print("📁 About to call export service for format: \(format)")
                #endif
                
                // Capture array locally to avoid main actor isolation issues
                let attributedStrings = exportAttributedStrings
                let filename = exportFilename
                
                let data: Data
                
                switch format {
                case .rtf:
                    // Use the array version for RTF to respect page break preferences
                    data = try await Task.detached {
                        try WordDocumentService.exportMultipleToRTF(attributedStrings, filename: filename)
                    }.value
                case .html:
                    // Use the array version for HTML to preserve page breaks and prevent CSS conflicts
                    #if DEBUG
                    print("📁 Calling HTMLExportService.exportMultipleToHTMLData with \(attributedStrings.count) strings")
                    #endif
                    data = try await Task.detached {
                        try HTMLExportService.exportMultipleToHTMLData(attributedStrings, filename: filename)
                    }.value
                // EPUB only supported for manuscript export
                case .epub:
                    return
                case .word:
                    // Export to DOCX using DOCXExportService - use array version for page breaks
                    data = try await Task.detached { [weak modelContext] in
                        guard let modelContext = modelContext else {
                            throw DOCXExportError.noContent
                        }
                        let exportService = DOCXExportService(modelContext: modelContext)
                        return try exportService.exportMultipleToDOCX(attributedStrings, filename: filename)
                    }.value
                case .markdown:
                    // Use the array version for Markdown to preserve page breaks
                    data = try await Task.detached {
                        try MarkdownExportService.exportMultipleToMarkdownData(attributedStrings, filename: filename)
                    }.value
            case .pdf, .plainText, .fountain, .finalDraft:
                    // Not supported for combined folder export
                    return
                }
                
                await MainActor.run {
                    exportData = data
                    showExportSaveDialog = true
                }
                
            } catch {
                await MainActor.run {
                    importErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed") + ": \(error.localizedDescription)"
                    showImportError = true
                }
            }
        }
    }
    
    /// Show image warning alert after a short delay so it doesn't get swallowed
    /// by the dismissing confirmationDialog on Mac Catalyst.
    func showImageWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showExportImageWarning = true
        }
    }

    func exportFiles(format: ExportFormat) {
        // Check entitlement for export
        if let projectType = folder.project?.type {
            if !EntitlementManager.shared.canExport(projectType: projectType) {
                upgradePromptReason = .exportBlocked(projectType: projectType)
                return
            }
        }
        
        // Set the export format
        self.exportFormat = format
        
        guard !filesToExport.isEmpty else { return }
        
        // Single file → use existing single-file export path
        if filesToExport.count == 1 {
            guard let firstFile = filesToExport.first,
                  let version = firstFile.currentVersion else {
                filesToExport = []
                return
            }
            
            var attributedString: NSAttributedString
            if let formattedContent = version.attributedContent {
                attributedString = formattedContent
            } else if !version.content.isEmpty {
                attributedString = NSAttributedString(
                    string: version.content,
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
            } else {
                filesToExport = []
                return
            }
            
            // For markdown files, render to rich text first
            if firstFile.isMarkdown && format != .markdown && format != .plainText {
                let markdownText = attributedString.string
                if let rendered = try? MarkdownImportService.importMarkdown(from: markdownText, styleSheet: firstFile.project?.styleSheet) {
                    attributedString = rendered
                }
            }
            
            performSingleFileExport(format: format, content: attributedString, filename: firstFile.name)
            return
        }
        
        // Multiple files → combine into a single document
        performMultiFileExport(format: format, files: filesToExport)
    }
    
    /// Export multiple files combined into a single document
    private func performMultiFileExport(format: ExportFormat, files: [TextFile]) {
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
            
            // For markdown files, render to rich text first
            if file.isMarkdown && format != .markdown && format != .plainText {
                let markdownText = content.string
                if let rendered = try? MarkdownImportService.importMarkdown(from: markdownText, styleSheet: file.project?.styleSheet) {
                    content = rendered
                }
            }
            
            attributedStrings.append(content)
        }
        
        guard !attributedStrings.isEmpty else {
            filesToExport = []
            return
        }
        
        let filename = folder.project?.name ?? folder.name ?? "Export"
        
        Task {
            do {
                let data: Data
                switch format {
                case .pdf:
                    guard let project = folder.project else { return }
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
                await MainActor.run {
                    importErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed") + ": \(error.localizedDescription)"
                    showImportError = true
                    filesToExport = []
                }
            }
        }
    }
    
    func performSingleFileExport(format: ExportFormat, content: NSAttributedString, filename: String) {
        #if DEBUG
        print("📤 performSingleFileExport called")
        print("   format: \(format)")
        print("   filename: \(filename)")
        print("   content length: \(content.length)")
        print("   content preview: '\(content.string.prefix(200))'")
        // Check if content has formatting (bold/italic)
        var boldRuns = 0, italicRuns = 0
        content.enumerateAttribute(.font, in: NSRange(location: 0, length: content.length), options: []) { value, _, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) { boldRuns += 1 }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { italicRuns += 1 }
            }
        }
        print("   formatting: bold=\(boldRuns) italic=\(italicRuns)")
        print("   has markdown syntax: \(content.string.contains("# ") || content.string.contains("**") || content.string.contains("## "))")
        #endif
        
        // Prepare export data based on format
        do {
            switch format {
            case .rtf:
                exportData = try WordDocumentService.exportToRTF(content, filename: filename)
            case .html:
                exportData = try HTMLExportService.exportToHTMLData(content, filename: filename)
            // EPUB only supported for manuscript export
            // case .epub:
            //     exportData = try EPUBExportService.exportToEPUB(content, filename: filename)
            case .epub:
                return
            case .word:
                // Export to DOCX using DOCXExportService
                let exportService = DOCXExportService(modelContext: modelContext)
                exportData = try exportService.exportToDOCX(content, filename: filename)
            case .markdown:
                exportData = try MarkdownExportService.exportToMarkdownData(content, filename: filename)
            case .pdf:
                guard let project = folder.project else { return }
                let manuscriptContent = ManuscriptContent(
                    attributedString: content,
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
            case .plainText, .fountain, .finalDraft:
                // Not supported for single file export from this view
                #if DEBUG
                print("   ❌ Format not supported for single file export")
                #endif
                return
            }
            
            // Set filename with proper extension for the file save dialog
            exportFilename = "\(filename).\(format.fileExtension)"
            
            #if DEBUG
            print("   ✅ Export data prepared: \(exportData?.count ?? 0) bytes")
            print("   Setting showExportSaveDialog = true")
            #endif
            
            showExportSaveDialog = true
            
        } catch {
            #if DEBUG
            print("   ❌ Export error: \(error)")
            #endif
            importErrorMessage = NSLocalizedString("export.error.failed", comment: "Export failed") + ": \(error.localizedDescription)"
            showImportError = true
            filesToExport = []
        }
    }
    
    func handleExportResult(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            #if DEBUG
            print("✅ Exported to: \(url.path)")
            #endif
            // Clear all files — multi-file exports are combined into one document
            filesToExport = []
        case .failure(let error):
            #if DEBUG
            print("❌ Export failed: \(error.localizedDescription)")
            #endif
            filesToExport = []
        }
    }
    
    func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .rtf:
            return .rtf
        case .html:
            return .html
        // EPUB only supported for manuscript export
        case .epub:
            return UTType(filenameExtension: "epub") ?? .data
        case .word:
            // DOCX uses the official UTType identifier
            return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pdf:
            return .pdf
        case .plainText:
            return .plainText
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        case .fountain:
            return UTType(filenameExtension: "fountain") ?? .plainText
        case .finalDraft:
            return UTType(filenameExtension: "fdx") ?? .xml
        }
    }
    
    func renameFile(newName: String) {
        guard let file = filesToRename.first else { return }
        
        file.name = newName
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error renaming file: \(error)")
            #endif
            // TODO: Show error alert
        }
        
        filesToRename = []
        showRenamePicker = false
    }
}

// MARK: - Export Document Type

struct ExportDocument: FileDocument {
    /// Cached content types to avoid repeated UTType lookups on every view evaluation
    private static let _contentTypes: [UTType] = {
        [.pdf, .rtf, .html, .xml, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "fountain") ?? .plainText, UTType(filenameExtension: "fdx") ?? .xml, UTType(filenameExtension: "epub") ?? .data, .data]
    }()
    
    static var readableContentTypes: [UTType] { _contentTypes }
    
    static var writableContentTypes: [UTType] { _contentTypes }
    
    var data: Data
    var filename: String
    var contentType: UTType
    
    init(data: Data, filename: String, contentType: UTType = .rtf) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        filename = ""
        contentType = .data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
