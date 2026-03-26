//
//  SyncDiagnosticsView.swift
//  Writing Shed Pro
//
//  Debug view to check CloudKit sync status
//

import SwiftUI
import SwiftData
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

struct SyncDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var stylesheets: [StyleSheet]
    @Query private var projects: [Project]
    @Query private var allFolders: [Folder]
    @Query private var allTextFiles: [TextFile]
    @State private var syncThrottler = CloudKitSyncThrottler.shared
    
    @State private var iCloudStatus: String = "Checking..."
    @State private var containerStatus: String = "Checking..."
    @State private var duplicateCount: Int = 0
    @State private var duplicateProjectCount: Int = 0
    @State private var projectOrderCollisionCount: Int = 0
    @State private var orphanedFolderCount: Int = 0
    @State private var orphanedFileCount: Int = 0
    @State private var duplicateStyleSheetCount: Int = 0
    @State private var repairMessage: String = ""
    @State private var showRepairResult = false
    
    @State private var syncForceStatus: String = ""
    @State private var isForceSyncInProgress = false
    @State private var lastForceSyncRequestDate: Date?
    @State private var forceSyncRequestToken = UUID()
    @State private var subscriptionStatus: String = "Checking…"
    
    var body: some View {
        NavigationStack {
            diagnosticsList
            .navigationTitle("Sync Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkiCloudStatus()
                checkForDuplicates()
                checkForDuplicateProjects()
                checkProjectOrderHealth()
                checkCloudKitSubscriptions()
                checkForOrphans()
                checkForDuplicateStyleSheets()
            }
            .alert("Repair Complete", isPresented: $showRepairResult) {
                Button("OK") { }
            } message: {
                Text(repairMessage)
            }
        }
    }

    private var diagnosticsList: some View {
        List {
            iCloudSection
            cloudKitContainerSection
            liveCloudKitSection
            localDataSection
            databaseHealthSection
            stylesheetsSection
            debugActionsSection
        }
    }

    private var liveCloudKitSection: some View {
        Section("Live CloudKit") {
            // ── Blocking state warnings ──────────────────────────────────────────
            if syncThrottler.isManualKickPaused {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync kicks are paused (\(syncThrottler.consecutiveImportNetworkFailures) transport failure(s))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        if let until = syncThrottler.manualKickPausedUntil {
                            Text("Resumes at \(until.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            if syncThrottler.isRateLimited {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CloudKit rate-limited")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        if let until = syncThrottler.rateLimitedUntil {
                            Text("Until \(until.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            // ───────────────────────────────────────────────────────────────────
            LabeledContent("isSyncing", value: syncThrottler.isSyncing ? "Yes" : "No")
            LabeledContent("Remote Events (Total)", value: "\(syncThrottler.totalSyncEventCount)")
            LabeledContent("Current Burst Count", value: "\(syncThrottler.syncEventCount)")
            LabeledContent("Import In Progress", value: syncThrottler.importInProgress ? "Yes" : "No")
            LabeledContent("Export In Progress", value: syncThrottler.exportInProgress ? "Yes" : "No")
            LabeledContent("Import Completed", value: syncThrottler.importCompleted ? "Yes" : "No")
            LabeledContent("Import Succeeded", value: syncThrottler.importSucceeded ? "Yes" : "No")
            LabeledContent("Export Completed", value: syncThrottler.exportCompleted ? "Yes" : "No")
            LabeledContent("Export Succeeded", value: syncThrottler.exportSucceeded ? "Yes" : "No")
            LabeledContent("Rate Limited", value: syncThrottler.isRateLimited ? "Yes" : "No")
            LabeledContent("Manual Kick Paused", value: syncThrottler.isManualKickPaused ? "Yes" : "No")
            LabeledContent("Import Network Failures", value: "\(syncThrottler.consecutiveImportNetworkFailures)")
            LabeledContent("CK Subscription", value: subscriptionStatus)

            if let lastSync = syncThrottler.lastSyncTime {
                LabeledContent("Last Remote Event") {
                    Text(lastSync.formatted(date: .omitted, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            if let rateLimitedUntil = syncThrottler.rateLimitedUntil {
                LabeledContent("Rate Limited Until") {
                    Text(rateLimitedUntil.formatted(date: .omitted, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            if let pausedUntil = syncThrottler.manualKickPausedUntil {
                LabeledContent("Manual Pause Until") {
                    Text(pausedUntil.formatted(date: .omitted, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            if syncThrottler.recentCloudKitEvents.isEmpty {
                Text("No CloudKit events captured yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(syncThrottler.recentCloudKitEvents.prefix(20)) { event in
                    cloudKitEventRow(event)
                }
            }

            Button("Copy Diagnostics Snapshot") {
                copyDiagnosticsSnapshot()
            }

            Button("Clear Event Timeline") {
                syncThrottler.clearRecentCloudKitEvents()
            }
        }
    }

    private func cloudKitEventRow(_ event: CloudKitEventLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(event.type) · \(event.phase) · \(event.status)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(event.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !event.message.isEmpty {
                Text(event.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func diagnosticsSnapshotText() -> String {
        let now = Date()
        var lines: [String] = []
        lines.append("CloudKit Diagnostics Snapshot")
        lines.append("Generated: \(now.formatted(date: .complete, time: .standard))")
        lines.append("isSyncing: \(syncThrottler.isSyncing)")
        lines.append("remoteEventsTotal: \(syncThrottler.totalSyncEventCount)")
        lines.append("currentBurstCount: \(syncThrottler.syncEventCount)")
        lines.append("importInProgress: \(syncThrottler.importInProgress)")
        lines.append("exportInProgress: \(syncThrottler.exportInProgress)")
        lines.append("importCompleted: \(syncThrottler.importCompleted)")
        lines.append("importSucceeded: \(syncThrottler.importSucceeded)")
        lines.append("exportCompleted: \(syncThrottler.exportCompleted)")
        lines.append("exportSucceeded: \(syncThrottler.exportSucceeded)")
        lines.append("isRateLimited: \(syncThrottler.isRateLimited)")
        lines.append("isManualKickPaused: \(syncThrottler.isManualKickPaused)")
        lines.append("consecutiveImportNetworkFailures: \(syncThrottler.consecutiveImportNetworkFailures)")
        lines.append("lastRemoteEvent: \(syncThrottler.lastSyncTime?.formatted(date: .omitted, time: .standard) ?? "nil")")
            if let importStart = syncThrottler.importStartTime {
                lines.append("importAgeSeconds: \(Int(Date().timeIntervalSince(importStart)))")
            } else {
                lines.append("importAgeSeconds: nil")
            }
            if let exportStart = syncThrottler.exportStartTime {
                lines.append("exportAgeSeconds: \(Int(Date().timeIntervalSince(exportStart)))")
            } else {
                lines.append("exportAgeSeconds: nil")
            }
        lines.append("rateLimitedUntil: \(syncThrottler.rateLimitedUntil?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("manualKickPausedUntil: \(syncThrottler.manualKickPausedUntil?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("recentCloudKitEvents:")

        for event in syncThrottler.recentCloudKitEvents.prefix(25) {
            let msg = event.message.isEmpty ? "" : " — \(event.message)"
            lines.append("- \(event.timestamp.formatted(date: .omitted, time: .standard)) | \(event.type) | \(event.phase) | \(event.status)\(msg)")
        }

        lines.append("")
        lines.append(contentsOf: projectInventoryLines())

        return lines.joined(separator: "\n")
    }

    private func copyDiagnosticsSnapshot() {
        let snapshot = diagnosticsSnapshotText()

        #if canImport(UIKit)
        UIPasteboard.general.string = snapshot
        #endif

        syncForceStatus = "✅ Diagnostics snapshot copied to clipboard"
    }

    private func projectInventoryLines() -> [String] {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("Project Inventory")

        let queryProjects = sortedProjectsForInventory(projects)
        lines.append("Source: @Query (main context cache)")
        for project in queryProjects {
            lines.append(projectInventoryLine(project, formatter: formatter))
        }

        lines.append("")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        let freshContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Project>()
        let storeProjects = sortedProjectsForInventory((try? freshContext.fetch(descriptor)) ?? [])
        for project in storeProjects {
            lines.append(projectInventoryLine(project, formatter: formatter))
        }

        let queryNameByID = Dictionary(uniqueKeysWithValues: queryProjects.map { ($0.id, $0.name ?? "") })
        let storeNameByID = Dictionary(uniqueKeysWithValues: storeProjects.map { ($0.id, $0.name ?? "") })
        let allIDs = Set(queryNameByID.keys).union(storeNameByID.keys)
        let nameMismatches = allIDs.filter { queryNameByID[$0] != storeNameByID[$0] }.sorted { $0.uuidString < $1.uuidString }

        lines.append("")
        lines.append("Inventory Comparison")
        lines.append("- @Query count=\(queryProjects.count) | Store count=\(storeProjects.count)")
        lines.append("- Name mismatches by id=\(nameMismatches.count)")
        for id in nameMismatches {
            lines.append("  - id=\(id.uuidString) | @Query='\(queryNameByID[id] ?? "")' | Store='\(storeNameByID[id] ?? "")'")
        }

        return lines
    }

    private func sortedProjectsForInventory(_ inputProjects: [Project]) -> [Project] {
        inputProjects.sorted { lhs, rhs in
            let lhsCreated = lhs.creationDate ?? .distantPast
            let rhsCreated = rhs.creationDate ?? .distantPast
            if lhsCreated != rhsCreated {
                return lhsCreated < rhsCreated
            }
            return (lhs.name ?? "") < (rhs.name ?? "")
        }
    }

    private func projectInventoryLine(_ project: Project, formatter: ISO8601DateFormatter) -> String {
        let created = project.creationDate.map { formatter.string(from: $0) } ?? "nil"
        let modified = project.modifiedDate.map { formatter.string(from: $0) } ?? "nil"
        let deleted = project.deletedDate.map { formatter.string(from: $0) } ?? "nil"
        let folderCount = project.folders?.count ?? 0
        return "- name=\(project.name ?? "Untitled") | id=\(project.id.uuidString) | type=\(project.type.rawValue) | trashed=\(project.isTrashed) | userOrder=\(project.userOrder.map(String.init) ?? "nil") | created=\(created) | modified=\(modified) | deleted=\(deleted) | folders=\(folderCount)"
    }

    private func copyProjectInventory() {
        let snapshot = projectInventoryLines().joined(separator: "\n")

        #if canImport(UIKit)
        UIPasteboard.general.string = snapshot
        #endif

        syncForceStatus = "✅ Project inventory copied to clipboard"
    }

    private var iCloudSection: some View {
        Section("iCloud Account") {
            Text(iCloudStatus)
                .font(.caption)
        }
    }

    private var cloudKitContainerSection: some View {
        Section("CloudKit Container") {
            Text(containerStatus)
                .font(.caption)
        }
    }

    private var localDataSection: some View {
        Section("Local Data") {
            LabeledContent("StyleSheets", value: "\(stylesheets.count)")
            LabeledContent("Projects", value: "\(projects.count)")
            LabeledContent("Folders", value: "\(allFolders.count)")
            LabeledContent("Text Files", value: "\(allTextFiles.count)")

            Button("Copy Project Inventory") {
                copyProjectInventory()
            }

            if duplicateCount > 0 {
                duplicateWarningRow
            }
        }
    }

    private var duplicateWarningRow: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("\(duplicateCount) duplicate file references detected")
                .foregroundColor(.orange)
        }
    }

    private var databaseHealthSection: some View {
        Section("Database Health") {
            duplicateProjectsStatusRow

            projectOrderStatusRow

            if projectOrderCollisionCount > 0 {
                normalizeProjectOrderRow
            }

            if duplicateProjectCount > 0 {
                duplicateProjectsRepairRow
            }

            orphanedFoldersStatusRow
            orphanedFilesStatusRow

            if orphanedFolderCount > 0 {
                orphanedFoldersRepairRow
            }

            if orphanedFileCount > 0 {
                orphanedFilesRepairRow
            }

            duplicateStyleSheetsStatusRow

            if duplicateStyleSheetCount > 0 {
                duplicateStyleSheetsRepairRow
            }

            duplicateCheckRow

            if duplicateCount > 0 {
                duplicateReferencesRepairRow
            }
        }
    }

    private var duplicateProjectsStatusRow: some View {
        HStack {
            Text("Duplicate Projects")
            Spacer()
            Text("\(duplicateProjectCount) found")
                .foregroundColor(duplicateProjectCount > 0 ? .red : .secondary)
        }
    }

    private var duplicateProjectsRepairRow: some View {
        HStack {
            Image(systemName: "doc.on.doc")
            Text("Remove Duplicate Projects")
            Spacer()
        }
        .foregroundColor(.red)
        .contentShape(Rectangle())
        .onTapGesture {
            deduplicateProjects()
        }
    }

    private var projectOrderStatusRow: some View {
        HStack {
            Text("Project Order Collisions")
            Spacer()
            Text("\(projectOrderCollisionCount) found")
                .foregroundColor(projectOrderCollisionCount > 0 ? .red : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            checkProjectOrderHealth()
        }
    }

    private var normalizeProjectOrderRow: some View {
        HStack {
            Image(systemName: "arrow.up.arrow.down")
            Text("Normalize Project Order")
            Spacer()
        }
        .foregroundColor(.orange)
        .contentShape(Rectangle())
        .onTapGesture {
            normalizeProjectOrder()
        }
    }

    private var orphanedFoldersStatusRow: some View {
        HStack {
            Text("Orphaned Folders")
            Spacer()
            Text("\(orphanedFolderCount) found")
                .foregroundColor(orphanedFolderCount > 0 ? .orange : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            checkForOrphans()
        }
    }

    private var orphanedFilesStatusRow: some View {
        HStack {
            Text("Orphaned Files")
            Spacer()
            Text("\(orphanedFileCount) found")
                .foregroundColor(orphanedFileCount > 0 ? .orange : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            checkForOrphans()
        }
    }

    private var orphanedFoldersRepairRow: some View {
        HStack {
            Image(systemName: "folder.badge.minus")
            Text("Delete Orphaned Folders")
            Spacer()
        }
        .foregroundColor(.red)
        .contentShape(Rectangle())
        .onTapGesture {
            deleteOrphanedFolders()
        }
    }

    private var orphanedFilesRepairRow: some View {
        HStack {
            Image(systemName: "trash")
            Text("Delete Orphaned Files")
            Spacer()
        }
        .foregroundColor(.red)
        .contentShape(Rectangle())
        .onTapGesture {
            deleteOrphanedFiles()
        }
    }

    private var duplicateStyleSheetsStatusRow: some View {
        HStack {
            Text("Duplicate StyleSheets")
            Spacer()
            Text("\(duplicateStyleSheetCount) found")
                .foregroundColor(duplicateStyleSheetCount > 0 ? .orange : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            checkForDuplicateStyleSheets()
        }
    }

    private var duplicateStyleSheetsRepairRow: some View {
        HStack {
            Image(systemName: "paintbrush.pointed")
            Text("Merge Duplicate StyleSheets")
            Spacer()
        }
        .foregroundColor(.orange)
        .contentShape(Rectangle())
        .onTapGesture {
            mergeDuplicateStyleSheets()
        }
    }

    private var duplicateCheckRow: some View {
        HStack {
            Text("Check for Duplicates")
            Spacer()
            Text("\(duplicateCount) found")
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            checkForDuplicates()
        }
    }

    private var duplicateReferencesRepairRow: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
            Text("Repair Duplicate References")
            Spacer()
        }
        .foregroundColor(.orange)
        .contentShape(Rectangle())
        .onTapGesture {
            repairDuplicates()
        }
    }

    private var stylesheetsSection: some View {
        Section("StyleSheets") {
            ForEach(stylesheets, id: \.id) { stylesheet in
                stylesheetDetailsRow(stylesheet)
            }
        }
    }

    private func stylesheetDetailsRow(_ stylesheet: StyleSheet) -> some View {
        VStack(alignment: .leading) {
            Text(stylesheet.name)
                .font(.headline)
            Text("Created: \(stylesheet.createdDate.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Modified: \(stylesheet.modifiedDate.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("System: \(stylesheet.isSystemStyleSheet ? "Yes" : "No")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var debugActionsSection: some View {
        Section("Sync Actions") {
            if !syncForceStatus.isEmpty {
                Text(syncForceStatus)
                    .font(.caption)
                    .foregroundStyle(syncForceStatus.hasPrefix("✅") ? .green :
                                     syncForceStatus.hasPrefix("❌") ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(isForceSyncInProgress ? "Syncing…" : "Force Sync Now") {
                forceSyncFromCloud()
            }
            .disabled(isForceSyncInProgress)

            if syncThrottler.isManualKickPaused || syncThrottler.consecutiveImportNetworkFailures > 0 {
                Button("Reset Sync Backoff State") {
                    resetSyncStateAndRetry()
                }
                .foregroundStyle(.orange)
            }
        }

        #if DEBUG
        Section("Debug Actions") {
            Button("Force Save Context") {
                saveContextAndShowStatus()
            }
        }
        #endif
    }

    private func saveContextAndShowStatus() {
        do {
            try modelContext.save()
            repairMessage = "Context saved successfully."
            showRepairResult = true
        } catch {
            repairMessage = "Error saving context: \(error.localizedDescription)"
            showRepairResult = true
        }
    }
    
    /// Check for duplicate projects (same name + creation date)
    private func checkForDuplicateProjects() {
        duplicateProjectCount = DeduplicationService.countDuplicateProjects(context: modelContext)
    }

    /// Check for orphaned folders and files
    private func checkForOrphans() {
        orphanedFolderCount = allFolders.filter { folder in
            folder.project == nil && folder.parentFolder == nil
        }.count

        orphanedFileCount = allTextFiles.filter { file in
            file.parentFolder == nil
        }.count
    }

    private func checkForDuplicateStyleSheets() {
        let customSheets = stylesheets.filter { !$0.isSystemStyleSheet }
        var nameGroups: [String: Int] = [:]
        for sheet in customSheets {
            let key = sheet.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            nameGroups[key, default: 0] += 1
        }
        duplicateStyleSheetCount = nameGroups.values.filter { $0 > 1 }.reduce(0) { $0 + ($1 - 1) }
    }

    private func mergeDuplicateStyleSheets() {
        let customSheets = stylesheets.filter { !$0.isSystemStyleSheet }
        var nameGroups: [String: [StyleSheet]] = [:]
        for sheet in customSheets {
            let key = sheet.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            nameGroups[key, default: []].append(sheet)
        }

        var mergedCount = 0
        for (_, group) in nameGroups where group.count > 1 {
            let sorted = group.sorted { lhs, rhs in
                let lhsCount = lhs.projects?.count ?? 0
                let rhsCount = rhs.projects?.count ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.createdDate <= rhs.createdDate
            }
            guard let keeper = sorted.first else { continue }
            for duplicate in sorted.dropFirst() {
                for project in duplicate.projects ?? [] {
                    project.styleSheet = keeper
                }
                modelContext.delete(duplicate)
                mergedCount += 1
            }
        }

        guard mergedCount > 0 else {
            repairMessage = "No duplicate stylesheets found."
            showRepairResult = true
            return
        }

        do {
            try modelContext.save()
            repairMessage = "Merged \(mergedCount) duplicate stylesheet(s)."
            duplicateStyleSheetCount = 0
        } catch {
            repairMessage = "Error merging stylesheets: \(error.localizedDescription)"
        }
        showRepairResult = true
    }

    /// Delete folders that have no project and no parent folder.
    /// These are unreachable in the UI and represent sync remnants.
    private func deleteOrphanedFolders() {
        let orphans = allFolders.filter { folder in
            folder.project == nil && folder.parentFolder == nil
        }

        guard !orphans.isEmpty else {
            repairMessage = "No orphaned folders found."
            showRepairResult = true
            return
        }

        for folder in orphans {
            modelContext.delete(folder)
        }

        do {
            try modelContext.save()
            repairMessage = "Deleted \(orphans.count) orphaned folder(s)."
            orphanedFolderCount = 0
        } catch {
            repairMessage = "Error deleting orphaned folders: \(error.localizedDescription)"
        }
        showRepairResult = true
    }

    /// Delete files that have no parent folder.
    /// These are unreachable in the UI and represent sync remnants.
    private func deleteOrphanedFiles() {
        let orphans = allTextFiles.filter { file in
            file.parentFolder == nil
        }

        guard !orphans.isEmpty else {
            repairMessage = "No orphaned files found."
            showRepairResult = true
            return
        }

        for file in orphans {
            modelContext.delete(file)
        }

        do {
            try modelContext.save()
            repairMessage = "Deleted \(orphans.count) orphaned file(s)."
            orphanedFileCount = 0
        } catch {
            repairMessage = "Error deleting orphaned files: \(error.localizedDescription)"
        }
        showRepairResult = true
    }

    /// Check whether the NSPersistentCloudKitContainer CKDatabaseSubscription exists.
    /// If it is missing, CloudKit won't be able to deliver silent pushes and sync will
    /// rely entirely on the watchdog timer. The container normally re-registers the
    /// subscription on every launch, so a missing subscription after some uptime is unusual.
    private func checkCloudKitSubscriptions() {
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        ckContainer.privateCloudDatabase.fetchAllSubscriptions { subscriptions, error in
            DispatchQueue.main.async {
                if let error = error {
                    subscriptionStatus = "❌ Error: \(error.localizedDescription)"
                    return
                }
                guard let subscriptions = subscriptions else {
                    subscriptionStatus = "❌ No subscriptions returned"
                    return
                }
                // NSPersistentCloudKitContainer registers a CKDatabaseSubscription
                // whose ID starts with "NSPERSISTENTCLOUDKITCONTAINER"
                let ckContainerSubs = subscriptions.filter { sub in
                    if let dbSub = sub as? CKDatabaseSubscription {
                        return dbSub.subscriptionID.hasPrefix("NSPERSISTENTCLOUDKITCONTAINER") ||
                               dbSub.subscriptionID.lowercased().contains("coredata")
                    }
                    return false
                }
                if ckContainerSubs.isEmpty {
                    subscriptionStatus = "⚠️ Missing (\(subscriptions.count) other sub(s) found)"
                } else {
                    subscriptionStatus = "✅ Found (\(ckContainerSubs.count) of \(subscriptions.count))"
                }
            }
        }
    }

    /// Reset all sync backoff state and immediately attempt a manual zone fetch.
    /// Use this when sync appears blocked due to prior transport failures.
    private func resetSyncStateAndRetry() {
        CloudKitSyncThrottler.shared.resetBackoffState()
        syncForceStatus = "Backoff state cleared — retrying sync…"
        // Small delay to let the backoff state clear on main thread before the zone fetch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            forceSyncFromCloud()
        }
    }
    
    /// Force a CloudKit zone fetch to pick up any missed remote changes.
    /// NSPersistentCloudKitContainer relies on silent push notifications which can
    /// be unreliable on Mac Catalyst and iPad. This performs a manual zone fetch
    /// which wakes up the mirroring engine.
    private func forceSyncFromCloud() {
        lastForceSyncRequestDate = Date()
        isForceSyncInProgress = true
        let requestToken = UUID()
        forceSyncRequestToken = requestToken

        // Warn (but don't block) if we're rate-limited — user explicitly tapped the button
        if CloudKitSyncThrottler.shared.isRateLimited {
            syncForceStatus = "⚠️ CloudKit rate-limited — request may fail. Retrying anyway…"
        } else {
            syncForceStatus = "Force sync requested — fetching zones…"
        }

        if CloudKitSyncThrottler.shared.isManualKickPaused {
            syncForceStatus += " Manual recovery kicks are currently paused, but this explicit request will still try CloudKit directly."
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard forceSyncRequestToken == requestToken, isForceSyncInProgress else { return }
            isForceSyncInProgress = false
            syncForceStatus = "⚠️ Force sync request timed out waiting for a CloudKit response. The request may still complete later, but this usually means CloudKit is stalled or very slow on this device."
        }
        
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        
        database.fetchAllRecordZones { zones, error in
            guard let zones = zones, !zones.isEmpty else {
                DispatchQueue.main.async {
                    guard forceSyncRequestToken == requestToken else { return }
                    isForceSyncInProgress = false
                    syncForceStatus = "❌ No zones found: \(error?.localizedDescription ?? "unknown error")"
                }
                return
            }
            
            DispatchQueue.main.async {
                syncForceStatus = "Fetching changes from \(zones.count) zone(s)…"
            }
            
            var configs = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
            for zone in zones {
                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                config.previousServerChangeToken = nil  // full fetch
                configs[zone.zoneID] = config
            }
            
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: zones.map(\.zoneID),
                configurationsByRecordZoneID: configs
            )
            
            operation.fetchRecordZoneChangesResultBlock = { result in
                DispatchQueue.main.async {
                    guard forceSyncRequestToken == requestToken else { return }
                    isForceSyncInProgress = false
                    switch result {
                    case .success:
                        syncForceStatus = "✅ Zone fetch completed — sync engine should process changes"
                    case .failure(let err):
                        syncForceStatus = "⚠️ Zone fetch error: \(err.localizedDescription)"
                    }
                }
            }
            
            operation.qualityOfService = .userInitiated
            database.add(operation)
        }
        
        // Also perform a local save + nudge to trigger export cycle
        do {
            try modelContext.save()
        } catch {
            syncForceStatus += " Local save failed: \(error.localizedDescription)"
        }
    }
    
    /// Remove duplicate projects, keeping the one with the most content
    private func deduplicateProjects() {
        let result = DeduplicationService.deduplicateProjects(context: modelContext)
        duplicateProjectCount = 0
        checkProjectOrderHealth()
        
        if !result.errors.isEmpty {
            repairMessage = result.errors.joined(separator: "\n")
        } else if result.duplicatesRemoved > 0 {
            repairMessage = "Removed \(result.duplicatesRemoved) duplicate project(s): \(result.projectsAffected.joined(separator: ", ")). Please restart the app."
        } else {
            repairMessage = "No duplicate projects found."
        }
        showRepairResult = true
    }

    private func checkProjectOrderHealth() {
        let activeProjects = projects.filter { !$0.isTrashed }
        var orderFrequency: [Int: Int] = [:]
        for project in activeProjects {
            guard let order = project.userOrder else { continue }
            orderFrequency[order, default: 0] += 1
        }
        projectOrderCollisionCount = orderFrequency.values.filter { $0 > 1 }.count
    }

    private func normalizeProjectOrder() {
        if CloudKitSyncThrottler.shared.hasActiveCloudKitEvent {
            repairMessage = "CloudKit sync is active. Wait until sync settles, then run Normalize Project Order."
            showRepairResult = true
            return
        }

        let activeProjects = ProjectSortService.sortProjects(
            projects.filter { !$0.isTrashed },
            by: .byUserOrder
        )

        for (index, project) in activeProjects.enumerated() {
            project.userOrder = index
        }

        do {
            try modelContext.save()
            checkProjectOrderHealth()
            repairMessage = "Normalized userOrder for \(activeProjects.count) active project(s)."
        } catch {
            repairMessage = "Error normalizing project order: \(error.localizedDescription)"
        }

        showRepairResult = true
    }
    
    /// Check for duplicate file references in folder relationships
    private func checkForDuplicates() {
        var totalDuplicates = 0
        
        for folder in allFolders {
            if let files = folder.textFiles {
                var seenIDs = Set<UUID>()
                for file in files {
                    if seenIDs.contains(file.id) {
                        totalDuplicates += 1
                        #if DEBUG
                        print("⚠️ Duplicate found: \(file.name) in folder \(folder.name ?? "unnamed")")
                        #endif
                    }
                    seenIDs.insert(file.id)
                }
            }
        }
        
        duplicateCount = totalDuplicates
    }
    
    /// Repair duplicate file references by removing duplicates from folder.textFiles arrays
    private func repairDuplicates() {
        var repairedCount = 0
        
        for folder in allFolders {
            guard let files = folder.textFiles else { continue }
            
            var seenIDs = Set<UUID>()
            var uniqueFiles: [TextFile] = []
            
            for file in files {
                if !seenIDs.contains(file.id) {
                    seenIDs.insert(file.id)
                    uniqueFiles.append(file)
                } else {
                    repairedCount += 1
                    #if DEBUG
                    print("🔧 Removing duplicate: \(file.name) from folder \(folder.name ?? "unnamed")")
                    #endif
                }
            }
            
            // If we found duplicates, update the folder's textFiles
            if uniqueFiles.count != files.count {
                folder.textFiles = uniqueFiles
            }
        }
        
        if repairedCount > 0 {
            do {
                try modelContext.save()
                repairMessage = "Successfully removed \(repairedCount) duplicate reference(s). Please restart the app."
                duplicateCount = 0
            } catch {
                repairMessage = "Error saving: \(error.localizedDescription)"
            }
        } else {
            repairMessage = "No duplicates found to repair."
        }
        
        showRepairResult = true
    }
    
    private func checkiCloudStatus() {
        // Check iCloud account status
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    iCloudStatus = "Error: \(error.localizedDescription)"
                    return
                }
                
                switch status {
                case .available:
                    iCloudStatus = "✅ Available"
                    checkContainerStatus()
                case .noAccount:
                    iCloudStatus = "❌ Not signed in to iCloud"
                case .restricted:
                    iCloudStatus = "⚠️ Restricted (parental controls?)"
                case .couldNotDetermine:
                    iCloudStatus = "❓ Could not determine"
                case .temporarilyUnavailable:
                    iCloudStatus = "⏳ Temporarily unavailable"
                @unknown default:
                    iCloudStatus = "Unknown status"
                }
            }
        }
    }
    
    private func checkContainerStatus() {
        let container = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        
        container.privateCloudDatabase.fetch(withRecordID: CKRecord.ID(recordName: "test")) { record, error in
            DispatchQueue.main.async {
                if let error = error as? CKError {
                    switch error.code {
                    case .unknownItem:
                        containerStatus = "✅ Container accessible (test record not found, which is expected)"
                    case .notAuthenticated:
                        containerStatus = "❌ Not authenticated to CloudKit"
                    case .networkUnavailable:
                        containerStatus = "📡 Network unavailable"
                    default:
                        containerStatus = "⚠️ Error: \(error.localizedDescription)"
                    }
                } else {
                    containerStatus = "✅ Container accessible"
                }
            }
        }
    }
}

#Preview {
    SyncDiagnosticsView()
        .modelContainer(for: [StyleSheet.self, Project.self], inMemory: true)
}
