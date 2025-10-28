import SwiftUI
import SwiftData
import ToolbarSUI

struct FileEditView: View {
    let file: File
    
    @State private var content: String
    @State private var attributedContent: NSAttributedString
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var previousContent: String = ""
    @State private var presentDeleteAlert = false
    @State private var isPerformingUndoRedo = false
    @State private var refreshTrigger = UUID()
    @State private var forceRefresh = false
    @StateObject private var undoManager: TextFileUndoManager
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    enum VersionAction: Int {
        case previous
        case next
        case add
        case delete
    }
    
    init(file: File) {
        self.file = file
        let initialContent = file.currentVersion?.content ?? ""
        _content = State(initialValue: initialContent)
        _previousContent = State(initialValue: initialContent)
        
        // Initialize attributed content
        let initialAttributed = file.currentVersion?.attributedContent ?? NSAttributedString(
            string: initialContent,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        _attributedContent = State(initialValue: initialAttributed)
        
        // Try to restore undo manager or create new one
        if let restoredManager = file.restoreUndoState() {
            _undoManager = StateObject(wrappedValue: restoredManager)
        } else {
            let newManager = TextFileUndoManager(file: file)
            _undoManager = StateObject(wrappedValue: newManager)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Version Navigator at top
            ToolbarView(
                label: file.versionLabel(),
                items: [
                    SUIToolbarItem(
                        icon: "chevron.left.circle",
                        title: "Show previous version",
                        disabled: file.atFirstVersion()
                    ),
                    SUIToolbarItem(
                        icon: "chevron.right.circle",
                        title: "Show next version",
                        disabled: file.atLastVersion()
                    ),
                    SUIToolbarItem(
                        icon: "plus.circle",
                        title: "Duplicate this version",
                        disabled: false
                    ),
                    SUIToolbarItem(
                        icon: "trash.circle",
                        title: "Delete this version",
                        disabled: (file.versions?.count ?? 0) <= 1
                    )
                ]
            ) { action in
                handleVersionAction(VersionAction(rawValue: action) ?? .next)
            }
            .alert(isPresented: $presentDeleteAlert) {
                Alert(
                    title: Text(NSLocalizedString("fileEdit.deleteVersionTitle", comment: "Delete Version?")),
                    message: Text(NSLocalizedString("fileEdit.deleteVersionMessage", comment: "Please confirm that you want to delete this version")),
                    primaryButton: .destructive(Text(NSLocalizedString("contentView.delete", comment: "Delete"))) {
                        file.deleteVersion()
                        loadCurrentVersion()
                        saveChanges()
                    },
                    secondaryButton: .cancel()
                )
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Text Editor
            if forceRefresh {
                FormattedTextEditor(
                    attributedText: $attributedContent,
                    selectedRange: $selectedRange,
                    onTextChange: { newText in
                        handleAttributedTextChange(newText)
                    }
                )
                .id(refreshTrigger)
            } else {
                FormattedTextEditor(
                    attributedText: $attributedContent,
                    selectedRange: $selectedRange,
                    onTextChange: { newText in
                        handleAttributedTextChange(newText)
                    }
                )
                .id(refreshTrigger)
            }
            
            // Formatting Toolbar at bottom - near keyboard (Pages style)
            FormattingToolbar(
                selectedRange: $selectedRange,
                attributedText: $attributedContent,
                onStylePicker: {
                    print("Style picker tapped")
                },
                onToggleBold: {
                    applyFormatting(.bold)
                },
                onToggleItalic: {
                    applyFormatting(.italic)
                },
                onToggleUnderline: {
                    applyFormatting(.underline)
                },
                onToggleStrikethrough: {
                    applyFormatting(.strikethrough)
                }
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(UIColor.secondarySystemBackground))
            .overlay(
                VStack(spacing: 0) {
                    Divider()
                    Spacer()
                    Divider()
                }
            )
        }
        .navigationTitle(file.name ?? NSLocalizedString("fileEdit.untitledFile", comment: "Untitled file"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Undo button
                    Button(action: {
                        performUndo()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!undoManager.canUndo || isPerformingUndoRedo)
                    .accessibilityLabel("Undo")
                    
                    // Redo button
                    Button(action: {
                        performRedo()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!undoManager.canRedo || isPerformingUndoRedo)
                    .accessibilityLabel("Redo")
                    
                    // Done button
                    Button(NSLocalizedString("fileEdit.done", comment: "Done button")) {
                        saveChanges()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            saveUndoState()
        }
    }
    
    // MARK: - Attributed Text Handling
    
    private func handleAttributedTextChange(_ newAttributedText: NSAttributedString) {
        #if DEBUG
        print("🔄 handleAttributedTextChange called")
        print("🔄 isPerformingUndoRedo: \(isPerformingUndoRedo)")
        #endif
        
        guard !isPerformingUndoRedo else {
            print("🔄 Skipping - performing undo/redo")
            return
        }
        
        let newContent = newAttributedText.string
        
        #if DEBUG
        print("🔄 Previous: '\(previousContent)'")
        print("🔄 New: '\(newContent)'")
        #endif
        
        // Only register change if content actually changed
        guard newContent != previousContent else {
            print("🔄 Content unchanged - skipping")
            return
        }
        
        print("🔄 Content changed - registering with undo manager")
        
        // Update state
        content = newContent
        
        // Create and execute undo command
        if let change = TextDiffService.diff(from: previousContent, to: newContent) {
            let command = TextDiffService.createCommand(from: change, file: file)
            undoManager.execute(command)
        }
        
        // Update previous content for next comparison
        previousContent = newContent
        
        // Save to model
        file.currentVersion?.content = newContent
        file.currentVersion?.attributedContent = newAttributedText
        file.modifiedDate = Date()
        
        // Save context
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // MARK: - Undo/Redo
    
    private func performUndo() {
        print("🔄 performUndo called - canUndo: \(undoManager.canUndo)")
        guard undoManager.canUndo else { return }
        
        isPerformingUndoRedo = true
        
        undoManager.undo()
        
        let newContent = file.currentVersion?.content ?? ""
        print("🔄 After undo - new content: '\(newContent)' (length: \(newContent.count))")
        
        // Create new attributed string from plain text
        let newAttributedContent = NSAttributedString(
            string: newContent,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        print("🔄 Created new attributed string from plain text")
        
        // Update all state
        content = newContent
        attributedContent = newAttributedContent
        previousContent = newContent
        
        // FIX: Position cursor at end of new content
        selectedRange = NSRange(location: newContent.count, length: 0)
        print("🔄 Set selectedRange to end: \(selectedRange)")
        
        // Save the attributed content to the version
        file.currentVersion?.attributedContent = newAttributedContent
        print("🔄 Updated attributedContent and saved RTF")
        
        // Force refresh
        forceRefresh.toggle()
        refreshTrigger = UUID()
        
        // Reset flag after UI has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPerformingUndoRedo = false
            print("🔄 Reset isPerformingUndoRedo flag")
        }
    }
    
    private func performRedo() {
        print("� performRedo called - canRedo: \(undoManager.canRedo)")
        guard undoManager.canRedo else { return }
        
        isPerformingUndoRedo = true
        
        undoManager.redo()
        
        let newContent = file.currentVersion?.content ?? ""
        print("🔄 After redo - new content: '\(newContent)' (length: \(newContent.count))")
        
        // Create new attributed string from plain text
        let newAttributedContent = NSAttributedString(
            string: newContent,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        print("🔄 Created new attributed string from plain text")
        
        // Update all state
        content = newContent
        attributedContent = newAttributedContent
        previousContent = newContent
        
        // FIX: Position cursor at end of new content
        selectedRange = NSRange(location: newContent.count, length: 0)
        print("🔄 Set selectedRange to end: \(selectedRange)")
        
        // Save the attributed content to the version
        file.currentVersion?.attributedContent = newAttributedContent
        print("🔄 Updated attributedContent and saved RTF")
        
        // Force refresh
        forceRefresh.toggle()
        refreshTrigger = UUID()
        
        // Reset flag after UI has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPerformingUndoRedo = false
            print("🔄 Reset isPerformingUndoRedo flag")
        }
    }
    
    // MARK: - Formatting
    
    /// Format types that can be applied
    private enum FormatType {
        case bold
        case italic
        case underline
        case strikethrough
    }
    
    /// Apply formatting to the current selection
    private func applyFormatting(_ formatType: FormatType) {
        #if DEBUG
        print("🎨 applyFormatting(\(formatType)) called")
        print("🎨 selectedRange: {\(selectedRange.location), \(selectedRange.length)}")
        #endif
        
        // Ensure we have a valid selection
        guard selectedRange.location != NSNotFound else {
            print("⚠️ selectedRange.location is NSNotFound")
            return
        }
        
        // If no text is selected (cursor only), do nothing
        // User must select text to apply formatting
        guard selectedRange.length > 0 else {
            print("⚠️ No text selected - formatting requires text selection")
            return
        }
        
        print("🎨 Applying \(formatType) to range {\(selectedRange.location), \(selectedRange.length)}")
        
        // Apply the appropriate formatting
        let newAttributedContent: NSAttributedString
        switch formatType {
        case .bold:
            newAttributedContent = TextFormatter.toggleBold(in: attributedContent, range: selectedRange)
        case .italic:
            newAttributedContent = TextFormatter.toggleItalic(in: attributedContent, range: selectedRange)
        case .underline:
            newAttributedContent = TextFormatter.toggleUnderline(in: attributedContent, range: selectedRange)
        case .strikethrough:
            newAttributedContent = TextFormatter.toggleStrikethrough(in: attributedContent, range: selectedRange)
        }
        
        print("🎨 Format applied successfully")
        
        // Update local state immediately for instant UI feedback
        attributedContent = newAttributedContent
        content = newAttributedContent.string
        
        print("🎨 Updated local state with formatted content")
        
        // Formatting is saved to the model when the file is closed (in saveChanges)
        // This avoids triggering encode/decode on every formatting change
        
        // TODO: Phase 6 - Add formatting command to undo stack
        // For now, formatting changes don't go into undo history
    }
    
    // MARK: - Version Management

    
    private func handleVersionAction(_ action: VersionAction) {
        switch action {
        case .previous:
            file.changeVersion(by: -1)
            loadCurrentVersion()
        case .next:
            file.changeVersion(by: 1)
            loadCurrentVersion()
        case .add:
            file.addVersion()
            loadCurrentVersion()
            saveChanges()
        case .delete:
            presentDeleteAlert = true
        }
    }
    
    private func loadCurrentVersion() {
        let newContent = file.currentVersion?.content ?? ""
        let newAttributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(
            string: newContent,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        content = newContent
        attributedContent = newAttributedContent
        previousContent = newContent
        selectedRange = NSRange(location: newContent.count, length: 0)
        
        forceRefresh.toggle()
        refreshTrigger = UUID()
    }
    
    // MARK: - Persistence
    
    private func saveUndoState() {
        undoManager.flushTypingBuffer()
        file.saveUndoState(undoManager)
        saveChanges()
    }
    
    private func saveChanges() {
        // Save the current attributed content to the model
        file.currentVersion?.attributedContent = attributedContent
        file.currentVersion?.content = content
        file.modifiedDate = Date()
        
        do {
            try modelContext.save()
            print("💾 Saved attributed content on file close")
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, File.self, configurations: config)
        let context = container.mainContext
        
        let project = Project(name: "Sample Project", type: .novel)
        context.insert(project)
        
        let file = File(name: "Chapter 1", content: "Once upon a time...")
        context.insert(file)
        
        return NavigationStack {
            FileEditView(file: file)
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
