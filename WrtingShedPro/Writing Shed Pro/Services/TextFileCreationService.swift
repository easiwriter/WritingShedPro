import Foundation
import SwiftData

@MainActor
struct FileCreationAuthorization {
    let canModifyContent: () -> Bool
    let canCreateFile: (_ projectType: ProjectType, _ existingCount: Int) -> Bool

    static let live = FileCreationAuthorization(
        canModifyContent: { EntitlementManager.shared.canModifyContent },
        canCreateFile: { projectType, existingCount in
            EntitlementManager.shared.canCreateFile(
                forProjectType: projectType,
                existingCount: existingCount
            )
        }
    )
}

struct FileCopyResult {
    let copiedCount: Int
    let destinationName: String

    var localizedMessage: String {
        let format = copiedCount == 1
            ? NSLocalizedString("copyToProject.success.single", comment: "1 file copied")
            : NSLocalizedString("copyToProject.success.multiple", comment: "%d files copied")
        return String(format: format, copiedCount)
            + " "
            + String(
                format: NSLocalizedString(
                    "copyToProject.success.destination",
                    comment: "to project"
                ),
                destinationName
            )
    }
}

enum TextFileCopyError: LocalizedError {
    case readOnlyAccess
    case fileLimit(ProjectType)
    case noDestinationFolder(sourceName: String, destinationName: String)
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .readOnlyAccess:
            return NSLocalizedString(
                "iap.readOnly.error",
                comment: "Error when an editing action requires Full Access"
            )
        case .fileLimit:
            return NSLocalizedString(
                "onboarding.error.fileLimit",
                comment: "File limit reached"
            )
        case .noDestinationFolder(let sourceName, let destinationName):
            return String(
                format: NSLocalizedString(
                    "copyToProject.error.noFolder",
                    comment: "No matching folder found"
                ),
                sourceName,
                destinationName
            )
        case .saveFailed(let error):
            return NSLocalizedString(
                "copyToProject.error.saveFailed",
                comment: "Save failed"
            ) + ": \(error.localizedDescription)"
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
        checkEntitlements: Bool = true,
        authorization: FileCreationAuthorization = .live
    ) throws -> TextFile {
        let file = try insertTextFile(
            name: name,
            parentFolder: parentFolder,
            modelContext: modelContext,
            poetryFormId: poetryFormId,
            poetryFormName: poetryFormName,
            contentType: contentType,
            workflowStatus: FolderCapabilityService.isContentFolder(parentFolder) ? .draft : nil,
            checkEntitlements: checkEntitlements,
            authorization: authorization
        )

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "onboarding-poetry-project")
            ReviewManager.shared.recordSignificantEvent()
            return file
        } catch {
            throw OnboardingCreationError.saveFailed(error)
        }
    }

    static func insertTextFile(
        name: String,
        initialContent: String = "",
        parentFolder: Folder,
        modelContext: ModelContext,
        poetryFormId: UUID? = nil,
        poetryFormName: String? = nil,
        contentType: FileContentType = .richText,
        workflowStatus: WorkflowStatus? = .draft,
        checkEntitlements: Bool = true,
        checkNameUniqueness: Bool = true,
        authorization: FileCreationAuthorization = .live
    ) throws -> TextFile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try NameValidator.validateFileName(trimmedName)

        if checkEntitlements,
           !OnboardingCoordinator.debugForceNewUserModeEnabled,
           let project = parentFolder.resolvedProject {
            guard authorization.canModifyContent() else {
                throw TextFileCopyError.readOnlyAccess
            }
            let existingFileCount = ProjectGateCounterService.activeFileCount(in: project)
            guard authorization.canCreateFile(project.type, existingFileCount) else {
                throw OnboardingCreationError.fileLimit(project.type)
            }
        }

        guard FolderCapabilityService.canAddFile(to: parentFolder) else {
            throw OnboardingCreationError.folderDoesNotAllowFiles(parentFolder.name ?? "")
        }

        if checkNameUniqueness,
           !UniquenessChecker.isFileNameUnique(trimmedName, in: parentFolder) {
            throw OnboardingCreationError.duplicateFileName
        }

        let file = TextFile(
            name: trimmedName,
            initialContent: initialContent,
            parentFolder: parentFolder,
            poetryFormId: poetryFormId,
            poetryFormName: poetryFormName
        )
        file.contentType = contentType
        file.workflowStatus = workflowStatus
        modelContext.insert(file)

        if parentFolder.textFiles == nil {
            parentFolder.textFiles = []
        }
        if parentFolder.textFiles?.contains(where: { $0.id == file.id }) != true {
            parentFolder.textFiles?.append(file)
        }

        return file
    }

    static func copyFiles(
        _ files: [TextFile],
        to destination: Project,
        matchingSourceFolderName sourceFolderName: String,
        modelContext: ModelContext,
        saveReason: String,
        authorization: FileCreationAuthorization = .live
    ) throws -> FileCopyResult {
        let copyableFiles = files.compactMap { file in
            file.currentVersion.map { (file, $0) }
        }
        let destinationName = destination.name ?? ""

        guard !copyableFiles.isEmpty else {
            return FileCopyResult(copiedCount: 0, destinationName: destinationName)
        }

        let existingFileCount = ProjectGateCounterService.activeFileCount(in: destination)
        try validateCopyAccess(
            projectType: destination.type,
            existingFileCount: existingFileCount,
            requestedFileCount: copyableFiles.count,
            authorization: authorization
        )

        guard let destinationFolder = matchingFolder(
            in: destination,
            sourceName: sourceFolderName
        ) else {
            throw TextFileCopyError.noDestinationFolder(
                sourceName: sourceFolderName,
                destinationName: destinationName
            )
        }

        var usedNames = Set((destinationFolder.textFiles ?? []).map(\.name))
        let baseFileOrder = (destinationFolder.textFiles ?? [])
            .compactMap(\.userOrder)
            .max() ?? -1
        let baseSceneOrder = (destination.scenes ?? [])
            .filter { !$0.isTrashed }
            .compactMap(\.userOrder)
            .max() ?? -1
        var insertedFiles: [TextFile] = []
        var insertedScenes: [StoryScene] = []

        for (offset, source) in copyableFiles.enumerated() {
            let (sourceFile, sourceVersion) = source
            let uniqueName = uniqueName(for: sourceFile.name, usedNames: usedNames)
            usedNames.insert(uniqueName)

            let copiedFile = TextFile(
                name: uniqueName,
                initialContent: sourceVersion.content,
                parentFolder: destinationFolder,
                poetryFormId: sourceFile.poetryFormId,
                poetryFormName: sourceFile.poetryFormName
            )
            copiedFile.workflowStatusRaw = sourceFile.workflowStatusRaw
            copiedFile.contentTypeRaw = sourceFile.contentTypeRaw
            copiedFile.userOrder = baseFileOrder + 1 + offset

            if let copiedVersion = copiedFile.currentVersion {
                if let formattedData = sourceVersion.effectiveFormattedContent {
                    copiedVersion.setFormattedContentData(
                        formattedData,
                        sourceText: sourceVersion.content
                    )
                }
                copiedVersion.referenceMetadataData = sourceVersion.referenceMetadataData
                copiedVersion.comment = sourceVersion.comment
                copiedVersion.notes = sourceVersion.notes
                copiedVersion.notesFormattedContent = sourceVersion.notesFormattedContent
            }

            modelContext.insert(copiedFile)
            insertedFiles.append(copiedFile)

            if destination.type == .fiction || destination.type == .drama {
                let scene = StoryScene(
                    name: uniqueName,
                    userOrder: baseSceneOrder + 1 + offset
                )
                scene.project = destination
                scene.textFile = copiedFile
                modelContext.insert(scene)
                insertedScenes.append(scene)
            }
        }

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: saveReason)
        } catch {
            insertedScenes.forEach { modelContext.delete($0) }
            insertedFiles.forEach { modelContext.delete($0) }
            throw TextFileCopyError.saveFailed(error)
        }

        return FileCopyResult(
            copiedCount: copyableFiles.count,
            destinationName: destinationName
        )
    }

    static func validateCopyAccess(
        projectType: ProjectType,
        existingFileCount: Int,
        requestedFileCount: Int,
        authorization: FileCreationAuthorization
    ) throws {
        try validateCreationAccess(
            projectType: projectType,
            existingFileCount: existingFileCount,
            requestedFileCount: requestedFileCount,
            authorization: authorization
        )
    }

    static func validateCreationAccess(
        projectType: ProjectType,
        existingFileCount: Int,
        requestedFileCount: Int,
        authorization: FileCreationAuthorization = .live
    ) throws {
        guard authorization.canModifyContent() else {
            throw TextFileCopyError.readOnlyAccess
        }
        guard requestedFileCount > 0 else { return }

        let countBeforeFinalInsertion = existingFileCount + requestedFileCount - 1
        guard authorization.canCreateFile(projectType, countBeforeFinalInsertion) else {
            throw TextFileCopyError.fileLimit(projectType)
        }
    }

    private static func matchingFolder(
        in project: Project,
        sourceName: String
    ) -> Folder? {
        guard let folders = project.folders else { return nil }

        if let exactMatch = folders.first(where: { $0.name == sourceName }) {
            return exactMatch
        }

        let contentFolderNames: Set<String> = [
            "Poems", "Scenes", "Stories", "Episodes", "Scripts", "Sections", "Prose",
        ]
        if let contentFolder = folders.first(where: {
            contentFolderNames.contains($0.name ?? "")
        }) {
            return contentFolder
        }

        return folders.first(where: { FolderCapabilityService.canAddFile(to: $0) })
    }

    private static func uniqueName(for name: String, usedNames: Set<String>) -> String {
        guard usedNames.contains(name) else { return name }

        for counter in 2...1000 {
            let candidate = "\(name) \(counter)"
            if !usedNames.contains(candidate) {
                return candidate
            }
        }

        return "\(name) \(UUID().uuidString.prefix(6))"
    }
}
