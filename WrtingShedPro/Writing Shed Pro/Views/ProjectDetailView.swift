import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showProjectInfo = false
    @State private var showDeleteConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var editedName = ""
    
    var body: some View {
        // Main content: FolderListView
        FolderListView(project: project)
        .sheet(isPresented: $showProjectInfo) {
            ProjectInfoSheet(
                project: project,
                isPresented: $showProjectInfo,
                showDeleteConfirmation: $showDeleteConfirmation,
                errorMessage: $errorMessage,
                showErrorAlert: $showErrorAlert
            )
        }
        .confirmationDialog(
            NSLocalizedString("projectDetail.moveToTrashTitle", comment: "Move project to trash confirmation dialog title"),
            isPresented: $showDeleteConfirmation,
            actions: {
                Button(NSLocalizedString("projectDetail.moveToTrash", comment: "Move to Trash button"), role: .destructive) {
                    deleteProject()
                }
                Button(NSLocalizedString("projectDetail.cancel", comment: "Cancel button"), role: .cancel) { }
            },
            message: {
                Text(String(format: NSLocalizedString("projectDetail.moveToTrashConfirmMessage", comment: "Move to Trash confirmation message with project name"), project.name ?? ""))
            }
        )
        .alert(NSLocalizedString("projectDetail.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("projectDetail.ok", comment: "OK button"), role: .cancel) {
                // Revert to original name on error
                project.name = editedName
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func validateAndUpdateName(_ newName: String) {
        // Validate name
        do {
            try NameValidator.validateProjectName(newName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Update name if valid
        project.name = newName
    }
    
    private func deleteProject() {
        project.isTrashed = true
        project.deletedDate = Date()
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Project Info Sheet

struct ProjectInfoSheet: View {
    let project: Project
    @Environment(\.modelContext) var modelContext
    @Query private var allProjects: [Project]
    @Query(sort: \StyleSheet.name) private var allStyleSheets: [StyleSheet]
    @Binding var isPresented: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var errorMessage: String
    @Binding var showErrorAlert: Bool
    @State private var editedName = ""
    @State private var originalName = ""
    @State private var authorText = ""
    @State private var originalAuthor = ""
    @State private var notesText = ""
    @State private var originalNotes = ""
    @State private var selectedStyleSheet: StyleSheet?
    @State private var originalStyleSheet: StyleSheet?
    @State private var hasInitialized = false
    @State private var nameValidationError = ""
    
    var body: some View {
        VStack(spacing: 0) {
            dismissBar
            projectInfoScrollContent
            saveProjectButton
        }
        .id(project.id)
        .onAppear { initializeFields() }
        .onChange(of: project.id) { oldValue, newValue in initializeFields() }
    }
    
    // MARK: - Extracted Subviews
    
    private var dismissBar: some View {
        HStack {
            Spacer()
            Button(action: {
                // Discard all changes and close
                if notesText != originalNotes {
                    project.notes = originalNotes.isEmpty ? nil : originalNotes
                }
                if authorText != originalAuthor {
                    project.author = originalAuthor.isEmpty ? nil : originalAuthor
                }
                if editedName != originalName {
                    project.name = originalName
                }
                if selectedStyleSheet?.id != originalStyleSheet?.id {
                    project.styleSheet = originalStyleSheet
                }
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(NSLocalizedString("projectDetail.close", comment: "Close button"))
            .accessibilityHint(NSLocalizedString("projectDetail.closeAccessibility", comment: "Discard changes and close sheet"))
        }
        .padding()
    }
    
    private var projectInfoScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("projectDetail.projectInfo", comment: "Section header for project information"))
                    .font(.headline)
                
                Divider()
                
                nameField
                
                if !nameValidationError.isEmpty {
                    Text(nameValidationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                authorField
                
                HStack {
                    Text(NSLocalizedString("projectDetail.type", comment: "Field label for project type"))
                    Spacer()
                    Text((project.type).rawValue.capitalized)
                }
                
                fictionClassPicker
                
                HStack {
                    Text(NSLocalizedString("projectDetail.created", comment: "Field label for creation date"))
                    Spacer()
                    Text((project.creationDate ?? Date()).formatted(date: .abbreviated, time: .shortened))
                }
                
                Divider()
                
                stylesheetPicker
                
                storyStructureSection
                
                Divider()
                
                notesSection
            }
            .padding()
        }
    }
    
    private var nameField: some View {
        HStack {
            Text(NSLocalizedString("projectDetail.name", comment: "Field label for project name"))
            Spacer()
            TextField("projectDetail.name.placeholder", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .padding(.vertical, 4)
                .background(nameValidationError.isEmpty ? Color(.systemGray6) : Color(.systemRed).opacity(0.1))
                .cornerRadius(6)
                .onChange(of: editedName) { oldValue, newValue in
                    nameValidationError = ""
                }
                .accessibilityLabel(NSLocalizedString("projectDetail.name", comment: "Field label for project name"))
                .accessibilityHint("Double tap to edit the project name")
        }
    }
    
    private var authorField: some View {
        HStack {
            Text(NSLocalizedString("projectDetail.author", comment: "Field label for project author"))
            Spacer()
            TextField(NSLocalizedString("projectDetail.author.placeholder", comment: "Placeholder for author field"), text: $authorText)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .padding(.vertical, 4)
                .onChange(of: authorText) { oldValue, newValue in
                    project.author = newValue.isEmpty ? nil : newValue
                }
                .accessibilityLabel(NSLocalizedString("projectDetail.author", comment: "Field label for project author"))
                .accessibilityHint("Double tap to edit the author name")
        }
    }
    
    @ViewBuilder
    private var fictionClassPicker: some View {
        if project.type == .fiction {
            HStack {
                Text(NSLocalizedString("projectDetail.fictionClass", comment: "Field label for fiction class"))
                Spacer()
                Picker("", selection: Binding(
                    get: { project.fictionClass ?? .novel },
                    set: { updateFictionClass($0) }
                )) {
                    ForEach(FictionClass.allCases, id: \.self) { fictionClass in
                        Text(fictionClass.localizedName).tag(fictionClass)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(NSLocalizedString("projectDetail.fictionClass", comment: "Fiction class picker"))
            }
        }
    }
    
    private func updateFictionClass(_ newValue: FictionClass) {
        let oldValue: FictionClass = project.fictionClass ?? .novel
        project.fictionClass = newValue
        
        if oldValue != newValue, let folders = project.folders {
            let oldFolderName: String = oldValue == .novel ? "Chapters" : "Stories"
            let newFolderName: String = newValue == .novel ? "Chapters" : "Stories"
            
            if let folder = folders.first(where: { $0.name == oldFolderName && $0.parentFolder == nil }) {
                folder.name = newFolderName
            }
            
            if let manuscriptFolder = folders.first(where: { $0.name == "Manuscript" && $0.parentFolder == nil }),
               let subfolders = manuscriptFolder.subfolders,
               let bodyFolder = subfolders.first(where: { $0.name == oldFolderName }) {
                bodyFolder.name = newFolderName
            }
        }
    }
    
    private var stylesheetPicker: some View {
        HStack {
            Text(NSLocalizedString("projectDetail.stylesheet", comment: "Field label for stylesheet"))
            Spacer()
            Picker("projectDetail.stylesheet.picker", selection: $selectedStyleSheet) {
                ForEach(allStyleSheets, id: \.id) { sheet in
                    HStack {
                        Text(sheet.name)
                        if sheet.isSystemStyleSheet {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(sheet as StyleSheet?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedStyleSheet) { oldValue, newValue in
                project.styleSheet = newValue
                NotificationCenter.default.post(
                    name: NSNotification.Name("ProjectStyleSheetChanged"),
                    object: nil,
                    userInfo: ["projectID": project.id]
                )
            }
            .accessibilityLabel(NSLocalizedString("projectDetail.stylesheet", comment: "Stylesheet picker"))
            .accessibilityHint(NSLocalizedString("projectDetail.stylesheetAccessibility", comment: "Stylesheet picker hint"))
        }
    }
    
    @ViewBuilder
    private var storyStructureSection: some View {
        if project.type == .fiction || project.type == .drama {
            Divider()
            
            Picker(NSLocalizedString("projectDetail.storyStructure", comment: "Story structure picker"), selection: Binding(
                get: { project.storyStructure },
                set: { project.storyStructure = $0 }
            )) {
                ForEach(StoryStructure.allCases, id: \.self) { structure in
                    Text(structure.localizedName).tag(structure)
                }
            }
            .accessibilityLabel(NSLocalizedString("projectDetail.storyStructure", comment: "Story structure picker"))
            
            if project.storyStructure != .freeform {
                Text(project.storyStructure.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var notesSection: some View {
        Group {
            Text(NSLocalizedString("projectDetail.notes", comment: "Notes label"))
                .font(.subheadline)
                .fontWeight(.semibold)
            
            TextEditor(text: $notesText)
                .border(Color.gray, width: 1)
                .frame(minHeight: 100)
                .onChange(of: notesText) { oldValue, newValue in
                    project.notes = newValue.isEmpty ? nil : newValue
                }
                .accessibilityLabel(NSLocalizedString("projectDetail.notes", comment: "Notes field"))
                .accessibilityHint(NSLocalizedString("projectDetail.notesAccessibility", comment: "Edit notes hint"))
        }
    }
    
    private var saveProjectButton: some View {
        Button(action: { saveAndClose() }) {
            Text(NSLocalizedString("projectDetail.done", comment: "Done button"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(NSLocalizedString("projectDetail.done", comment: "Done button"))
        .accessibilityHint(NSLocalizedString("projectDetail.doneAccessibility", comment: "Save changes hint"))
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func saveAndClose() {
        let trimmedName: String = editedName.trimmingCharacters(in: .whitespaces)
        
        if trimmedName.isEmpty {
            nameValidationError = NSLocalizedString("validation.emptyProjectName", comment: "Error when project name is empty")
            return
        }
        
        let isDuplicate: Bool = allProjects.contains { (otherProject: Project) -> Bool in
            guard otherProject.id != project.id else { return false }
            let otherName: String = (otherProject.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return otherName.lowercased() == trimmedName.lowercased()
        }
        
        if isDuplicate {
            nameValidationError = NSLocalizedString("validation.duplicateProjectName", comment: "Error when project name already exists")
            return
        }
        
        project.name = trimmedName

        do {
            try modelContext.save()
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func initializeFields() {
        notesText = project.notes ?? ""
        originalNotes = project.notes ?? ""
        authorText = project.author ?? ""
        originalAuthor = project.author ?? ""
        editedName = project.name ?? ""
        originalName = project.name ?? ""
        nameValidationError = ""
        
        if let currentStyleSheet = project.styleSheet {
            selectedStyleSheet = currentStyleSheet
            originalStyleSheet = currentStyleSheet
        } else {
            if let defaultSheet = StyleSheetService.getDefaultStyleSheet(context: modelContext) {
                selectedStyleSheet = defaultSheet
                originalStyleSheet = defaultSheet
                project.styleSheet = defaultSheet
            }
        }
    }
    
    private func validateAndUpdateName(_ newName: String) {
        // Validate name
        do {
            try NameValidator.validateProjectName(newName)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
        
        // Update name if valid
        project.name = newName
    }
}
