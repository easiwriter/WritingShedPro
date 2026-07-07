//
//  SyncDiagnosticsView.swift
//  Writing Shed Pro
//
//  Debug view to check CloudKit sync status
//

import SwiftUI
import SwiftData
import CloudKit
import SQLite3
#if canImport(UIKit)
import UIKit
#endif

struct SyncDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var stylesheets: [StyleSheet]
    @Query private var projects: [Project]
    @Query private var publications: [Publication]
    @Query private var allFolders: [Folder]
    @Query private var allTextFiles: [TextFile]
    @State private var syncThrottler = CloudKitSyncThrottler.shared
    
    @State private var iCloudStatus: String = "Checking..."
    @State private var containerStatus: String = "Checking..."
    @State private var duplicateCount: Int = 0
    @State private var duplicateProjectCount: Int = 0
    @State private var projectOrderCollisionCount: Int = 0
    @State private var orphanedFolderCount: Int = 0
    @State private var orphanedFolderDetails: [(id: UUID, name: String, fileCount: Int, subfolderCount: Int)] = []
    @State private var orphanedFileCount: Int = 0
    @State private var orphanedFileExcludedCount: Int = 0
    @State private var orphanedFileDetails: [(id: UUID, name: String)] = []
    @State private var orphanReassignStatus: String = ""
    @State private var orphanedPublicationCount: Int = 0
    @State private var duplicateStyleSheetCount: Int = 0
    @State private var tombstoneCount: Int = 0
    @State private var repairMessage: String = ""
    @State private var showRepairResult = false
    
    @State private var syncForceStatus: String = ""
    @State private var isForceSyncInProgress = false
    @State private var lastForceSyncRequestDate: Date?
    @State private var forceSyncRequestToken = UUID()
    @State private var subscriptionStatus: String = "Checking…"
    @State private var showResetSyncConfirmation = false
    @State private var syncResetScheduled = false
    @State private var showDeleteZoneConfirmation = false
    @State private var showClearStuckFlagsConfirmation = false
    @State private var zoneDeleteStatus: String = ""
    @State private var zoneWasDeletedThisSession = false
    @State private var reexportStatus: String = ""
    @State private var zoneVerifyStatus: String = ""
    @State private var activeZoneVerifyRequestID: UUID?
    @State private var activeZoneVerifyOperation: CKFetchRecordZoneChangesOperation?
    @State private var activeZoneVerifyTimeoutTask: Task<Void, Never>?
    @State private var foreignZoneStatus: String = ""
    @State private var purgeOrphansStatus: String = ""
    @State private var showPurgeOrphansConfirmation = false
    @State private var guidedRecoveryStatus: String = ""
    @State private var isGuidedRecoveryInProgress = false
    @State private var showSyncBlockedSupport = false
    @State private var convergenceStatus: String = "Checking…"
    @State private var convergenceMismatchCount: Int = 0
    @State private var convergenceLastCheckedAt: Date?
    @State private var cloudflareSyncPOCStatus: String = ""
    @State private var isCloudflareSyncPOCRunning = false
    @State private var selectedCloudflareSyncPOCProjectId: UUID?

#if DEBUG || targetEnvironment(simulator)
    private let showAdvancedZoneRecovery = true
#else
    private let showAdvancedZoneRecovery = false
