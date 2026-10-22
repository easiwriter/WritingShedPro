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
    @State private var showPublishRecoveryBaselineConfirmation = false
    @State private var showRemoveEnsemblesCloudDataConfirmation = false
    @State private var showRemoveLegacyCloudDataConfirmation = false
    @State private var localResetQueued = false
    @State private var localRecoveryModeQueued = UserDefaults.standard.bool(forKey: Write_App.localRecoveryModeOnNextLaunchKey)
    @State private var ensemblesCloudDataRemovedThisSession = false
    @State private var lastSafetyBackupName: String?
    @State private var lastRecoveryExportName: String?
    @State private var didRestoreRecoveredInduction = false
    @State private var didRepairRecoveredInductionHeading = false
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
                "Publish this Mac as the recovery baseline?",
                isPresented: $showPublishRecoveryBaselineConfirmation,
                titleVisibility: .visible,
                actions: publishRecoveryBaselineDialogActions,
                message: publishRecoveryBaselineDialogMessage
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
                showPublishRecoveryBaselineConfirmation = true
            } label: {
                Label("Publish Recovery Baseline", systemImage: "icloud.and.arrow.up")
            }
            .disabled(
                Write_App.activeEnsemblesContainer == nil ||
                Write_App.isLocalRecoveryModeEnabled ||
                Write_App.currentEnsemblesSeedPolicy != "mergeAllData (existing store)" ||
                projectCount == 0 || folderCount == 0 || fileCount == 0 || versionCount == 0 ||
                !isEnsemblesIdle
            )

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

            if Write_App.isLocalRecoveryModeEnabled {
                Button {
                    prepareV4SourceAttach()
                } label: {
                    Label("Prepare Verified V4 Source Attach", systemImage: "checkmark.shield")
                }
                .disabled(Write_App.activeEnsemblesContainer != nil || projectCount == 0)

                Button {
                    exportRecoveryCandidates()
                } label: {
                    Label("Export All Recovery Candidates", systemImage: "square.and.arrow.up.on.square")
                }
                .disabled(Write_App.activeEnsemblesContainer != nil || projectCount == 0)

                Button {
                    restoreRecoveredInduction()
                } label: {
                    Label("Restore Recovered Induction Text", systemImage: "text.badge.checkmark")
                }
                .disabled(Write_App.activeEnsemblesContainer != nil || didRestoreRecoveredInduction)

                Button {
                    repairRecoveredInductionHeading()
                } label: {
                    Label("Repair Induction Title 2 Spacing", systemImage: "text.line.last.and.arrowtriangle.forward")
                }
                .disabled(Write_App.activeEnsemblesContainer != nil || didRepairRecoveredInductionHeading)
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
                Text("Local reset queued. Quit and relaunch the app to back up this device's local store and re-import from sync.")
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

            if let lastRecoveryExportName {
                Text("Recovery exports created: \(lastRecoveryExportName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
        Text("This only affects this device. The app will detach it from Ensembles, then on next launch back up its local SQLite store and Ensembles event cache, remove the local copies, and re-import from the sync cloud. Do not use this if this device has unsynced work that is not on your other devices.")
    }

    @ViewBuilder
    private func publishRecoveryBaselineDialogActions() -> some View {
        Button("Publish Recovery Baseline") {
            Task { await publishRecoveryBaseline() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func publishRecoveryBaselineDialogMessage() -> some View {
        Text("Use this only on the verified source Mac after removing the old sync zones, while every follower app is closed. A safety backup will be created first, then this Mac's complete local store will be force-rebased into a new cloud baseline. Never use this action on an empty or partial follower.")
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
        if let container = Write_App.activeEnsemblesContainer, container.isAttached {
            let activity = String(describing: container.currentActivity)
            guard activity == "none" else {
                UserDefaults.standard.set(true, forKey: Write_App.detachLocalEnsemblesBeforeResetOnNextLaunchKey)
                localResetQueued = true
                syncStatusMessage = "Detach queued. Quit and relaunch the app; after detach completes, quit and relaunch once more for the local reset."
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

        UserDefaults.standard.removeObject(forKey: Write_App.localRecoveryModeOnNextLaunchKey)
        UserDefaults.standard.set(true, forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey)
        localResetQueued = true
        localRecoveryModeQueued = false
        syncStatusMessage = "Local reset queued. Quit and relaunch the app."
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
        UserDefaults.standard.removeObject(forKey: Write_App.v3BaselinePublishedKey)
        UserDefaults.standard.set(true, forKey: Write_App.sourceReseedPendingKey)
        Write_App.clearEnsemblesCloudKitListingCaches()
        Write_App.logToFile("✅ [Ensembles] Source reseed prepared with mergeAllData policy")
    }

    @MainActor
    private func prepareV4SourceAttach() {
        guard Write_App.isLocalRecoveryModeEnabled,
              Write_App.activeEnsemblesContainer == nil else {
            syncStatusMessage = "V4 source preparation requires isolated Local Recovery Mode."
            return
        }

        let context = ModelContext(modelContext.container)
        let counts = [
            "projects": fetchCount(Project.self, in: context),
            "folders": fetchCount(Folder.self, in: context),
            "files": fetchCount(TextFile.self, in: context),
            "versions": fetchCount(Version.self, in: context),
            "publications": fetchCount(Publication.self, in: context),
            "scenes": fetchCount(StoryScene.self, in: context)
        ]

        guard let projects = counts["projects"], projects > 0,
              let folders = counts["folders"], folders > 0,
              let files = counts["files"], files > 0,
              let versions = counts["versions"], versions > 0,
              versions * 10 >= files else {
            syncStatusMessage = "V4 source preparation blocked: this store is empty or partial."
            Write_App.logErrorToFile("🛑 [Ensembles] Refused to arm V4 source attach for counts=\(counts)")
            return
        }

        guard createLocalSafetyBackup(reason: "prepare-v4-source-attach") != nil else {
            syncStatusMessage = "V4 source preparation blocked: safety backup failed."
            return
        }

        UserDefaults.standard.set(counts, forKey: Write_App.verifiedSourceCountsKey)
        UserDefaults.standard.set(true, forKey: Write_App.sourceReseedPendingKey)
        UserDefaults.standard.removeObject(forKey: Write_App.localRecoveryModeOnNextLaunchKey)
        localRecoveryModeQueued = false
        syncStatusMessage = "Verified V4 source armed with \(projects) projects, \(folders) folders, \(files) files and \(versions) versions. Quit and relaunch to attach."
        Write_App.logToFile("✅ [Ensembles] Armed exact V4 source fingerprint counts=\(counts); next launch may attach only this store")
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

    @MainActor
    private func exportRecoveryCandidates() {
        guard Write_App.isLocalRecoveryModeEnabled,
              Write_App.activeEnsemblesContainer == nil else {
            syncStatusMessage = "Recovery export blocked: Local Recovery Mode is not isolated from Ensembles."
            return
        }

        do {
            let projects = try modelContext.fetch(FetchDescriptor<Project>())
                .filter { !$0.isTrashed }
            let timestamp = Int(Date().timeIntervalSince1970)
            let directoryName = "WSPRecoveryExports_\(timestamp)"
            let directory = URL.documentsDirectory.appending(
                path: directoryName,
                directoryHint: .isDirectory
            )
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let exportService = JSONExportService()
            for project in projects {
                let safeName = (project.name ?? "Untitled").map { character in
                    character.isLetter || character.isNumber || character == " " || character == "-" || character == "_"
                        ? character
                        : "_"
                }
                let idPrefix = project.id.uuidString.prefix(8)
                let filename = "\(String(safeName))__\(idPrefix).wsp"
                try exportService.exportProject(
                    project,
                    to: directory.appending(path: filename)
                )
            }

            lastRecoveryExportName = directoryName
            syncStatusMessage = "Exported \(projects.count) recovery candidates to Documents/\(directoryName)."
            Write_App.logToFile("🛟 [Recovery] Exported \(projects.count) project candidates to \(directoryName)")
        } catch {
            syncStatusMessage = "Recovery export failed: \(error.localizedDescription)"
            Write_App.logErrorToFile("❌ [Recovery] Candidate export failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func restoreRecoveredInduction() {
        let expectedProjectID = "DDECC671-BA40-45DF-857C-9930AC455E76"
        let expectedFileID = "F01C1484-5593-4362-B2D1-14E4B0D88F54"
        let expectedVersionID = "A753926D-A942-4D4E-9EE5-4AE9496B7DDF"
        let rolledBackTextHash = "4a362a192a66ef0d2ffac5ea185720d409ad9edae3522cd489f632ddea07a415"
        let recoveredTextHash = "a65d00f6d78b466a1b376aa1e20116f79b287f3ff4996fcd3874104bef37ea47"

        guard Write_App.isLocalRecoveryModeEnabled,
              Write_App.activeEnsemblesContainer == nil else {
            syncStatusMessage = "Induction restore blocked: Local Recovery Mode is not isolated from Ensembles."
            return
        }

        let textURL = URL.documentsDirectory.appending(path: "InductionRecovery-1403.txt")
        let richURL = URL.documentsDirectory.appending(path: "InductionRecovery-1403.plist")

        do {
            let recoveredText = try String(contentsOf: textURL, encoding: .utf8)
            let recoveredRichData = try Data(contentsOf: richURL)

            guard AttributedStringSerializer.sourceTextHash(for: recoveredText) == recoveredTextHash,
                  AttributedStringSerializer.sourceTextLength(for: recoveredText) == 1403,
                  !AttributedStringSerializer.hasContentFingerprintMismatch(
                    in: recoveredRichData,
                    text: recoveredText
                  ) else {
                syncStatusMessage = "Induction restore blocked: recovered text or rich-content fingerprint is invalid."
                return
            }

            let versions = try modelContext.fetch(FetchDescriptor<Version>())
            guard let version = versions.first(where: { $0.id.uuidString == expectedVersionID }),
                  let file = version.textFile,
                  file.id.uuidString == expectedFileID,
                  file.name == "Induction",
                  version.content.count == 713,
                  AttributedStringSerializer.sourceTextHash(for: version.content) == rolledBackTextHash else {
                syncStatusMessage = "Induction restore blocked: the expected rolled-back Version was not found unchanged."
                return
            }

            var folder = file.parentFolder
            var owningProject: Project?
            while let currentFolder = folder {
                if let project = currentFolder.project {
                    owningProject = project
                    break
                }
                folder = currentFolder.parentFolder
            }

            guard let owningProject,
                  owningProject.id.uuidString == expectedProjectID,
                  owningProject.name == "Memoirs of a Software Engineer" else {
                syncStatusMessage = "Induction restore blocked: the Version is not owned by the expected Memoirs project."
                return
            }

            version.content = recoveredText
            version.setFormattedContentData(recoveredRichData, sourceText: recoveredText)
            file.modifiedDate = Date()
            owningProject.modifiedDate = Date()
            try EnsemblesSaveGate.save(modelContext, reason: "sync-diagnostics-restore-induction")

            guard version.content.count == 1403,
                  !version.hasFormattedContentSyncMismatch else {
                modelContext.rollback()
                syncStatusMessage = "Induction restore failed post-save verification."
                return
            }

            didRestoreRecoveredInduction = true
            syncStatusMessage = "Restored the verified 1,403-character Induction revision with its recovered formatting."
            Write_App.logToFile("✅ [Recovery] Restored verified Induction Version \(expectedVersionID)")
        } catch {
            modelContext.rollback()
            syncStatusMessage = "Induction restore failed: \(error.localizedDescription)"
            Write_App.logErrorToFile("❌ [Recovery] Induction restore failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func repairRecoveredInductionHeading() {
        let expectedProjectID = "DDECC671-BA40-45DF-857C-9930AC455E76"
        let expectedFileID = "F01C1484-5593-4362-B2D1-14E4B0D88F54"
        let expectedVersionID = "A753926D-A942-4D4E-9EE5-4AE9496B7DDF"
        let expectedTextHash = "a65d00f6d78b466a1b376aa1e20116f79b287f3ff4996fcd3874104bef37ea47"
        let heading = "Ferranti Automation Systems"

        guard Write_App.isLocalRecoveryModeEnabled,
              Write_App.activeEnsemblesContainer == nil else {
            syncStatusMessage = "Title 2 repair blocked: Local Recovery Mode is not isolated from Ensembles."
            return
        }

        do {
            let versions = try modelContext.fetch(FetchDescriptor<Version>())
            guard let version = versions.first(where: { $0.id.uuidString == expectedVersionID }),
                  let file = version.textFile,
                  file.id.uuidString == expectedFileID,
                  file.name == "Induction",
                  AttributedStringSerializer.sourceTextHash(for: version.content) == expectedTextHash,
                  !version.hasFormattedContentSyncMismatch,
                  let attributedContent = version.attributedContent else {
                syncStatusMessage = "Title 2 repair blocked: the verified recovered Induction Version was not found unchanged."
                return
            }

            var folder = file.parentFolder
            var owningProject: Project?
            while let currentFolder = folder {
                if let project = currentFolder.project {
                    owningProject = project
                    break
                }
                folder = currentFolder.parentFolder
            }

            guard let owningProject,
                  owningProject.id.uuidString == expectedProjectID,
                  owningProject.name == "Memoirs of a Software Engineer" else {
                syncStatusMessage = "Title 2 repair blocked: Induction is not owned by the expected Memoirs project."
                return
            }

            let headingRange = (attributedContent.string as NSString).range(of: heading)
            guard headingRange.location != NSNotFound else {
                syncStatusMessage = "Title 2 repair blocked: the expected heading was not found."
                return
            }

            let repairedContent = TextFormatter.applyStyle(
                named: UIFont.TextStyle.title2.rawValue,
                to: attributedContent,
                range: headingRange,
                project: owningProject,
                context: modelContext
            )

            guard repairedContent.string == version.content,
                  let paragraphStyle = repairedContent.attribute(
                    .paragraphStyle,
                    at: headingRange.location,
                    effectiveRange: nil
                  ) as? NSParagraphStyle,
                  paragraphStyle.paragraphSpacing == 12 else {
                syncStatusMessage = "Title 2 repair blocked: applying the style did not produce the expected 12-point spacing."
                return
            }

            version.attributedContent = repairedContent
            file.modifiedDate = Date()
            owningProject.modifiedDate = Date()
            try EnsemblesSaveGate.save(modelContext, reason: "sync-diagnostics-repair-induction-title2")

            guard AttributedStringSerializer.sourceTextHash(for: version.content) == expectedTextHash,
                  !version.hasFormattedContentSyncMismatch else {
                modelContext.rollback()
                syncStatusMessage = "Title 2 repair failed post-save verification."
                return
            }

            didRepairRecoveredInductionHeading = true
            syncStatusMessage = "Reapplied Title 2 to the Induction heading with 12-point spacing after."
            Write_App.logToFile("✅ [Recovery] Repaired Induction Title 2 paragraph spacing")
        } catch {
            modelContext.rollback()
            syncStatusMessage = "Title 2 repair failed: \(error.localizedDescription)"
            Write_App.logErrorToFile("❌ [Recovery] Induction Title 2 repair failed: \(error.localizedDescription)")
        }
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
            let operationConfiguration = CKOperation.Configuration()
            operationConfiguration.timeoutIntervalForRequest = 15
            operationConfiguration.timeoutIntervalForResource = 30
            operation.configuration = operationConfiguration

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
        guard !Write_App.storeUnregisteredBlockedThisLaunch,
              !Write_App.partialStoreBlockedThisLaunch else {
            syncStatusMessage = "Sync is blocked because the local store is quarantined. Copy diagnostics before recovery."
            Write_App.logErrorToFile("⛔️ [Ensembles] Diagnostics manual sync blocked by sync quarantine")
            return
        }
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
    private func publishRecoveryBaseline() async {
        guard !Write_App.isLocalRecoveryModeEnabled,
              Write_App.currentEnsemblesSeedPolicy == "mergeAllData (existing store)",
              let container = Write_App.activeEnsemblesContainer,
              container.isAttached,
              String(describing: container.currentActivity) == "none" else {
            syncStatusMessage = "Recovery baseline blocked: this device is not an attached, idle source store."
            Write_App.logErrorToFile("⚠️ [Ensembles] Recovery baseline publication blocked by source-state guard")
            return
        }

        let freshContext = ModelContext(modelContext.container)
        let sourceProjectCount = fetchCount(Project.self, in: freshContext)
        let sourceFolderCount = fetchCount(Folder.self, in: freshContext)
        let sourceFileCount = fetchCount(TextFile.self, in: freshContext)
        let sourceVersionCount = fetchCount(Version.self, in: freshContext)
        guard sourceProjectCount > 0,
              sourceFolderCount > 0,
              sourceFileCount > 0,
              sourceVersionCount > 0 else {
            syncStatusMessage = "Recovery baseline blocked: the source store is empty or incomplete."
            Write_App.logErrorToFile("⚠️ [Ensembles] Recovery baseline publication blocked for incomplete store projects=\(sourceProjectCount) folders=\(sourceFolderCount) files=\(sourceFileCount) versions=\(sourceVersionCount)")
            return
        }

        guard createLocalSafetyBackup(reason: "publish-recovery-baseline") != nil else {
            syncStatusMessage = "Recovery baseline blocked: the safety backup failed."
            return
        }

        syncStatusMessage = "Publishing this Mac's recovery baseline..."
        Write_App.logToFile("🛟 [Ensembles] Publishing verified source recovery baseline projects=\(sourceProjectCount) folders=\(sourceFolderCount) files=\(sourceFileCount) versions=\(sourceVersionCount)")
        do {
            try await container.sync(options: .forceRebase)
            guard Write_App.recordFirstEnsemblesDataAvailableIfNeeded(
                modelContainer: modelContext.container,
                reason: "recovery baseline publication"
            ) else {
                syncStatusMessage = "Recovery baseline publication finished, but source verification failed. Keep followers closed and copy diagnostics."
                Write_App.logErrorToFile("❌ [Ensembles] Recovery baseline publication failed post-sync source verification")
                return
            }

            UserDefaults.standard.set(true, forKey: Write_App.v3BaselinePublishedKey)
            UserDefaults.standard.removeObject(forKey: Write_App.sourceReseedPendingKey)
            Write_App.recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: "recovery baseline publication")
            syncStatusMessage = "Recovery baseline published. Verify Sync Zones before opening a follower."
            Write_App.logToFile("✅ [Ensembles] Verified source recovery baseline published with forced rebase")
        } catch {
            syncStatusMessage = "Recovery baseline publication failed. Keep followers closed and copy diagnostics."
            Write_App.logErrorToFile("❌ [Ensembles] Recovery baseline publication failed: \(Write_App.detailedErrorDescription(error))")
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
            guard !scene.isTrashed else { return false }
            if let textFile = scene.textFile {
                return textFile.parentFolder == nil
            }
            return scene.chapter == nil
                && scene.act == nil
                && scene.book == nil
                && !scene.isInBodyMatter
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
