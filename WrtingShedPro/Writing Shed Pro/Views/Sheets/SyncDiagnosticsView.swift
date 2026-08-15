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
    @State private var showRemoveLegacyCloudDataConfirmation = false
    @State private var localResetQueued = false
    @State private var localRecoveryModeQueued = UserDefaults.standard.bool(forKey: Write_App.localRecoveryModeOnNextLaunchKey)
    @State private var ensemblesCloudDataRemovedThisSession = false
    @State private var lastSafetyBackupName: String?
    @State private var lastRefreshed: Date?
    @State private var diagnosticsRefreshID = UUID()

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
                "Remove all Writing Shed Pro sync cloud data?",
                isPresented: $showRemoveEnsemblesCloudDataConfirmation,
                titleVisibility: .visible,
                actions: removeCloudDataDialogActions,
                message: removeCloudDataDialogMessage
            )
            .confirmationDialog(
                "Remove the legacy Core Data CloudKit zone?",
                isPresented: $showRemoveLegacyCloudDataConfirmation,
                titleVisibility: .visible,
                actions: removeLegacyCloudDataDialogActions,
                message: removeLegacyCloudDataDialogMessage
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
        .id(diagnosticsRefreshID)
    }

    private var syncBackendSection: some View {
        Section("Sync Backend") {
            LabeledContent("Backend", value: "Ensembles")
            LabeledContent("Cloud Container", value: "iCloud.com.appworks.writingshedpro")
            LabeledContent("Container Active", value: Write_App.activeEnsemblesContainer == nil ? "No" : "Yes")
            LabeledContent("Seed Policy", value: Write_App.currentEnsemblesSeedPolicy)
            if let container = Write_App.activeEnsemblesContainer {
                LabeledContent("Attached", value: container.isAttached ? "Yes" : "No")
                LabeledContent("Sync Suspended", value: container.isSyncSuspended ? "Yes" : "No")
                LabeledContent("Current Activity", value: String(describing: container.currentActivity))
            } else {
                LabeledContent("Attached", value: "No container")
                LabeledContent("Sync Suspended", value: "No container")
                LabeledContent("Current Activity", value: "No container")
            }
            LabeledContent("First Sync This Launch", value: Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch ? "Yes" : "No")
            LabeledContent("Data Observed This Launch", value: Write_App.hasObservedEnsemblesDataThisLaunch ? "Yes" : "No")
            LabeledContent("Partial Store Observed", value: Write_App.hasObservedPartialEnsemblesStoreThisLaunch ? "Yes" : "No")
            LabeledContent("Local Recovery Mode", value: Write_App.isLocalRecoveryModeEnabled ? "Yes" : "No")
            LabeledContent("Local Reset Queued", value: UserDefaults.standard.bool(forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey) ? "Yes" : "No")

            Button {
                Task { await runManualSync() }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(Write_App.activeEnsemblesContainer == nil)

            Button {
                Task { await verifyEnsemblesZoneContent() }
            } label: {
                Label("Verify Sync Zones", systemImage: "icloud.and.arrow.down")
            }

            Button(role: .destructive) {
                showRemoveLegacyCloudDataConfirmation = true
            } label: {
                Label("Remove Legacy Core Data Zone Only", systemImage: "icloud.slash")
            }

            Button {
                createLocalSafetyBackup(reason: "manual")
            } label: {
                Label("Create Local Safety Backup", systemImage: "externaldrive.badge.plus")
            }

            Button(role: .destructive) {
                showRemoveEnsemblesCloudDataConfirmation = true
            } label: {
                Label(Write_App.activeEnsemblesContainer == nil ? "Remove All Sync Cloud Data (Local Recovery)" : "Remove All Sync Cloud Data", systemImage: "icloud.slash")
            }
            .disabled(projectCount == 0)

            Button(role: .destructive) {
                showLocalResetConfirmation = true
            } label: {
                Label("Reset This Device on Next Launch", systemImage: "arrow.clockwise.icloud")
            }

            Button {
                localRecoveryModeQueued.toggle()
                UserDefaults.standard.set(localRecoveryModeQueued, forKey: Write_App.localRecoveryModeOnNextLaunchKey)
                syncStatusMessage = localRecoveryModeQueued
                    ? "Local Recovery Mode enabled. Quit and relaunch; sync will not start."
                    : "Local Recovery Mode disabled for next launch."
                Write_App.logToFile(localRecoveryModeQueued
                    ? "🛟 [Ensembles] Local Recovery Mode enabled from diagnostics"
                    : "🛟 [Ensembles] Local Recovery Mode disabled from diagnostics")
            } label: {
                Label(localRecoveryModeQueued ? "Disable Local Recovery Mode" : "Enable Local Recovery Mode", systemImage: "wrench.and.screwdriver")
            }

            if localResetQueued {
                Text("Local reset queued. Quit and relaunch this Mac app to back up the local store and re-import from sync.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if localRecoveryModeQueued || Write_App.isLocalRecoveryModeEnabled {
                Text("Local Recovery Mode opens this Mac's local store without starting Ensembles. Use it only while repairing/restoring local data, then disable it before reseeding sync.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let lastSafetyBackupName {
                Text("Safety backup created: \(lastSafetyBackupName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if ensemblesCloudDataRemovedThisSession {
                Text("Both sync zones were removed. This source device's local store is the only source of truth: do not reset it. Keep Local Recovery Mode enabled, wait at least 60 seconds, and verify both zones are absent before reseeding.")
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

            if duplicateProjectCount > 0 {
                Button(role: .destructive) {
                    cleanupDuplicateProjects()
                } label: {
                    Label("Clean Duplicate Projects", systemImage: "rectangle.stack.badge.minus")
                }
                .disabled(!isEnsemblesIdle)
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

            if !isEnsemblesIdle && (duplicateProjectCount > 0 || exactIDDuplicateCount > 0 || duplicateTemplateFolderCount > 0) {
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
        Button("Remove Both Sync Zones", role: .destructive) {
            Task { await removeEnsemblesCloudDataFromSourceDevice() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func removeCloudDataDialogMessage() -> some View {
        if Write_App.activeEnsemblesContainer == nil {
            Text("Use this only during controlled recovery after all other devices are closed. Local Recovery Mode is active, so this will first make a safety backup, permanently delete both sync zones, and remove the old local Ensembles event history. This Mac's rebuilt project store is preserved. Do not reset it after deletion. Wait at least 60 seconds, verify both zones are absent, then disable Local Recovery Mode and relaunch to create a fresh baseline from this Mac.")
        } else {
            Text("Cloud data can only be removed in Local Recovery Mode so automatic sync cannot reattach during recovery. Cancel, enable Local Recovery Mode, then quit and relaunch before trying again.")
        }
    }

    @ViewBuilder
    private func removeLegacyCloudDataDialogActions() -> some View {
        Button("Remove Legacy Zone Only", role: .destructive) {
            Task { await removeLegacyCoreDataCloudZone() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func removeLegacyCloudDataDialogMessage() -> some View {
        Text("This permanently deletes only com.apple.coredata.cloudkit.zone. It does not modify the Ensembles zone or this device's local store. Keep all other Writing Shed Pro devices powered off during this recovery step.")
    }

    @MainActor
    private func detachAndQueueLocalReset() async {
        if projectCount > 0, activeEventStoreObjectChangeCount() == 0 {
            syncStatusMessage = "Local reset blocked: this device has projects, but the active Ensembles event store has no object changes. Create/verify a cloud seed or restore from backup first."
            Write_App.logErrorToFile("⚠️ [Ensembles] Local reset blocked because local projects exist but active event store has zero object changes")
            return
        }

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
    private func activeEventStoreObjectChangeCount() -> Int? {
        guard let container = Write_App.activeEnsemblesContainer else { return nil }
        return try? container.ensemble.coreDataEnsemble.eventStore.countAllObjectChanges()
    }

    @MainActor
    private func verifyEnsemblesZoneContent() async {
        syncStatusMessage = "Checking both sync zones..."
        let ensemblesStatus: String
        do {
            ensemblesStatus = "present (\(try await fetchEnsemblesZoneSummary()))"
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            ensemblesStatus = "absent"
        } catch {
            ensemblesStatus = "check failed: \(Write_App.detailedErrorDescription(error))"
        }

        let legacyStatus = await cloudZoneStatus(zoneName: "com.apple.coredata.cloudkit.zone")
        let summary = "Ensembles zone: \(ensemblesStatus). Legacy Core Data zone: \(legacyStatus)."
        syncStatusMessage = summary
        Write_App.logToFile("☁️ [Sync Zones] \(summary)")
    }

    @MainActor
    private func removeEnsemblesCloudDataFromSourceDevice() async {
        guard Write_App.activeEnsemblesContainer == nil else {
            syncStatusMessage = "Cloud data removal blocked: enable Local Recovery Mode, then quit and relaunch before trying again."
            Write_App.logErrorToFile("⚠️ [Ensembles] Cloud data removal blocked because an active auto-sync container could reattach after removal")
            return
        }

        guard projectCount > 0 else {
            syncStatusMessage = "Cloud data removal blocked: this device has no local projects."
            Write_App.logErrorToFile("⚠️ [Ensembles] Cloud data removal blocked because local project count is zero")
            return
        }

        guard createLocalSafetyBackup(reason: "remove-all-sync-cloud-data") != nil else {
            syncStatusMessage = "Cloud data removal blocked: local safety backup failed. Copy diagnostics before trying again."
            return
        }

        Write_App.logToFile("🛟 [Sync Zones] Removing both sync zones from Local Recovery Mode without attach/detach")

        syncStatusMessage = "Removing both sync cloud zones..."
        Write_App.logToFile("🧨 [Sync Zones] Cloud data removal started from diagnostics (projects=\(projectCount))")

        do {
            try await removeEnsemblesCloudData()
            try prepareLocalEnsemblesHistoryForSourceReseed()
            ensemblesCloudDataRemovedThisSession = true
            syncStatusMessage = "Both sync zones and the backed-up local Ensembles history were removed. The rebuilt project store was preserved. Keep Local Recovery Mode enabled, wait at least 60 seconds, then verify both zones are absent before reseeding."
            Write_App.logToFile("✅ [Sync Zones] Both sync zones removed and local Ensembles history cleared for source reseed")
        } catch {
            syncStatusMessage = "Sync cloud data removal or local reseed preparation failed. Keep Local Recovery Mode enabled and copy diagnostics."
            Write_App.logErrorToFile("❌ [Sync Zones] Cloud data removal failed: \(Write_App.detailedErrorDescription(error))")
        }
    }

    private func prepareLocalEnsemblesHistoryForSourceReseed() throws {
        let eventDataDirectory = URL.documentsDirectory.appending(path: "EnsemblesEventData", directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: eventDataDirectory.path) {
            try FileManager.default.removeItem(at: eventDataDirectory)
            Write_App.logToFile("🗑️ [Ensembles] Removed backed-up local Ensembles history for fresh source reseed")
        }
        UserDefaults.standard.removeObject(forKey: Write_App.excludeLocalDataOnNextEnsemblesAttachKey)
        Write_App.clearEnsemblesCloudKitListingCaches()
        Write_App.logToFile("✅ [Ensembles] Source reseed prepared with mergeAllData policy")
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
            withIdentifier: Write_App.ensembleIdentifier,
            in: cloudFileSystem
        )

        let database = CKContainer(identifier: "iCloud.com.appworks.writingshedpro").privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.mentalfaculty.ensembles.zone.schema2",
            ownerName: CKCurrentUserDefaultName
        )
        do {
            _ = try await database.deleteRecordZone(withID: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // The Ensembles removal may already have removed the dedicated zone.
        }

        let legacyZoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )
        do {
            _ = try await database.deleteRecordZone(withID: legacyZoneID)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // The legacy native CloudKit zone may already be absent.
        }
        Write_App.clearEnsemblesCloudKitListingCaches()
    }

    @MainActor
    private func removeLegacyCoreDataCloudZone() async {
        guard isEnsemblesIdle else {
            syncStatusMessage = "Legacy zone removal blocked until Ensembles activity returns to none."
            return
        }

        syncStatusMessage = "Removing legacy Core Data CloudKit zone..."
        let database = CKContainer(identifier: "iCloud.com.appworks.writingshedpro").privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        do {
            _ = try await database.deleteRecordZone(withID: zoneID)
            syncStatusMessage = "Legacy Core Data CloudKit zone removed. The Ensembles zone and local store were not changed."
            Write_App.logToFile("✅ [Sync Zones] Removed legacy Core Data CloudKit zone only")
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            syncStatusMessage = "Legacy Core Data CloudKit zone is already absent."
            Write_App.logToFile("✅ [Sync Zones] Legacy Core Data CloudKit zone already absent")
        } catch {
            syncStatusMessage = "Legacy Core Data CloudKit zone removal failed. Copy diagnostics."
            Write_App.logErrorToFile("❌ [Sync Zones] Legacy Core Data CloudKit zone removal failed: \(Write_App.detailedErrorDescription(error))")
        }
    }

    private func cloudZoneStatus(zoneName: String) async -> String {
        let database = CKContainer(identifier: "iCloud.com.appworks.writingshedpro").privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await database.recordZone(for: zoneID)
            return "present"
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            return "absent"
        } catch {
            return "check failed: \(Write_App.detailedErrorDescription(error))"
        }
    }

    private func fetchEnsemblesZoneSummary() async throws -> String {
        let database = CKContainer(identifier: "iCloud.com.appworks.writingshedpro").privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.mentalfaculty.ensembles.zone.schema2", ownerName: CKCurrentUserDefaultName)

        _ = try await database.recordZone(for: zoneID)

        return try await withCheckedThrowingContinuation { continuation in
            var recordTypeCounts: [String: Int] = [:]
            var deletedTypeCounts: [String: Int] = [:]
            var sampleRecordNames: [String] = []
            var sampleRecordDetails: [String] = []
            let resumeLock = NSLock()
            var didResume = false

            func claimContinuation() -> Bool {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !didResume else { return false }
                didResume = true
                return true
            }

            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = nil
            configuration.desiredKeys = []

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration]
            )
            operation.timeoutIntervalForRequest = 15
            operation.timeoutIntervalForResource = 30

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

            operation.recordZoneFetchResultBlock = { _, result in
                guard case .failure(let error) = result,
                      claimContinuation() else { return }
                continuation.resume(throwing: error)
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                guard claimContinuation() else { return }
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
        let storeHasDataBeforeSync = Write_App.recordFirstEnsemblesDataAvailableIfNeeded(modelContainer: modelContext.container, reason: "diagnostics manual sync preflight")
        do {
            if storeHasDataBeforeSync {
                try await container.sync(options: .none)
            } else {
                try await container.sync(options: .suppressCloudFileDeposition)
            }

            if Write_App.recordFirstEnsemblesDataAvailableIfNeeded(modelContainer: modelContext.container, reason: "diagnostics manual sync") {
                Write_App.recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: "diagnostics manual sync")
                syncStatusMessage = "Sync transferred changes at \(Date().formatted(date: .omitted, time: .standard))."
                Write_App.logToFile("✅ [Ensembles] Manual sync completed from diagnostics (hadLocalData=\(storeHasDataBeforeSync), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
            } else {
                syncStatusMessage = "Sync transferred cloud files, but no local projects were observed yet. Relaunch or copy diagnostics."
                Write_App.logToFile("⚠️ [Ensembles] Manual sync completed but local store is still empty (hadLocalData=\(storeHasDataBeforeSync), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
            }
        } catch {
            syncStatusMessage = "Sync failed. Copy diagnostics."
            Write_App.logErrorToFile("❌ [Ensembles] Manual sync failed from diagnostics: \(Write_App.detailedErrorDescription(error))")
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
        diagnosticsRefreshID = UUID()
    }

    @MainActor
    private func cleanupDuplicateProjects() {
        let freshContext = ModelContext(modelContext.container)
        let result = DeduplicationService.deduplicateProjects(context: freshContext)
        if result.duplicatesRemoved > 0 {
            syncStatusMessage = "Removed \(result.duplicatesRemoved) duplicate project\(result.duplicatesRemoved == 1 ? "" : "s"): \(result.projectsAffected.joined(separator: ", "))."
            NotificationCenter.default.post(name: .projectContentCountsDidChange, object: nil)
        } else if let error = result.errors.first {
            syncStatusMessage = error
        } else {
            syncStatusMessage = "No duplicate project clones found."
        }
        refreshCounts()
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
