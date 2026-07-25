import SwiftUI
import SwiftData
import Observation

enum OnboardingStep: Int {
    case welcome
    case genre
    case fictionClass
    case projectName
    case fileName
}

struct OnboardingDefaults {
    let projectType: ProjectType
    let fictionClass: FictionClass?
    let defaultProjectNameKey: String
    let defaultFileNameKey: String
    let destinationFolderName: String

    var defaultProjectName: String {
        NSLocalizedString(defaultProjectNameKey, comment: "Default onboarding project name")
    }

    var defaultFileName: String {
        NSLocalizedString(defaultFileNameKey, comment: "Default onboarding file name")
    }

    static func defaults(for projectType: ProjectType, fictionClass: FictionClass? = nil) -> OnboardingDefaults {
        switch projectType {
        case .poetry:
            return OnboardingDefaults(
                projectType: .poetry,
                fictionClass: nil,
                defaultProjectNameKey: "onboarding.defaultProject.poetry",
                defaultFileNameKey: "onboarding.defaultFile.poetry",
                destinationFolderName: NSLocalizedString("folder.poems", comment: "Poems")
            )
        case .prose:
            return OnboardingDefaults(
                projectType: .prose,
                fictionClass: nil,
                defaultProjectNameKey: "onboarding.defaultProject.prose",
                defaultFileNameKey: "onboarding.defaultFile.prose",
                destinationFolderName: NSLocalizedString("folder.prose", comment: "Prose")
            )
        case .fiction:
            switch fictionClass ?? .novel {
            case .novel:
                return OnboardingDefaults(
                    projectType: .fiction,
                    fictionClass: .novel,
                    defaultProjectNameKey: "onboarding.defaultProject.novel",
                    defaultFileNameKey: "onboarding.defaultFile.novel",
                    destinationFolderName: NSLocalizedString("folder.scenes", comment: "Scenes")
                )
            case .shortFiction:
                return OnboardingDefaults(
                    projectType: .fiction,
                    fictionClass: .shortFiction,
                    defaultProjectNameKey: "onboarding.defaultProject.shortFiction",
                    defaultFileNameKey: "onboarding.defaultFile.shortFiction",
                    destinationFolderName: NSLocalizedString("folder.scenes", comment: "Scenes")
                )
            case .verseNovel:
                return OnboardingDefaults(
                    projectType: .fiction,
                    fictionClass: .verseNovel,
                    defaultProjectNameKey: "onboarding.defaultProject.verseNovel",
                    defaultFileNameKey: "onboarding.defaultFile.verseNovel",
                    destinationFolderName: NSLocalizedString("folder.episodes", comment: "Episodes")
                )
            }
        case .drama:
            return OnboardingDefaults(
                projectType: .drama,
                fictionClass: nil,
                defaultProjectNameKey: "onboarding.defaultProject.drama",
                defaultFileNameKey: "onboarding.defaultFile.drama",
                destinationFolderName: NSLocalizedString("folder.scenes", comment: "Scenes")
            )
        }
    }
}

