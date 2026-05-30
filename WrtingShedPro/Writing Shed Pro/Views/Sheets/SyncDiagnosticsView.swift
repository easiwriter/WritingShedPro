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
    @State private var zoneDeleteStatus: String = ""
    @State private var zoneWasDeletedThisSession = false
    @State private var reexportStatus: String = ""
    @State private var zoneVerifyStatus: String = ""
    @State private var foreignZoneStatus: String = ""
    @State private var purgeOrphansStatus: String = ""
    @State private var showPurgeOrphansConfirmation = false
    
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
                checkForOrphanedPublications()
                checkForDuplicateStyleSheets()
                tombstoneCount = DeduplicationService.tombstoneCount
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

    private func diagnosticsSnapshotText() -> String {
        _ = syncThrottler.hasActiveCloudKitEvent
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
        lines.append("consecutiveExportRateLimits: \(syncThrottler.consecutiveExportRateLimits)")
        lines.append("isManualKickPaused: \(syncThrottler.isManualKickPaused)")
        lines.append("consecutiveImportNetworkFailures: \(syncThrottler.consecutiveImportNetworkFailures)")
        lines.append("consecutiveImportFailures: \(syncThrottler.consecutiveImportFailures)")
        lines.append("autoResetScheduled: \(syncThrottler.autoResetScheduled)")
        lines.append("isPostReset: \(syncThrottler.isPostReset)")
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
        lines.append("")
        lines.append(contentsOf: publicationInventoryLines())

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

        // Search for NaPoWriMo variants to diagnose the name collision issue
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

    private func publicationInventoryLines() -> [String] {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("Publication Inventory")

        let queryPublications = sortedPublicationsForInventory(publications)
        lines.append("Source: @Query (main context cache)")
        for publication in queryPublications {
            lines.append(publicationInventoryLine(publication, formatter: formatter))
        }

        lines.append("")
        lines.append("Source: Fresh ModelContext (store snapshot)")
        let freshContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Publication>()
        let storePublications = sortedPublicationsForInventory((try? freshContext.fetch(descriptor)) ?? [])
        for publication in storePublications {
            lines.append(publicationInventoryLine(publication, formatter: formatter))
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
            Text("Zombie Tombstones")
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
        zoneVerifyStatus = "Querying zone…"
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

        // First verify the zone exists
        database.fetch(withRecordZoneID: zoneID) { zone, error in
            if let error = error {
                DispatchQueue.main.async {
                    zoneVerifyStatus = "❌ Zone fetch failed: \(error.localizedDescription)"
                }
                return
            }
            guard zone != nil else {
                DispatchQueue.main.async {
                    zoneVerifyStatus = "❌ Zone does not exist"
                }
                return
            }

            // Fetch all changes with nil token (= full zone contents)
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil
            let fetchOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])

            var typeCounts: [String: Int] = [:]
            var totalRecords = 0
            var projectNames: [String] = []

            fetchOp.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    let type = record.recordType
                    DispatchQueue.main.async {
                        typeCounts[type, default: 0] += 1
                        totalRecords += 1
                        if type == "CD_Project", let name = record["CD_name"] as? String {
                            projectNames.append(name)
                        }
                    }
                }
            }

            fetchOp.fetchRecordZoneChangesResultBlock = { result in
                // Give a moment for all recordWasChanged callbacks
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    switch result {
                    case .success:
                        if totalRecords == 0 {
                            zoneVerifyStatus = "⚠️ Zone exists but contains 0 records"
                        } else {
                            let summary = typeCounts.sorted { $0.key < $1.key }
                                .map { "\($0.key): \($0.value)" }
                                .joined(separator: "\n")
                            let projectList = projectNames.sorted().joined(separator: ", ")
                            zoneVerifyStatus = "✅ Zone has \(totalRecords) records:\n\(summary)\n\nProjects in zone (\(projectNames.count)): \(projectList)"
                        }
                    case .failure(let error):
                        zoneVerifyStatus = "❌ Zone fetch changes failed: \(error.localizedDescription)"
                    }
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
        let orphanedFiles = fetchedFiles.filter { file in
            file.parentFolder == nil
        }
        orphanedFileCount = orphanedFiles.count
        orphanedFileDetails = orphanedFiles.map { file in
            (id: file.id, name: file.name.isEmpty ? "Untitled" : file.name)
        }
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
