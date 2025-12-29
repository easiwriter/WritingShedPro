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
/// - Bottom toolbar with Move/Delete for multiple selections
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
///     onMove: { files in
///         showMoveDestinationPicker = true
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
    
    /// Called when user initiates move action (single or multiple files)
    let onMove: ([TextFile]) -> Void
    
    /// Called when user initiates delete action (single or multiple files)
    let onDelete: ([TextFile]) -> Void
    
    /// Called when user initiates export action (optional)
    let onExport: (([TextFile]) -> Void)?
    
    /// Called when user initiates submit action (optional - only for folders that support submissions)
    let onSubmit: (([TextFile]) -> Void)?
    
    /// Called when user initiates add to collection action (optional - only for Ready folder)
    let onAddToCollection: (([TextFile]) -> Void)?
    
    /// Called when user drags to reorder files (optional - not used, files always alphabetically sorted)
    let onReorder: (() -> Void)?
    
    /// Called when user renames a file
    let onRename: (([TextFile]) -> Void)?
    
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
    
    /// Tracks which alphabetical sections are expanded (collapsed by default)
    @State private var expandedSections: Set<String> = []
    
    /// Tracks the most recently opened section for quick return
    @State private var lastOpenedSection: String?
    
    /// AppStorage key prefix for persisting last opened section per folder
    private var storageKey: String {
        // Use hash of files to create unique key per folder
        "lastOpenedSection_\(files.map { $0.id.uuidString }.joined().hashValue)"
    }
    
    // MARK: - Computed Properties
    
    /// Selected files based on selectedFileIDs
    private var selectedFiles: [TextFile] {
        files.filter { selectedFileIDs.contains($0.id) }
    }
    
    /// Whether edit mode is currently active
    private var isEditMode: Bool {
        editMode?.wrappedValue == .active
    }
    
    /// Whether toolbar should be visible (edit mode + items selected)
    private var showToolbar: Bool {
        isEditMode && !selectedFileIDs.isEmpty
    }
    
    /// Alphabetically grouped sections of files
    private var sections: [AlphabeticalSectionHelper.Section<TextFile>] {
        AlphabeticalSectionHelper.groupFiles(files)
    }
    
    /// Determines if alphabetical sections should be used
    /// Use sections when file count exceeds one screenful (~15 files)
    private var useSections: Bool {
        files.count > 15
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            if useSections {
                // Show alphabetical sections for long lists
                ForEach(sections) { section in
                    Section {
                        // Only show files if section is expanded
                        if expandedSections.contains(section.letter) {
                            ForEach(section.items) { file in
                                fileRow(for: file)
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
                // Show flat list for short lists
                ForEach(files) { file in
                    fileRow(for: file)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isEditMode {
                                swipeActionButtons(for: file)
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            // Top toolbar for expand/collapse all button (only when using sections and not in edit mode)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if useSections && !isEditMode {
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
        .alert(
            "Delete \(filesToDelete.count) \(filesToDelete.count == 1 ? "file" : "files")?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("button.cancel", role: .cancel) {
                filesToDelete = []
            }
            Button("fileList.delete", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("fileList.deleteConfirmation.message")
        }
        .onChange(of: editMode?.wrappedValue) { _, newValue in
            if useSections {
                if newValue == .active {
                    // Expand all sections when entering edit mode for easier multi-select
                    expandedSections = Set(sections.map { $0.letter })
                } else if newValue == .inactive {
                    // Collapse all sections except last opened when exiting edit mode
                    if let lastSection = lastOpenedSection {
                        expandedSections = [lastSection]
                    } else {
                        expandedSections.removeAll()
                    }
                }
            }
            
            if newValue == .inactive {
                // Clear selection when exiting edit mode
                selectedFileIDs.removeAll()
            }
        }
        .onAppear {
            if useSections {
                loadLastOpenedSection()
            }
        }
        .sheet(isPresented: $showRenameModal) {
            if let fileToRename = selectedFiles.first {
                RenameFileModal(
                    file: fileToRename,
                    filesInFolder: files,
                    onRename: { _ in
                        onRename?([fileToRename])
                        selectedFileIDs.removeAll()
                    }
                )
            }
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
                
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                
                Text(file.name)
                
                Spacer(minLength: 8)  // Ensure some spacing before the button
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
            
            // Submissions button (only in normal mode) - separate tap target
            if !isEditMode {
                SubmissionsButton(file: file)
            }
        }
    }
    
    /// Swipe action buttons (only shown in normal mode)
    @ViewBuilder
    private func swipeActionButtons(for file: TextFile) -> some View {
        Button {
            onMove([file])
        } label: {
            Label("fileList.move", systemImage: "folder")
        }
        .tint(.blue)
        
        Button {
            prepareDelete([file])
        } label: {
            Label("fileList.delete", systemImage: "trash")
        }
        .tint(.red)
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
    
    /// Bottom toolbar content for edit mode
    @ViewBuilder
    private var bottomToolbarContent: some View {
        Button {
            onMove(selectedFiles)
            exitEditMode()
        } label: {
            Label(
                String(format: NSLocalizedString("fileList.moveCount", comment: "Move count"), selectedFiles.count),
                systemImage: "folder"
            )
        }
        .disabled(selectedFiles.isEmpty)
        .accessibilityLabel("fileList.moveSelected.accessibility")
        
        Spacer()
        
        // Add to Collection button (if onAddToCollection callback provided)
        if let onAddToCollection = onAddToCollection {
            Button {
                onAddToCollection(selectedFiles)
                exitEditMode()
            } label: {
                Label(
                    NSLocalizedString("fileList.addToCollection", comment: "Add files to collection"),
                    systemImage: "folder.badge.plus"
                )
            }
            .disabled(selectedFiles.isEmpty)
            
            Spacer()
        }
        
        // Submit button (if onSubmit callback provided)
        if let onSubmit = onSubmit {
            Button {
                onSubmit(selectedFiles)
                exitEditMode()
            } label: {
                Label(
                    NSLocalizedString("fileList.submit", comment: "Submit files"),
                    systemImage: "paperplane"
                )
            }
            .disabled(selectedFiles.isEmpty)
            
            Spacer()
        }
        
        // Rename button (only when exactly 1 file is selected)
        if selectedFiles.count == 1, onRename != nil {
            Button {
                showRenameModal = true
            } label: {
                Label(
                    NSLocalizedString("fileList.rename", comment: "Rename file"),
                    systemImage: "pencil.circle"
                )
            }
            .accessibilityLabel("fileList.rename.accessibility")
            
            Spacer()
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
            
            Spacer()
        }
        
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
        
        Divider()
        
        Button {
            onMove([file])
        } label: {
            Label("fileList.contextMenu.moveTo", systemImage: "folder")
        }
        
        Divider()
        
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
    
    /// Exits edit mode (returns to normal mode)
    private func exitEditMode() {
        withAnimation {
            editMode?.wrappedValue = .inactive
        }
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
/// NOTE: Uses the file's submittedFiles relationship instead of a query for performance
private struct SubmissionsButton: View {
    @State private var showSubmissions = false
    
    let file: TextFile
    
    // Count submissions from the file's relationship (no separate query needed!)
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
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.file.submissions", comment: "File submissions"), submissionCount)))
            .sheet(isPresented: $showSubmissions) {
                FileSubmissionsView(file: file)
            }
        }
    }
}
