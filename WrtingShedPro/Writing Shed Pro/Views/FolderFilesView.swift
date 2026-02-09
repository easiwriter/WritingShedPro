//
//  FolderFilesView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature 008a Integration: Replaces FileEditableList with FileListView
//

import SwiftUI
import SwiftData
import TipKit
import UniformTypeIdentifiers

/// View for displaying and managing files within a folder
/// Uses the new FileListView component with full file movement support
struct FolderFilesView: View {
    @Bindable var folder: Folder
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    // Query all folders to ensure we have fresh relationships
    @Query private var allFolders: [Folder]
    
    // Query all files (lazily loaded by SwiftData)
    @Query(sort: [SortDescriptor(\TextFile.name, order: .forward)]) var allTextFiles: [TextFile]
    
    // State for edit mode (shared with FileListView)
    @State var editMode: EditMode = .inactive
    
    // State for add file sheet
    @State var showAddFileSheet = false
    
    // State for add folder sheet (for mixed-content folders)
    @State var showAddFolderSheet = false
    
    // State for navigation
    @State var selectedFile: TextFile?
    @State var navigateToFile = false
    
    // State for submission picker
    @State var showSubmissionPicker = false
    @State var filesToSubmit: [TextFile] = []
    
    // State for collection picker
    @State var showCollectionPicker = false
    @State var filesToAddToCollection: [TextFile] = []
    
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
    @State var showImageWarning = false  // Show warning for RTF with images
    @State var imageWarningMessage = ""
    
    // State for search
    @State var showSearchView = false
    
    // State for header/footer editor
    @State var showHeaderFooterEditor = false
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
    
    // State for early dismissal - prevents continued rendering during navigation
    @State var isDismissing = false
    
    // Query all trash items (for trash count check)
    @Query private var allTrashItems: [TrashItem]
    
