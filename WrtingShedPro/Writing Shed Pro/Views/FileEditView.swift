import SwiftUI
import SwiftData
import ToolbarSUI

struct FileEditView: View {
    let file: File
    
    @State private var content: String
    @State private var presentDeleteAlert = false
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
        _content = State(initialValue: file.currentVersion?.content ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $content)
                .font(.body)
                .padding()
                .onChange(of: content) { _, newValue in
                    // Auto-save content to current version as user types
                    file.currentVersion?.updateContent(newValue)
                    file.modifiedDate = Date()
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
            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("fileEdit.done", comment: "Done button")) {
                    saveChanges()
                    dismiss()
                }
            }
        }
        .onDisappear {
            // Auto-save when view disappears
            saveChanges()
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
        content = file.currentVersion?.content ?? ""
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
