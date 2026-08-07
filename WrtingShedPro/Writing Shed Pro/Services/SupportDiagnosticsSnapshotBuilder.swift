import Foundation
import SwiftData
import CryptoKit

/// Builds a compact sync diagnostics snapshot suitable for support emails.
enum SupportDiagnosticsSnapshotBuilder {
    @MainActor
    static func buildSnapshot(modelContext: ModelContext) -> String {
        var lines: [String] = []
        let now = Date()
        lines.append("Sync & Data Health Snapshot")
        lines.append("Generated: \(now.formatted(date: .complete, time: .standard))")
        lines.append("syncBackend: Ensembles")
        lines.append("cloudContainer: iCloud.com.appworks.writingshedpro")
        lines.append("activeEnsemblesContainer: \(Write_App.activeEnsemblesContainer != nil)")
        lines.append("firstSuccessfulSyncThisLaunch: \(Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch)")
        lines.append("observedEnsemblesDataThisLaunch: \(Write_App.hasObservedEnsemblesDataThisLaunch)")
        lines.append("observedPartialEnsemblesStoreThisLaunch: \(Write_App.hasObservedPartialEnsemblesStoreThisLaunch)")
        lines.append("localSyncResetQueued: \(UserDefaults.standard.bool(forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey))")
        if let ensemblesContainer = Write_App.activeEnsemblesContainer {
            lines.append("ensemblesIsAttached: \(ensemblesContainer.isAttached)")
            lines.append("ensemblesSyncSuspended: \(ensemblesContainer.isSyncSuspended)")
            lines.append("ensemblesCurrentActivity: \(String(describing: ensemblesContainer.currentActivity))")
        }
        lines.append(contentsOf: recentSyncOutcomeLines())

        let freshContext = ModelContext(modelContext.container)
        let formatter = ISO8601DateFormatter()

        let storeProjects = ((try? freshContext.fetch(FetchDescriptor<Project>())) ?? [])
            .sorted { lhs, rhs in
                let lhsCreated = lhs.creationDate ?? .distantPast
                let rhsCreated = rhs.creationDate ?? .distantPast
                if lhsCreated != rhsCreated {
                    return lhsCreated < rhsCreated
                }
                return (lhs.name ?? "") < (rhs.name ?? "")
            }

        lines.append("")
        lines.append("Project Inventory")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        for project in storeProjects {
            let created = project.creationDate.map { formatter.string(from: $0) } ?? "nil"
            let modified = project.modifiedDate.map { formatter.string(from: $0) } ?? "nil"
            let deleted = project.deletedDate.map { formatter.string(from: $0) } ?? "nil"
            let folderCount = project.folders?.count ?? 0
            lines.append("- name=\(project.name ?? "Untitled") | id=\(project.id.uuidString) | type=\(project.type.rawValue) | trashed=\(project.isTrashed) | userOrder=\(project.userOrder.map(String.init) ?? "nil") | created=\(created) | modified=\(modified) | deleted=\(deleted) | folders=\(folderCount)")
        }

        lines.append("")
        lines.append("Project Deep Counts (store)")
        lines.append("- format: id | name | folders | textFiles | scenes | activeScenes | scenesWithText | sceneFilesInFolders | sceneFilesInTrash | versions | submittedFiles | submissions | publications | poetryCollections")
        for project in storeProjects {
            let folderCount = countFolders(in: project)
            let textFileCount = countTextFiles(in: project)
            let sceneCount = project.scenes?.count ?? 0
            let activeScenes = (project.scenes ?? []).filter { !$0.isTrashed }
            let activeSceneCount = activeScenes.count
            let scenesWithTextCount = activeScenes.filter { $0.textFile != nil }.count
            let sceneFilesInFoldersCount = activeScenes.filter { $0.textFile?.parentFolder != nil }.count
            let sceneFilesInTrashCount = activeScenes.filter { $0.textFile?.trashItem != nil }.count
            let versionCount = countVersions(in: project)
            let submittedFileCount = countSubmittedFiles(in: project)
            let submissionCount = countSubmissions(in: project)
            let publicationCount = project.publications?.count ?? 0
            let poetryCollectionCount = project.poetryCollections?.count ?? 0

            lines.append("- \(project.id.uuidString) | \(project.name ?? "Untitled") | \(folderCount) | \(textFileCount) | \(sceneCount) | \(activeSceneCount) | \(scenesWithTextCount) | \(sceneFilesInFoldersCount) | \(sceneFilesInTrashCount) | \(versionCount) | \(submittedFileCount) | \(submissionCount) | \(publicationCount) | \(poetryCollectionCount)")
        }

        lines.append("")
        lines.append("Scene/TextFile Mismatches (store)")
        lines.append("- format: project | sceneName | sceneId | sceneTrashed | textFile | filePlacement")
        var mismatchCount = 0
        for project in storeProjects {
            let activeScenes = (project.scenes ?? []).filter { !$0.isTrashed }
            for scene in activeScenes.sorted(by: sortScenesByOrderThenName) {
                let placement = sceneTextFilePlacement(scene.textFile)
                guard !placement.hasPrefix("in-folder(") else { continue }

                mismatchCount += 1
                let textFileDescription: String
                if let textFile = scene.textFile {
                    textFileDescription = "\(textFile.name) (\(textFile.id.uuidString))"
                } else {
                    textFileDescription = "nil"
                }
                lines.append("- \(project.name ?? "Untitled") | \(scene.name ?? "Untitled") | \(scene.id.uuidString) | \(scene.isTrashed) | \(textFileDescription) | \(placement)")
            }
        }
        if mismatchCount == 0 {
            lines.append("- none")
        }

        lines.append("")
        lines.append("Project Sync Fingerprints (store)")
        lines.append("- format: id | name | modified | fingerprint")
        for project in storeProjects {
            let modified = project.modifiedDate.map { formatter.string(from: $0) } ?? "nil"
            let fingerprint = stableProjectFingerprint(for: project)
            lines.append("- \(project.id.uuidString) | \(project.name ?? "Untitled") | \(modified) | \(fingerprint)")
        }

        let storePublications = (try? freshContext.fetch(FetchDescriptor<Publication>())) ?? []
        lines.append("")
        lines.append("Publication Inventory")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        lines.append("- count=\(storePublications.count)")

        lines.append("")
        lines.append("Image Attachment Diagnostics (store)")
        let imageAttachmentLines = imageAttachmentDiagnosticsLines(for: storeProjects)
        if imageAttachmentLines.isEmpty {
            lines.append("- none")
        } else {
            lines.append(contentsOf: imageAttachmentLines)
        }

        lines.append("")
        lines.append("Recent File Version Diagnostics (store)")
        let fileVersionLines = recentFileVersionDiagnosticsLines(for: storeProjects)
        if fileVersionLines.isEmpty {
            lines.append("- none")
        } else {
            lines.append(contentsOf: fileVersionLines)
        }

        lines.append("")
        lines.append("Entity Counts (store):")
        lines.append("- Project: \((try? freshContext.fetchCount(FetchDescriptor<Project>())) ?? -1)")
        lines.append("- Publication: \((try? freshContext.fetchCount(FetchDescriptor<Publication>())) ?? -1)")
        lines.append("- Folder: \((try? freshContext.fetchCount(FetchDescriptor<Folder>())) ?? -1)")
        lines.append("- TextFile: \((try? freshContext.fetchCount(FetchDescriptor<TextFile>())) ?? -1)")
        lines.append("- StoryScene: \((try? freshContext.fetchCount(FetchDescriptor<StoryScene>())) ?? -1)")
        lines.append("- TrashItem: \((try? freshContext.fetchCount(FetchDescriptor<TrashItem>())) ?? -1)")
        lines.append("- Version: \((try? freshContext.fetchCount(FetchDescriptor<Version>())) ?? -1)")
        lines.append("- StyleSheet: \((try? freshContext.fetchCount(FetchDescriptor<StyleSheet>())) ?? -1)")
        lines.append("- TextStyleModel: \((try? freshContext.fetchCount(FetchDescriptor<TextStyleModel>())) ?? -1)")
        lines.append("- ImageStyle: \((try? freshContext.fetchCount(FetchDescriptor<ImageStyle>())) ?? -1)")
        lines.append("- PoetryFormModel: \((try? freshContext.fetchCount(FetchDescriptor<PoetryFormModel>())) ?? -1)")
        lines.append("- PoetryCollection: \((try? freshContext.fetchCount(FetchDescriptor<PoetryCollection>())) ?? -1)")

        let hiddenProjectIDs = Set(ContentViewState.hiddenProjectIDsForDiagnostics)
        let hiddenActiveProjectCount = storeProjects.filter { !$0.isTrashed && hiddenProjectIDs.contains($0.id) }.count
        lines.append("")
        lines.append("Project Visibility Filter:")
        lines.append("- hiddenProjectIDs: \(hiddenProjectIDs.count)")
        lines.append("- hiddenActiveProjectsInStore: \(hiddenActiveProjectCount)")
        lines.append("- visibleActiveProjectsAfterFilter: \(max(0, storeProjects.filter { !$0.isTrashed }.count - hiddenActiveProjectCount))")

        let presentedProjects = DeduplicationService.presentedProjects(
            from: storeProjects.filter { !$0.isTrashed && !hiddenProjectIDs.contains($0.id) }
        )
        lines.append("- presentedProjectsAfterUIDedup: \(presentedProjects.count)")
        for project in presentedProjects {
            lines.append("  - \(project.name ?? "Untitled") | id=\(project.id.uuidString) | type=\(project.type.rawValue)")
        }

        let exactIDDuplicateCount = DeduplicationService.countExactIDDuplicateRecords(context: freshContext)
        lines.append("")
        lines.append("Exact ID Duplicates:")
        lines.append("- duplicateRecords: \(exactIDDuplicateCount)")
        let exactDuplicateSummary = DeduplicationService.exactIDDuplicateSummaryLines(context: freshContext)
        if !exactDuplicateSummary.isEmpty {
            lines.append(contentsOf: exactDuplicateSummary)
        }

        let duplicateTemplateFolderCount = DeduplicationService.countDuplicateTemplateFolderRecords(context: freshContext)
        lines.append("")
        lines.append("Duplicate Template Folders:")
        lines.append("- duplicateRecords: \(duplicateTemplateFolderCount)")

        let tombstones = DeduplicationService.tombstoneDescriptions()
        lines.append("")
        lines.append("Zombie Tombstones: \(tombstones.count)")
        for tombstone in tombstones {
            lines.append("- \(tombstone.name) | type=\(tombstone.type) | deleted=\(tombstone.deletedAt.formatted(date: .abbreviated, time: .shortened))")
        }

        lines.append("")
        lines.append("Local Ensembles Event Cache")
        for cacheLine in localEnsemblesEventCacheLines() {
            lines.append(cacheLine)
        }

        lines.append("")
        lines.append("Ensembles Event Store")
        for eventStoreLine in ensemblesEventStoreLines() {
            lines.append(eventStoreLine)
        }

        lines.append("")
        lines.append("Zone Verification Log")
        for logLine in recentZoneVerificationLines(limit: 10) {
            lines.append(logLine)
        }

        lines.append("")
        lines.append("Recent Sync Log")
        for logLine in recentDiagnosticsLogLines(limit: 80) {
            lines.append(logLine)
        }

        return lines.joined(separator: "\n")
    }

