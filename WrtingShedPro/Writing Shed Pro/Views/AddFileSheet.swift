import SwiftUI
import SwiftData

struct AddFileSheet: View {
    @Binding var isPresented: Bool
    let parentFolder: Folder
    let existingFiles: [TextFile]
    
    @State private var fileName = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var selectedPoetryForm: PoetryForm?
    @Environment(\.modelContext) var modelContext
    
    /// Whether this file is being created in a Poetry project
    private var isPoetryProject: Bool {
        parentFolder.project?.type == .poetry
    }
    
    /// Whether the device is set to an English locale
    /// Poetry form analysis only works for English
    private var isEnglishLocale: Bool {
        Locale.current.language.languageCode?.identifier == "en"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(NSLocalizedString("addFile.fileName", comment: "File name field"), text: $fileName)
                        .accessibilityLabel(NSLocalizedString("addFile.fileNameAccessibility", comment: "File name accessibility"))
                        .onSubmit {
                            if !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                addFile()
                            }
                        }
                }
                
                // Poetry form picker section (only for Poetry projects with English locale)
                if isPoetryProject && isEnglishLocale {
                    Section {
                        PoetryFormPickerCompact(selectedForm: $selectedPoetryForm)
                    } header: {
                        Text(NSLocalizedString("addFile.poetryFormHeader", comment: "Poetry Form section header"))
                    } footer: {
                        Text(NSLocalizedString("addFile.poetryFormFooter", comment: "Poetry Form section footer"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("addFile.title", comment: "Add file title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("addFile.cancel", comment: "Cancel button")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("addFile.add", comment: "Add button")) {
                        addFile()
                    }
                    .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(.blue)
                }
            }
            .alert(NSLocalizedString("addFile.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("addFile.ok", comment: "OK button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func addFile() {
        // Check if folder allows files
        guard FolderCapabilityService.canAddFile(to: parentFolder) else {
            errorMessage = FolderCapabilityService.disallowedOperationMessage(for: parentFolder, operation: .addFile)
            showErrorAlert = true
            return
        }
        
        // Validate file name
        do {
            try NameValidator.validateFileName(fileName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Check uniqueness
        if !UniquenessChecker.isFileNameUnique(fileName, in: parentFolder) {
            // Determine if conflict is with active file or trashed file
            let conflict = UniquenessChecker.getFileNameConflict(fileName, in: parentFolder)
            if conflict == "trash" {
                errorMessage = NSLocalizedString("addFile.duplicateNameInTrash", comment: "File with this name exists in Trash")
            } else {
                errorMessage = NSLocalizedString("addFile.duplicateName", comment: "Duplicate file name error")
            }
            showErrorAlert = true
            return
        }
        
        // Store poetry form info (but don't insert template - show reference sheet instead)
        var poetryFormId: UUID? = nil
        var poetryFormName: String? = nil
        
        if isPoetryProject, let form = selectedPoetryForm {
            poetryFormId = form.id
            poetryFormName = form.name
        }
        
        // Create TextFile with empty content
        // Poetry form reference will auto-show when document opens
        let newFile = TextFile(
            name: fileName,
            initialContent: "",
            parentFolder: parentFolder,
            poetryFormId: poetryFormId,
            poetryFormName: poetryFormName
        )
        
        // Set initial workflow status for content folders (Poems, Scenes, Scripts)
        if FolderCapabilityService.isContentFolder(parentFolder) {
            newFile.workflowStatus = .draft
        }
        
        modelContext.insert(newFile)
        
        // Save context to ensure relationships are updated immediately
        // This prevents duplicate name issues when quickly creating multiple files
        do {
            try modelContext.save()
            
            // Record significant event for review prompts
            ReviewManager.shared.recordSignificantEvent()
        } catch {
            #if DEBUG
            print("Error saving new file: \(error)")
            #endif
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }
        
        isPresented = false
    }
}
