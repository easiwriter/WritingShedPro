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

    private func deleteProject() {
        DeduplicationService.trashProjectFamily(project, context: modelContext, deletedAt: Date())
        WriteCoalescer.shared?.requestSave(reason: "project-detail-trash")
        WriteCoalescer.shared?.flush()
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
    @State private var originalFictionClass: FictionClass = .novel
    @State private var hasInitialized = false
    @State private var nameValidationError = ""

    private var uniqueStyleSheets: [StyleSheet] {
        StyleSheetService.uniqueStyleSheets(
            from: allStyleSheets,
            preferredSheetID: selectedStyleSheet?.id ?? project.styleSheet?.id
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            dismissBar
            projectInfoScrollContent
            saveProjectButton
        }
        .id(project.id)
        .onAppear { initializeFields() }
        .onChange(of: project.id) { oldValue, newValue in initializeFields() }
        .onChange(of: allStyleSheets) { _, _ in
            handleStyleSheetListChange()
        }
    }

    private func handleStyleSheetListChange() {
        // If the selected stylesheet was deleted, fall back to default.
        guard let selected = selectedStyleSheet,
              !allStyleSheets.contains(where: { $0.id == selected.id }) else {
            return
        }

        if let defaultSheet = StyleSheetService.getDefaultStyleSheet(context: modelContext) {
            selectedStyleSheet = defaultSheet
            project.styleSheet = defaultSheet
        }
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
                if project.fictionClass != originalFictionClass {
                    project.fictionClass = originalFictionClass
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
                    get: { currentFictionClass },
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

    private var currentFictionClass: FictionClass {
        project.fictionClass ?? inferredFictionClassFromFolders()
    }

    private func updateFictionClass(_ newValue: FictionClass) {
        project.fictionClass = newValue
    }

    private func reconcileFictionFolders(from oldValue: FictionClass, to newValue: FictionClass) {
        guard let folders = project.folders else { return }

        let oldNames = fictionRootFolderNames(for: oldValue)
        let newNames = fictionRootFolderNames(for: newValue)

        for (oldName, newName) in zip(oldNames, newNames) where oldName != newName {
            let targetExists = folders.contains { $0.name == newName && $0.parentFolder == nil }
            if !targetExists,
               let folder = folders.first(where: { $0.name == oldName && $0.parentFolder == nil }) {
                folder.name = newName
            }
        }

        let currentRootNames = Set((project.folders ?? []).filter { $0.parentFolder == nil }.compactMap { $0.name })
        for (index, name) in newNames.enumerated() where !currentRootNames.contains(name) {
            let folder = Folder(name: name, project: project, userOrder: index + 1)
            folder.parentFolder = nil
            modelContext.insert(folder)
        }

        removeEmptyObsoleteFictionFolders(keeping: Set(newNames))
    }

    private func removeEmptyObsoleteFictionFolders(keeping newNames: Set<String>) {
        let allFictionFolderNames = Set(FictionClass.allCases.flatMap { fictionRootFolderNames(for: $0) })
        let obsoleteNames = allFictionFolderNames.subtracting(newNames)
        let obsoleteFolders = (project.folders ?? []).filter { folder in
            guard folder.parentFolder == nil, let name = folder.name else { return false }
            return obsoleteNames.contains(name) && isEmptyFolder(folder)
        }

        for folder in obsoleteFolders {
            modelContext.delete(folder)
        }
    }

    private func isEmptyFolder(_ folder: Folder) -> Bool {
        (folder.textFiles?.isEmpty ?? true) && (folder.folders?.isEmpty ?? true)
    }

    private func inferredFictionClassFromFolders() -> FictionClass {
        let rootNames = Set((project.folders ?? []).filter { $0.parentFolder == nil }.compactMap { $0.name })
        if rootNames.contains("Books") || rootNames.contains("Episodes") {
            return .verseNovel
        }
        if rootNames.contains("Stories") {
            return .shortFiction
        }
        return .novel
    }

    private func fictionRootFolderNames(for fictionClass: FictionClass) -> [String] {
        switch fictionClass {
        case .novel:
            return ["Chapters", "Scenes"]
        case .shortFiction:
            return ["Stories", "Scenes"]
        case .verseNovel:
            return ["Books", "Episodes"]
        }
    }

    private var stylesheetPicker: some View {
        HStack {
            Text(NSLocalizedString("projectDetail.stylesheet", comment: "Field label for stylesheet"))
            Spacer()
            Picker("projectDetail.stylesheet.picker", selection: $selectedStyleSheet) {
                ForEach(uniqueStyleSheets, id: \.id) { sheet in
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
                project.modifiedDate = Date()
                WriteCoalescer.shared?.requestSave()
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

        // CRITICAL: Check for name conflicts using ALL projects in the database,
        // not just the ones visible in @Query. @Query may exclude trashed or hidden duplicates.
        // This prevents users from renaming to a name that another project already has,
        // even if that other project is archived/hidden.
        let freshContext = ModelContext(modelContext.container)
        let allProjectsDescriptor = FetchDescriptor<Project>()
        let allProjects = (try? freshContext.fetch(allProjectsDescriptor)) ?? []

        let isDuplicate = DeduplicationService.hasProjectNameConflict(trimmedName, in: allProjects, excluding: project)

        if isDuplicate {
            nameValidationError = NSLocalizedString("validation.duplicateProjectName", comment: "Error when project name already exists")
            return
        }

        // If user intentionally renames to this value, clear any stale tombstone
        // for the same name/type so post-import zombie cleanup cannot remove it.
        DeduplicationService.clearTombstone(name: trimmedName, typeRaw: project.typeRaw)

        let savedFictionClass = currentFictionClass
        if originalFictionClass != savedFictionClass {
            reconcileFictionFolders(from: originalFictionClass, to: savedFictionClass)
        }

        project.name = trimmedName
        project.modifiedDate = Date()

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "project-detail-save")
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
        originalFictionClass = currentFictionClass
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