enum OnboardingCreationError: LocalizedError {
    case projectLimit(ProjectType)
    case fileLimit(ProjectType)
    case duplicateProjectName
    case duplicateFileName
    case destinationFolderMissing(String)
    case folderDoesNotAllowFiles(String)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .projectLimit:
            return NSLocalizedString("onboarding.error.projectLimit", comment: "Project limit reached")
        case .fileLimit:
            return NSLocalizedString("onboarding.error.fileLimit", comment: "File limit reached")
        case .duplicateProjectName:
            return NSLocalizedString("addProject.duplicateName", comment: "Duplicate project name")
        case .duplicateFileName:
            return NSLocalizedString("addFile.duplicateName", comment: "Duplicate file name")
        case .destinationFolderMissing(let folderName):
            return String(format: NSLocalizedString("onboarding.error.destinationMissing", comment: "Destination folder missing"), folderName)
        case .folderDoesNotAllowFiles(let folderName):
            return String(format: NSLocalizedString("folder.error.noFiles", comment: "Folder cannot contain files"), folderName)
        case .saveFailed(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
struct ProjectCreationService {
    static func createProject(
        name: String,
        type: ProjectType,
        fictionClass: FictionClass?,
        storyStructure: StoryStructure = .freeform,
        details: String? = nil,
        styleSheet: StyleSheet? = nil,
        allProjects: [Project],
        modelContext: ModelContext
    ) throws -> Project {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try NameValidator.validateProjectName(trimmedName)

        let activeProjects = allProjects.filter { !$0.isTrashed }
        guard UniquenessChecker.isProjectNameUnique(trimmedName, in: activeProjects) else {
            throw OnboardingCreationError.duplicateProjectName
        }

        if !OnboardingCoordinator.debugForceNewUserModeEnabled {
            let existingProjectsOfType = ProjectGateCounterService.activeProjectCount(ofType: type, in: allProjects)
            guard EntitlementManager.shared.canCreateProject(ofType: type, existingCount: existingProjectsOfType) else {
                throw OnboardingCreationError.projectLimit(type)
            }
        }

        let project = Project(
            name: trimmedName,
            type: type,
            details: details?.isEmpty == false ? details : nil,
            userOrder: ProjectSortService.nextUserOrder(for: allProjects)
        )

        if type == .fiction {
            project.fictionClassRaw = (fictionClass ?? .novel).rawValue
        }

        if type == .fiction || type == .drama {
            project.storyStructure = storyStructure
        }

        project.styleSheet = styleSheet ?? StyleSheetService.getDefaultStyleSheet(context: modelContext)

        modelContext.insert(project)
        DeduplicationService.clearTombstone(name: trimmedName, typeRaw: project.typeRaw)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "onboarding-fiction-project")
            ReviewManager.shared.recordSignificantEvent()
            return project
        } catch {
            throw OnboardingCreationError.saveFailed(error)
        }
    }
}

@MainActor
struct TextFileCreationService {
    static func createTextFile(
        name: String,
        parentFolder: Folder,
        modelContext: ModelContext,
        poetryFormId: UUID? = nil,
        poetryFormName: String? = nil,
        contentType: FileContentType = .richText,
        checkEntitlements: Bool = true
    ) throws -> TextFile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try NameValidator.validateFileName(trimmedName)

        if checkEntitlements, !OnboardingCoordinator.debugForceNewUserModeEnabled, let project = parentFolder.resolvedProject {
            let existingFileCount = ProjectGateCounterService.activeFileCount(in: project)
            guard EntitlementManager.shared.canCreateFile(forProjectType: project.type, existingCount: existingFileCount) else {
                throw OnboardingCreationError.fileLimit(project.type)
            }
        }

        guard FolderCapabilityService.canAddFile(to: parentFolder) else {
            throw OnboardingCreationError.folderDoesNotAllowFiles(parentFolder.name ?? "")
        }

        guard UniquenessChecker.isFileNameUnique(trimmedName, in: parentFolder) else {
            throw OnboardingCreationError.duplicateFileName
        }

        let file = TextFile(
            name: trimmedName,
            initialContent: "",
            parentFolder: parentFolder,
            poetryFormId: poetryFormId,
            poetryFormName: poetryFormName
        )

        file.contentType = contentType
        if FolderCapabilityService.isContentFolder(parentFolder) {
            file.workflowStatus = .draft
        }

        modelContext.insert(file)
        if parentFolder.textFiles == nil {
            parentFolder.textFiles = []
        }
        if parentFolder.textFiles?.contains(where: { $0.id == file.id }) != true {
            parentFolder.textFiles?.append(file)
        }

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "onboarding-poetry-project")
            ReviewManager.shared.recordSignificantEvent()
            return file
        } catch {
            throw OnboardingCreationError.saveFailed(error)
        }
    }
}

@MainActor
struct OnboardingCreationService {
    static func createStarterProjectAndFile(
        defaults: OnboardingDefaults,
        projectName: String,
        fileName: String,
        allProjects: [Project],
        modelContext: ModelContext
    ) throws -> (Project, TextFile) {
        let project = try ProjectCreationService.createProject(
            name: projectName,
            type: defaults.projectType,
            fictionClass: defaults.fictionClass,
            allProjects: allProjects,
            modelContext: modelContext
        )

        let file = try createStarterFile(
            name: fileName,
            project: project,
            defaults: defaults,
            modelContext: modelContext
        )

        return (project, file)
    }

