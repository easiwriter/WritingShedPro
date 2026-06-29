//
//  FileListView.swift
//  Writing Shed Pro
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 2, 6
//

import SwiftUI
import SwiftData

/// Reusable file list component with edit mode, swipe actions, and multi-select toolbar.
///
/// **Key Features:**
/// - Edit mode with selection circles (⚪/⚫)
/// - Swipe actions for quick single-file operations (normal mode only)
/// - Bottom toolbar with Delete for multiple selections
/// - iOS-standard pattern following Mail/Files/Photos apps
/// - **Mac Catalyst**: Cmd+Click multi-select, right-click context menu
///
/// **Usage:**
/// ```swift
/// FileListView(
///     files: folder.textFiles ?? [],
///     onFileSelected: { file in
///         navigationPath.append(file)
///     },
///     onDelete: { files in
///         deleteFiles(files)
///     }
/// )
/// ```
struct FileListView: View {
    // MARK: - Properties
    
    /// Files to display in the list
    let files: [TextFile]
    
    /// Called when user taps a file in normal mode
    let onFileSelected: (TextFile) -> Void
    
    /// Called when user initiates move action (optional - only for Prose projects)
    let onMove: (([TextFile]) -> Void)?
    
    /// Called when user initiates delete action (single or multiple files)
    let onDelete: ([TextFile]) -> Void
    
    /// Called when user initiates export action (optional)
    let onExport: (([TextFile]) -> Void)?

    /// Called when user initiates Save As action (optional)
    let onExportSaveAs: (([TextFile]) -> Void)?
    
    /// Called when user initiates submit action (optional - only for folders that support submissions)
    let onSubmit: (([TextFile]) -> Void)?
    
    /// Called when user drags to reorder files (optional)
    /// Signature matches .onMove: (source: IndexSet, destination: Int)
    let onReorder: ((IndexSet, Int) -> Void)?
    
    /// Called when user renames a file
    let onRename: (([TextFile]) -> Void)?
    
    /// Called when user initiates permanent delete action (bypassing trash)
    let onDeletePermanently: (([TextFile]) -> Void)?
    
    /// Called when user wants to change workflow status (optional - only for content folders)
    let onChangeStatus: (([TextFile]) -> Void)?
    
    /// Called when user wants to add files to a poetry collection (optional - only for Poetry content folders)
    let onAddToCollection: (([TextFile]) -> Void)?
    
    /// Called when user wants to manage container assignments (optional - shows full-screen assignment dialog)
    let onManageContainers: (() -> Void)?
    
    /// Called when user wants to print selected files (optional)
    let onPrint: (([TextFile]) -> Void)?
    
    /// Optional: Collection groups for displaying files grouped by collection (Poetry projects)
    /// When provided, a toggle button appears in the toolbar to switch between flat and collection-grouped views
    let collectionGroups: [CollectionGroup]?

    /// Whether there are any collections available for Add to Collection action.
    let hasAvailableCollectionsForAddToCollection: Bool
    
    // MARK: - State
    
    /// Edit mode state - read from environment (set by parent view with EditButton)
    @Environment(\.editMode) private var editMode
    
    /// Currently selected file IDs for multi-select operations
    /// Using UUID instead of TextFile for selection to work with List
    @State private var selectedFileIDs: Set<UUID> = []
    
    /// Controls delete confirmation alert
    @State private var showDeleteConfirmation = false
    
    /// Files pending deletion (cached for confirmation alert)
    @State private var filesToDelete: [TextFile] = []
    
    /// Controls rename modal visibility
    @State private var showRenameModal = false
    @State private var renameText = ""
    @State private var showRenameDuplicateWarning = false
    @State private var showNoCollectionsWarning = false
    @State private var showCollectionEligibilityWarning = false
    @State private var skippedCollectionIneligibleCount = 0
    @State private var pendingCollectionReadyFileIDs: Set<UUID> = []
    @State private var showSubmissionEligibilityWarning = false
    @State private var skippedSubmissionIneligibleCount = 0

    /// Tracks which alphabetical sections are expanded (collapsed by default)
    @State private var expandedSections: Set<String> = []
    
    /// Tracks the most recently opened section for quick return
    @State private var lastOpenedSection: String?
    
