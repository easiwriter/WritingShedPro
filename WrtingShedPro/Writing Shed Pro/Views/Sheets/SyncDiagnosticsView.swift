import SwiftData
import SwiftUI
import CloudKit
import Ensembles
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
    @State private var detachedSceneCount = 0
    @State private var tombstoneCount = 0
    @State private var snapshotCopied = false
    @State private var syncStatusMessage = ""
    @State private var showLocalResetConfirmation = false
    @State private var showForceRebaseConfirmation = false
    @State private var showDeleteEnsemblesZoneConfirmation = false
    @State private var localResetQueued = false
    @State private var ensemblesZoneDeletedThisSession = false
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
                "Force this device to rebuild the sync baseline?",
                isPresented: $showForceRebaseConfirmation,
                titleVisibility: .visible,
                actions: forceRebaseDialogActions,
                message: forceRebaseDialogMessage
            )
            .confirmationDialog(
                "Delete the Ensembles cloud zone?",
                isPresented: $showDeleteEnsemblesZoneConfirmation,
                titleVisibility: .visible,
                actions: deleteZoneDialogActions,
                message: deleteZoneDialogMessage
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
                showForceRebaseConfirmation = true
            } label: {
                Label("Force Rebase This Device to Cloud", systemImage: "arrow.triangle.branch")
            }
            .disabled(Write_App.activeEnsemblesContainer == nil || projectCount == 0 || ensemblesZoneDeletedThisSession)

            Button(role: .destructive) {
                showDeleteEnsemblesZoneConfirmation = true
            } label: {
                Label("Delete Ensembles Cloud Zone", systemImage: "icloud.slash")
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

            if ensemblesZoneDeletedThisSession {
                Text("Ensembles cloud zone was deleted in this app session. Quit and relaunch this source device before attempting force rebase.")
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

    @ViewBuilder
    private func forceRebaseDialogActions() -> some View {
        Button("Force Rebase From This Device", role: .destructive) {
            Task { await forceRebaseFromThisDevice() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func forceRebaseDialogMessage() -> some View {
        Text("Use this only on a device that already shows the complete project list and is attached to Ensembles. If you just deleted the Ensembles cloud zone, quit and relaunch this source device first.")
    }

    @ViewBuilder
    private func deleteZoneDialogActions() -> some View {
        Button("Delete Ensembles Cloud Zone", role: .destructive) {
            Task { await deleteEnsemblesCloudZoneFromSourceDevice() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func deleteZoneDialogMessage() -> some View {
        Text("Use this only on the source device that visibly has the complete project list. Do not run this on the empty Mac. After deletion, quit and relaunch this source device, then force rebase from it so Ensembles recreates a clean cloud state.")
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
    private func forceRebaseFromThisDevice() async {
        guard projectCount > 0 else {
            syncStatusMessage = "Force rebase blocked: this device has no local projects."
            Write_App.logErrorToFile("⚠️ [Ensembles] Force rebase blocked because local project count is zero")
            return
        }

        guard let container = Write_App.activeEnsemblesContainer else { return }
        guard !ensemblesZoneDeletedThisSession else {
            syncStatusMessage = "Force rebase blocked: quit and relaunch this source device after deleting the Ensembles zone."
            Write_App.logErrorToFile("⚠️ [Ensembles] Force rebase blocked because zone was deleted in this app session")
            return
        }
        guard container.isAttached else {
            syncStatusMessage = "Force rebase blocked: this device is not attached to Ensembles. Quit and relaunch, then confirm it is attached before rebasing."
            Write_App.logErrorToFile("⚠️ [Ensembles] Force rebase blocked because container is detached")
            return
        }
        guard createLocalSafetyBackup(reason: "force-rebase") != nil else {
            syncStatusMessage = "Force rebase blocked: local safety backup failed. Copy diagnostics before trying again."
            return
        }
        syncStatusMessage = "Force rebasing this device to cloud..."
        Write_App.logToFile("🔁 [Ensembles] Force rebase started from diagnostics (projects=\(projectCount), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")

        do {
            try await container.ensemble.sync(options: .forceRebase)
            syncStatusMessage = "Force rebase completed at \(Date().formatted(date: .omitted, time: .standard))"
            Write_App.logToFile("✅ [Ensembles] Force rebase completed from diagnostics")
        } catch {
            syncStatusMessage = "Force rebase failed. Copy diagnostics."
            Write_App.logErrorToFile("❌ [Ensembles] Force rebase failed from diagnostics: \(Write_App.detailedErrorDescription(error))")
        }

        refreshCounts()
    }

    @MainActor
    private func deleteEnsemblesCloudZoneFromSourceDevice() async {
        guard projectCount > 0 else {
            syncStatusMessage = "Zone delete blocked: this device has no local projects."
            Write_App.logErrorToFile("⚠️ [Ensembles] Cloud zone delete blocked because local project count is zero")
            return
        }

        guard createLocalSafetyBackup(reason: "delete-ensembles-zone") != nil else {
            syncStatusMessage = "Zone delete blocked: local safety backup failed. Copy diagnostics before trying again."
            return
        }

        syncStatusMessage = "Deleting Ensembles CloudKit zone..."
        Write_App.logToFile("🧨 [Ensembles] Ensembles CloudKit zone delete started from diagnostics (projects=\(projectCount))")

        do {
            try await deleteEnsemblesCloudKitZone()
            ensemblesZoneDeletedThisSession = true
            syncStatusMessage = "Ensembles cloud zone deleted. Quit and relaunch this source device, then force rebase from it."
            Write_App.logToFile("✅ [Ensembles] Ensembles CloudKit zone deleted from diagnostics")
        } catch {
            syncStatusMessage = "Ensembles cloud zone delete failed. Copy diagnostics."
            Write_App.logErrorToFile("❌ [Ensembles] Ensembles CloudKit zone delete failed: \(Write_App.detailedErrorDescription(error))")
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

    private func deleteEnsemblesCloudKitZone() async throws {
        let database = CKContainer(identifier: "iCloud.com.appworks.writingshedpro").privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.mentalfaculty.ensembles.zone.schema2", ownerName: CKCurrentUserDefaultName)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [zoneID])
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
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
        syncStatusMessage = "Sync completed at \(Date().formatted(date: .omitted, time: .standard)) (didSync=\(didSync))"
        Write_App.logToFile("✅ [Ensembles] Manual sync completed from diagnostics (didSync=\(didSync), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
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
        detachedSceneCount = countDetachedScenes(in: freshContext)
        tombstoneCount = DeduplicationService.tombstoneCount
        lastRefreshed = Date()
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