    private static func createStarterFile(
        name: String,
        project: Project,
        defaults: OnboardingDefaults,
        modelContext: ModelContext
    ) throws -> TextFile {
        let destinationFolder = project.folders?.first(where: { $0.name == defaults.destinationFolderName })
            ?? project.folders?.first(where: { FolderCapabilityService.canAddFile(to: $0) })

        guard let destinationFolder else {
            throw OnboardingCreationError.destinationFolderMissing(defaults.destinationFolderName)
        }

        if project.type == .fiction || project.type == .drama {
            return try createStoryStarterFile(
                name: name,
                project: project,
                parentFolder: destinationFolder,
                isVerseNovel: defaults.fictionClass == .verseNovel,
                modelContext: modelContext
            )
        }

        let usesPoetryEditor = project.type == .poetry
        return try TextFileCreationService.createTextFile(
            name: name,
            parentFolder: destinationFolder,
            modelContext: modelContext,
            poetryFormId: usesPoetryEditor ? PoetryForm.freeVerseId : nil,
            poetryFormName: usesPoetryEditor ? "Free Verse" : nil,
            contentType: .richText,
            checkEntitlements: true
        )
    }

    private static func createStoryStarterFile(
        name: String,
        project: Project,
        parentFolder: Folder,
        isVerseNovel: Bool,
        modelContext: ModelContext
    ) throws -> TextFile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try NameValidator.validateFileName(trimmedName)

        if !OnboardingCoordinator.debugForceNewUserModeEnabled {
            let existingFileCount = ProjectGateCounterService.activeFileCount(in: project)
            guard EntitlementManager.shared.canCreateFile(forProjectType: project.type, existingCount: existingFileCount) else {
                throw OnboardingCreationError.fileLimit(project.type)
            }
        }

        guard UniquenessChecker.isFileNameUnique(trimmedName, in: parentFolder) else {
            throw OnboardingCreationError.duplicateFileName
        }

        let maxSceneOrder = (project.scenes ?? []).filter { !$0.isTrashed }.compactMap(\.userOrder).max() ?? -1
        let scene = StoryScene(name: trimmedName, userOrder: maxSceneOrder + 1)
        scene.project = project

        if project.type == .fiction, project.fictionClass == .novel {
            let chapter = Chapter(name: trimmedName, userOrder: 0)
            chapter.project = project
            modelContext.insert(chapter)
            scene.chapter = chapter
        }

        if project.scenes == nil {
            project.scenes = []
        }
        project.scenes?.append(scene)

        let file = TextFile(
            name: trimmedName,
            initialContent: "",
            parentFolder: parentFolder,
            poetryFormId: isVerseNovel ? PoetryForm.freeVerseId : nil,
            poetryFormName: isVerseNovel ? "Free Verse" : nil
        )
        file.contentType = .richText
        file.workflowStatus = .draft
        file.scene = scene
        scene.textFile = file

        modelContext.insert(scene)
        modelContext.insert(file)
        if parentFolder.textFiles == nil {
            parentFolder.textFiles = []
        }
        if parentFolder.textFiles?.contains(where: { $0.id == file.id }) != true {
            parentFolder.textFiles?.append(file)
        }

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "onboarding-empty-project")
            ReviewManager.shared.recordSignificantEvent()
            return file
        } catch {
            throw OnboardingCreationError.saveFailed(error)
        }
    }
}

@MainActor
@Observable
final class OnboardingCoordinator {
    private static let completedKey = "onboarding.completed"
    private static let editorIntroShownKey = "onboarding.editorIntroShown"
    private static let debugForceNewUserModeKey = "onboarding.debug.forceNewUserMode"

    private static var syncedCompletionStore: NSUbiquitousKeyValueStore {
        NSUbiquitousKeyValueStore.default
    }