    /// Tracks which collection sections are expanded (bound from parent)
    @Binding var expandedCollections: Set<String>
    
    /// Feature 021: Poetry form picker for changing form
    @State private var fileForFormChange: TextFile?
    
    /// File details sheet
    @State private var fileForDetails: TextFile?
    
    /// AppStorage key prefix for persisting last opened section per folder
    private var storageKey: String {
        // Use hash of files to create unique key per folder
        "lastOpenedSection_\(files.map { $0.id.uuidString }.joined().hashValue)"
    }
    
    // MARK: - Computed Properties
    
    /// Selected files based on selectedFileIDs (uses uniqueFiles to avoid duplicates)
    private var selectedFiles: [TextFile] {
        uniqueFiles.filter { selectedFileIDs.contains($0.id) }
    }
    
    /// Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode?.wrappedValue == .active
    }
    
    /// Deduplicated files - handles any database corruption where same file appears multiple times
    private var uniqueFiles: [TextFile] {
        var seenIDs = Set<UUID>()
        return files.filter { file in
            if seenIDs.contains(file.id) {
                #if DEBUG
                print("⚠️ [FileListView] Duplicate file detected: \(file.name) (ID: \(file.id))")
                #endif
                return false
            }
            seenIDs.insert(file.id)
            return true
        }
    }
    
    /// Whether toolbar should be visible (edit mode + items selected)
    private var showToolbar: Bool {
        isEditMode && !selectedFileIDs.isEmpty
    }

    /// Selected files that are eligible for adding to a collection.
    private var selectedReadyFilesForCollection: [TextFile] {
        selectedFiles.filter { $0.workflowStatus == .ready }
    }

    /// Add to Collection should be available when at least one selected file is ready.
    private var canAddSelectedFilesToCollection: Bool {
        !selectedReadyFilesForCollection.isEmpty
    }

    /// Add to Submission should be available when at least one selected file is ready.
    private var canAddSelectedFilesToSubmission: Bool {
        !selectedReadyFilesForCollection.isEmpty
    }
    
    /// Alphabetically grouped sections of files
    private var sections: [AlphabeticalSectionHelper.Section<TextFile>] {
        AlphabeticalSectionHelper.groupFiles(uniqueFiles)
    }
    
    /// Determines if alphabetical sections should be used
    /// Use sections when file count exceeds one screenful (~15 files)
    /// Never use sections when reordering is enabled — drag-to-reorder
    /// requires a flat ForEach with .onMove, and cross-section drag
    /// doesn't make sense for user-ordered content folders.
    /// Disabled when collection grouping is active.
    private var useSections: Bool {
        !useCollectionGrouping && onReorder == nil && uniqueFiles.count > 15
    }
    
    /// Whether collection grouping is currently active (always on when data exists)
    private var useCollectionGrouping: Bool {
        collectionGroups != nil && !(collectionGroups?.isEmpty ?? true)
    }

    /// Whether every file in the current list is selected.
    private var allFilesSelected: Bool {
        !uniqueFiles.isEmpty && selectedFileIDs.count == uniqueFiles.count
    }
    
    // MARK: - Body
    
    var body: some View {
        let deleteTitle: String = filesToDelete.count == 1
            ? NSLocalizedString("fileList.deleteFile.title", comment: "Delete file?")
            : String(format: NSLocalizedString("fileList.deleteFiles.title", comment: "Delete files?"), filesToDelete.count)
        
        fileListContainer
            .toolbar {
                // Top toolbar for alphabetical expand/collapse (only when using sections and not in edit mode)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditMode {
                        selectAllToggleButton
                    } else if useSections {
                        expandCollapseButtons
                    }
                }
                
                // Bottom toolbar for multi-select actions (only in edit mode)
                ToolbarItemGroup(placement: .bottomBar) {
                    if showToolbar {
                        bottomToolbarContent
                    }
                }
            }
            .confirmationDialog(
                deleteTitle,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                deleteConfirmationButtons
            } message: {
                Text(NSLocalizedString("fileList.deleteConfirmation.messageEnhanced", comment: "Delete moves to trash, Delete Forever is permanent"))
            }
        .onChange(of: editMode?.wrappedValue) { _, newValue in
            handleEditModeChange(newValue)
        }
        .onAppear {
            handleAppear()
        }
        .alert("fileList.rename.title", isPresented: $showRenameModal) {
            TextField("fileList.rename.placeholder", text: $renameText)
            
            Button("fileList.rename.cancel", role: .cancel) {
                renameText = ""
            }
            
            Button("fileList.rename.confirm") {
                handleRename()
            }
        } message: {
            Text("fileList.rename.prompt")
        }
        .alert("fileList.rename.duplicateTitle", isPresented: $showRenameDuplicateWarning) {
            Button("fileList.rename.duplicateConfirm", role: .destructive) {
                confirmRename()
            }
            Button("fileList.rename.duplicateCancel", role: .cancel) { }
        } message: {
            Text("fileList.rename.duplicateMessage")
        }
        .alert(NSLocalizedString("fileList.noCollections.title", comment: "No collections available"), isPresented: $showNoCollectionsWarning) {
            Button("button.ok", role: .cancel) { }
        } message: {
            Text(NSLocalizedString("fileList.noCollections.message", comment: "Create a collection first"))
        }
        .alert(NSLocalizedString("fileList.partialSelection.title", comment: "Some files were skipped"), isPresented: $showCollectionEligibilityWarning) {
            Button("button.cancel", role: .cancel) {
                pendingCollectionReadyFileIDs.removeAll()
            }
            Button("button.continue") {
                continueAddToCollectionAfterWarning()
            }
        } message: {
            Text(String(format: NSLocalizedString("fileList.partialSelection.message", comment: "Skipped non-ready files message"), skippedCollectionIneligibleCount))
        }
        .alert(NSLocalizedString("fileList.partialSelection.title", comment: "Some files were skipped"), isPresented: $showSubmissionEligibilityWarning) {
            Button("button.ok", role: .cancel) { }
        } message: {
            Text(String(format: NSLocalizedString("fileList.partialSelection.message", comment: "Skipped non-ready files message"), skippedSubmissionIneligibleCount))
        }
        .sheet(item: $fileForFormChange) { file in
            PoetryFormPickerSheet(file: file)
        }
        .sheet(item: $fileForDetails) { file in
            FileDetailsSheet(file: file, onExport: onExport != nil ? { f in
                fileForDetails = nil
                onExport?([f])
            } : nil, onSaveAs: onExportSaveAs != nil ? { f in
                fileForDetails = nil
                onExportSaveAs?([f])
            } : nil)
        }
    }
    
    private func handleEditModeChange(_ newValue: EditMode?) {
        if useCollectionGrouping, let groups = collectionGroups {
            if newValue == .active {
                expandedCollections = Set(groups.map { $0.id })
            }
        } else if useSections {
            if newValue == .active {
                expandedSections = Set(sections.map { $0.letter })
            } else if newValue == .inactive {
                if let lastSection = lastOpenedSection {
                    expandedSections = [lastSection]
                } else {
                    expandedSections.removeAll()
                }
            }
        }
        
        if newValue == .inactive {
            selectedFileIDs.removeAll()
        }
    }
    
    private func handleAppear() {
        if useCollectionGrouping, let groups = collectionGroups {
            if expandedCollections.isEmpty {
                expandedCollections = Set(groups.map { $0.id })
            }
        } else if useSections {
            loadLastOpenedSection()
        }
    }

    private func continueAddToCollectionAfterWarning() {
        guard hasAvailableCollectionsForAddToCollection else {
            pendingCollectionReadyFileIDs.removeAll()
            showNoCollectionsWarning = true
            return
        }

        guard let onAddToCollection = onAddToCollection else {
            pendingCollectionReadyFileIDs.removeAll()
            return
        }

        let readyFiles = uniqueFiles.filter { pendingCollectionReadyFileIDs.contains($0.id) }
        guard !readyFiles.isEmpty else {
            pendingCollectionReadyFileIDs.removeAll()
            return
        }

        onAddToCollection(readyFiles)
        pendingCollectionReadyFileIDs.removeAll()
    }
    
    // MARK: - Extracted Content
    
    private var fileListContainer: some View {
        List {
            if useCollectionGrouping, let groups = collectionGroups {
                ForEach(groups) { group in
                    Section {
                        if expandedCollections.contains(group.id) {
                            ForEach(group.files) { file in
                                fileRow(for: file)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if !isEditMode {
                                            swipeActionButtons(for: file)
                                        }
                                    }
                            }
                        }
                    } header: {
                        collectionSectionHeader(for: group)
                    }
                }
            } else if useSections {
                ForEach(sections) { section in
                    Section {
                        if expandedSections.contains(section.letter) {
                            ForEach(section.items) { file in
                                fileRow(for: file)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if !isEditMode {
                                            swipeActionButtons(for: file)
                                        }
                                    }
                            }
                        }
                    } header: {
                        sectionHeader(for: section)
                    }
                }
            } else {
                ForEach(uniqueFiles) { file in
                    fileRow(for: file)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isEditMode {
                                swipeActionButtons(for: file)
                            }
                        }
                }
                .onMove(perform: onReorder)
            }
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var deleteConfirmationButtons: some View {
        Button(NSLocalizedString("fileList.delete", comment: "Delete"), role: .destructive) {
            confirmDelete()
        }
        if onDeletePermanently != nil {
            Button(NSLocalizedString("fileList.deletePermanently", comment: "Delete Forever"), role: .destructive) {
                confirmDeletePermanently()
            }
        }
        Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
            filesToDelete = []
        }
    }
    
    // MARK: - View Builders
    
    /// Section header with letter, count, and expand/collapse functionality
    @ViewBuilder
    private func sectionHeader(for section: AlphabeticalSectionHelper.Section<TextFile>) -> some View {
        let isExpanded = expandedSections.contains(section.letter)
        
        Button {
            withAnimation {
                if expandedSections.contains(section.letter) {
                    expandedSections.remove(section.letter)
                } else {
                    expandedSections.insert(section.letter)
                    // Track this as the last opened section
                    lastOpenedSection = section.letter
                    saveLastOpenedSection(section.letter)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Disclosure indicator - more prominent
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(width: 20)
                
                Text(section.letter)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("(\(section.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(section.letter), \(section.count) files"))
        .accessibilityHint(Text(isExpanded ? "Tap to collapse section" : "Tap to expand section"))
    }
    
    /// File row view - behavior changes based on edit mode
    @ViewBuilder
    private func fileRow(for file: TextFile) -> some View {
        HStack {
            // Main content area - clickable to select/navigate
            HStack {
                // Selection circle in edit mode
                if isEditMode {
                    Image(systemName: selectedFileIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedFileIDs.contains(file.id) ? .blue : .gray)
                        .imageScale(.large)
                }
                
                // File icon - different for markdown files
                Image(systemName: file.isMarkdown ? "number.square" : "doc.text")
                    .foregroundStyle(file.isMarkdown ? .orange : .secondary)
                
                Text(file.name)
                    .foregroundColor(file.workflowStatus.map { Color($0.color) } ?? .primary)
                    .opacity(file.includedInManuscript ? 1.0 : 0.5)
                
                // Manuscript exclusion indicator (Feature 029)
                if !file.includedInManuscript && file.project?.folders?.contains(where: { $0.name == "Manuscript" }) == true {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                Spacer(minLength: 8)  // Ensure some spacing before the buttons
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditMode {
                    // Edit mode: toggle selection
                    toggleSelection(for: file)
                } else {
                    // Normal mode: navigate to file
                    onFileSelected(file)
                }
            }
            .contextMenu {
                contextMenuItems(for: file)
            }
            
            // Submissions button and ellipsis menu (only in normal mode) - separate tap targets
            if !isEditMode {
                SubmissionsButton(file: file)
                
                // Ellipsis menu button (hidden for back matter files)
                let isBackMatterFile = ["Endnotes", "Glossary", "References", "Index", "Contributors"].contains(file.name)
                if !isBackMatterFile {
                    fileOptionsMenu(for: file)
                }
            }
        }
    }
    
    /// Details button for a file (ellipsis button opens details sheet directly)
    @ViewBuilder
    private func fileOptionsMenu(for file: TextFile) -> some View {
        Button {
            fileForDetails = file
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("fileList.options", comment: "File options"))
    }
    
    /// Swipe action buttons (only shown in normal mode)
    @ViewBuilder
    private func swipeActionButtons(for file: TextFile) -> some View {
        // Move button only shown if onMove is provided (Prose projects)
        if let onMove = onMove {
            Button {
                onMove([file])
            } label: {
                Label("fileList.move", systemImage: "folder")
            }
            .tint(.blue)
        }
        
        // Delete button not shown for back matter files
        let isBackMatterFile = ["Endnotes", "Glossary", "References", "Index"].contains(file.name)
        if !isBackMatterFile {
            Button {
                prepareDelete([file])
            } label: {
                Label("fileList.delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }
    
    /// Expand/Collapse all buttons for section view
    @ViewBuilder
    private var expandCollapseButtons: some View {
        let allExpanded = expandedSections.count == sections.count
        
        Button {
            withAnimation {
                if allExpanded {
                    // Collapse all
                    expandedSections.removeAll()
                    lastOpenedSection = nil
                    // Clear saved preference so next visit defaults to expanded
                    UserDefaults.standard.removeObject(forKey: storageKey)
                } else {
                    // Expand all
                    expandedSections = Set(sections.map { $0.letter })
                    // Don't save preference - let it default to expanded next time
                }
            }
        } label: {
            Label(
                allExpanded ? 
                    NSLocalizedString("fileList.collapseAll", comment: "Collapse all sections") :
                    NSLocalizedString("fileList.expandAll", comment: "Expand all sections"),
                systemImage: allExpanded ? "chevron.up.circle" : "chevron.down.circle"
            )
        }
        .accessibilityLabel(Text(allExpanded ?
            "fileList.collapseAll.accessibility" :
            "fileList.expandAll.accessibility"))
        .accessibilityHint(Text(allExpanded ?
            "fileList.collapseAll.hint" :
            "fileList.expandAll.hint"))
    }

    @ViewBuilder
    private var selectAllToggleButton: some View {
        Button {
            if allFilesSelected {
                selectedFileIDs.removeAll()
            } else {
                selectedFileIDs = Set(uniqueFiles.map { $0.id })
            }
        } label: {
            Text(allFilesSelected
                ? NSLocalizedString("fileList.deselectAll", comment: "Deselect All")
                : NSLocalizedString("fileList.selectAll", comment: "Select All"))
        }
        .disabled(uniqueFiles.isEmpty)
        .accessibilityLabel(allFilesSelected
            ? NSLocalizedString("fileList.deselectAll.accessibility", comment: "Deselect all files")
            : NSLocalizedString("fileList.selectAll.accessibility", comment: "Select all files"))
    }
    
    /// Collection section header with name, count, and expand/collapse
    @ViewBuilder
    private func collectionSectionHeader(for group: CollectionGroup) -> some View {
        let isExpanded = expandedCollections.contains(group.id)
        
        Button {
            withAnimation {
                if expandedCollections.contains(group.id) {
                    expandedCollections.remove(group.id)
                } else {
                    expandedCollections.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
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
            NSLocalizedString("section.collapse.hint", comment: "Tap to collapse") :
            NSLocalizedString("section.expand.hint", comment: "Tap to expand")))
    }
    
    /// Bottom toolbar content for edit mode
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Change Status button (if onChangeStatus callback provided)
        if let onChangeStatus = onChangeStatus {
            Button {
                onChangeStatus(selectedFiles)
            } label: {
                Label(
                    NSLocalizedString("fileList.changeStatus", comment: "Change status"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .disabled(selectedFiles.isEmpty)
        }
        
        // Add to Collection button (if onAddToCollection callback provided - Poetry projects)
        if onAddToCollection != nil {
            Button {
                guard hasAvailableCollectionsForAddToCollection else {
                    showNoCollectionsWarning = true
                    return
                }

                let readyFiles = selectedReadyFilesForCollection
                let skippedCount = selectedFiles.count - readyFiles.count
                if skippedCount > 0 {
                    pendingCollectionReadyFileIDs = Set(readyFiles.map { $0.id })
                    skippedCollectionIneligibleCount = skippedCount
                    showCollectionEligibilityWarning = true
                } else {
                    onAddToCollection?(readyFiles)
                }
            } label: {
                Label(
                    NSLocalizedString("fileList.addToCollection", comment: "Add to Collection"),
                    systemImage: "doc.text"
                )
            }
            .disabled(!canAddSelectedFilesToCollection)
        }
        
        // Add to submission button (if onSubmit callback provided)
        if let onSubmit = onSubmit {
            Button {
                let readyFiles = selectedReadyFilesForCollection
                let skippedCount = selectedFiles.count - readyFiles.count
                onSubmit(readyFiles)

                if skippedCount > 0 {
                    skippedSubmissionIneligibleCount = skippedCount
                    showSubmissionEligibilityWarning = true
                }
                exitEditMode()
            } label: {
                Label(
                    NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"),
                    systemImage: "tray.and.arrow.down"
                )
            }
            .disabled(!canAddSelectedFilesToSubmission)
        }
        
        // Rename button (only when exactly 1 file is selected)
        if selectedFiles.count == 1, let file = selectedFiles.first, onRename != nil {
            Button {
                renameText = file.name
                showRenameModal = true
            } label: {
                Label(
                    NSLocalizedString("fileList.rename", comment: "Rename file"),
                    systemImage: "pencil.circle"
                )
            }
            .accessibilityLabel("fileList.rename.accessibility")
        }
        
        // Export button (if onExport callback provided)
        if let onExport = onExport {
            Button {
                onExport(selectedFiles)
                exitEditMode()
            } label: {
                Label(
                    NSLocalizedString("fileList.export", comment: "Export files"),
                    systemImage: "square.and.arrow.up"
                )
            }
            .disabled(selectedFiles.isEmpty)
            .accessibilityLabel("Export selected files")

            #if os(macOS) || targetEnvironment(macCatalyst)
            if let onExportSaveAs = onExportSaveAs {
                Button {
                    onExportSaveAs(selectedFiles)
                    exitEditMode()
                } label: {
                    Label(
                        NSLocalizedString("manuscript.saveAs", comment: "Save As…"),
                        systemImage: "square.and.arrow.down"
                    )
                }
                .disabled(selectedFiles.isEmpty)
                .accessibilityLabel("Save selected files as")
            }
            #endif
        }
        
        // Print button (if onPrint callback provided)
        if let onPrint = onPrint {
            Button {
                onPrint(selectedFiles)
            } label: {
                Label(
                    NSLocalizedString("fileList.print", comment: "Print"),
                    systemImage: "printer"
                )
            }
            .disabled(selectedFiles.isEmpty)
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
        .accessibilityLabel("fileList.deleteSelected.accessibility")
    }
    
    /// Context menu items for macOS right-click
    @ViewBuilder
    private func contextMenuItems(for file: TextFile) -> some View {
        #if targetEnvironment(macCatalyst)
        // macOS: Show context menu
        Button {
            onFileSelected(file)
        } label: {
            Label("fileList.contextMenu.open", systemImage: "doc")
        }
        
        // Poetry form change option (only for poetry projects)
        if file.project?.type == .poetry {
            Divider()
            
            Button {
                fileForFormChange = file
            } label: {
                Label("fileList.contextMenu.changeForm", systemImage: "text.book.closed")
            }
        }
        
        // Workflow status change option (only if callback provided)
        if let onChangeStatus = onChangeStatus {
            Divider()
            
            // Use callback to show status picker (parent handles status change and submission sync)
            Button {
                onChangeStatus([file])
            } label: {
                Label(NSLocalizedString("fileList.contextMenu.changeStatus", comment: "Change Status"), systemImage: "arrow.triangle.2.circlepath")
            }
        }
        
        // Manuscript include/exclude toggle (Feature 029)
        // Show for projects that have a Manuscript folder
        if file.project?.folders?.contains(where: { $0.name == "Manuscript" }) == true {
            Divider()
            
            Button {
                file.includedInManuscript.toggle()
            } label: {
                if file.includedInManuscript {
                    Label(NSLocalizedString("fileList.contextMenu.excludeFromManuscript", comment: "Exclude from Manuscript"), systemImage: "doc.badge.minus")
                } else {
                    Label(NSLocalizedString("fileList.contextMenu.includeInManuscript", comment: "Include in Manuscript"), systemImage: "doc.badge.plus")
                }
            }
        }
        
        Divider()
        
        // Move option (only for Prose projects)
        if let onMove = onMove {
            Button {
                onMove([file])
            } label: {
                Label("fileList.contextMenu.moveTo", systemImage: "folder")
            }
        }
        
        Button(role: .destructive) {
            prepareDelete([file])
        } label: {
            Label("fileList.contextMenu.delete", systemImage: "trash")
        }
        #else
        // iOS: Context menu disabled (use swipe actions instead)
        EmptyView()
        #endif
    }
    
    // MARK: - Actions
    
    /// Toggles selection for a file (tap-to-toggle in edit mode)
    private func toggleSelection(for file: TextFile) {
        if selectedFileIDs.contains(file.id) {
            selectedFileIDs.remove(file.id)
        } else {
            selectedFileIDs.insert(file.id)
        }
    }
    
    /// Prepares files for deletion and shows confirmation alert
    private func prepareDelete(_ files: [TextFile]) {
        filesToDelete = files
        showDeleteConfirmation = true
    }
    
    /// Confirms deletion and exits edit mode
    private func confirmDelete() {
        onDelete(filesToDelete)
        filesToDelete = []
        exitEditMode()
    }
    
    /// Confirms permanent deletion and exits edit mode
    private func confirmDeletePermanently() {
        onDeletePermanently?(filesToDelete)
        filesToDelete = []
        exitEditMode()
    }
    
    /// Exits edit mode (returns to normal mode)
    private func exitEditMode() {
        withAnimation {
            editMode?.wrappedValue = .inactive
        }
    }
    
    // MARK: - Rename Methods
    
    /// Handles rename - checks for duplicates
    private func handleRename() {
        guard let fileToRename = selectedFiles.first else { return }
        let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
        
        // Check if a file with this name already exists
        let hasDuplicate = files.contains { otherFile in
            otherFile.id != fileToRename.id &&
            otherFile.name.lowercased() == trimmedName.lowercased()
        }
        
        if hasDuplicate {
            showRenameDuplicateWarning = true
        } else {
            confirmRename()
        }
    }
    
    /// Performs the actual rename
    private func confirmRename() {
        guard let fileToRename = selectedFiles.first else { return }
        let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
        
        if !trimmedName.isEmpty && trimmedName != fileToRename.name {
            fileToRename.name = trimmedName
            fileToRename.modifiedDate = Date()
            onRename?([fileToRename])
        }
        
        renameText = ""
        selectedFileIDs.removeAll()
    }
    
    // MARK: - Section Persistence
    
    /// Saves the last opened section to UserDefaults
    private func saveLastOpenedSection(_ letter: String) {
        UserDefaults.standard.set(letter, forKey: storageKey)
    }
    
    /// Loads the last opened section from UserDefaults and expands it
    /// If no saved preference exists, expands all sections by default
    private func loadLastOpenedSection() {
        if let savedSection = UserDefaults.standard.string(forKey: storageKey),
           sections.contains(where: { $0.letter == savedSection }) {
            // Restore the last opened section only if user had previously opened one
            lastOpenedSection = savedSection
            expandedSections.insert(savedSection)
        } else {
            // No saved preference - expand all sections by default for first visit
            expandedSections = Set(sections.map { $0.letter })
        }
    }
    
}

// MARK: - Submissions Button Component

/// Button that shows submission icon and opens submission history for a file
/// Only displayed if the file has at least one submission
private struct SubmissionsButton: View {
    @State private var showSubmissions = false
    
    let file: TextFile
    
    // Count submissions from the file's relationship
    private var submissionCount: Int {
        file.submittedFiles?.count ?? 0
    }
    
    var body: some View {
        // Only show button if file has submissions
        if submissionCount > 0 {
            Button {
                showSubmissions = true
            } label: {
                Image(systemName: "paperplane.circle")
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.file.submissions", comment: "File submissions"), submissionCount)))
            .sheet(isPresented: $showSubmissions) {
                FileSubmissionsView(file: file)
            }
        }
    }
}

// MARK: - Collection Group

/// Represents a group of files belonging to a poetry collection
struct CollectionGroup: Identifiable {
    let id: String
    let name: String
    let files: [TextFile]
    
    var count: Int { files.count }
}
