import SwiftUI
import SwiftData
import TipKit

struct AddFileSheet: View {
    @Binding var isPresented: Bool
    let parentFolder: Folder
    let existingFiles: [TextFile]
    
    @State private var fileName = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var selectedPoetryForm: PoetryForm?
    @State private var selectedContentType: FileContentType = .richText
    @State private var upgradePromptReason: UpgradePromptReason?
    @Environment(\.modelContext) var modelContext
    
    /// Whether this file is being created in a Poetry project
    private var isPoetryProject: Bool {
        parentFolder.project?.type == .poetry
    }
    
    /// Whether this file is being created in a Verse Novel's Episodes folder
    private var isVerseNovelEpisode: Bool {
        parentFolder.project?.type == .fiction &&
        parentFolder.project?.fictionClass == .verseNovel &&
        parentFolder.name == "Episodes"
    }
    
    /// Whether this file should use the poetry editor (Poetry project OR Verse Novel episode)
    private var usesPoetryEditor: Bool {
        isPoetryProject || isVerseNovelEpisode
    }
    
    /// Whether this file is being created in a Drama project
    private var isDramaProject: Bool {
        parentFolder.project?.type == .drama
    }
    
    /// Whether markdown content type is available (not for Poetry, Drama, or Verse Novel episodes)
    private var supportsMarkdown: Bool {
        !usesPoetryEditor && !isDramaProject
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
                
                // FR-2.5: New File tip
                if TipKitConfiguration.tipsEnabled {
                    TipView(NewFileTip()) { action in
                        TipActionHandler.handle(action, guideSection: NewFileTip.guideSection)
                    }
                }
                
                // Poetry form picker section (for Poetry projects and Verse Novel episodes)
                if usesPoetryEditor {
                    Section {
                        PoetryFormPickerCompact(selectedForm: $selectedPoetryForm)
                    } header: {
                        Text(NSLocalizedString("addFile.poetryFormHeader", comment: "Poetry Form section header"))
                    } footer: {
                        Text(NSLocalizedString("addFile.poetryFormFooter", comment: "Poetry Form section footer"))
                    }
                }
                
                // Content type picker (not for Poetry or Drama projects - they require rich text)
                if supportsMarkdown {
                    Section {
                        Picker(NSLocalizedString("addFile.contentType", comment: "Content Type"), selection: $selectedContentType) {
                            ForEach(FileContentType.allCases, id: \.self) { contentType in
                                Label(contentType.localizedName, systemImage: contentType.systemImage)
                                    .tag(contentType)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text(NSLocalizedString("addFile.contentTypeHeader", comment: "Content Type section header"))
                    } footer: {
                        Text(selectedContentType.description)
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
                    .foregroundColor(isAddButtonDisabled ? .gray : .blue)
                    .disabled(isAddButtonDisabled)
                }
            }
            .alert(NSLocalizedString("addFile.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("addFile.ok", comment: "OK button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .upgradePrompt(reason: $upgradePromptReason)
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Validation
    
    private var isAddButtonDisabled: Bool {
        // Name is required - same for all project types
        return fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addFile() {
        // Explicitly check if name is empty first
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = NSLocalizedString("addFile.nameRequired", comment: "File name is required")
            showErrorAlert = true
            return
        }
        
        // Check entitlement for free tier limits
        if let projectType = parentFolder.project?.type {
            let existingFileCount = countFilesInProject()
            if !EntitlementManager.shared.canCreateFile(forProjectType: projectType, existingCount: existingFileCount) {
                upgradePromptReason = .fileLimit(projectType: projectType)
                return
            }
        }
        
        // Check if folder allows files
        guard FolderCapabilityService.canAddFile(to: parentFolder) else {
            errorMessage = FolderCapabilityService.disallowedOperationMessage(for: parentFolder, operation: .addFile)
            showErrorAlert = true
            return
        }
        
        // Validate file name format
        do {
            try NameValidator.validateFileName(trimmedName)
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
        
        if usesPoetryEditor {
            // Use selected form, or free verse if none selected
            poetryFormId = selectedPoetryForm?.id ?? PoetryForm.freeVerseId
            poetryFormName = selectedPoetryForm?.name ?? "Free Verse"
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
        
        // Set content type (Poetry and Drama projects always use rich text)
        if supportsMarkdown {
            newFile.contentType = selectedContentType
        }
        
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
    
    /// Count all non-trashed files across all folders in the project
    private func countFilesInProject() -> Int {
        guard let project = parentFolder.project else { return 0 }
        
        var count = 0
        func countInFolder(_ folder: Folder) {
            if let files = folder.files {
                // Files are trashed if they have a trashItem relationship
                count += files.filter { $0.trashItem == nil }.count
            }
            if let subfolders = folder.subfolders {
                for subfolder in subfolders {
                    countInFolder(subfolder)
                }
            }
        }
        
        if let folders = project.folders {
            for folder in folders {
                countInFolder(folder)
            }
        }
        
        return count
    }
}