    private static var hasSyncedCompletion: Bool {
        syncedCompletionStore.synchronize()
        return syncedCompletionStore.bool(forKey: completedKey)
    }

    static var debugForceNewUserModeEnabled: Bool {
        get {
            #if DEBUG || targetEnvironment(simulator)
            return UserDefaults.standard.bool(forKey: debugForceNewUserModeKey)
            #else
            return false
            #endif
        }
        set {
            #if DEBUG || targetEnvironment(simulator)
            UserDefaults.standard.set(newValue, forKey: debugForceNewUserModeKey)
            #endif
        }
    }

    var step: OnboardingStep = .welcome
    var selectedProjectType: ProjectType?
    var selectedFictionClass: FictionClass = .novel
    var projectName: String = ""
    var fileName: String = ""
    var skippedForCurrentLaunch = false
    var isCreating = false
    var errorMessage = ""
    var showError = false

    var hasCompletedOnboarding: Bool {
        if Self.debugForceNewUserModeEnabled {
            return false
        }

        if UserDefaults.standard.bool(forKey: Self.completedKey) {
            return true
        }

        if Self.hasSyncedCompletion {
            UserDefaults.standard.set(true, forKey: Self.completedKey)
            return true
        }

        return false
    }

    var hasShownEditorIntro: Bool {
        if Self.debugForceNewUserModeEnabled {
            return false
        }
        return UserDefaults.standard.bool(forKey: Self.editorIntroShownKey)
    }

    var currentDefaults: OnboardingDefaults? {
        guard let selectedProjectType else { return nil }
        return OnboardingDefaults.defaults(
            for: selectedProjectType,
            fictionClass: selectedProjectType == .fiction ? selectedFictionClass : nil
        )
    }

    func selectProjectType(_ projectType: ProjectType) {
        selectedProjectType = projectType
        applyDefaults()
    }

    func selectFictionClass(_ fictionClass: FictionClass) {
        selectedFictionClass = fictionClass
        applyDefaults()
    }

    func applyDefaults() {
        guard let defaults = currentDefaults else { return }
        projectName = defaults.defaultProjectName
        fileName = defaults.defaultFileName
    }

    func skipForNow() {
        skippedForCurrentLaunch = true
    }

    func markCompleted() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        Self.syncedCompletionStore.set(true, forKey: Self.completedKey)
        Self.syncedCompletionStore.synchronize()
    }

    func resetCompletionForRestart() {
        UserDefaults.standard.set(false, forKey: Self.completedKey)
        UserDefaults.standard.set(false, forKey: Self.editorIntroShownKey)
        skippedForCurrentLaunch = false
        resetFlow()
    }

    func markEditorIntroShown() {
        UserDefaults.standard.set(true, forKey: Self.editorIntroShownKey)
    }

    func resetFlow() {
        step = .welcome
        selectedProjectType = nil
        selectedFictionClass = .novel
        projectName = ""
        fileName = ""
        errorMessage = ""
        showError = false
        isCreating = false
    }
}