    private static func imageAttachmentDiagnosticsLines(for projects: [Project]) -> [String] {
        var lines: [String] = []

        for project in projects {
            var fileSummaries: [(name: String, id: UUID, imageCount: Int, versionCount: Int, modified: Date?)] = []

            for file in allTextFiles(in: project) {
                let versions = file.versions ?? []
                let imageCount = versions.reduce(0) { $0 + countImageAttachments(in: $1) }
                guard imageCount > 0 else { continue }
                fileSummaries.append((
                    name: file.name,
                    id: file.id,
                    imageCount: imageCount,
                    versionCount: versions.count,
                    modified: file.modifiedDate
                ))
            }

            guard !fileSummaries.isEmpty else { continue }

            let totalImages = fileSummaries.reduce(0) { $0 + $1.imageCount }
            lines.append("- project=\(project.name ?? "Untitled") | id=\(project.id.uuidString) | filesWithImages=\(fileSummaries.count) | imageAttachments=\(totalImages)")

            for summary in fileSummaries.sorted(by: imageFileSort).prefix(8) {
                let modified = summary.modified.map { ISO8601DateFormatter().string(from: $0) } ?? "nil"
                lines.append("  - file=\(summary.name) | id=\(summary.id.uuidString) | images=\(summary.imageCount) | versions=\(summary.versionCount) | modified=\(modified)")
            }
        }

        return lines
    }

