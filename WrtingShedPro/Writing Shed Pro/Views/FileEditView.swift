import SwiftUI
import SwiftData
import ToolbarSUI

struct FileEditView: View {
    let file: File
    
    @State private var content: String
    @State private var previousContent: String = ""
    @State private var presentDeleteAlert = false
    @State private var isPerformingUndoRedo = false // Flag to prevent re-entrancy
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
        // Load content from current version
        let initialContent = file.currentVersion?.content ?? ""
        _content = State(initialValue: initialContent)
        _previousContent = State(initialValue: initialContent)
        
        // Try to restore undo manager from saved state, or create new one
        if let restoredManager = file.restoreUndoState() {
            _undoManager = StateObject(wrappedValue: restoredManager)
        } else {
            _undoManager = StateObject(wrappedValue: TextFileUndoManager(file: file))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $content)
                .font(.body)
                .padding()
                .onChange(of: content) { oldValue, newValue in
                    handleTextChange(from: oldValue, to: newValue)
                }
                .onAppear {
                    // Set initial previousContent
                    previousContent = content
                }
            
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
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
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
                    .disabled(!undoManager.canUndo)
                    .accessibilityLabel("Undo")
                    
                    // Redo button
                    Button(action: {
                        performRedo()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!undoManager.canRedo)
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
            // Flush undo buffer and auto-save when view disappears
            undoManager.flushTypingBuffer()
            
            // Save undo state to file
            file.saveUndoState(undoManager)
            
            // Save changes
            saveChanges()
        }
    }
    
    private func handleTextChange(from oldValue: String, to newValue: String) {
        // Skip if performing undo/redo (prevents re-entrancy)
        guard !isPerformingUndoRedo else { return }
        
        // Skip if content hasn't really changed
        guard oldValue != newValue else { return }
        
        // Update file content immediately
        file.currentVersion?.updateContent(newValue)
        file.modifiedDate = Date()
        
        // Compute diff and create command for undo tracking
        if let change = TextDiffService.diff(from: oldValue, to: newValue) {
            let command = TextDiffService.createCommand(from: change, file: file)
            
            // Execute command adds it to undo stack
            // The command's execute() will be called, but since we already updated the content above,
            // it will just set it to the same value (no-op in effect)
            undoManager.execute(command)
        }
        
        // Update tracking
        previousContent = newValue
    }
    
    private func performUndo() {
        // Set flag to prevent onChange from creating new commands
        isPerformingUndoRedo = true
        
        // Perform undo
        undoManager.undo()
        
        // Force update content binding
        let newContent = file.currentVersion?.content ?? ""
        
        // Update content which will trigger UI refresh
        DispatchQueue.main.async {
            self.content = newContent
            self.previousContent = newContent
            
            // Reset flag
            DispatchQueue.main.async {
                self.isPerformingUndoRedo = false
            }
        }
    }
    
    private func performRedo() {
        // Set flag to prevent onChange from creating new commands
        isPerformingUndoRedo = true
        
        // Perform redo
        undoManager.redo()
        
        // Force update content binding
        let newContent = file.currentVersion?.content ?? ""
        
        // Update content which will trigger UI refresh
        DispatchQueue.main.async {
            self.content = newContent
            self.previousContent = newContent
            
            // Reset flag
            DispatchQueue.main.async {
                self.isPerformingUndoRedo = false
            }
        }
    }
    
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
        isPerformingUndoRedo = true
        content = file.currentVersion?.content ?? ""
        previousContent = content
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            isPerformingUndoRedo = false
        }
    }
    
    private func saveChanges() {
        do {
            try modelContext.save()
            print("✅ File versions saved: \(file.name ?? "Unknown")")
        } catch {
            print("❌ Error saving file: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        FileEditView(file: File(name: "Test File", content: "This is some test content."))
    }
}
