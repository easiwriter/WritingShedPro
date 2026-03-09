//
//  SyncDiagnosticsView.swift
//  Writing Shed Pro
//
//  Debug view to check CloudKit sync status
//

import SwiftUI
import SwiftData
import CloudKit

struct SyncDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var stylesheets: [StyleSheet]
    @Query private var projects: [Project]
    @Query private var allFolders: [Folder]
    @Query private var allTextFiles: [TextFile]
    
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
            List {
                Section("iCloud Account") {
                    Text(iCloudStatus)
                        .font(.caption)
                }
                
                Section("CloudKit Container") {
                    Text(containerStatus)
                        .font(.caption)
                }
                
                Section("Local Data") {
                    LabeledContent("StyleSheets", value: "\(stylesheets.count)")
                    LabeledContent("Projects", value: "\(projects.count)")
                    LabeledContent("Folders", value: "\(allFolders.count)")
                    LabeledContent("Text Files", value: "\(allTextFiles.count)")
                    
                    if duplicateCount > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(duplicateCount) duplicate file references detected")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section("Database Health") {
                    HStack {
                        Text("Duplicate Projects")
                        Spacer()
                        Text("\(duplicateProjectCount) found")
                            .foregroundColor(duplicateProjectCount > 0 ? .red : .secondary)
                    }
                    
                    if duplicateProjectCount > 0 {
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
                    
                    if duplicateCount > 0 {
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
                }
                
                Section("StyleSheets") {
                    ForEach(stylesheets, id: \.id) { stylesheet in
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
                }
                
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
                
                #if DEBUG
                Section("Actions") {
                    Button("Force Save Context") {
                        do {
                            try modelContext.save()
                            repairMessage = "Context saved successfully."
                            showRepairResult = true
                        } catch {
                            repairMessage = "Error saving context: \(error.localizedDescription)"
                            showRepairResult = true
                        }
                    }
                }
                #endif
            }
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
    
    /// Check for duplicate projects (same name + creation date)
    private func checkForDuplicateProjects() {
        duplicateProjectCount = DeduplicationService.countDuplicateProjects(context: modelContext)
    }
    
    /// Force a CloudKit zone fetch to pick up any missed remote changes.
    /// NSPersistentCloudKitContainer relies on silent push notifications which can
    /// be unreliable on Mac Catalyst and iPad. This performs a manual zone fetch
    /// which wakes up the mirroring engine.
    private func forceSyncFromCloud() {
        syncForceStatus = "Fetching zones…"
        
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
