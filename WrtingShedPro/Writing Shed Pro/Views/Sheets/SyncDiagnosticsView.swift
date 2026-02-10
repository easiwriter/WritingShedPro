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
    @State private var orphanedFileCount: Int = 0
    @State private var orphanedFolderCount: Int = 0
    @State private var repairMessage: String = ""
    @State private var showRepairResult = false
    
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
                    
                    HStack {
                        Text("Orphaned Files (no parent folder)")
                        Spacer()
                        Text("\(orphanedFileCount) found")
                            .foregroundColor(orphanedFileCount > 0 ? .orange : .secondary)
                    }
                    
                    HStack {
                        Text("Orphaned Folders (no project/parent)")
                        Spacer()
                        Text("\(orphanedFolderCount) found")
                            .foregroundColor(orphanedFolderCount > 0 ? .orange : .secondary)
                    }
                    
                    if orphanedFileCount > 0 || orphanedFolderCount > 0 {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Orphaned Records")
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            deleteOrphans()
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
                checkForOrphans()
            }
            .alert("Repair Complete", isPresented: $showRepairResult) {
                Button("OK") { }
            } message: {
                Text(repairMessage)
            }
        }
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
    
    /// Check for orphaned records (TextFiles with no parent, Folders with no project/parent)
    private func checkForOrphans() {
        // Find TextFiles with no parentFolder
        orphanedFileCount = allTextFiles.filter { $0.parentFolder == nil }.count
        
        // Find Folders with no project AND no parentFolder (truly orphaned)
        orphanedFolderCount = allFolders.filter { $0.project == nil && $0.parentFolder == nil }.count
        
        #if DEBUG
        if orphanedFileCount > 0 {
            print("⚠️ Found \(orphanedFileCount) orphaned TextFile(s)")
            for file in allTextFiles where file.parentFolder == nil {
                print("  - \(file.name) (id: \(file.id))")
            }
        }
        if orphanedFolderCount > 0 {
            print("⚠️ Found \(orphanedFolderCount) orphaned Folder(s)")
            for folder in allFolders where folder.project == nil && folder.parentFolder == nil {
                print("  - \(folder.name ?? "unnamed") (id: \(folder.id))")
            }
        }
        #endif
    }
    
    /// Delete orphaned records from the database
    private func deleteOrphans() {
        var deletedFiles = 0
        var deletedFolders = 0
        
        // Delete orphaned TextFiles
        for file in allTextFiles where file.parentFolder == nil {
            #if DEBUG
            print("🗑️ Deleting orphaned file: \(file.name)")
            #endif
            modelContext.delete(file)
            deletedFiles += 1
        }
        
        // Delete orphaned Folders (no project and no parent)
        for folder in allFolders where folder.project == nil && folder.parentFolder == nil {
            #if DEBUG
            print("🗑️ Deleting orphaned folder: \(folder.name ?? "unnamed")")
            #endif
            modelContext.delete(folder)
            deletedFolders += 1
        }
        
        do {
            try modelContext.save()
            repairMessage = "Deleted \(deletedFiles) orphaned file(s) and \(deletedFolders) orphaned folder(s)."
            orphanedFileCount = 0
            orphanedFolderCount = 0
        } catch {
            repairMessage = "Error deleting orphans: \(error.localizedDescription)"
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
        let container = CKContainer(identifier: "iCloud.com.appworks.writingshedpro.v2")
        
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