struct OnboardingView: View {
    @Bindable var coordinator: OnboardingCoordinator
    let onSkip: () -> Void
    let onCreate: (OnboardingDefaults, String, String) throws -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.step {
                case .welcome:
                    welcomeView
                case .genre:
                    genreView
                case .fictionClass:
                    fictionClassView
                case .projectName:
                    projectNameView
                case .fileName:
                    fileNameView
                }
            }
            .navigationTitle(NSLocalizedString("onboarding.title", comment: "Onboarding title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("onboarding.skipForNow", comment: "Skip onboarding for now")) {
                        coordinator.skipForNow()
                        onSkip()
                    }
                    .disabled(coordinator.isCreating)
                }
            }
            .alert(NSLocalizedString("onboarding.error.title", comment: "Onboarding error title"), isPresented: $coordinator.showError) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(coordinator.errorMessage)
            }
        }
        .interactiveDismissDisabled(coordinator.isCreating)
    }

    private var welcomeView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 24)
            Image("WSPAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(NSLocalizedString("onboarding.welcome.heading", comment: "Onboarding welcome heading"))
                .font(.title.bold())
            Text(NSLocalizedString("onboarding.welcome.body", comment: "Onboarding welcome body"))
                .font(.title3)
                .foregroundStyle(.primary)
            (
                Text(NSLocalizedString("onboarding.welcome.guide.prefix", comment: "Onboarding user guide note before help button icon"))
                + Text(Image(systemName: "questionmark.circle"))
                + Text(NSLocalizedString("onboarding.welcome.guide.suffix", comment: "Onboarding user guide note after help button icon"))
            )
                .font(.title3)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                coordinator.step = .genre
            } label: {
                Text(NSLocalizedString("onboarding.continue", comment: "Continue onboarding"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var genreView: some View {
        Form {
            Section {
                genreRow(.poetry, systemImage: "text.quote")
                genreRow(.prose, systemImage: "doc.text")
                genreRow(.fiction, systemImage: "book")
                genreRow(.drama, systemImage: "theatermasks")
            } header: {
                Text(NSLocalizedString("onboarding.genre.section", comment: "Genre section"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomButton(NSLocalizedString("onboarding.next", comment: "Next")) {
                guard coordinator.selectedProjectType != nil else { return }
                coordinator.step = coordinator.selectedProjectType == .fiction ? .fictionClass : .projectName
            }
            .disabled(coordinator.selectedProjectType == nil)
        }
    }

    private func genreRow(_ type: ProjectType, systemImage: String) -> some View {
        Button {
            coordinator.selectProjectType(type)
        } label: {
            HStack {
                Label(type.localizedName, systemImage: systemImage)
                Spacer()
                Image(systemName: coordinator.selectedProjectType == type ? "checkmark.square.fill" : "square")
                    .foregroundStyle(coordinator.selectedProjectType == type ? Color.accentColor : Color.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var fictionClassView: some View {
        Form {
            Section {
                ForEach(FictionClass.allCases, id: \.self) { fictionClass in
                    Button {
                        coordinator.selectFictionClass(fictionClass)
                    } label: {
                        HStack {
                            Text(fictionClass.localizedName)
                            Spacer()
                            Image(systemName: coordinator.selectedFictionClass == fictionClass ? "checkmark.square.fill" : "square")
                                .foregroundStyle(coordinator.selectedFictionClass == fictionClass ? Color.accentColor : Color.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text(NSLocalizedString("onboarding.fictionClass.section", comment: "Fiction class section"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomButton(NSLocalizedString("onboarding.next", comment: "Next")) {
                coordinator.applyDefaults()
                coordinator.step = .projectName
            }
        }
    }

    private var projectNameView: some View {
        Form {
            Section {
                TextField(NSLocalizedString("onboarding.projectName.placeholder", comment: "Project name placeholder"), text: $coordinator.projectName)
            } header: {
                Text(NSLocalizedString("onboarding.projectName.section", comment: "Project name section"))
            } footer: {
                Text(NSLocalizedString("onboarding.projectName.footer", comment: "Project name footer"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomButton(NSLocalizedString("onboarding.next", comment: "Next")) {
                coordinator.step = .fileName
            }
            .disabled(coordinator.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var fileNameView: some View {
        Form {
            Section {
                TextField(NSLocalizedString("onboarding.fileName.placeholder", comment: "File name placeholder"), text: $coordinator.fileName)
            } header: {
                Text(NSLocalizedString("onboarding.fileName.section", comment: "File name section"))
            } footer: {
                Text(NSLocalizedString("onboarding.fileName.footer", comment: "File name footer"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomButton(NSLocalizedString("onboarding.create", comment: "Create project and file")) {
                createProjectAndFile()
            }
            .disabled(coordinator.fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isCreating)
        }
    }

    private func bottomButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if coordinator.isCreating {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .background(.bar)
    }

    private func createProjectAndFile() {
        guard let defaults = coordinator.currentDefaults else { return }
        coordinator.isCreating = true
        do {
            try onCreate(defaults, coordinator.projectName, coordinator.fileName)
        } catch {
            coordinator.errorMessage = error.localizedDescription
            coordinator.showError = true
        }
        coordinator.isCreating = false
    }
}