    /// Returns the number of TrashItem objects for this folder's project
    private var trashItemCount: Int {
        guard let project = folder.project else { return 0 }
        return allTrashItems.filter { $0.project?.id == project.id }.count
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
            onAddToCollection: fileListOnAddToCollection,
            onReorder: nil,
            onRename: isReadOnly ? { _ in } : handleRename,
            onDeletePermanently: isReadOnly ? { _ in } : deleteFilesPermanently,
            onChangeStatus: (isContentFolder && !isReadOnly) ? handleChangeStatus : nil
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
    
    @ViewBuilder
    var navigationDestinationContent: some View {
        if let file = selectedFile {
            if let project = folder.resolvedProject, project.type == .drama,
               FolderCapabilityService.isContentFolder(folder) {
                DramaSceneEditorView(file: file, project: project)
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
            
            // FR-8.1: Donate file creation event for Collections tip
            if !sortedFiles.isEmpty {
                Task { await CollectionsTip.fileCreated.donate() }
            }
        }
    }
    
    // MARK: - Main Content (extracted to reduce body complexity)
    
    @ViewBuilder
    private var mainContent: some View {
        // Skip rendering file list when navigating away to improve back button responsiveness
        if isDismissing {
            #if DEBUG
            let _ = print("🔙 [FolderFilesView] isDismissing=true, rendering Color.clear instead of file list")
            #endif
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if folder.name == "Trash" && trashItemCount == 0 {
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
                            // FR-2.4: Folder organisation tip
                            if TipKitConfiguration.tipsEnabled {
                                TipView(FolderOrganisationTip()) { action in
                                    TipActionHandler.handle(action, guideSection: FolderOrganisationTip.guideSection)
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                            }
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
            showSubmissionPicker = true
        } : nil
    }
    
    private var fileListOnAddToCollection: (([TextFile]) -> Void)? {
        supportsAddToCollection ? { files in
            filesToAddToCollection = files
            showCollectionPicker = true
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
            if newValue == .inactive {
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
                Text(file.name)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    /// Reorder matter folder files
    private func moveMatterFiles(from source: IndexSet, to destination: Int) {
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
            .foregroundStyle(.primary)
            
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
        
        // Submit button (only when files selected, no folders)
        if filesOnlySelected {
            Button {
                filesToSubmit = selectedFiles
                showSubmissionPicker = true
            } label: {
                Image(systemName: "book.badge.plus")
            }
            .accessibilityLabel(NSLocalizedString("fileList.submit", comment: "Submit files"))
            
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
    
    func createSubmission(for publication: Publication, name: String, expectedResponseDate: Date? = nil) {
        guard let project = folder.project else { return }
        
        // Create submission
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        submission.name = name
        submission.isCollection = false  // This is a submission to a publication
        submission.returnExpectedBy = expectedResponseDate
        modelContext.insert(submission)
        
        // Create submitted file records for each selected file
        for file in filesToSubmit {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        // Clear selection after submission
        selectedFileIDs.removeAll()
        editMode = .inactive
        filesToSubmit = []
    }
    
    func addFilesToCollection(_ collection: Submission) {
        guard let project = folder.project else { return }
        
        // Create submitted file records for each selected file in the collection
        for file in filesToAddToCollection {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: collection,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error adding files to collection: \(error)")
            #endif
            // TODO: Show error alert
        }
        
        filesToAddToCollection = []
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
                  let attributedString = version.attributedContent else {
                continue
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
        
        // Check for images in RTF export
        if format == .rtf && RTFImageEncoder.containsImages(combinedContent) {
            imageWarningMessage = "RTF format does not support embedded images. Images will be replaced with '[Image omitted]' placeholders. For documents with images, please use HTML or EPUB export instead."
            showImageWarning = true
            // Don't proceed with export yet - wait for user to dismiss alert
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
                // EPUB reserved for future release
                // case .epub:
                //     // Use the array version for EPUB to preserve page breaks and prevent CSS conflicts
                //     data = try await Task.detached {
                //         try EPUBExportService.exportMultipleToEPUB(attributedStrings, filename: filename)
                //     }.value
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
                case .pdf, .plainText:
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
        
        // Get the first file to export
        guard let firstFile = filesToExport.first,
              let version = firstFile.currentVersion else {
            #if DEBUG
            print("❌ Export failed: No file or version available")
            #endif
            filesToExport = []
            return
        }
        
        // Get content - try formatted content first, fall back to plain text
        let attributedString: NSAttributedString
        if let formattedContent = version.attributedContent {
            attributedString = formattedContent
        } else if !version.content.isEmpty {
            // Create attributed string from plain text
            attributedString = NSAttributedString(
                string: version.content,
                attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
            )
            #if DEBUG
            print("📝 Export: Using plain text content for '\(firstFile.name)'")
            #endif
        } else {
            #if DEBUG
            print("❌ Export failed: No content available for '\(firstFile.name)'")
            #endif
            importErrorMessage = NSLocalizedString("export.error.noContent", comment: "No content to export")
            showImportError = true
            filesToExport = []
            return
        }
        
        // Check for images in RTF export
        if format == .rtf && RTFImageEncoder.containsImages(attributedString) {
            imageWarningMessage = "RTF format does not support embedded images. Images will be replaced with '[Image omitted]' placeholders. For documents with images, please use HTML or EPUB export instead."
            showImageWarning = true
            // Don't proceed with export yet - wait for user to dismiss alert
            return
        }
        
        // Perform the actual export
        performSingleFileExport(format: format, content: attributedString, filename: firstFile.name)
    }
    
    func performSingleFileExport(format: ExportFormat, content: NSAttributedString, filename: String) {
        #if DEBUG
        print("📤 performSingleFileExport called")
        print("   format: \(format)")
        print("   filename: \(filename)")
        print("   content length: \(content.length)")
        #endif
        
        // Prepare export data based on format
        do {
            switch format {
            case .rtf:
                exportData = try WordDocumentService.exportToRTF(content, filename: filename)
            case .html:
                exportData = try HTMLExportService.exportToHTMLData(content, filename: filename)
            // EPUB reserved for future release
            // case .epub:
            //     exportData = try EPUBExportService.exportToEPUB(content, filename: filename)
            case .word:
                // Export to DOCX using DOCXExportService
                let exportService = DOCXExportService(modelContext: modelContext)
                exportData = try exportService.exportToDOCX(content, filename: filename)
            case .markdown:
                exportData = try MarkdownExportService.exportToMarkdownData(content, filename: filename)
            case .pdf, .plainText:
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
            // Remove the first file and continue with remaining files if any
            if !filesToExport.isEmpty {
                filesToExport.removeFirst()
                if !filesToExport.isEmpty {
                    // Export next file
                    exportFiles(format: exportFormat)
                }
            }
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
        // EPUB reserved for future release
        // case .epub:
        //     // EPUB uses a custom UTType
        //     return UTType(filenameExtension: "epub") ?? .data
        case .word:
            // DOCX uses the official UTType identifier
            return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .pdf:
            return .pdf
        case .plainText:
            return .plainText
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
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
    static var readableContentTypes: [UTType] { 
        [.rtf, .html, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, UTType(filenameExtension: "md") ?? .plainText, .data] 
    }
    
    static var writableContentTypes: [UTType] { 
        [.rtf, .html, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, UTType(filenameExtension: "md") ?? .plainText, .data] 
    }
    
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
