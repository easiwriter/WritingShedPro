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
    @State private var repairMessage: String = ""
    @State private var showRepairResult = false
    
    @State private var syncForceStatus: String = ""
    @State private var showSyncForceResult = false
    
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
            syncActionsSection
            debugActionsSection
        }
    }

    private var liveCloudKitSection: some View {
        Section("Live CloudKit") {
            LabeledContent("isSyncing", value: syncThrottler.isSyncing ? "Yes" : "No")
            LabeledContent("Remote Events (Total)", value: "\(syncThrottler.totalSyncEventCount)")
            LabeledContent("Current Burst Count", value: "\(syncThrottler.syncEventCount)")
            LabeledContent("Import In Progress", value: syncThrottler.importInProgress ? "Yes" : "No")
            LabeledContent("Export In Progress", value: syncThrottler.exportInProgress ? "Yes" : "No")
            LabeledContent("Import Completed", value: syncThrottler.importCompleted ? "Yes" : "No")
            LabeledContent("Import Succeeded", value: syncThrottler.importSucceeded ? "Yes" : "No")
            LabeledContent("Rate Limited", value: syncThrottler.isRateLimited ? "Yes" : "No")
            LabeledContent("Manual Kick Paused", value: syncThrottler.isManualKickPaused ? "Yes" : "No")
            LabeledContent("Import Network Failures", value: "\(syncThrottler.consecutiveImportNetworkFailures)")

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
        lines.append("isRateLimited: \(syncThrottler.isRateLimited)")
        lines.append("isManualKickPaused: \(syncThrottler.isManualKickPaused)")
        lines.append("consecutiveImportNetworkFailures: \(syncThrottler.consecutiveImportNetworkFailures)")
        lines.append("lastRemoteEvent: \(syncThrottler.lastSyncTime?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("rateLimitedUntil: \(syncThrottler.rateLimitedUntil?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("manualKickPausedUntil: \(syncThrottler.manualKickPausedUntil?.formatted(date: .omitted, time: .standard) ?? "nil")")
        lines.append("recentCloudKitEvents:")

        for event in syncThrottler.recentCloudKitEvents.prefix(25) {
            let msg = event.message.isEmpty ? "" : " — \(event.message)"
            lines.append("- \(event.timestamp.formatted(date: .omitted, time: .standard)) | \(event.type) | \(event.phase) | \(event.status)\(msg)")
        }

        return lines.joined(separator: "\n")
    }

    private func copyDiagnosticsSnapshot() {
        let snapshot = diagnosticsSnapshotText()

        #if canImport(UIKit)
        UIPasteboard.general.string = snapshot
        #endif

        syncForceStatus = "✅ Diagnostics snapshot copied to clipboard"
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

            if duplicateProjectCount > 0 {
                duplicateProjectsRepairRow
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

    private var syncActionsSection: some View {
        Section("Sync Actions") {
            Button {
                forceSyncFromCloud()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise.icloud")
                    Text("Force Sync from Cloud")
                }
            }

            if !syncForceStatus.isEmpty {
                Text(syncForceStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var debugActionsSection: some View {
        #if DEBUG
        Section("Actions") {
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
    
    /// Force a CloudKit zone fetch to pick up any missed remote changes.
    /// NSPersistentCloudKitContainer relies on silent push notifications which can
    /// be unreliable on Mac Catalyst and iPad. This performs a manual zone fetch
    /// which wakes up the mirroring engine.
    private func forceSyncFromCloud() {
        // Warn (but don't block) if we're rate-limited — user explicitly tapped the button
        if CloudKitSyncThrottler.shared.isRateLimited {
            syncForceStatus = "⚠️ CloudKit rate-limited — request may fail. Retrying anyway…"
        } else {
            syncForceStatus = "Fetching zones…"
        }
        
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        
        database.fetchAllRecordZones { zones, error in
            guard let zones = zones, !zones.isEmpty else {
                DispatchQueue.main.async {
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
        try? modelContext.save()
    }
    
    /// Remove duplicate projects, keeping the one with the most content
    private func deduplicateProjects() {
        let result = DeduplicationService.deduplicateProjects(context: modelContext)
        duplicateProjectCount = 0
        
        if !result.errors.isEmpty {
            repairMessage = result.errors.joined(separator: "\n")
        } else if result.duplicatesRemoved > 0 {
            repairMessage = "Removed \(result.duplicatesRemoved) duplicate project(s): \(result.projectsAffected.joined(separator: ", ")). Please restart the app."
        } else {
            repairMessage = "No duplicate projects found."
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
