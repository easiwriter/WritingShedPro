import SwiftUI
import SwiftData

struct AddFolderSheet: View {
    @Binding var isPresented: Bool
    let project: Project
    let parentFolder: Folder?
    let existingFolders: [Folder]
    
    @State private var folderName = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(NSLocalizedString("addFolder.folderName", comment: "Folder name field"), text: $folderName)
                        .accessibilityLabel(NSLocalizedString("addFolder.folderNameAccessibility", comment: "Folder name accessibility"))
                }
                
                if let parentFolder = parentFolder {
                    Section {
                        HStack {
                            Text(NSLocalizedString("addFolder.parentFolder", comment: "Parent folder label"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(parentFolder.name ?? "")
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("addFolder.title", comment: "Add folder title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("addFolder.cancel", comment: "Cancel button")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("addFolder.add", comment: "Add button")) {
                        addFolder()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(NSLocalizedString("addFolder.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("addFolder.ok", comment: "OK button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addFolder() {
        // Validate folder name
        do {
            try NameValidator.validateFolderName(folderName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Check uniqueness
        if let parentFolder = parentFolder {
            if !UniquenessChecker.isFolderNameUnique(folderName, in: parentFolder) {
                errorMessage = NSLocalizedString("addFolder.duplicateName", comment: "Duplicate folder name error")
                showErrorAlert = true
                return
            }
        } else {
            // Check uniqueness at root level
            if existingFolders.contains(where: { ($0.name ?? "").caseInsensitiveCompare(folderName) == .orderedSame }) {
                errorMessage = NSLocalizedString("addFolder.duplicateName", comment: "Duplicate folder name error")
                showErrorAlert = true
                return
            }
        }
        
        // Create folder
        let newFolder = Folder(name: folderName, project: project, parentFolder: parentFolder)
        modelContext.insert(newFolder)
        
        // Add to parent's folders array if exists
        if var parent = parentFolder {
            if parent.folders == nil {
                parent.folders = []
            }
            parent.folders?.append(newFolder)
        }
        
        isPresented = false
    }
}

//#Preview {
//    let container = try! ModelContainer(for: Project.self, Folder.self, File.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
//    let context = ModelContext(container)
//    
//    let project = Project(name: "My Poetry", type: .poetry)
//    context.insert(project)
//    
//    return AddFolderSheet(
//        isPresented: .constant(true),
//        project: project,
//        parentFolder: nil,
//        existingFolders: []
//    )
//    .modelContainer(container)
//}
