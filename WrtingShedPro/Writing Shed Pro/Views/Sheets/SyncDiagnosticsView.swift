import SwiftData
import SwiftUI
import CloudKit
import Ensembles
import EnsemblesCloudKit
#if canImport(UIKit)
import UIKit
#endif

struct SyncDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var projectCount = 0
    @State private var activeProjectCount = 0
    @State private var trashedProjectCount = 0
    @State private var publicationCount = 0
    @State private var folderCount = 0
    @State private var fileCount = 0
    @State private var versionCount = 0
    @State private var styleSheetCount = 0
    @State private var textStyleCount = 0
    @State private var imageStyleCount = 0
    @State private var poetryFormCount = 0
    @State private var poetryCollectionCount = 0
    @State private var duplicateProjectCount = 0
    @State private var exactIDDuplicateCount = 0
    @State private var duplicateTemplateFolderCount = 0
    @State private var detachedSceneCount = 0
    @State private var tombstoneCount = 0
    @State private var snapshotCopied = false
    @State private var syncStatusMessage = ""
    @State private var showLocalResetConfirmation = false
    @State private var showRemoveEnsemblesCloudDataConfirmation = false
    @State private var localResetQueued = false
    @State private var ensemblesCloudDataRemovedThisSession = false
    @State private var lastSafetyBackupName: String?
    @State private var lastRefreshed: Date?

    var body: some View {
        NavigationStack {
            diagnosticsForm
            .navigationTitle("Sync & Data Health")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                refreshCounts()
            }
            .confirmationDialog(
                "Reset this device's local sync data?",
                isPresented: $showLocalResetConfirmation,
                titleVisibility: .visible,
                actions: localResetDialogActions,
                message: localResetDialogMessage
            )
            .confirmationDialog(
                "Remove the Ensembles cloud data?",
                isPresented: $showRemoveEnsemblesCloudDataConfirmation,
                titleVisibility: .visible,
                actions: removeCloudDataDialogActions,
                message: removeCloudDataDialogMessage
            )
        }
    }

    private var diagnosticsForm: some View {
        Form {
            syncBackendSection
            localDataSection
            stylesSection
            dataHealthSection
            supportSection
        }
    }

    private var syncBackendSection: some View {
        Section("Sync Backend") {
            LabeledContent("Backend", value: "Ensembles")
            LabeledContent("Cloud Container", value: "iCloud.com.appworks.writingshedpro")
            LabeledContent("Container Active", value: Write_App.activeEnsemblesContainer == nil ? "No" : "Yes")
            LabeledContent("First Sync This Launch", value: Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch ? "Yes" : "No")

            Button {
                Task { await runManualSync() }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(Write_App.activeEnsemblesContainer == nil)

            Button {
                Task { await verifyEnsemblesZoneContent() }
            } label: {
                Label("Verify Ensembles Zone", systemImage: "icloud.and.arrow.down")
            }

            Button {
                createLocalSafetyBackup(reason: "manual")
            } label: {
                Label("Create Local Safety Backup", systemImage: "externaldrive.badge.plus")
            }

            Button(role: .destructive) {
                showRemoveEnsemblesCloudDataConfirmation = true
            } label: {
                Label("Remove Ensembles Cloud Data", systemImage: "icloud.slash")
            }
            .disabled(projectCount == 0)

            Button(role: .destructive) {
                showLocalResetConfirmation = true
            } label: {
                Label("Reset This Device on Next Launch", systemImage: "arrow.clockwise.icloud")
            }

            if localResetQueued {
                Text("Local reset queued. Quit and relaunch this Mac app to back up the local store and re-import from sync.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let lastSafetyBackupName {
                Text("Safety backup created: \(lastSafetyBackupName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if ensemblesCloudDataRemovedThisSession {
                Text("Ensembles cloud data was removed in this app session. Wait a few minutes for CloudKit propagation, then sync this complete source device first.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !syncStatusMessage.isEmpty {
                Text(syncStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var localDataSection: some View {
        Section("Local Data") {
            LabeledContent("Projects", value: "\(projectCount)")
            LabeledContent("Active Projects", value: "\(activeProjectCount)")
            LabeledContent("Trashed Projects", value: "\(trashedProjectCount)")
            LabeledContent("Publications", value: "\(publicationCount)")
            LabeledContent("Folders", value: "\(folderCount)")
            LabeledContent("Files", value: "\(fileCount)")
            LabeledContent("Versions", value: "\(versionCount)")
            LabeledContent("Poetry Collections", value: "\(poetryCollectionCount)")
        }
    }

    private var stylesSection: some View {
        Section("Styles") {
            LabeledContent("Style Sheets", value: "\(styleSheetCount)")
            LabeledContent("Text Styles", value: "\(textStyleCount)")
            LabeledContent("Image Styles", value: "\(imageStyleCount)")
            LabeledContent("Poetry Forms", value: "\(poetryFormCount)")
        }
    }

    private var dataHealthSection: some View {
        Section("Data Health") {
            LabeledContent("Duplicate Projects", value: "\(duplicateProjectCount)")
            LabeledContent("Exact-ID Duplicate Records", value: "\(exactIDDuplicateCount)")
            LabeledContent("Duplicate Template Folders", value: "\(duplicateTemplateFolderCount)")
            LabeledContent("Detached Scene Rows", value: "\(detachedSceneCount)")
            LabeledContent("Zombie Tombstones", value: "\(tombstoneCount)")

            Button {
                refreshCounts()
            } label: {
                Label("Refresh Checks", systemImage: "arrow.clockwise")
            }

            if tombstoneCount > 0 {
                Button(role: .destructive) {
                    DeduplicationService.clearAllTombstones()
                    refreshCounts()
                } label: {
                    Label("Clear Tombstones", systemImage: "trash")
                }
            }

            if exactIDDuplicateCount > 0 {
                Button(role: .destructive) {
                    cleanupExactIDDuplicates()
                } label: {
                    Label("Clean Exact-ID Duplicates", systemImage: "square.stack.3d.up.slash")
                }
                .disabled(!isEnsemblesIdle)
            }

            if duplicateTemplateFolderCount > 0 {
                Button(role: .destructive) {
                    cleanupDuplicateTemplateFolders()
                } label: {
                    Label("Clean Duplicate Template Folders", systemImage: "folder.badge.minus")
                }
                .disabled(!isEnsemblesIdle)
            }

            if !isEnsemblesIdle && (exactIDDuplicateCount > 0 || duplicateTemplateFolderCount > 0) {
                Text("Cleanup is available once Ensembles activity is none.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if detachedSceneCount > 0 {
                Button(role: .destructive) {
                    trashDetachedScenes()
                } label: {
                    Label("Trash Detached Scene Rows", systemImage: "rectangle.stack.badge.minus")
                }
            }

            if let lastRefreshed {
                Text("Last refreshed \(lastRefreshed.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var supportSection: some View {
        Section("Support") {
            Button {
                copyDiagnosticsSnapshot()
            } label: {
                Label(snapshotCopied ? "Snapshot Copied" : "Copy Diagnostics Snapshot", systemImage: snapshotCopied ? "checkmark" : "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func localResetDialogActions() -> some View {
        Button("Detach, Back Up and Reset on Next Launch", role: .destructive) {
            Task { await detachAndQueueLocalReset() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func localResetDialogMessage() -> some View {
        Text("This only affects this Mac. The app will detach this Mac from Ensembles, then on next launch back up its local SQLite store and Ensembles event cache, remove the local copies, and re-import from the sync cloud. Do not use this if this Mac has unsynced work that is not on your iOS devices.")
    }

    private var isEnsemblesIdle: Bool {
        guard let container = Write_App.activeEnsemblesContainer else { return true }
        return container.isAttached && String(describing: container.currentActivity) == "none"
    }

    @ViewBuilder
    private func removeCloudDataDialogActions() -> some View {
        Button("Remove Ensembles Cloud Data", role: .destructive) {
            Task { await removeEnsemblesCloudDataFromSourceDevice() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func removeCloudDataDialogMessage() -> some View {
        Text("Use this only on the source device that visibly has the complete project list, after all other devices have been detached or kept offline. This first detaches this device, then removes the shared Ensembles cloud history. Wait a few minutes, then sync this source device first to seed clean cloud data.")
    }

    @MainActor
    private func detachAndQueueLocalReset() async {
        if let container = Write_App.activeEnsemblesContainer, container.isAttached {
            let activity = String(describing: container.currentActivity)
            guard activity == "none" else {
                UserDefaults.standard.set(true, forKey: Write_App.detachLocalEnsemblesBeforeResetOnNextLaunchKey)
                localResetQueued = true
                syncStatusMessage = "Detach queued. Quit and relaunch this Mac app; after detach completes, quit and relaunch once more for the local reset."
                Write_App.logToFile("🔌 [Ensembles] Queued launch-time detach before local reset because activity=\(activity)")
                return
            }

            syncStatusMessage = "Detaching this Mac from sync..."
            Write_App.logToFile("🔌 [Ensembles] Detach requested before local reset (activity=\(activity))")
            do {
                try await container.detach()
                Write_App.logToFile("✅ [Ensembles] Detached this device before local reset")
            } catch {
                Write_App.logErrorToFile("❌ [Ensembles] Detach before local reset failed: \(Write_App.detailedErrorDescription(error))")
                syncStatusMessage = "Detach failed; reset was not queued. Copy diagnostics and try again after sync activity stops."
                return
            }
        }

        UserDefaults.standard.set(true, forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey)
        localResetQueued = true
        syncStatusMessage = "Local reset queued. Quit and relaunch this Mac app."
    }

    @MainActor
    private func verifyEnsemblesZoneContent() async {
        syncStatusMessage = "Checking Ensembles CloudKit zone..."
        do {
            let summary = try await fetchEnsemblesZoneSummary()
            syncStatusMessage = summary
            Write_App.logToFile("☁️ [Ensembles] Zone verification: \(summary)")
        } catch {
            let detail = Write_App.detailedErrorDescription(error)
            syncStatusMessage = "Ensembles zone check failed. Copy diagnostics."
            Write_App.logErrorToFile("❌ [Ensembles] Zone verification failed: \(detail)")
        }
    }

    @MainActor
    private func removeEnsemblesCloudDataFromSourceDevice() async {
        guard projectCount > 0 else {
            syncStatusMessage = "Cloud data removal blocked: this device has no local projects."
            Write_App.logErrorToFile("⚠️ [Ensembles] Cloud data removal blocked because local project count is zero")
            return
        }

        guard createLocalSafetyBackup(reason: "remove-ensembles-cloud-data") != nil else {
            syncStatusMessage = "Cloud data removal blocked: local safety backup failed. Copy diagnostics before trying again."
            return
        }

        if let container = Write_App.activeEnsemblesContainer, container.isAttached {
            let activity = String(describing: container.currentActivity)
            guard activity == "none" else {
                syncStatusMessage = "Cloud data removal blocked: Ensembles is busy (activity=\(activity)). Try again when activity is none."
                Write_App.logErrorToFile("⚠️ [Ensembles] Cloud data removal blocked because source device activity=\(activity)")
                return
            }

            syncStatusMessage = "Detaching this source device before removing cloud data..."
            Write_App.logToFile("🔌 [Ensembles] Source detach before cloud data removal started (isAttached=\(container.isAttached), activity=\(activity))")
            do {
                try await container.detach()
                Write_App.logToFile("✅ [Ensembles] Source device detached before cloud data removal")
            } catch {
                syncStatusMessage = "Cloud data removal blocked: detach failed. Copy diagnostics and try again after sync activity stops."
                Write_App.logErrorToFile("❌ [Ensembles] Source detach before cloud data removal failed: \(Write_App.detailedErrorDescription(error))")
                return
            }
        }

        syncStatusMessage = "Removing Ensembles cloud data..."
        Write_App.logToFile("🧨 [Ensembles] Ensembles cloud data removal started from diagnostics (projects=\(projectCount))")

        do {
            try await removeEnsemblesCloudData()
            ensemblesCloudDataRemovedThisSession = true
            syncStatusMessage = "Ensembles cloud data removed. Wait a few minutes, then sync this complete source device first."
            Write_App.logToFile("✅ [Ensembles] Ensembles cloud data removed from diagnostics")
        } catch {
            syncStatusMessage = "Ensembles cloud data removal failed. Copy diagnostics."
            Write_App.logErrorToFile("❌ [Ensembles] Ensembles cloud data removal failed: \(Write_App.detailedErrorDescription(error))")
        }
    }

    @discardableResult
    private func createLocalSafetyBackup(reason: String) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = URL.documentsDirectory
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupDirectory = documentsDirectory.appending(path: "SyncSafetyBackup_\(timestamp)", directoryHint: .isDirectory)

        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            Write_App.logErrorToFile("❌ [Ensembles] Safety backup directory failed before \(reason): \(error.localizedDescription)")
            return nil
        }

        let storeURL = documentsDirectory.appending(path: "writingshed.sqlite")
        let pathsToCopy = [
            storeURL,
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"),
            documentsDirectory.appending(path: "EnsemblesEventData", directoryHint: .isDirectory)
        ]

        var copiedCount = 0
        for sourceURL in pathsToCopy where fileManager.fileExists(atPath: sourceURL.path) {
            let destinationURL = backupDirectory.appending(path: sourceURL.lastPathComponent, directoryHint: sourceURL.hasDirectoryPath ? .isDirectory : .notDirectory)
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                copiedCount += 1
            } catch {
                Write_App.logErrorToFile("❌ [Ensembles] Safety backup failed copying \(sourceURL.lastPathComponent) before \(reason): \(error.localizedDescription)")
                return nil
            }
        }

        guard copiedCount > 0 else {
            Write_App.logErrorToFile("❌ [Ensembles] Safety backup found no local files to copy before \(reason)")
            return nil
        }

        lastSafetyBackupName = backupDirectory.lastPathComponent
        Write_App.logToFile("💾 [Ensembles] Safety backup created before \(reason): \(backupDirectory.lastPathComponent) files=\(copiedCount)")
        return backupDirectory
    }

    private func removeEnsemblesCloudData() async throws {
        let cloudFileSystem = CloudKitFileSystem(
            privateDatabaseForUbiquityContainerIdentifier: "iCloud.com.appworks.writingshedpro",
            schemaVersion: .v2
        )
        try await CoreDataEnsemble.removeEnsemble(
            withIdentifier: "WritingShedProConfiguration",
            in: cloudFileSystem
        )
    }

    private func fetchEnsemblesZoneSummary() async throws -> String {
        let database = CKContainer(identifier: "iCloud.com.appworks.writingshedpro").privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.mentalfaculty.ensembles.zone.schema2", ownerName: CKCurrentUserDefaultName)

        return try await withCheckedThrowingContinuation { continuation in
            var recordTypeCounts: [String: Int] = [:]
            var deletedTypeCounts: [String: Int] = [:]
            var sampleRecordNames: [String] = []
            var sampleRecordDetails: [String] = []
            var didResume = false

            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = nil

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration]
            )

            operation.recordWasChangedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    recordTypeCounts[record.recordType, default: 0] += 1
                    if sampleRecordNames.count < 8 {
                        sampleRecordNames.append("\(record.recordType):\(recordID.recordName)")
                    }
                    if sampleRecordDetails.count < 8 {
                        sampleRecordDetails.append(describeCloudKitRecord(record))
                    }
                case .failure:
                    recordTypeCounts["<record fetch failed>", default: 0] += 1
                }
            }

            operation.recordWithIDWasDeletedBlock = { _, recordType in
                deletedTypeCounts[recordType, default: 0] += 1
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success:
                    let totalRecords = recordTypeCounts.values.reduce(0, +)
                    let totalDeleted = deletedTypeCounts.values.reduce(0, +)
                    let recordSummary = recordTypeCounts
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value)" }
                        .joined(separator: ", ")
                    let deletedSummary = deletedTypeCounts
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value)" }
                        .joined(separator: ", ")
                    let samples = sampleRecordNames.joined(separator: ", ")
                    let details = sampleRecordDetails.joined(separator: " || ")
                    continuation.resume(returning: "records=\(totalRecords) [\(recordSummary.isEmpty ? "none" : recordSummary)] deleted=\(totalDeleted) [\(deletedSummary.isEmpty ? "none" : deletedSummary)] samples=[\(samples.isEmpty ? "none" : samples)] details=[\(details.isEmpty ? "none" : details)]")
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func describeCloudKitRecord(_ record: CKRecord) -> String {
        let fieldDescriptions = record.allKeys()
            .sorted()
            .map { key -> String in
                guard let value = record[key] else { return "\(key)=nil" }
                if let asset = value as? CKAsset {
                    let size = asset.fileURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? NSNumber }?.intValue
                    return "\(key)=CKAsset(\(size.map(String.init) ?? "unknown") bytes)"
                }
                if let data = value as? Data {
                    return "\(key)=Data(\(data.count) bytes)"
                }
                if let string = value as? String {
                    return "\(key)=String(\(string.count) chars)"
                }
                if let number = value as? NSNumber {
                    return "\(key)=Number(\(number))"
                }
                if let date = value as? Date {
                    return "\(key)=Date(\(date.formatted(date: .numeric, time: .standard)))"
                }
                if let values = value as? [Any] {
                    return "\(key)=Array(\(values.count))"
                }
                return "\(key)=\(type(of: value))"
            }
            .joined(separator: ",")

        return "\(record.recordID.recordName){\(fieldDescriptions.isEmpty ? "no-fields" : fieldDescriptions)}"
    }

    @MainActor
    private func runManualSync() async {
        guard let container = Write_App.activeEnsemblesContainer else { return }
        syncStatusMessage = "Syncing..."
        Write_App.logToFile("🔄 [Ensembles] Manual sync started from diagnostics (isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        let didSync = await container.sync()
        if didSync {
            Write_App.recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: "diagnostics manual sync")
            syncStatusMessage = "Sync transferred changes at \(Date().formatted(date: .omitted, time: .standard))."
            Write_App.logToFile("✅ [Ensembles] Manual sync transferred changes from diagnostics (didSync=true, isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        } else {
            syncStatusMessage = "Sync stopped with no changes reported. If this device is stale, copy diagnostics."
            Write_App.logToFile("⚠️ [Ensembles] Manual sync stopped with no changes from diagnostics (didSync=false, isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        }
        refreshCounts()
    }

    @MainActor
    private func refreshCounts() {
        let freshContext = ModelContext(modelContext.container)

        let projects = (try? freshContext.fetch(FetchDescriptor<Project>())) ?? []
        projectCount = projects.count
        activeProjectCount = projects.filter { !$0.isTrashed }.count
        trashedProjectCount = projects.filter(\.isTrashed).count

        publicationCount = fetchCount(Publication.self, in: freshContext)
        folderCount = fetchCount(Folder.self, in: freshContext)
        fileCount = fetchCount(TextFile.self, in: freshContext)
        versionCount = fetchCount(Version.self, in: freshContext)
        styleSheetCount = fetchCount(StyleSheet.self, in: freshContext)
        textStyleCount = fetchCount(TextStyleModel.self, in: freshContext)
        imageStyleCount = fetchCount(ImageStyle.self, in: freshContext)
        poetryFormCount = fetchCount(PoetryFormModel.self, in: freshContext)
        poetryCollectionCount = fetchCount(PoetryCollection.self, in: freshContext)
        duplicateProjectCount = DeduplicationService.countDuplicateProjects(context: freshContext)
        exactIDDuplicateCount = DeduplicationService.countExactIDDuplicateRecords(context: freshContext)
        duplicateTemplateFolderCount = DeduplicationService.countDuplicateTemplateFolderRecords(context: freshContext)
        detachedSceneCount = countDetachedScenes(in: freshContext)
        tombstoneCount = DeduplicationService.tombstoneCount
        lastRefreshed = Date()
    }

    @MainActor
    private func cleanupExactIDDuplicates() {
        let freshContext = ModelContext(modelContext.container)
        let result = DeduplicationService.cleanupExactIDDuplicates(context: freshContext)
        if result.recordsRemoved > 0 {
            syncStatusMessage = "Removed \(result.recordsRemoved) exact-ID duplicate record\(result.recordsRemoved == 1 ? "" : "s") across \(result.groupsAffected) group\(result.groupsAffected == 1 ? "" : "s")."
        } else if let error = result.errors.first {
            syncStatusMessage = error
        } else {
            syncStatusMessage = "No exact-ID duplicate records found."
        }
        refreshCounts()
    }

    @MainActor
    private func cleanupDuplicateTemplateFolders() {
        let freshContext = ModelContext(modelContext.container)
        let result = DeduplicationService.cleanupDuplicateTemplateFolders(context: freshContext)
        if result.recordsRemoved > 0 {
            syncStatusMessage = "Removed \(result.recordsRemoved) duplicate template folder\(result.recordsRemoved == 1 ? "" : "s")."
        } else if let error = result.errors.first {
            syncStatusMessage = error
        } else if result.skippedNonEmptyGroups > 0 {
            syncStatusMessage = "Skipped \(result.skippedNonEmptyGroups) non-empty duplicate template folder group\(result.skippedNonEmptyGroups == 1 ? "" : "s")."
        } else {
            syncStatusMessage = "No duplicate template folders found."
        }
        refreshCounts()
    }

    @MainActor
    private func trashDetachedScenes() {
        let freshContext = ModelContext(modelContext.container)
        let scenes = detachedScenes(in: freshContext)
        let now = Date()

        for scene in scenes {
            scene.moveToTrash()
            scene.modifiedDate = now
            scene.project?.modifiedDate = now
            scene.textFile?.modifiedDate = now
        }

        do {
            try EnsemblesSaveGate.save(freshContext, reason: "sync-diagnostics-trash-detached-scenes")
            syncStatusMessage = "Trashed \(scenes.count) detached scene row\(scenes.count == 1 ? "" : "s")."
        } catch {
            syncStatusMessage = "Failed to trash detached scene rows: \(error.localizedDescription)"
        }

        refreshCounts()
    }

    private func countDetachedScenes(in context: ModelContext) -> Int {
        detachedScenes(in: context).count
    }

    private func detachedScenes(in context: ModelContext) -> [StoryScene] {
        let scenes = (try? context.fetch(FetchDescriptor<StoryScene>())) ?? []
        return scenes.filter { scene in
            !scene.isTrashed && scene.textFile != nil && scene.textFile?.parentFolder == nil
        }
    }

    private func fetchCount<T: PersistentModel>(_ type: T.Type, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }

    private func copyDiagnosticsSnapshot() {
        let snapshot = SupportDiagnosticsSnapshotBuilder.buildSnapshot(modelContext: modelContext)
        #if canImport(UIKit)
        UIPasteboard.general.string = snapshot
        #endif

        snapshotCopied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            snapshotCopied = false
        }
    }
}