#endif
    
    var body: some View {
        NavigationStack {
            diagnosticsList
            .navigationTitle("Sync Troubleshooting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Always run convergence check (used in the status summary)
                analyzeConvergenceSignals()
                #if DEBUG || targetEnvironment(simulator)
                checkiCloudStatus()
                checkForDuplicates()
                checkForDuplicateProjects()
                checkProjectOrderHealth()
                checkCloudKitSubscriptions()
                checkForOrphans()
                checkForOrphanedPublications()
                checkForDuplicateStyleSheets()
                tombstoneCount = DeduplicationService.tombstoneCount
                #endif
            }
            .alert("Repair Complete", isPresented: $showRepairResult) {
                Button("OK") { }
            } message: {
                Text(repairMessage)
            }
            .alert("Clear Stuck Sync Flags?", isPresented: $showClearStuckFlagsConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear") {
                    syncThrottler.clearInProgressFlagsForDiagnostics(reason: "sync-diagnostics")
                }
            } message: {
                Text("This only clears in-memory import/export in-progress flags when CloudKit misses end events. It does not delete or reset any data.")
            }
            .sheet(isPresented: $showSyncBlockedSupport) {
                ContactSupportView(
                    initialReportType: .bug,
                    initialSubject: "Sync blocked after CloudKit export failure",
                    initialDetails: syncBlockedSupportDetails
                )
            }
        }
    }

    private var diagnosticsList: some View {
        List {
            // ── Always visible to users ──────────────────────────────
            syncStatusSummarySection
            syncBlockedRecoverySection
            debugActionsSection

            // ── Technical / developer-only sections ──────────────────
            #if DEBUG || targetEnvironment(simulator)
            iCloudSection
            cloudKitContainerSection
            liveCloudKitSection
            convergenceSection
            cloudflareSyncPOCSection
            localDataSection
            databaseHealthSection
            stylesheetsSection
            #endif
        }
    }

    @ViewBuilder
    private var syncBlockedRecoverySection: some View {
        if syncThrottler.hasBlockingExportFailure {
            Section("Sync Blocked") {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CloudKit rejected the last export")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Changes on this device may not have reached your other devices. Treat this device as the possible source of truth until recovery is complete.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)

                if let message = syncThrottler.lastExportFailureMessage, !message.isEmpty {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Stop editing, importing, deleting, or renaming projects on other devices.", systemImage: "1.circle")
                    Label("Check which device has the project list you want to keep.", systemImage: "2.circle")
                    Label("Do not reset this device if it has the desired data.", systemImage: "3.circle")
                    Label("Contact support from this screen before recovery.", systemImage: "4.circle")
                    Label("If this device is the source of truth, use zone recovery from this device only; reset other devices only after export succeeds.", systemImage: "5.circle")
                }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

                Button("Contact Support") {
                    showSyncBlockedSupport = true
                }

                Text("The support report includes sync diagnostics automatically. Reset Sync Database deletes local data on this device. Use it only on stale devices after the source-of-truth device has exported successfully.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var syncBlockedSupportDetails: String {
        var lines: [String] = []
        lines.append("Sync is blocked because CloudKit rejected the last export.")
        lines.append("")
        lines.append("What I was doing before the error:")
        lines.append("-")
        lines.append("")
        lines.append("Which device currently has the project list I want to keep:")
        lines.append("-")
        lines.append("")
        if let message = syncThrottler.lastExportFailureMessage, !message.isEmpty {
            lines.append("Last export failure:")
            lines.append(message)
        }
        return lines.joined(separator: "\n")
    }

    /// Compact status summary for release users.
    private var syncStatusSummarySection: some View {
        Section("iCloud Sync Status") {
            HStack {
                let blocked = syncThrottler.hasBlockingExportFailure
                let healthy = syncThrottler.importSucceeded && syncThrottler.exportSucceeded && !syncThrottler.isRateLimited
                Image(systemName: healthy ? "checkmark.icloud.fill" : (blocked ? "xmark.icloud.fill" : "exclamationmark.icloud.fill"))
                    .foregroundStyle(healthy ? .green : (blocked ? .red : .orange))
                VStack(alignment: .leading, spacing: 2) {
                    Text(healthy ? "Sync is working normally" : (blocked ? "Sync is blocked" : "Sync may need attention"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let lastSync = syncThrottler.lastSyncTime {
                        Text("Last activity: \(lastSync.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            if convergenceMismatchCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(convergenceMismatchCount) project(s) may have stale data on this device")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if syncThrottler.isRateLimited {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundStyle(.red)
                    Text("Sync is temporarily rate-limited by iCloud. This clears automatically.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
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
            let _ = syncThrottler.hasActiveCloudKitEvent
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
            LabeledContent("Export Rate-Limit Streak", value: "\(syncThrottler.consecutiveExportRateLimits)")
            LabeledContent("Manual Kick Paused", value: syncThrottler.isManualKickPaused ? "Yes" : "No")
            LabeledContent("Import Network Failures", value: "\(syncThrottler.consecutiveImportNetworkFailures)")
            LabeledContent("Import Failures (total)", value: "\(syncThrottler.consecutiveImportFailures)")
            if syncThrottler.autoResetScheduled {
                LabeledContent("Auto-Reset", value: "Scheduled (relaunch to apply)")
                    .foregroundStyle(.orange)
            }
            LabeledContent("CK Subscription", value: subscriptionStatus)

            if let lastSync = syncThrottler.lastSyncTime {
                LabeledContent("Last Remote Event") {
                    Text(lastSync.formatted(date: .omitted, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            if let lastMirroring = syncThrottler.lastMirroringEventTime {
                LabeledContent("Last Mirroring Event") {
                    Text(lastMirroring.formatted(date: .omitted, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            if hasLikelyStaleInProgressFlags {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Import/export flag appears stale (no recent mirroring end event)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 2)
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

            Button("Copy Full Diagnostics Snapshot") {
                copyDiagnosticsSnapshot(includeVerboseInventory: true)
            }

            Button("Clear Event Timeline") {
                syncThrottler.clearRecentCloudKitEvents()
            }

            if hasLikelyStaleInProgressFlags {
                Button("Clear Stuck Sync Flags") {
                    showClearStuckFlagsConfirmation = true
                }
            }
        }
    }

    private var hasLikelyStaleInProgressFlags: Bool {
        guard syncThrottler.importInProgress || syncThrottler.exportInProgress else { return false }
        guard !syncThrottler.isSyncing else { return false }

        let reference = syncThrottler.lastMirroringEventTime
            ?? syncThrottler.importStartTime
            ?? syncThrottler.exportStartTime
            ?? Date()

        return Date().timeIntervalSince(reference) > 20
    }

    private var convergenceSection: some View {
        Section("Convergence") {
            HStack {
                Text("Status")
                Spacer()
                Text(convergenceStatus)
                    .font(.caption)
                    .foregroundStyle(convergenceStatus.hasPrefix("✅") ? .green :
                                     convergenceStatus.hasPrefix("⚠️") ? .orange : .secondary)
            }

            LabeledContent("Mismatch Signals", value: "\(convergenceMismatchCount)")

            if let checkedAt = convergenceLastCheckedAt {
                LabeledContent("Last Checked") {
                    Text(checkedAt.formatted(date: .omitted, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            Button("Re-check Convergence") {
                analyzeConvergenceSignals()
            }
        }
    }

    private func cloudKitEventRow(_ event: CloudKitEventLogEntry) -> some View {
        let isResetLatencyEvent = event.type == "mirroring"
            && event.phase == "first-import-started"
            && event.status == "latency"

        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                if isResetLatencyEvent {
                    Label("\(event.type) · \(event.phase) · \(event.status)", systemImage: "timer")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                } else {
                    Text("\(event.type) · \(event.phase) · \(event.status)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Spacer()
                Text(event.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !event.message.isEmpty {
                Text(event.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(isResetLatencyEvent ? 3 : 2)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, isResetLatencyEvent ? 6 : 0)
        .background(
            isResetLatencyEvent
                ? Color.orange.opacity(0.12)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func diagnosticsSnapshotText(includeVerboseInventory: Bool = false) -> String {
        _ = syncThrottler.hasActiveCloudKitEvent
        let now = Date()
        var lines: [String] = []
        lines.append("CloudKit Diagnostics Snapshot")
        lines.append("Generated: \(now.formatted(date: .complete, time: .standard))")
        lines.append("verbosity: \(includeVerboseInventory ? "full" : "compact")")
        lines.append("isSyncing: \(syncThrottler.isSyncing)")
        lines.append("remoteEventsTotal: \(syncThrottler.totalSyncEventCount)")
        lines.append("currentBurstCount: \(syncThrottler.syncEventCount)")
        lines.append("importInProgress: \(syncThrottler.importInProgress)")
        lines.append("exportInProgress: \(syncThrottler.exportInProgress)")
        lines.append("importCompleted: \(syncThrottler.importCompleted)")
        lines.append("importSucceeded: \(syncThrottler.importSucceeded)")
        lines.append("exportCompleted: \(syncThrottler.exportCompleted)")
        lines.append("exportSucceeded: \(syncThrottler.exportSucceeded)")
        lines.append("hasBlockingExportFailure: \(syncThrottler.hasBlockingExportFailure)")
        lines.append("lastExportFailureDomain: \(syncThrottler.lastExportFailureDomain ?? "nil")")
        lines.append("lastExportFailureCode: \(syncThrottler.lastExportFailureCode.map(String.init) ?? "nil")")
        lines.append("lastExportFailureMessage: \(syncThrottler.lastExportFailureMessage ?? "nil")")
        lines.append("isRateLimited: \(syncThrottler.isRateLimited)")
        lines.append("consecutiveExportRateLimits: \(syncThrottler.consecutiveExportRateLimits)")
        lines.append("isManualKickPaused: \(syncThrottler.isManualKickPaused)")
        lines.append("consecutiveImportNetworkFailures: \(syncThrottler.consecutiveImportNetworkFailures)")
        lines.append("consecutiveImportFailures: \(syncThrottler.consecutiveImportFailures)")
        lines.append("autoResetScheduled: \(syncThrottler.autoResetScheduled)")
        lines.append("isPostReset: \(syncThrottler.isPostReset)")
        lines.append("lastRemoteEvent: \(syncThrottler.lastSyncTime?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("lastMirroringEvent: \(syncThrottler.lastMirroringEventTime?.formatted(date: .omitted, time: .standard) ?? "nil")")
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

        let eventLimit = includeVerboseInventory ? 25 : 12
        for event in syncThrottler.recentCloudKitEvents.prefix(eventLimit) {
            let msg = event.message.isEmpty ? "" : " — \(event.message)"
            lines.append("- \(event.timestamp.formatted(date: .omitted, time: .standard)) | \(event.type) | \(event.phase) | \(event.status)\(msg)")
        }

        if !includeVerboseInventory && syncThrottler.recentCloudKitEvents.count > eventLimit {
            lines.append("- (truncated to \(eventLimit) events; use full snapshot for complete timeline)")
        }

        lines.append("")
        lines.append(contentsOf: projectInventoryLines(includeDetails: includeVerboseInventory, includeNaPoVariantSearch: includeVerboseInventory))
        lines.append("")
        lines.append(contentsOf: publicationInventoryLines(includeDetails: includeVerboseInventory))

        let tombstones = DeduplicationService.tombstoneDescriptions()
        lines.append("")
        lines.append("Zombie Tombstones: \(tombstones.count)")
        for t in tombstones {
            lines.append("- \(t.name) | type=\(t.type) | deleted=\(t.deletedAt.formatted(date: .abbreviated, time: .shortened))")
        }

        // Entity counts for debugging
        lines.append("")
        lines.append("Entity Counts (store):")
        let freshCtx = ModelContext(modelContext.container)
        let ssCount = (try? freshCtx.fetchCount(FetchDescriptor<StyleSheet>())) ?? -1
        let tsCount = (try? freshCtx.fetchCount(FetchDescriptor<TextStyleModel>())) ?? -1
        let isCount = (try? freshCtx.fetchCount(FetchDescriptor<ImageStyle>())) ?? -1
        let pfCount = (try? freshCtx.fetchCount(FetchDescriptor<PoetryFormModel>())) ?? -1
        let folderCount = (try? freshCtx.fetchCount(FetchDescriptor<Folder>())) ?? -1
        let fileCount = (try? freshCtx.fetchCount(FetchDescriptor<TextFile>())) ?? -1
        let versionCount = (try? freshCtx.fetchCount(FetchDescriptor<Version>())) ?? -1
        let collectionCount = (try? freshCtx.fetchCount(FetchDescriptor<PoetryCollection>())) ?? -1
        lines.append("- StyleSheet: \(ssCount)")
        lines.append("- TextStyleModel: \(tsCount)")
        lines.append("- ImageStyle: \(isCount)")
        lines.append("- PoetryFormModel: \(pfCount)")
        lines.append("- Folder: \(folderCount)")
        lines.append("- TextFile: \(fileCount)")
        lines.append("- Version: \(versionCount)")
        lines.append("- PoetryCollection: \(collectionCount)")

        // Inline notes payload diagnostics (helps catch oversized text fields).
        lines.append("")
        lines.append(contentsOf: notesPayloadLines())

        // Pending CloudKit exports from ANSCKRECORDMETADATA
        lines.append("")
        lines.append(contentsOf: pendingExportLines())

        return lines.joined(separator: "\n")
    }

    private func copyDiagnosticsSnapshot(includeVerboseInventory: Bool = false) {
        let snapshot = diagnosticsSnapshotText(includeVerboseInventory: includeVerboseInventory)

        #if canImport(UIKit)
        UIPasteboard.general.string = snapshot
        #endif

        syncForceStatus = includeVerboseInventory
            ? "✅ Full diagnostics snapshot copied to clipboard"
            : "✅ Diagnostics snapshot copied to clipboard"
    }

    private func copyGuidedRecoveryReport() {
        let guidedResult = guidedRecoveryStatus.isEmpty
            ? "(no guided recovery run captured yet)"
            : guidedRecoveryStatus

        let report = [
            "Guided Recovery Report",
            "Generated: \(Date().formatted(date: .complete, time: .standard))",
            "",
            "Guided Recovery Result:",
            guidedResult,
            "",
            diagnosticsSnapshotText(includeVerboseInventory: true)
        ].joined(separator: "\n")

        #if canImport(UIKit)
        UIPasteboard.general.string = report
        #endif

        syncForceStatus = "✅ Guided recovery report copied to clipboard"
    }

    private func projectInventoryLines(includeDetails: Bool = true, includeNaPoVariantSearch: Bool = true) -> [String] {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("Project Inventory")

        let queryProjects = sortedProjectsForInventory(projects)
        lines.append("Source: @Query (main context cache)")
        if includeDetails {
            for project in queryProjects {
                lines.append(projectInventoryLine(project, formatter: formatter))
            }
        } else {
            lines.append("- count=\(queryProjects.count)")
        }

        lines.append("")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        let freshContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Project>()
        let storeProjects = sortedProjectsForInventory((try? freshContext.fetch(descriptor)) ?? [])
        if includeDetails {
            for project in storeProjects {
                lines.append(projectInventoryLine(project, formatter: formatter))
            }
        } else {
            lines.append("- count=\(storeProjects.count)")
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

        // Keep this focused diagnostic only in full snapshots.
        if includeNaPoVariantSearch {
            lines.append("")
            lines.append("Diagnostic: Search for NaPoWriMo variants")
            let allStoredProjects = (try? freshContext.fetch(FetchDescriptor<Project>())) ?? []
            let napoVariants = allStoredProjects.filter {
                let name = $0.name ?? ""
                return name.lowercased().contains("napo")
            }
            if napoVariants.isEmpty {
                lines.append("- No projects with 'napo' in name found")
            } else {
                for project in napoVariants.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
                    lines.append("- FOUND: name='\(project.name ?? "?")' | id=\(project.id.uuidString) | trashed=\(project.isTrashed) | created=\(project.creationDate?.formatted() ?? "?")")
                }
            }
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

    private func publicationInventoryLines(includeDetails: Bool = true) -> [String] {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("Publication Inventory")

        let queryPublications = sortedPublicationsForInventory(publications)
        lines.append("Source: @Query (main context cache)")
        if includeDetails {
            for publication in queryPublications {
                lines.append(publicationInventoryLine(publication, formatter: formatter))
            }
        } else {
            lines.append("- count=\(queryPublications.count)")
        }

        lines.append("")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        let freshContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Publication>()
        let storePublications = sortedPublicationsForInventory((try? freshContext.fetch(descriptor)) ?? [])
        if includeDetails {
            for publication in storePublications {
                lines.append(publicationInventoryLine(publication, formatter: formatter))
            }
        } else {
            lines.append("- count=\(storePublications.count)")
        }

        let queryNameByID = Dictionary(uniqueKeysWithValues: queryPublications.map { ($0.id, $0.name) })
        let storeNameByID = Dictionary(uniqueKeysWithValues: storePublications.map { ($0.id, $0.name) })
        let allIDs = Set(queryNameByID.keys).union(storeNameByID.keys)
        let nameMismatches = allIDs.filter { queryNameByID[$0] != storeNameByID[$0] }.sorted { $0.uuidString < $1.uuidString }

        lines.append("")
        lines.append("Publication Inventory Comparison")
        lines.append("- @Query count=\(queryPublications.count) | Store count=\(storePublications.count)")
        lines.append("- Name mismatches by id=\(nameMismatches.count)")
        for id in nameMismatches {
            lines.append("  - id=\(id.uuidString) | @Query='\(queryNameByID[id] ?? "")' | Store='\(storeNameByID[id] ?? "")'")
        }

        return lines
    }

    private func sortedPublicationsForInventory(_ inputPublications: [Publication]) -> [Publication] {
        inputPublications.sorted { lhs, rhs in
            let lhsCreated = lhs.createdDate
            let rhsCreated = rhs.createdDate
            if lhsCreated != rhsCreated {
                return lhsCreated < rhsCreated
            }
            return lhs.name < rhs.name
        }
    }

    private func publicationInventoryLine(_ publication: Publication, formatter: ISO8601DateFormatter) -> String {
        let created = formatter.string(from: publication.createdDate)
        let modified = formatter.string(from: publication.modifiedDate)
        let projectID = publication.project?.id.uuidString ?? "nil"
        let projectName = publication.project?.name ?? "nil"
        let submissionCount = publication.submissions?.count ?? 0
        return "- name=\(publication.name) | id=\(publication.id.uuidString) | type=\(publication.type?.rawValue ?? "nil") | project=\(projectName) | projectID=\(projectID) | created=\(created) | modified=\(modified) | submissions=\(submissionCount)"
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
            LabeledContent("Publications", value: "\(publications.count)")
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

            orphanedPublicationsStatusRow

            if orphanedPublicationCount > 0 {
                orphanedPublicationsRepairRow
            }

            duplicateStyleSheetsStatusRow

            if duplicateStyleSheetCount > 0 {
                duplicateStyleSheetsRepairRow
            }

            duplicateCheckRow

            if duplicateCount > 0 {
                duplicateReferencesRepairRow
            }

            tombstoneStatusRow

            if tombstoneCount > 0 {
                tombstoneClearRow
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Orphaned Files (No Folder + No Trash)")
                Spacer()
                Text("\(orphanedFileCount) found")
                    .foregroundColor(orphanedFileCount > 0 ? .orange : .secondary)
            }
            if orphanedFileExcludedCount > 0 {
                Text("Excluded \(orphanedFileExcludedCount) unparented file(s) still linked via Trash/other relationships")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            checkForOrphans()
        }
    }

    private var orphanedFoldersRepairRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(orphanedFolderDetails, id: \.id) { detail in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detail.name)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Text("\(detail.fileCount) files, \(detail.subfolderCount) subfolders")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        deleteOrphanedFolder(id: detail.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }

            if !orphanReassignStatus.isEmpty {
                Text(orphanReassignStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var orphanedFilesRepairRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(orphanedFileDetails, id: \.id) { detail in
                HStack {
                    Text(detail.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(role: .destructive) {
                        deleteOrphanedFile(id: detail.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }
            if orphanedFileDetails.isEmpty {
                Text("No orphaned files found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !orphanReassignStatus.isEmpty {
                Text(orphanReassignStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var orphanedPublicationsStatusRow: some View {
        HStack {
            Text("Orphaned Publications")
            Spacer()
            Text("\(orphanedPublicationCount) found")
                .foregroundColor(orphanedPublicationCount > 0 ? .orange : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            checkForOrphanedPublications()
        }
    }

    private var orphanedPublicationsRepairRow: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text("Orphaned Publication Cleanup Disabled")
            Spacer()
        }
        .foregroundColor(.orange)
        .contentShape(Rectangle())
        .onTapGesture {
            deleteOrphanedPublications()
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

    private var tombstoneStatusRow: some View {
        HStack {
            Text("Zombie Tombstones (Local Device)")
            Spacer()
            Text("\(tombstoneCount) active")
                .foregroundColor(tombstoneCount > 0 ? .red : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tombstoneCount = DeduplicationService.tombstoneCount
        }
    }

    private var tombstoneClearRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "trash.slash")
                Text("Clear All Tombstones")
                Spacer()
            }
            .foregroundColor(.red)
            .contentShape(Rectangle())
            .onTapGesture {
                clearAllTombstones()
            }
            ForEach(DeduplicationService.tombstoneDescriptions(), id: \.name) { t in
                Text("\(t.name) (\(t.type)) — \(t.deletedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
            
            if syncResetScheduled || syncThrottler.autoResetScheduled {
                Text("Sync reset scheduled — quit and relaunch the app to complete.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if zoneWasDeletedThisSession {
                Text("⚠️ Zone was just deleted. Quit and relaunch to re-export local data. Do NOT reset the local database or all data will be lost.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button("Reset Sync Database") {
                    showResetSyncConfirmation = true
                }
                .foregroundStyle(.red)

                Text("Deletes local data on this device and re-imports from iCloud on next launch. iCloud data is not deleted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Section("Guided Recovery") {
            Text("Run a safe recovery sequence before scheduling a local cache rebuild.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(isGuidedRecoveryInProgress ? "Running Guided Recovery…" : "Run Guided Recovery") {
                runGuidedRecovery()
            }
            .disabled(isGuidedRecoveryInProgress)

            if !guidedRecoveryStatus.isEmpty {
                Text(guidedRecoveryStatus)
                    .font(.caption)
                    .foregroundStyle(guidedRecoveryStatus.hasPrefix("✅") ? .green :
                                     guidedRecoveryStatus.hasPrefix("❌") ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                Button("Copy Guided Recovery Report") {
                    copyGuidedRecoveryReport()
                }
                .disabled(isGuidedRecoveryInProgress)
            }
        }
        .alert("Reset Sync Database?", isPresented: $showResetSyncConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Local Data & Re-Import", role: .destructive) {
                UserDefaults.standard.set(true, forKey: "resetSyncOnNextLaunch")
                syncResetScheduled = true
            }
        } message: {
            Text("⚠️ This DELETES ALL LOCAL DATA on this device and re-imports from CloudKit on next launch. Only use this if the CloudKit zone has good data. If you just deleted the CloudKit zone, do NOT use this — just quit and relaunch instead.")
        }
        .alert("Delete CloudKit Zone?", isPresented: $showDeleteZoneConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Zone", role: .destructive) {
                deleteCloudKitZone()
            }
        } message: {
            Text("⚠️ This permanently deletes ALL data in the CloudKit zone. This device's local data is preserved. After deleting, just QUIT AND RELAUNCH this app — it will re-export local data to a fresh zone. Do NOT use 'Reset Sync Database' on this device afterwards or you will lose everything.")
        }

        if showAdvancedZoneRecovery {
        Section("Zone Recovery") {
            Button("Force Re-export All Data") {
                forceReexportAllData()
            }
            .foregroundStyle(.orange)

            if !reexportStatus.isEmpty {
                Text(reexportStatus)
                    .font(.caption)
                    .foregroundStyle(reexportStatus.hasPrefix("✅") ? .green :
                                     reexportStatus.hasPrefix("❌") ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Delete CloudKit Zone") {
                showDeleteZoneConfirmation = true
            }
            .foregroundStyle(.red)

            if !zoneDeleteStatus.isEmpty {
                Text(zoneDeleteStatus)
                    .font(.caption)
                    .foregroundStyle(zoneDeleteStatus.hasPrefix("✅") ? .green : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Verify Zone Content") {
                verifyZoneContent()
            }
            .foregroundStyle(.blue)

            if !zoneVerifyStatus.isEmpty {
                Text(zoneVerifyStatus)
                    .font(.caption)
                    .foregroundStyle(zoneVerifyStatus.hasPrefix("✅") ? .green :
                                     zoneVerifyStatus.hasPrefix("❌") ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Button("List & Delete Foreign Zones") {
                listAndDeleteForeignZones()
            }
            .foregroundStyle(.orange)

            if !foreignZoneStatus.isEmpty {
                Text(foreignZoneStatus)
                    .font(.caption)
                    .foregroundStyle(foreignZoneStatus.hasPrefix("✅") ? .green :
                                     foreignZoneStatus.hasPrefix("❌") ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Button("Purge Orphaned Zone Records") {
                showPurgeOrphansConfirmation = true
            }
            .foregroundStyle(.red)
            .alert("Purge Orphaned Zone Records?", isPresented: $showPurgeOrphansConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Purge", role: .destructive) {
                    purgeOrphanedZoneRecords()
                }
            } message: {
                Text("This deletes all records from the CloudKit zone EXCEPT StyleSheet, TextStyleModel, PoetryFormModel, and ImageStyle. Use when the zone has orphaned child records with no parent Project.")
            }

            if !purgeOrphansStatus.isEmpty {
                Text(purgeOrphansStatus)
                    .font(.caption)
                    .foregroundStyle(purgeOrphansStatus.hasPrefix("✅") ? .green :
                                     purgeOrphansStatus.hasPrefix("❌") ? .red : .orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
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

#if DEBUG || targetEnvironment(simulator)
    private var cloudflareSyncPOCSection: some View {
        Section("Cloudflare Sync POC") {
            Text("Debug-only client for the deployed /api/sync/v1 Worker. This does not replace CloudKit or apply pulled changes locally.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Endpoint", value: CloudflareSyncPOCService.shared.configuredEndpoint)
            LabeledContent("Token", value: CloudflareSyncPOCService.shared.hasToken ? "Configured" : "Missing")

            Picker("Source Project", selection: cloudflareSyncPOCProjectSelection) {
                ForEach(cloudflareSyncPOCProjects, id: \.id) { project in
                    Text(project.name ?? "Untitled").tag(Optional(project.id))
                }
            }
            .disabled(isCloudflareSyncPOCRunning || cloudflareSyncPOCProjects.isEmpty)

            if let project = selectedCloudflareSyncPOCProjects.first {
                LabeledContent("Selected", value: project.name ?? "Untitled")
            }

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Check Cloudflare Health") {
                runCloudflareSyncPOCHealthCheck()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Check Remote Changes") {
                runCloudflareSyncPOCHeadCheck()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Sync State Summary") {
                runCloudflareSyncPOCSyncStateSummary()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Local Cursor Summary") {
                runCloudflareSyncPOCLocalCursorSummary()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Trigger Status") {
                runCloudflareSyncPOCTriggerStatusSummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Orchestrator Policy") {
                runCloudflareSyncPOCOrchestratorPolicySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Manual Sync Policy") {
                runCloudflareSyncPOCManualSyncPolicySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Production Apply Readiness") {
                runCloudflareSyncPOCProductionApplyReadinessSummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Production Apply Operation Coverage") {
                runCloudflareSyncPOCProductionApplyOperationCoverageSummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Production Apply Transaction Safety") {
                runCloudflareSyncPOCProductionApplyTransactionSafetySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Production Apply Model Family Coverage") {
                runCloudflareSyncPOCProductionApplyModelFamilyCoverageSummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Production Apply CloudKit Coexistence") {
                runCloudflareSyncPOCProductionApplyCloudKitCoexistenceSummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Production Apply Migration Cutover") {
                runCloudflareSyncPOCProductionApplyMigrationCutoverSummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Launch Policy") {
                runCloudflareSyncPOCLaunchPolicySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Foreground Policy") {
                runCloudflareSyncPOCForegroundPolicySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Network Recovery Policy") {
                runCloudflareSyncPOCNetworkRecoveryPolicySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Silent Push Policy") {
                runCloudflareSyncPOCSilentPushPolicySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Background Refresh Policy") {
                runCloudflareSyncPOCBackgroundRefreshPolicySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Debounce State") {
                runCloudflareSyncPOCOrchestratorDebounceSummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Show Network Recovery Eligibility") {
                runCloudflareSyncPOCNetworkRecoveryEligibilitySummary()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Check And Pull Into Scratch Store") {
                runCloudflareSyncPOCCheckAndPullIntoScratchStore()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Sync Now Dry Run") {
                runCloudflareSyncPOCSyncNowDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Foreground Trigger Dry Run") {
                runCloudflareSyncPOCForegroundTriggerDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Foreground Debounce Skip Probe") {
                runCloudflareSyncPOCForegroundDebounceSkipProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Launch Trigger Dry Run") {
                runCloudflareSyncPOCLaunchTriggerDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Background Refresh Trigger Dry Run") {
                runCloudflareSyncPOCBackgroundRefreshTriggerDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Background Refresh Expired Budget Probe") {
                runCloudflareSyncPOCBackgroundRefreshExpiredBudgetProbe()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Network Recovery Trigger Dry Run") {
                runCloudflareSyncPOCNetworkRecoveryTriggerDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Network Recovery If Eligible Dry Run") {
                runCloudflareSyncPOCNetworkRecoveryIfEligibleDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Silent Push Trigger Dry Run") {
                runCloudflareSyncPOCSilentPushTriggerDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Lifecycle Sequence Dry Run") {
                runCloudflareSyncPOCLifecycleSequenceDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Single-Flight Guard Probe") {
                runCloudflareSyncPOCSingleFlightGuardProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Transport Failure Classification Probe") {
                runCloudflareSyncPOCTransportFailureClassificationProbe()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Network Recovery Eligibility Probe") {
                runCloudflareSyncPOCNetworkRecoveryEligibilityProbe()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Network Recovery Debounce Eligibility Probe") {
                runCloudflareSyncPOCNetworkRecoveryDebounceEligibilityProbe()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Network Recovery In-Flight Eligibility Probe") {
                runCloudflareSyncPOCNetworkRecoveryInFlightEligibilityProbe()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Silent Push Payload Guardrail Probe") {
                runCloudflareSyncPOCSilentPushPayloadGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Silent Push Matching Payload Dry Run") {
                runCloudflareSyncPOCSilentPushMatchingPayloadDryRun()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Remote Change Probe") {
                runCloudflareSyncPOCRemoteChangeProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Text File Update Probe") {
                runCloudflareSyncPOCExistingTextFileUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing StyleSheet Update Probe") {
                runCloudflareSyncPOCExistingStyleSheetUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Text Style Update Probe") {
                runCloudflareSyncPOCExistingTextStyleUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Image Style Update Probe") {
                runCloudflareSyncPOCExistingImageStyleUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Page Setup Update Probe") {
                runCloudflareSyncPOCExistingPageSetupUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Printer Paper Update Probe") {
                runCloudflareSyncPOCExistingPrinterPaperUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Publication Update Probe") {
                runCloudflareSyncPOCExistingPublicationUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Submission Update Probe") {
                runCloudflareSyncPOCExistingSubmissionUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Submitted File Update Probe") {
                runCloudflareSyncPOCExistingSubmittedFileUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Folder Update Probe") {
                runCloudflareSyncPOCExistingFolderUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Version Update Probe") {
                runCloudflareSyncPOCExistingVersionUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Comment Update Probe") {
                runCloudflareSyncPOCExistingCommentUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Footnote Update Probe") {
                runCloudflareSyncPOCExistingFootnoteUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Note Entry Update Probe") {
                runCloudflareSyncPOCExistingNoteEntryUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Contributor Update Probe") {
                runCloudflareSyncPOCExistingContributorUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Reference Entry Update Probe") {
                runCloudflareSyncPOCExistingReferenceEntryUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Glossary Entry Update Probe") {
                runCloudflareSyncPOCExistingGlossaryEntryUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Index Entry Update Probe") {
                runCloudflareSyncPOCExistingIndexEntryUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Poetry Form Update Probe") {
                runCloudflareSyncPOCExistingPoetryFormUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Poetry Collection Update Probe") {
                runCloudflareSyncPOCExistingPoetryCollectionUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Chapter Update Probe") {
                runCloudflareSyncPOCExistingChapterUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Act Update Probe") {
                runCloudflareSyncPOCExistingActUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Book Update Probe") {
                runCloudflareSyncPOCExistingBookUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Prose Section Update Probe") {
                runCloudflareSyncPOCExistingProseSectionUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Story Scene Update Probe") {
                runCloudflareSyncPOCExistingStorySceneUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Character Update Probe") {
                runCloudflareSyncPOCExistingCharacterUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Location Update Probe") {
                runCloudflareSyncPOCExistingLocationUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Plot Element Update Probe") {
                runCloudflareSyncPOCExistingPlotElementUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Ordered Text File Link Update Probe") {
                runCloudflareSyncPOCExistingOrderedTextFileLinkUpdateProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Remote Delete Probe") {
                runCloudflareSyncPOCRemoteDeleteProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Project Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingProjectDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Folder Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingFolderDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Folder Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingFolderRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Text File Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingTextFileDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Text File Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingTextFileRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Version Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingVersionDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Version Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingVersionRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Comment Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingCommentDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Comment Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingCommentRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Footnote Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingFootnoteDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Footnote Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingFootnoteRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Relationship Link Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingRelationshipLinkDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Relationship Link Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingRelationshipLinkRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Note Entry Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingNoteEntryDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Note Entry Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingNoteEntryRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Contributor Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingContributorDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Contributor Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingContributorRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Reference Entry Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingReferenceEntryDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Reference Entry Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingReferenceEntryRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Glossary Entry Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingGlossaryEntryDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Glossary Entry Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingGlossaryEntryRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Index Entry Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingIndexEntryDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Index Entry Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingIndexEntryRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Publication Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingPublicationDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Publication Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingPublicationRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Submission Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingSubmissionDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Submission Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingSubmissionRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Submitted File Delete Guardrail Probe") {
                runCloudflareSyncPOCExistingSubmittedFileDeleteGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Submitted File Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingSubmittedFileRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Remote Restore Probe") {
                runCloudflareSyncPOCRemoteRestoreProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Existing Project Restore Guardrail Probe") {
                runCloudflareSyncPOCExistingProjectRestoreGuardrailProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Missing Dependency Probe") {
                runCloudflareSyncPOCMissingDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Satisfied Dependency Probe") {
                runCloudflareSyncPOCSatisfiedDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Satisfied Dependency State Summary Probe") {
                runCloudflareSyncPOCSatisfiedDependencyStateSummaryProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Folder Dependency Probe") {
                runCloudflareSyncPOCFolderDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Annotation Dependency Probe") {
                runCloudflareSyncPOCAnnotationDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Style Dependency Probe") {
                runCloudflareSyncPOCStyleDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Submission Dependency Probe") {
                runCloudflareSyncPOCSubmissionDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Poetry Collection Dependency Probe") {
                runCloudflareSyncPOCPoetryCollectionDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Prose Section Dependency Probe") {
                runCloudflareSyncPOCProseSectionDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Remote Note Entry CreateMissing Probe") {
                runCloudflareSyncPOCNoteEntryDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Glossary Citation Dependency Probe") {
                runCloudflareSyncPOCGlossaryCitationDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Reference Entry Dependency Probe") {
                runCloudflareSyncPOCReferenceEntryDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Index Entry Dependency Probe") {
                runCloudflareSyncPOCIndexEntryDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Contributor Entry Dependency Probe") {
                runCloudflareSyncPOCContributorEntryDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Page Setup Dependency Probe") {
                runCloudflareSyncPOCPageSetupDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Custom Attribute Dependency Probe") {
                runCloudflareSyncPOCCustomAttributeDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Trash Item Dependency Probe") {
                runCloudflareSyncPOCTrashItemDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Manuscript Review Dependency Probe") {
                runCloudflareSyncPOCManuscriptReviewDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Poetry Form Dependency Probe") {
                runCloudflareSyncPOCPoetryFormDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Story Link Dependency Probe") {
                runCloudflareSyncPOCStoryLinkDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Location Link Dependency Probe") {
                runCloudflareSyncPOCLocationLinkDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Scene Character Dependency Probe") {
                runCloudflareSyncPOCSceneCharacterDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Scene Location Dependency Probe") {
                runCloudflareSyncPOCSceneLocationDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Scene Chapter Dependency Probe") {
                runCloudflareSyncPOCSceneChapterDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Scene Act Dependency Probe") {
                runCloudflareSyncPOCSceneActDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Scene Book Dependency Probe") {
                runCloudflareSyncPOCSceneBookDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Scene Plot Dependency Probe") {
                runCloudflareSyncPOCScenePlotDependencyProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Unsupported Operation Probe") {
                runCloudflareSyncPOCUnsupportedOperationProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run No-Payload Probe") {
                runCloudflareSyncPOCNoPayloadProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Preview Pending Apply") {
                runCloudflareSyncPOCPendingApplyPreview()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Materialize Pending Apply Preview") {
                runCloudflareSyncPOCMaterializePendingApplyPreview()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Pull Pending Changes Into Scratch Store") {
                runCloudflareSyncPOCPullPendingChangesIntoScratchStore()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Inspect Pending Apply Scratch Store") {
                runCloudflareSyncPOCInspectPendingApplyScratchStore()
            }
            .disabled(isCloudflareSyncPOCRunning)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Pull Pending Changes") {
                runCloudflareSyncPOCPullPendingChanges()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Push/Pull Project Sample") {
                runCloudflareSyncPOCPushPull()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Create Remote Snapshot") {
                runCloudflareSyncPOCSnapshot()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Preview Remote Import") {
                runCloudflareSyncPOCImportPreview()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Materialize Isolated Import") {
                runCloudflareSyncPOCMaterializedImport()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            Button(isCloudflareSyncPOCRunning ? "Running…" : "Run Tombstone Probe") {
                runCloudflareSyncPOCTombstoneProbe()
            }
            .disabled(isCloudflareSyncPOCRunning || projects.isEmpty)

            if !cloudflareSyncPOCStatus.isEmpty {
                Button("Copy Cloudflare Status") {
                    UIPasteboard.general.string = cloudflareSyncPOCStatus
                }

                Text(cloudflareSyncPOCStatus)
                    .font(.body)
                    .foregroundStyle(cloudflareSyncPOCStatus.hasPrefix("✅") ? .green :
                                     cloudflareSyncPOCStatus.hasPrefix("❌") ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if !CloudflareSyncPOCService.shared.hasToken {
                Text("Set cloudflareSyncPOCToken in UserDefaults before running authenticated POC calls.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    private var cloudflareSyncPOCProjects: [Project] {
        projects
            .filter { !$0.isTrashed }
            .sorted { ($0.name ?? "Untitled", $0.id.uuidString) < ($1.name ?? "Untitled", $1.id.uuidString) }
    }

    private var cloudflareSyncPOCProjectSelection: Binding<UUID?> {
        Binding(
            get: {
                if let selectedCloudflareSyncPOCProjectId,
                   cloudflareSyncPOCProjects.contains(where: { $0.id == selectedCloudflareSyncPOCProjectId }) {
                    return selectedCloudflareSyncPOCProjectId
                }
                return cloudflareSyncPOCProjects.first?.id
            },
            set: { selectedCloudflareSyncPOCProjectId = $0 }
        )
    }

    private var selectedCloudflareSyncPOCProjects: [Project] {
        guard let selectedId = cloudflareSyncPOCProjectSelection.wrappedValue,
              let project = cloudflareSyncPOCProjects.first(where: { $0.id == selectedId }) else {
            return []
        }
        return [project]
    }

    private func runCloudflareSyncPOCHealthCheck() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Checking Cloudflare sync POC…"

        Task {
            do {
                let health = try await CloudflareSyncPOCService.shared.fetchHealth()
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ Phase \(health.phase) \(health.version) db=\(health.syncDbConfigured) blobs=\(health.syncBlobsConfigured) auth=\(health.authConfigured)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Health check failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCHeadCheck() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Checking Cloudflare sync POC remote head…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.checkRemoteChanges(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Remote head check failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSyncStateSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC state summary…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.syncStateSummary(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Sync state summary failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCLocalCursorSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC local cursor summary…"

        Task {
            do {
                let result = try await MainActor.run {
                    try CloudflareSyncPOCService.shared.localCursorSummary(projects: selectedCloudflareSyncPOCProjects)
                }
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Local cursor summary failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCTriggerStatusSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC trigger status…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.triggerStatusSummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCOrchestratorPolicySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC orchestrator policy…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.orchestratorPolicySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCManualSyncPolicySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC manual sync policy…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.manualSyncPolicySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCProductionApplyReadinessSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC production apply readiness…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.productionApplyReadinessSummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCProductionApplyOperationCoverageSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC production apply operation coverage…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.productionApplyOperationCoverageSummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCProductionApplyTransactionSafetySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC production apply transaction safety…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.productionApplyTransactionSafetySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCProductionApplyModelFamilyCoverageSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC production apply model family coverage…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.productionApplyModelFamilyCoverageSummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCProductionApplyCloudKitCoexistenceSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC production apply CloudKit coexistence…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.productionApplyCloudKitCoexistenceSummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCProductionApplyMigrationCutoverSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC production apply migration cutover…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.productionApplyMigrationCutoverSummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCLaunchPolicySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC launch policy…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.launchPolicySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCForegroundPolicySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC foreground policy…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.foregroundPolicySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCNetworkRecoveryPolicySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC network recovery policy…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.networkRecoveryPolicySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCSilentPushPolicySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC silent push policy…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.silentPushPolicySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCBackgroundRefreshPolicySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC background refresh policy…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.backgroundRefreshPolicySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCOrchestratorDebounceSummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC debounce state…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.orchestratorDebounceSummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCNetworkRecoveryEligibilitySummary() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Loading Cloudflare sync POC network recovery eligibility…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.networkRecoveryEligibilitySummary()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCCheckAndPullIntoScratchStore() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Checking Cloudflare sync POC remote head and pulling into scratch store if needed…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.checkAndPullPendingChangesIntoScratchStore(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Check and pull into scratch store failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSyncNowDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC Sync Now dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.syncNowDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Sync Now dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCForegroundTriggerDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC foreground trigger dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.foregroundSyncDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Foreground trigger dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCForegroundDebounceSkipProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC foreground debounce skip probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.foregroundDebounceSkipProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Foreground debounce skip probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCLaunchTriggerDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC launch trigger dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.launchSyncDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Launch trigger dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCBackgroundRefreshTriggerDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC background refresh trigger dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.backgroundRefreshSyncDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Background refresh trigger dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCBackgroundRefreshExpiredBudgetProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC background refresh expired-budget probe…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.backgroundRefreshExpiredBudgetProbe()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCNetworkRecoveryTriggerDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC network recovery trigger dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.networkRecoverySyncDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Network recovery trigger dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCNetworkRecoveryIfEligibleDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC gated network recovery dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.networkRecoveryIfEligibleDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Gated network recovery dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCNetworkRecoveryInFlightEligibilityProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC network recovery in-flight eligibility probe…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.networkRecoveryInFlightEligibilityProbe()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCSilentPushTriggerDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC silent push trigger dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.silentPushSyncDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Silent push trigger dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCLifecycleSequenceDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC lifecycle sequence dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.lifecycleSequenceDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Lifecycle sequence dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSingleFlightGuardProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC single-flight guard probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.singleFlightGuardProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Single-flight guard probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCTransportFailureClassificationProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC transport failure classification probe…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.transportFailureClassificationProbe()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCNetworkRecoveryEligibilityProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC network recovery eligibility probe…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.networkRecoveryEligibilityProbe()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCNetworkRecoveryDebounceEligibilityProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC network recovery debounce eligibility probe…"

        Task {
            let result = await MainActor.run {
                CloudflareSyncPOCService.shared.networkRecoveryDebounceEligibilityProbe()
            }
            await MainActor.run {
                cloudflareSyncPOCStatus = "✅ \(result.message)"
                isCloudflareSyncPOCRunning = false
            }
        }
    }

    private func runCloudflareSyncPOCSilentPushPayloadGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC silent push payload guardrail probe…"

        Task {
            do {
                let result = try await MainActor.run {
                    try CloudflareSyncPOCService.shared.silentPushPayloadGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                }
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Silent push payload guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSilentPushMatchingPayloadDryRun() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC silent push matching-payload dry run…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.silentPushMatchingPayloadDryRun(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Silent push matching-payload dry run failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCRemoteChangeProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC remote change probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteChangeProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Remote change probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingTextFileUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing text file update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingTextFileUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing text file update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingStyleSheetUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing stylesheet update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingStyleSheetUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing stylesheet update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingTextStyleUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing text style update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingTextStyleUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing text style update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingImageStyleUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing image style update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingImageStyleUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing image style update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPageSetupUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing page setup update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPageSetupUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing page setup update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPrinterPaperUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing printer paper update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPrinterPaperUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing printer paper update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPublicationUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing publication update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPublicationUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing publication update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingSubmissionUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing submission update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingSubmissionUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing submission update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingSubmittedFileUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing submitted file update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingSubmittedFileUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing submitted file update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingFolderUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing folder update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingFolderUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing folder update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingVersionUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing version update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingVersionUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing version update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingCommentUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing comment update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingCommentUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing comment update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingFootnoteUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing footnote update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingFootnoteUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing footnote update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingNoteEntryUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing note entry update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingNoteEntryUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing note entry update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingContributorUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing contributor update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingContributorUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing contributor update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingReferenceEntryUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing reference entry update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingReferenceEntryUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing reference entry update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingGlossaryEntryUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing glossary entry update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingGlossaryEntryUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing glossary entry update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingIndexEntryUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing index entry update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingIndexEntryUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing index entry update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPoetryFormUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing poetry form update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPoetryFormUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing poetry form update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPoetryCollectionUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing poetry collection update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPoetryCollectionUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing poetry collection update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingChapterUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing chapter update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingChapterUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing chapter update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingActUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing act update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingActUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing act update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingBookUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing book update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingBookUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing book update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingProseSectionUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing prose section update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingProseSectionUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing prose section update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingStorySceneUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing story scene update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingStorySceneUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing story scene update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingCharacterUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing character update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingCharacterUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing character update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingLocationUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing location update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingLocationUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing location update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPlotElementUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing plot element update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPlotElementUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing plot element update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCRemoteDeleteProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC remote delete probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteDeleteProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Remote delete probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingProjectDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing project delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingProjectDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing project delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingFolderDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing folder delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingFolderDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing folder delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingFolderRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing folder restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingFolderRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing folder restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingTextFileDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing text file delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingTextFileDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing text file delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingTextFileRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing text file restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingTextFileRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing text file restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingVersionDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing version delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingVersionDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing version delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingVersionRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing version restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingVersionRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing version restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingCommentDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing comment delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingCommentDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing comment delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingCommentRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing comment restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingCommentRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing comment restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingFootnoteDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing footnote delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingFootnoteDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing footnote delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingFootnoteRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing footnote restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingFootnoteRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing footnote restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingRelationshipLinkDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing relationship link delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingRelationshipLinkDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing relationship link delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingRelationshipLinkRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing relationship link restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingRelationshipLinkRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing relationship link restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingNoteEntryDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing note entry delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingNoteEntryDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing note entry delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingNoteEntryRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing note entry restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingNoteEntryRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing note entry restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingContributorDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing contributor delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingContributorDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing contributor delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingContributorRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing contributor restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingContributorRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing contributor restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingReferenceEntryDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing reference entry delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingReferenceEntryDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing reference entry delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingReferenceEntryRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing reference entry restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingReferenceEntryRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing reference entry restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingGlossaryEntryDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing glossary entry delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingGlossaryEntryDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing glossary entry delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingGlossaryEntryRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing glossary entry restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingGlossaryEntryRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing glossary entry restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingIndexEntryDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing index entry delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingIndexEntryDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing index entry delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingIndexEntryRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing index entry restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingIndexEntryRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing index entry restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPublicationDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing publication delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPublicationDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing publication delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingPublicationRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing publication restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingPublicationRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing publication restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingSubmissionDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing submission delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingSubmissionDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing submission delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingSubmissionRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing submission restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingSubmissionRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing submission restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingSubmittedFileDeleteGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing submitted file delete guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingSubmittedFileDeleteGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing submitted file delete guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingSubmittedFileRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing submitted file restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingSubmittedFileRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing submitted file restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingOrderedTextFileLinkUpdateProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing ordered text file link update probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingOrderedTextFileLinkUpdateProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing ordered text file link update probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCRemoteRestoreProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC remote restore probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteRestoreProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Remote restore probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCExistingProjectRestoreGuardrailProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC existing project restore guardrail probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runExistingProjectRestoreGuardrailProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Existing project restore guardrail probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCMissingDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC missing dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteMissingDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Missing dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSatisfiedDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC satisfied dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteSatisfiedDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Satisfied dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSatisfiedDependencyStateSummaryProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC satisfied dependency state summary probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runSatisfiedDependencyStateSummaryProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Satisfied dependency state summary probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCFolderDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC folder dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteFolderDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Folder dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCAnnotationDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC annotation dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteAnnotationDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Annotation dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCStyleDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC style dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteStyleDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Style dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSubmissionDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC submission dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteSubmissionDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Submission dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCPoetryCollectionDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC poetry collection dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemotePoetryCollectionDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Poetry collection dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCProseSectionDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC prose section dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteProseSectionDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Prose section dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCNoteEntryDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC remote note entry createMissing probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteNoteEntryDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Remote note entry createMissing probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCGlossaryCitationDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC glossary citation dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteGlossaryCitationDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Glossary citation dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCReferenceEntryDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC reference entry dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteReferenceEntryDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Reference entry dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCIndexEntryDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC index entry dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteIndexEntryDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Index entry dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCContributorEntryDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC contributor entry dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteContributorEntryDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Contributor entry dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCPageSetupDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC page setup dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemotePageSetupDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Page setup dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCCustomAttributeDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC custom attribute dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteCustomAttributeDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Custom attribute dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCTrashItemDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC trash item dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteTrashItemDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Trash item dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCManuscriptReviewDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC manuscript review dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteManuscriptReviewDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Manuscript review dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCPoetryFormDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC poetry form dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemotePoetryFormDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Poetry form dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCStoryLinkDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC story link dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteStoryLinkDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Story link dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCLocationLinkDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC location link dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteLocationLinkDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Location link dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSceneCharacterDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC scene character dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteSceneCharacterDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Scene character dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSceneLocationDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC scene location dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteSceneLocationDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Scene location dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSceneChapterDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC scene chapter dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteSceneChapterDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Scene chapter dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSceneActDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC scene act dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteSceneActDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Scene act dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSceneBookDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC scene book dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteSceneBookDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Scene book dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCScenePlotDependencyProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC scene plot dependency probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteScenePlotDependencyProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Scene plot dependency probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCUnsupportedOperationProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC unsupported operation probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteUnsupportedOperationProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Unsupported operation probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCNoPayloadProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC no-payload probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runRemoteNoPayloadProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ No-payload probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCPendingApplyPreview() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Previewing Cloudflare sync POC pending apply…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.previewPendingApply(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Pending apply preview failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCMaterializePendingApplyPreview() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Materializing Cloudflare sync POC pending apply preview…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.materializePendingApplyPreview(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Materialize pending apply preview failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCPullPendingChangesIntoScratchStore() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Pulling Cloudflare sync POC pending changes into scratch store…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.pullPendingChangesIntoScratchStore(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Pull pending changes into scratch store failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCInspectPendingApplyScratchStore() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Inspecting Cloudflare sync POC pending apply scratch store…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.inspectPendingApplyScratchStore()
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Inspect pending apply scratch store failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCPullPendingChanges() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Pulling Cloudflare sync POC pending changes…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.pullPendingChanges(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Pull pending changes failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCPushPull() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC sample push/pull…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.pushPullProjectSample(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Push/pull failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCSnapshot() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Creating Cloudflare sync POC remote snapshot…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.createRemoteSnapshot(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Snapshot failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCImportPreview() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Previewing Cloudflare sync POC remote import…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.previewRemoteImport(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Import preview failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCMaterializedImport() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Materializing Cloudflare sync POC import in isolated local store…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.materializeIsolatedImport(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Materialized import failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }

    private func runCloudflareSyncPOCTombstoneProbe() {
        isCloudflareSyncPOCRunning = true
        cloudflareSyncPOCStatus = "Running Cloudflare sync POC tombstone probe…"

        Task {
            do {
                let result = try await CloudflareSyncPOCService.shared.runTombstoneProbe(projects: selectedCloudflareSyncPOCProjects)
                await MainActor.run {
                    cloudflareSyncPOCStatus = "✅ \(result.message)"
                    isCloudflareSyncPOCRunning = false
                }
            } catch {
                await MainActor.run {
                    cloudflareSyncPOCStatus = "❌ Tombstone probe failed: \(error.localizedDescription)"
                    isCloudflareSyncPOCRunning = false
                }
            }
        }
    }
#endif

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

    private func deleteCloudKitZone() {
        zoneDeleteStatus = "Deleting zone…"
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

        let operation = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [zoneID])
        operation.modifyRecordZonesResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    DeduplicationService.clearAllTombstones()
                    zoneDeleteStatus = "✅ Zone deleted (tombstones cleared). Quit and relaunch this app to re-export. Other devices: Reset Sync Database then relaunch."
                    zoneWasDeletedThisSession = true
                case .failure(let error):
                    zoneDeleteStatus = "❌ Zone delete failed: \(error.localizedDescription)"
                }
            }
        }
        operation.qualityOfService = .userInitiated
        database.add(operation)
    }

    /// Purge orphaned records from CloudKit zone.
    /// Keeps only standalone types (StyleSheet, TextStyleModel, PoetryFormModel, ImageStyle).
    /// Deletes everything else (Versions, Folders, TextFiles, Publications, etc.).
    private func purgeOrphanedZoneRecords() {
        purgeOrphansStatus = "Fetching zone records…"
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

        let safeTypes: Set<String> = [
            "CD_StyleSheet", "CD_TextStyleModel", "CD_PoetryFormModel", "CD_ImageStyle"
        ]

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = nil
        let fetchOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])

        var recordIDsToDelete: [CKRecord.ID] = []
        var keptCount = 0

        fetchOp.recordWasChangedBlock = { recordID, result in
            if case .success(let record) = result {
                if safeTypes.contains(record.recordType) {
                    keptCount += 1
                } else {
                    recordIDsToDelete.append(recordID)
                }
            }
        }

        fetchOp.fetchRecordZoneChangesResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    purgeOrphansStatus = "❌ Fetch failed: \(error.localizedDescription)"
                case .success:
                    if recordIDsToDelete.isEmpty {
                        purgeOrphansStatus = "✅ No orphaned records to purge. \(keptCount) safe records kept."
                        return
                    }
                    purgeOrphansStatus = "Deleting \(recordIDsToDelete.count) orphaned records (keeping \(keptCount))…"
                    self.batchDeleteFromCloudKit(database: database, recordIDs: recordIDsToDelete, keptCount: keptCount)
                }
            }
        }

        fetchOp.qualityOfService = .userInitiated
        database.add(fetchOp)
    }

    /// Delete CKRecords in batches of 400 (CloudKit limit)
    private func batchDeleteFromCloudKit(database: CKDatabase, recordIDs: [CKRecord.ID], keptCount: Int) {
        let batchSize = 400
        let batches = stride(from: 0, to: recordIDs.count, by: batchSize).map {
            Array(recordIDs[$0..<min($0 + batchSize, recordIDs.count)])
        }
        let totalToDelete = recordIDs.count
        var deletedSoFar = 0
        var failedCount = 0

        func deleteBatch(index: Int) {
            guard index < batches.count else {
                DispatchQueue.main.async {
                    if failedCount == 0 {
                        purgeOrphansStatus = "✅ Purged \(totalToDelete) orphaned records. \(keptCount) safe records kept."
                    } else {
                        purgeOrphansStatus = "⚠️ Purged \(deletedSoFar) of \(totalToDelete) records. \(failedCount) failed. \(keptCount) safe records kept."
                    }
                }
                return
            }

            let batch = batches[index]
            let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: batch)
            deleteOp.modifyRecordsResultBlock = { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        deletedSoFar += batch.count
                        purgeOrphansStatus = "Deleting… \(deletedSoFar)/\(totalToDelete)"
                    case .failure:
                        failedCount += batch.count
                    }
                    deleteBatch(index: index + 1)
                }
            }
            deleteOp.qualityOfService = .userInitiated
            database.add(deleteOp)
        }

        deleteBatch(index: 0)
    }

    private func listAndDeleteForeignZones() {
        foreignZoneStatus = "Fetching all zones…"
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        let expectedZoneName = "com.apple.coredata.cloudkit.zone"

        database.fetchAllRecordZones { zones, error in
            guard let zones = zones else {
                DispatchQueue.main.async {
                    foreignZoneStatus = "❌ Failed to fetch zones: \(error?.localizedDescription ?? "unknown")"
                }
                return
            }

            let foreignZones = zones.filter { $0.zoneID.zoneName != expectedZoneName && $0.zoneID.zoneName != "_defaultZone" }
            let allNames = zones.map { $0.zoneID.zoneName }

            if foreignZones.isEmpty {
                DispatchQueue.main.async {
                    foreignZoneStatus = "✅ No foreign zones found. All zones: \(allNames.joined(separator: ", "))"
                }
                return
            }

            DispatchQueue.main.async {
                foreignZoneStatus = "Found \(foreignZones.count) foreign zone(s): \(foreignZones.map { $0.zoneID.zoneName }.joined(separator: ", ")). Deleting…"
            }

            let foreignZoneIDs = foreignZones.map { $0.zoneID }
            let deleteOp = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: foreignZoneIDs)
            deleteOp.modifyRecordZonesResultBlock = { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Also clean foreign zone metadata from local SQLite
                        let localCleanCount = Self.cleanForeignZoneMetadataFromLocalStore()
                        let deletedNames = foreignZones.map { $0.zoneID.zoneName }.joined(separator: ", ")
                        let remaining = allNames.filter { name in !foreignZoneIDs.contains(where: { $0.zoneName == name }) }.joined(separator: ", ")
                        foreignZoneStatus = "✅ Deleted \(foreignZones.count) foreign zone(s): \(deletedNames). Local metadata rows cleaned: \(localCleanCount). Remaining zones: \(remaining)"
                    case .failure(let err):
                        foreignZoneStatus = "❌ Failed to delete foreign zones: \(err.localizedDescription)"
                    }
                }
            }
            deleteOp.qualityOfService = .userInitiated
            database.add(deleteOp)
        }
    }

    /// Remove foreign zone metadata rows from the local SQLite store.
    /// NSPersistentCloudKitContainer uses internal tables (ANSCKRECORDZONEMETADATA etc.)
    /// to track zone state. Foreign entries (e.g. co.pointfree.SQLiteData) can confuse
    /// the mirroring engine into exporting operations against non-existent zones.
    private static func cleanForeignZoneMetadataFromLocalStore() -> Int {
        let storeURL = URL.documentsDirectory.appending(path: "writingshed.sqlite")
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return 0 }

        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let db = db else { return 0 }
        defer { sqlite3_close(db) }

        let expectedZone = "com.apple.coredata.cloudkit.zone"
        var totalDeleted = 0

        // Tables that store zone-related metadata
        let metadataTables = [
            "ANSCKRECORDZONEMETADATA",
            "ANSCKDATABASEMETADATA"
        ]

        for table in metadataTables {
            // Check if table exists
            var checkStmt: OpaquePointer?
            let checkSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(table)'"
            guard sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK else { continue }
            let exists = sqlite3_step(checkStmt) == SQLITE_ROW
            sqlite3_finalize(checkStmt)
            guard exists else { continue }

            // For zone metadata, delete rows not matching our expected zone
            if table == "ANSCKRECORDZONEMETADATA" {
                let deleteSQL = "DELETE FROM \(table) WHERE ZZONENAME IS NOT NULL AND ZZONENAME != ?"
                var deleteStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK else { continue }
                sqlite3_bind_text(deleteStmt, 1, (expectedZone as NSString).utf8String, -1, nil)
                if sqlite3_step(deleteStmt) == SQLITE_DONE {
                    totalDeleted += Int(sqlite3_changes(db))
                }
                sqlite3_finalize(deleteStmt)
            }
        }

        #if DEBUG
        print("🧹 [SyncDiag] Cleaned \(totalDeleted) foreign zone metadata rows from local store")
        #endif
        return totalDeleted
    }

    private func verifyZoneContent() {
        // Cancel any prior in-flight query before starting a new one.
        activeZoneVerifyTimeoutTask?.cancel()
        activeZoneVerifyTimeoutTask = nil
        activeZoneVerifyOperation?.cancel()
        activeZoneVerifyOperation = nil

        let requestID = UUID()
        activeZoneVerifyRequestID = requestID
        zoneVerifyStatus = "Querying zone sample…"

        activeZoneVerifyTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard activeZoneVerifyRequestID == requestID else { return }
            activeZoneVerifyRequestID = nil
            activeZoneVerifyOperation?.cancel()
            activeZoneVerifyOperation = nil
            zoneVerifyStatus = "❌ Zone sample timed out after 45s. Sync transport may still be healthy; this diagnostic query is slow on this device/account."
        }

        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

        // First verify the zone exists
        database.fetch(withRecordZoneID: zoneID) { zone, error in
            if let error = error {
                DispatchQueue.main.async {
                    guard activeZoneVerifyRequestID == requestID else { return }
                    zoneVerifyStatus = "❌ Zone fetch failed: \(error.localizedDescription)"
                    activeZoneVerifyRequestID = nil
                    activeZoneVerifyOperation = nil
                    activeZoneVerifyTimeoutTask?.cancel()
                    activeZoneVerifyTimeoutTask = nil
                }
                return
            }
            guard zone != nil else {
                DispatchQueue.main.async {
                    guard activeZoneVerifyRequestID == requestID else { return }
                    zoneVerifyStatus = "❌ Zone does not exist"
                    activeZoneVerifyRequestID = nil
                    activeZoneVerifyOperation = nil
                    activeZoneVerifyTimeoutTask?.cancel()
                    activeZoneVerifyTimeoutTask = nil
                }
                return
            }

            // Fetch all changes with nil token (= full zone contents)
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil
            // Keep the payload tiny for diagnostics; we only need type + project names.
            config.desiredKeys = ["CD_name"]
            let fetchOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])
            // IMPORTANT: sample only the first server batch so diagnostics returns quickly.
            fetchOp.fetchAllChanges = false
            activeZoneVerifyOperation = fetchOp

            let countLock = NSLock()
            var typeCounts: [String: Int] = [:]
            var totalRecords = 0
            var projectNames: [String] = []

            fetchOp.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    let type = record.recordType
                    countLock.lock()
                    typeCounts[type, default: 0] += 1
                    totalRecords += 1
                    if type == "CD_Project", let name = record["CD_name"] as? String {
                        projectNames.append(name)
                    }
                    countLock.unlock()
                }
            }

            fetchOp.fetchRecordZoneChangesResultBlock = { result in
                countLock.lock()
                let finalTypeCounts = typeCounts
                let finalTotalRecords = totalRecords
                let finalProjectNames = projectNames
                countLock.unlock()

                DispatchQueue.main.async {
                    guard activeZoneVerifyRequestID == requestID else { return }
                    switch result {
                    case .success:
                        if finalTotalRecords == 0 {
                            #if DEBUG
                            zoneVerifyStatus = "⚠️ Zone exists but sample returned 0 records. In Debug builds, CloudKit usually points to the DEVELOPMENT environment, which is separate from TestFlight/production data."
                            #else
                            zoneVerifyStatus = "⚠️ Zone exists but sample returned 0 records"
                            #endif
                        } else {
                            let summary = finalTypeCounts.sorted { $0.key < $1.key }
                                .map { "\($0.key): \($0.value)" }
                                .joined(separator: "\n")
                            let projectList = finalProjectNames.sorted().joined(separator: ", ")
                            zoneVerifyStatus = "✅ Zone sample contains \(finalTotalRecords) records:\n\(summary)\n\nProjects in sample (\(finalProjectNames.count)): \(projectList)"
                        }
                    case .failure(let error):
                        zoneVerifyStatus = "❌ Zone fetch changes failed: \(error.localizedDescription)"
                    }
                    activeZoneVerifyRequestID = nil
                    activeZoneVerifyOperation = nil
                    activeZoneVerifyTimeoutTask?.cancel()
                    activeZoneVerifyTimeoutTask = nil
                }
            }

            fetchOp.qualityOfService = .userInitiated
            database.add(fetchOp)
        }
    }

    /// Touch every record to force NSPersistentCloudKitContainer to re-export
    /// all data. Use after a zone delete + relaunch when the persistent history
    /// token has advanced past records that need re-exporting.
    private func forceReexportAllData() {
        reexportStatus = "Touching all records…"
        let now = Date()
        var touchedCount = 0

        // Touch all projects
        for project in projects {
            project.modifiedDate = now
            touchedCount += 1
        }

        // Touch all folders (no modifiedDate — set userOrder to force dirty)
        for folder in allFolders {
            let order = folder.userOrder ?? 0
            folder.userOrder = order
            touchedCount += 1
        }

        // Touch all text files
        for file in allTextFiles {
            file.modifiedDate = now
            touchedCount += 1
        }

        // Touch all publications
        for pub in publications {
            pub.modifiedDate = now
            touchedCount += 1
        }

        do {
            try modelContext.save()
            reexportStatus = "✅ Touched \(touchedCount) records. Export should begin shortly."
        } catch {
            reexportStatus = "❌ Save failed: \(error.localizedDescription)"
        }
    }

    /// Check for duplicate projects (same name + creation date)
    private func checkForDuplicateProjects() {
        duplicateProjectCount = DeduplicationService.countDuplicateProjects(context: modelContext)
    }

    /// Check for orphaned folders and files
    private func checkForOrphans() {
        let now = Date()
        let importRecentlyStarted = syncThrottler.importStartTime.map { now.timeIntervalSince($0) < 600 } ?? false
        if syncThrottler.importInProgress || syncThrottler.isSyncing || importRecentlyStarted {
            orphanedFolderCount = 0
            orphanedFolderDetails = []
            orphanedFileCount = 0
            orphanedFileExcludedCount = 0
            orphanedFileDetails = []
            orphanReassignStatus = "Orphan check deferred while CloudKit import is active/recent."
            return
        }

        orphanReassignStatus = ""

        // Use a fresh context to avoid false positives from main-context cache staleness.
        let freshCtx = ModelContext(modelContext.container)

        let folderDescriptor = FetchDescriptor<Folder>()
        let fetchedFolders = (try? freshCtx.fetch(folderDescriptor)) ?? []
        let orphanedFolders = fetchedFolders.filter { folder in
            let hasNoProject = folder.project == nil
            let hasNoParent = folder.parentFolder == nil
            return hasNoProject && hasNoParent
        }

        orphanedFolderCount = orphanedFolders.count
        orphanedFolderDetails = orphanedFolders.map { folder in
            (id: folder.id,
             name: folder.name ?? "unnamed",
             fileCount: folder.textFiles?.count ?? 0,
             subfolderCount: folder.folders?.count ?? 0)
        }

        let fileDescriptor = FetchDescriptor<TextFile>()
        let fetchedFiles = (try? freshCtx.fetch(fileDescriptor)) ?? []
        let folderReferencedFileIDs = Set(
            fetchedFolders.flatMap { folder in
                (folder.textFiles ?? []).map(\.id)
            }
        )
        let unparentedFiles = fetchedFiles.filter { $0.parentFolder == nil }
        let orphanedFiles = unparentedFiles.filter { file in
            isTrueOrphanedFile(file, folderReferencedFileIDs: folderReferencedFileIDs)
        }
        orphanedFileExcludedCount = max(0, unparentedFiles.count - orphanedFiles.count)
        orphanedFileCount = orphanedFiles.count
        orphanedFileDetails = orphanedFiles.map { file in
            (id: file.id, name: file.name.isEmpty ? "Untitled" : file.name)
        }
    }

    private func isTrueOrphanedFile(_ file: TextFile, folderReferencedFileIDs: Set<UUID>) -> Bool {
        guard file.parentFolder == nil else { return false }
        if file.trashItem != nil { return false }
        if folderReferencedFileIDs.contains(file.id) { return false }

        // If a file is still linked to another parent-like entity, it is not
        // considered a true storage orphan.
        let hasSubmittedLink = file.submittedFiles?.contains(where: { $0.submission != nil }) == true
        if hasSubmittedLink { return false }

        let hasSectionLink = file.sectionLinks?.contains(where: { $0.section != nil }) == true
        if hasSectionLink { return false }

        let hasCollectionLink = file.poetryCollectionLinks?.contains(where: { $0.poetryCollection != nil }) == true
        if hasCollectionLink { return false }

        return true
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

    /// Clear all zombie tombstones to prevent imported projects from being killed.
    private func clearAllTombstones() {
        DeduplicationService.clearAllTombstones()
        tombstoneCount = 0
        repairMessage = "All zombie tombstones cleared. Re-imported projects are now safe."
        showRepairResult = true
    }

    /// Read pending export counts from the CloudKit metadata SQLite table.
    private func pendingExportLines() -> [String] {
        var lines: [String] = []
        lines.append("Pending CloudKit Exports:")

        let storeURL = URL.documentsDirectory.appending(path: "writingshed.sqlite")
        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db = db else {
            lines.append("- (could not open store)")
            return lines
        }
        defer { sqlite3_close(db) }

        // Total pending uploads
        var stmt: OpaquePointer?
        let totalSQL = "SELECT count(*) FROM ANSCKRECORDMETADATA WHERE ZNEEDSUPLOAD=1;"
        if sqlite3_prepare_v2(db, totalSQL, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let total = sqlite3_column_int(stmt, 0)
                lines.append("- Total pending: \(total)")
            }
        }
        sqlite3_finalize(stmt)

        // Pending deletes
        stmt = nil
        let deleteSQL = "SELECT count(*) FROM ANSCKRECORDMETADATA WHERE ZNEEDSCLOUDDELETE=1;"
        if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let total = sqlite3_column_int(stmt, 0)
                lines.append("- Total pending deletes: \(total)")
            }
        }
        sqlite3_finalize(stmt)

        // Breakdown by entity type
        stmt = nil
        let breakdownSQL = """
            SELECT p.Z_NAME, count(*), m.ZPENDINGEXPORTCHANGETYPENUMBER
            FROM ANSCKRECORDMETADATA m
            JOIN Z_PRIMARYKEY p ON p.Z_ENT = m.ZENTITYID
            WHERE m.ZNEEDSUPLOAD=1 OR m.ZNEEDSCLOUDDELETE=1
            GROUP BY p.Z_NAME, m.ZPENDINGEXPORTCHANGETYPENUMBER
            ORDER BY count(*) DESC;
            """
        if sqlite3_prepare_v2(db, breakdownSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 0))
                let count = sqlite3_column_int(stmt, 1)
                let changeType = sqlite3_column_int(stmt, 2)
                let changeLabel: String
                switch changeType {
                case 0: changeLabel = "insert"
                case 1: changeLabel = "update"
                case 2: changeLabel = "delete"
                default: changeLabel = "type=\(changeType)"
                }
                lines.append("  - \(name): \(count) (\(changeLabel))")
            }
        }
        sqlite3_finalize(stmt)

        return lines
    }

    /// Summarize notes payload sizes stored inline in SwiftData tables.
    /// Useful when diagnosing sync failures suspected to be caused by large pasted notes.
    private func notesPayloadLines() -> [String] {
        var lines: [String] = []
        lines.append("Notes Payloads (inline text):")

        let storeURL = URL.documentsDirectory.appending(path: "writingshed.sqlite")
        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db = db else {
            lines.append("- (could not open store)")
            return lines
        }
        defer { sqlite3_close(db) }

        struct PayloadMetric {
            let label: String
            let sql: String
        }

        let warningThreshold = 50_000
        let metrics: [PayloadMetric] = [
            PayloadMetric(
                label: "Project.notes",
                sql: "SELECT IFNULL(MAX(LENGTH(ZNOTES)),0), IFNULL(SUM(CASE WHEN LENGTH(ZNOTES) > \(warningThreshold) THEN 1 ELSE 0 END),0) FROM ZPROJECT;"
            ),
            PayloadMetric(
                label: "Publication.notes",
                sql: "SELECT IFNULL(MAX(LENGTH(ZNOTES)),0), IFNULL(SUM(CASE WHEN LENGTH(ZNOTES) > \(warningThreshold) THEN 1 ELSE 0 END),0) FROM ZPUBLICATION;"
            ),
            PayloadMetric(
                label: "Submission.notes",
                sql: "SELECT IFNULL(MAX(LENGTH(ZNOTES)),0), IFNULL(SUM(CASE WHEN LENGTH(ZNOTES) > \(warningThreshold) THEN 1 ELSE 0 END),0) FROM ZSUBMISSION;"
            ),
            PayloadMetric(
                label: "SubmittedFile.statusNotes",
                sql: "SELECT IFNULL(MAX(LENGTH(ZSTATUSNOTES)),0), IFNULL(SUM(CASE WHEN LENGTH(ZSTATUSNOTES) > \(warningThreshold) THEN 1 ELSE 0 END),0) FROM ZSUBMITTEDFILE;"
            ),
            PayloadMetric(
                label: "Version.notes",
                sql: "SELECT IFNULL(MAX(LENGTH(ZNOTES)),0), IFNULL(SUM(CASE WHEN LENGTH(ZNOTES) > \(warningThreshold) THEN 1 ELSE 0 END),0) FROM ZVERSION;"
            )
        ]

        for metric in metrics {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, metric.sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let maxLength = sqlite3_column_int(stmt, 0)
                    let oversizedCount = sqlite3_column_int(stmt, 1)
                    lines.append("- \(metric.label): max=\(maxLength) chars, >\(warningThreshold)=\(oversizedCount)")
                } else {
                    lines.append("- \(metric.label): (no rows)")
                }
            } else {
                lines.append("- \(metric.label): (query failed)")
            }
            sqlite3_finalize(stmt)
        }

        return lines
    }

    /// Delete folders that have no project and no parent folder.
    /// These are unreachable in the UI and represent sync remnants.
    private func deleteOrphanedFolders() {
        repairMessage = "Safety lock: orphan cleanup is disabled. CloudKit syncs relationships separately, so temporary nil relationships must never be auto-deleted."
        showRepairResult = true
    }

    /// Delete orphaned folders that are provably empty (no files, no subfolders).
    /// These cannot contain user data and are safe to remove.
    private func deleteEmptyOrphanedFolders() {
        let freshCtx = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Folder>()
        guard let allFolders = try? freshCtx.fetch(descriptor) else {
            repairMessage = "Failed to fetch folders."
            showRepairResult = true
            return
        }
        let toDelete = allFolders.filter { folder in
            let hasNoProject = folder.project == nil
            let hasNoParent = folder.parentFolder == nil
            let hasNoFiles = folder.textFiles?.isEmpty ?? true
            let hasNoSubfolders = folder.folders?.isEmpty ?? true
            return hasNoProject && hasNoParent && hasNoFiles && hasNoSubfolders
        }
        guard !toDelete.isEmpty else {
            repairMessage = "No empty orphaned folders found."
            showRepairResult = true
            return
        }
        let names = toDelete.map { $0.name ?? "unnamed" }.joined(separator: ", ")
        for folder in toDelete {
            freshCtx.delete(folder)
        }
        do {
            try freshCtx.save()
            checkForOrphans()
            repairMessage = "Deleted \(toDelete.count) empty orphaned folder(s): \(names)."
        } catch {
            repairMessage = "Save failed: \(error.localizedDescription)"
        }
        showRepairResult = true
    }

    private func checkForOrphanedPublications() {
        let projectSet = Set(projects.map { $0.persistentModelID })
        orphanedPublicationCount = publications.filter { pub in
            pub.project == nil || !projectSet.contains(pub.project!.persistentModelID)
        }.count
    }

    /// Delete publications that have no parent project.
    /// These are unreachable in the UI and represent sync remnants.
    private func deleteOrphanedPublications() {
        repairMessage = "Safety lock: orphan cleanup is disabled. Run manual recovery steps instead of deleting records based on missing relationships."
        showRepairResult = true
    }

    /// Delete files that have no parent folder.
    /// These are unreachable in the UI and represent sync remnants.
    private func deleteOrphanedFiles() {
        repairMessage = "Safety lock: orphan cleanup is disabled. CloudKit may attach relationships after records arrive."
        showRepairResult = true
    }

    /// Delete a specific orphaned folder (and its contents via cascade) by UUID.
    private func deleteOrphanedFolder(id: UUID) {
        let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == id })
        guard let folder = (try? modelContext.fetch(descriptor))?.first else {
            orphanReassignStatus = "❌ Folder not found"
            return
        }
        let name = folder.name ?? "folder"
        modelContext.delete(folder)
        do {
            try modelContext.save()
            orphanReassignStatus = "✅ Deleted \"\(name)\""
            checkForOrphans()
        } catch {
            orphanReassignStatus = "❌ Delete failed: \(error.localizedDescription)"
        }
    }

    /// Delete a specific orphaned file by UUID.
    private func deleteOrphanedFile(id: UUID) {
        let descriptor = FetchDescriptor<TextFile>(predicate: #Predicate { $0.id == id })
        guard let file = (try? modelContext.fetch(descriptor))?.first else {
            orphanReassignStatus = "❌ File not found"
            return
        }
        let folderDescriptor = FetchDescriptor<Folder>()
        let allFolders = (try? modelContext.fetch(folderDescriptor)) ?? []
        let folderReferencedFileIDs = Set(
            allFolders.flatMap { folder in
                (folder.textFiles ?? []).map(\.id)
            }
        )

        guard isTrueOrphanedFile(file, folderReferencedFileIDs: folderReferencedFileIDs) else {
            orphanReassignStatus = "⚠️ File no longer qualifies as a true orphan; delete skipped"
            checkForOrphans()
            return
        }
        let name = file.name
        modelContext.delete(file)
        do {
            try modelContext.save()
            orphanReassignStatus = "✅ Deleted \"\(name)\""
            checkForOrphans()
        } catch {
            orphanReassignStatus = "❌ Delete failed: \(error.localizedDescription)"
        }
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

    private func runGuidedRecovery() {
        guard !isGuidedRecoveryInProgress else { return }
        isGuidedRecoveryInProgress = true
        guidedRecoveryStatus = "Step 1/4: Refreshing sync backoff state…"

        Task { @MainActor in
            CloudKitSyncThrottler.shared.resetBackoffState()
            try? await Task.sleep(nanoseconds: 200_000_000)

            guidedRecoveryStatus = "Step 2/4: Requesting CloudKit fetch…"
            forceSyncFromCloud()

            let _ = await waitForForceSyncResult(timeoutSeconds: 25)

            guidedRecoveryStatus = "Step 3/4: Waiting for CloudKit to settle…"
            let settled = await waitForCloudKitIdle(timeoutSeconds: 30)

            guidedRecoveryStatus = "Step 4/4: Re-checking local store snapshot…"
            let freshContext = ModelContext(modelContext.container)
            let totalProjects = (try? freshContext.fetchCount(FetchDescriptor<Project>())) ?? -1
            let totalFiles = (try? freshContext.fetchCount(FetchDescriptor<TextFile>())) ?? -1
            analyzeConvergenceSignals()

            let throttler = CloudKitSyncThrottler.shared
            let transportHealthy = throttler.importCompleted && throttler.importSucceeded && throttler.exportCompleted && throttler.exportSucceeded && !throttler.isRateLimited
            let exportBlocked = throttler.hasBlockingExportFailure

            var lines: [String] = []
            lines.append("\(transportHealthy ? "✅" : "⚠️") Guided recovery check complete")
            lines.append("CloudKit settled: \(settled ? "yes" : "no")")
            lines.append("Transport state: import=\(throttler.importSucceeded ? "ok" : "not-ok"), export=\(throttler.exportSucceeded ? "ok" : "not-ok"), rateLimited=\(throttler.isRateLimited ? "yes" : "no")")
            if exportBlocked {
                lines.append("Export blocked: CloudKit rejected the last export with CKErrorDomain code=2. Do not make further changes on other devices until source-of-truth recovery is complete.")
            }
            lines.append("Local store: projects=\(totalProjects), files=\(totalFiles)")
            lines.append("Convergence signals: \(convergenceMismatchCount)")

            if transportHealthy {
                lines.append("If one project is still stale on this device, use Reset Sync Database to rebuild local cache from iCloud.")
            } else if exportBlocked {
                lines.append("Repeated Guided Recovery will not clear this export queue. Preserve the source-of-truth device and use zone recovery only after confirming which device has the desired data.")
            } else {
                lines.append("Sync transport is not fully healthy yet. Wait 1-2 minutes, then run Guided Recovery again before resetting local cache.")
            }

            guidedRecoveryStatus = lines.joined(separator: "\n")
            isGuidedRecoveryInProgress = false
        }
    }

    private func analyzeConvergenceSignals() {
        let freshContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Project>()
        let storeProjects = (try? freshContext.fetch(descriptor)) ?? []

        let queryActive = projects.filter { !$0.isTrashed }
        let storeActive = storeProjects.filter { !$0.isTrashed }

        let queryByID = Dictionary(uniqueKeysWithValues: queryActive.map { ($0.id, $0) })
        let storeByID = Dictionary(uniqueKeysWithValues: storeActive.map { ($0.id, $0) })
        let allIDs = Set(queryByID.keys).union(storeByID.keys)

        var mismatches = 0
        for id in allIDs {
            guard let queryProject = queryByID[id], let storeProject = storeByID[id] else {
                mismatches += 1
                continue
            }

            if queryProject.name != storeProject.name {
                mismatches += 1
                continue
            }

            if queryProject.modifiedDate != storeProject.modifiedDate {
                mismatches += 1
            }
        }

        convergenceMismatchCount = mismatches
        convergenceLastCheckedAt = Date()

        let hasHealthyTransport = syncThrottler.importCompleted && syncThrottler.importSucceeded && syncThrottler.exportCompleted && syncThrottler.exportSucceeded && !syncThrottler.isRateLimited && !syncThrottler.hasActiveCloudKitEvent

        if mismatches == 0 {
            convergenceStatus = "✅ Converged"
        } else if hasHealthyTransport {
            convergenceStatus = "⚠️ Likely stale local cache"
        } else {
            convergenceStatus = "⚠️ Divergence while sync active"
        }
    }

    private func waitForForceSyncResult(timeoutSeconds: Int) async -> Bool {
        for _ in 0..<timeoutSeconds {
            if !isForceSyncInProgress {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return false
    }

    private func waitForCloudKitIdle(timeoutSeconds: Int) async -> Bool {
        for _ in 0..<timeoutSeconds {
            let throttler = CloudKitSyncThrottler.shared
            if !throttler.isSyncing && !throttler.hasActiveCloudKitEvent {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return false
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