    private static func countImageAttachments(in version: Version) -> Int {
        guard let attributedContent = version.attributedContent else { return 0 }
        var count = 0
        attributedContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedContent.length)) { value, _, _ in
            if value is ImageAttachment {
                count += 1
            }
        }
        return count
    }

    private static func recentFileVersionDiagnosticsLines(for projects: [Project]) -> [String] {
        let formatter = ISO8601DateFormatter()
        let files = projects
            .flatMap { project in allTextFiles(in: project).map { (project, $0) } }
            .sorted { lhs, rhs in
                if lhs.1.modifiedDate != rhs.1.modifiedDate {
                    return lhs.1.modifiedDate > rhs.1.modifiedDate
                }
                return lhs.1.name < rhs.1.name
            }
            .prefix(25)

        return files.map { project, file in
            let versions = file.sortedVersions
            let versionSummary = versions.map { version in
                let formattedBytes = version.effectiveFormattedContent?.count ?? 0
                let metadataBytes = version.referenceMetadataData?.count ?? 0
                return "v\(version.versionNumber):text=\(version.content.count),formatted=\(formattedBytes),refs=\(metadataBytes)"
            }.joined(separator: ";")
            return "- project=\(project.name ?? "Untitled") | file=\(file.name) | id=\(file.id.uuidString) | currentIndex=\(file.currentVersionIndex) | modified=\(formatter.string(from: file.modifiedDate)) | versions=[\(versionSummary)]"
        }
    }

    private static func imageFileSort(
        _ lhs: (name: String, id: UUID, imageCount: Int, versionCount: Int, modified: Date?),
        _ rhs: (name: String, id: UUID, imageCount: Int, versionCount: Int, modified: Date?)
    ) -> Bool {
        let lhsModified = lhs.modified ?? .distantPast
        let rhsModified = rhs.modified ?? .distantPast
        if lhsModified != rhsModified { return lhsModified > rhsModified }
        return lhs.name < rhs.name
    }

    private static func localEnsemblesEventCacheLines() -> [String] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ["- unavailable: documents directory not found"]
        }

        let eventDataURL = documentsDirectory.appendingPathComponent("EnsemblesEventData", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: eventDataURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ["- missing"]
        }

        guard let enumerator = FileManager.default.enumerator(
            at: eventDataURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ["- unavailable: could not enumerate"]
        }

        var fileCount = 0
        var directoryCount = 0
        var totalBytes = 0
        var samples: [String] = []

        for case let url as URL in enumerator {
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isDirectoryKey])
            if resourceValues?.isDirectory == true {
                directoryCount += 1
                continue
            }

            guard resourceValues?.isRegularFile == true else { continue }
            fileCount += 1
            let fileSize = resourceValues?.fileSize ?? 0
            totalBytes += fileSize

            if samples.count < 12 {
                let relativePath = url.path.replacingOccurrences(of: eventDataURL.path + "/", with: "")
                samples.append("\(relativePath)(\(fileSize)b)")
            }
        }

        return [
            "- directories=\(directoryCount) files=\(fileCount) bytes=\(totalBytes)",
            "- samples=\(samples.isEmpty ? "none" : samples.joined(separator: ", "))"
        ]
    }

    @MainActor
    private static func ensemblesEventStoreLines() -> [String] {
        guard let ensemblesContainer = Write_App.activeEnsemblesContainer else {
            return ["- unavailable: no active Ensembles container"]
        }

        let eventStore = ensemblesContainer.ensemble.coreDataEnsemble.eventStore
        var lines: [String] = []
        lines.append("- containsEventData: \(eventStore.containsEventData)")
        lines.append("- needsFullIntegration: \(eventStore.needsFullIntegration)")
        lines.append("- lastMergeRevisionSaved: \(String(describing: eventStore.lastMergeRevisionSaved))")
        lines.append("- lastSaveRevisionSaved: \(String(describing: eventStore.lastSaveRevisionSaved))")
        lines.append("- lastRevisionSaved: \(String(describing: eventStore.lastRevisionSaved))")
        lines.append("- currentBaselineIdentifier: \(eventStore.currentBaselineIdentifier ?? "nil")")
        lines.append("- identifierOfBaselineUsedToConstructStore: \(eventStore.identifierOfBaselineUsedToConstructStore ?? "nil")")
        lines.append("- persistentStoreIdentifier: \(eventStore.persistentStoreIdentifier ?? "nil")")
        lines.append("- incompleteMandatoryEventIdentifiers: \(eventStore.incompleteMandatoryEventIdentifiers.count)")
        lines.append("- allDataFilenames: \(eventStore.allDataFilenames.count)")
        lines.append("- newlyImportedDataFilenames: \(eventStore.newlyImportedDataFilenames.count)")
        lines.append("- previouslyReferencedDataFilenames: \(eventStore.previouslyReferencedDataFilenames.count)")
        lines.append("- pathToEventStoreRootDirectory: \(eventStore.pathToEventStoreRootDirectory)")
        do {
            lines.append("- eventCountAll: \(try eventStore.countAllEvents())")
            lines.append("- eventCountBaseline: \(try eventStore.countEvents(type: .baseline))")
            lines.append("- eventCountSave: \(try eventStore.countEvents(type: .save))")
            lines.append("- eventCountMerge: \(try eventStore.countEvents(type: .merge))")
            lines.append("- objectChangeCountAll: \(try eventStore.countAllObjectChanges())")
            lines.append("- objectChangeCountBaseline: \(try eventStore.countObjectChanges(eventType: .baseline))")
            lines.append("- objectChangeCountSave: \(try eventStore.countObjectChanges(eventType: .save))")
            lines.append("- objectChangeCountMerge: \(try eventStore.countObjectChanges(eventType: .merge))")
            lines.append("- objectChangeCountInsert: \(try eventStore.countNonBaselineObjectChanges(changeType: .insert))")
            lines.append("- objectChangeCountUpdate: \(try eventStore.countNonBaselineObjectChanges(changeType: .update))")
            lines.append("- objectChangeCountDelete: \(try eventStore.countNonBaselineObjectChanges(changeType: .delete))")
            lines.append("- persistentStoreIdentifiers: \(try eventStore.fetchPersistentStoreIdentifiers().sorted().joined(separator: ","))")
        } catch {
            lines.append("- eventStoreCountsError: \(error.localizedDescription)")
        }
        return lines
    }

    private static func recentZoneVerificationLines(limit: Int) -> [String] {
        let lines = diagnosticsLogLines()
            .filter { $0.contains("Zone verification") }
        return lines.isEmpty ? ["- none"] : Array(lines.suffix(limit))
    }

    private static func recentDiagnosticsLogLines(limit: Int) -> [String] {
        let relevantLines = diagnosticsLogLines()
            .filter { line in
                line.contains("[Ensembles]") ||
                line.contains("iCloud account") ||
                line.contains("CloudKit container") ||
                line.contains("Private database") ||
                line.contains("didSync=") ||
                line.contains("Error") ||
                line.contains("error")
            }

        return Array(relevantLines.suffix(limit))
    }

    private static func recentSyncOutcomeLines() -> [String] {
        let lines = diagnosticsLogLines()
        let lastMerge = lines.last { $0.contains("[Ensembles] Merge changes saved") }
        let lastError = lines.last { line in
            line.contains("[Ensembles] Encountered error") || line.contains("[Ensembles] Forced detach")
        }
        let lastManualCompletion = lines.last { line in
            line.contains("Manual sync completed") || line.contains("Manual sync transferred changes") || line.contains("Manual sync stopped with no changes")
        }

        var summary = ["lastMergeSaved: \(lastMerge ?? "none")"]
        summary.append("lastSyncError: \(lastError ?? "none")")
        summary.append("lastManualSyncResult: \(lastManualCompletion ?? "none")")
        return summary
    }

    private static func diagnosticsLogLines() -> [String] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ["- unavailable: documents directory not found"]
        }

        let logURL = documentsDirectory.appendingPathComponent("CloudKitDiagnostics.log")
        guard let data = try? Data(contentsOf: logURL),
              let content = String(data: data, encoding: .utf8) else {
            return ["- unavailable: CloudKitDiagnostics.log not found"]
        }

        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private static func countFolders(in project: Project) -> Int {
        var count = 0
        for folder in project.folders ?? [] {
            count += countFolderTree(folder)
        }
        return count
    }

    private static func stableProjectFingerprint(for project: Project) -> String {
        let folderCount = countFolders(in: project)
        let textFileCount = countTextFiles(in: project)
        let versionCount = countVersions(in: project)
        let submittedFileCount = countSubmittedFiles(in: project)
        let submissionCount = countSubmissions(in: project)

        var parts: [String] = []
        parts.reserveCapacity(32)
        parts.append(project.id.uuidString)
        parts.append(project.name ?? "")
        parts.append(project.typeRaw ?? "")
        parts.append(project.isTrashed ? "1" : "0")
        parts.append(project.creationDate?.timeIntervalSince1970.description ?? "")
        parts.append(project.modifiedDate?.timeIntervalSince1970.description ?? "")
        parts.append(String(project.details?.count ?? 0))
        parts.append(String(project.notes?.count ?? 0))
        parts.append(String(project.author?.count ?? 0))
        parts.append(project.fictionClassRaw ?? "")
        parts.append(project.storyStructureRaw ?? "")
        parts.append(project.dramaScriptTypeRaw ?? "")
        parts.append(String(project.manuscriptSettingsData?.count ?? 0))
        parts.append(String(project.tocSettingsData?.count ?? 0))
        parts.append(String(project.publications?.count ?? 0))
        parts.append(String(project.submissions?.count ?? 0))
        parts.append(String(project.submittedFiles?.count ?? 0))
        parts.append(String(project.poetryCollections?.count ?? 0))
        parts.append(String(project.scenes?.count ?? 0))
        parts.append(String(project.chapters?.count ?? 0))
        parts.append(String(project.acts?.count ?? 0))
        parts.append(String(project.sections?.count ?? 0))
        parts.append(String(project.books?.count ?? 0))
        parts.append(String(project.characters?.count ?? 0))
        parts.append(String(project.locations?.count ?? 0))
        parts.append(String(project.plotElements?.count ?? 0))
        parts.append(String(folderCount))
        parts.append(String(textFileCount))
        parts.append(String(versionCount))
        parts.append(String(submittedFileCount))
        parts.append(String(submissionCount))

        let canonical = parts.joined(separator: "|")

        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static func countTextFiles(in project: Project) -> Int {
        var count = 0
        for folder in project.folders ?? [] {
            count += countTextFilesInFolderTree(folder)
        }
        return count
    }

    private static func allTextFiles(in project: Project) -> [TextFile] {
        var files: [TextFile] = []
        for folder in project.folders ?? [] {
            files.append(contentsOf: textFilesInFolderTree(folder))
        }
        return files
    }

    private static func sortScenesByOrderThenName(_ lhs: StoryScene, _ rhs: StoryScene) -> Bool {
        let lhsOrder = lhs.userOrder ?? Int.max
        let rhsOrder = rhs.userOrder ?? Int.max
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }
        return (lhs.name ?? "") < (rhs.name ?? "")
    }

    private static func sceneTextFilePlacement(_ textFile: TextFile?) -> String {
        guard let textFile else { return "missing-text-file" }
        if let trashItem = textFile.trashItem {
            let originalFolder = trashItem.originalFolder?.name ?? "unknown"
            return "in-trash(originalFolder=\(originalFolder))"
        }
        if let parentFolder = textFile.parentFolder {
            return "in-folder(\(parentFolder.name ?? "Untitled"))"
        }
        return "detached-no-folder"
    }

    private static func countVersions(in project: Project) -> Int {
        var count = 0
        for folder in project.folders ?? [] {
            count += countVersionsInFolderTree(folder)
        }
        return count
    }

    private static func countSubmittedFiles(in project: Project) -> Int {
        let publications = project.publications ?? []
        var count = 0
        for publication in publications {
            for submission in publication.submissions ?? [] {
                count += submission.submittedFiles?.count ?? 0
            }
        }
        return count
    }

    private static func countSubmissions(in project: Project) -> Int {
        let publications = project.publications ?? []
        var count = 0
        for publication in publications {
            count += publication.submissions?.count ?? 0
        }
        return count
    }

    private static func countFolderTree(_ folder: Folder) -> Int {
        var count = 1
        for child in folder.folders ?? [] {
            count += countFolderTree(child)
        }
        return count
    }

    private static func countTextFilesInFolderTree(_ folder: Folder) -> Int {
        var count = folder.textFiles?.count ?? 0
        for child in folder.folders ?? [] {
            count += countTextFilesInFolderTree(child)
        }
        return count
    }

    private static func textFilesInFolderTree(_ folder: Folder) -> [TextFile] {
        var files = folder.textFiles ?? []
        for child in folder.folders ?? [] {
            files.append(contentsOf: textFilesInFolderTree(child))
        }
        return files
    }

    private static func countVersionsInFolderTree(_ folder: Folder) -> Int {
        var count = 0
        for file in folder.textFiles ?? [] {
            count += file.versions?.count ?? 0
        }
        for child in folder.folders ?? [] {
            count += countVersionsInFolderTree(child)
        }
        return count
    }
}