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
            .upgradePrompt(reason: $upgradePromptReason) {
                self.addFile()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Validation
    
    private var isAddButtonDisabled: Bool {
        // Name is required - same for all project types
        return fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addFile() {
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = NSLocalizedString("addFile.nameRequired", comment: "File name is required")
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

        do {
            _ = try TextFileCreationService.createTextFile(
                name: trimmedName,
                parentFolder: parentFolder,
                modelContext: modelContext,
                poetryFormId: poetryFormId,
                poetryFormName: poetryFormName,
                contentType: supportsMarkdown ? selectedContentType : .richText
            )
            isPresented = false
        } catch OnboardingCreationError.fileLimit(let projectType) {
            upgradePromptReason = .fileLimit(projectType: projectType)
        } catch OnboardingCreationError.folderDoesNotAllowFiles {
            errorMessage = FolderCapabilityService.disallowedOperationMessage(for: parentFolder, operation: .addFile)
            showErrorAlert = true
        } catch {
            if !UniquenessChecker.isFileNameUnique(trimmedName, in: parentFolder),
               UniquenessChecker.getFileNameConflict(trimmedName, in: parentFolder) == "trash" {
                errorMessage = NSLocalizedString("addFile.duplicateNameInTrash", comment: "File with this name exists in Trash")
            } else {
                errorMessage = error.localizedDescription
            }
            showErrorAlert = true
        }
    }
    
}
