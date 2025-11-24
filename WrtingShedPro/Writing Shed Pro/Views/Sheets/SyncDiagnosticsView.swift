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
    @Query private var stylesheets: [StyleSheet]
    @Query private var projects: [Project]
    
    @State private var iCloudStatus: String = "Checking..."
    @State private var containerStatus: String = "Checking..."
    
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
                
                Section("Actions") {
                    Button("Force Save Context") {
                        try? modelContext.save()
                    }
                    
                    Button("Check iCloud Status") {
                        checkiCloudStatus()
                    }
                }
            }
            .navigationTitle("Sync Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkiCloudStatus()
            }
        }
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
