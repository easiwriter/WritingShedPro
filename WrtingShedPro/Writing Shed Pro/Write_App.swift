//
//  Write_App.swift
//  Write!
//
//  Created by Keith Lander on 21/10/2025.
//

import SwiftUI
import SwiftData
import CloudKit
import os

@main
struct Write_App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            TrashItem.self,
            StyleSheet.self,
            TextStyleModel.self,
            PageSetup.self,
            PrinterPaper.self,
            // Feature 008b: Publication Management
            Publication.self,
            Submission.self,
            SubmittedFile.self,
            // Feature 014: Comments
            CommentModel.self,
            // Feature 015: Footnotes
            FootnoteModel.self
        ])
        
        print("☁️ [Write_App] Initializing ModelContainer with CloudKit")
        
        let storeURL = URL.documentsDirectory.appending(path: "writingshed.sqlite")
        let modelConfiguration = ModelConfiguration(
            "WritingShedProConfiguration",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private("iCloud.com.appworks.writingshedpro.v2")
        )

        do {
            print("✅ [Write_App] Creating ModelContainer...")
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [Write_App] ModelContainer created successfully with CloudKit enabled")
            
            // Check if CloudKit is actually syncing
            let mainContext = container.mainContext
            print("✅ [Write_App] Main context ready")
            
            // Monitor CloudKit sync errors at the transaction level
            mainContext.autosaveEnabled = true
            print("✅ [Write_App] Autosave enabled for CloudKit sync")
            
            // Try to trigger an immediate sync attempt
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
                do {
                    // Force a context save which should trigger CloudKit sync
                    try mainContext.save()
                    print("✅ [Write_App] Background sync save triggered")
                } catch {
                    print("❌ [Write_App] Background sync save failed: \(error)")
                    if let nsError = error as? NSError {
                        print("   Domain: \(nsError.domain), Code: \(nsError.code)")
                        print("   UserInfo: \(nsError.userInfo)")
                    }
                }
            }
            
            // Initialize default stylesheets on first launch
            StyleSheetService.initializeStyleSheetsIfNeeded(context: mainContext)
            print("✅ [Write_App] Stylesheets initialized")
            
            return container
        } catch {
            let errorMsg = "❌ [Write_App] Failed to create ModelContainer: \(error)"
            print(errorMsg)
            if let nsError = error as? NSError {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error description: \(nsError.localizedDescription)")
            }
            fatalError(errorMsg)
        }
    }()

    init() {
        // Log CloudKit configuration for debugging
        print("========================================")
        print("🚀 Writing Shed Pro APP LAUNCHED")
        print("========================================")
        print("🚀 App initializing...")
        
        print("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro.v2")
        print("✅ [CloudKit Config] Database: private")
        print("✅ [CloudKit Config] aps-environment: production")
        
        // Log to file for TestFlight diagnostics
        logToFile("========================================")
        logToFile("🚀 Writing Shed Pro APP LAUNCHED")
        logToFile("========================================")
        logToFile("🚀 App initializing...")
        logToFile("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro.v2")
        logToFile("✅ [CloudKit Config] Database: private")
        logToFile("✅ [CloudKit Config] aps-environment: production")
        
        checkCloudKitStatus()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func checkCloudKitStatus() {
        // Check iCloud account status
        CKContainer.default().accountStatus { status, error in
            let statusMsg: String
            switch status {
            case .available:
                statusMsg = "✅ iCloud account available"
                self.checkContainerStatus()
            case .noAccount:
                statusMsg = "❌ No iCloud account signed in"
            case .restricted:
                statusMsg = "⚠️ iCloud restricted (parental controls?)"
            case .couldNotDetermine:
                statusMsg = "❓ Could not determine iCloud status"
            case .temporarilyUnavailable:
                statusMsg = "⏳ iCloud temporarily unavailable"
            @unknown default:
                statusMsg = "❓ Unknown iCloud status"
            }
            print(statusMsg)
            self.logToFile(statusMsg)
            
            if let error = error {
                let errorMsg = "❌ Error checking account: \(error.localizedDescription)"
                print(errorMsg)
                self.logToFile(errorMsg)
            }
        }
    }
    
    private func checkContainerStatus() {
        let container = CKContainer(identifier: "iCloud.com.appworks.writingshedpro.v2")
        
        container.accountStatus { status, error in
            if status == .available {
                print("✅ CloudKit container accessible")
                self.logToFile("✅ CloudKit container accessible")
                
                // Try to access the private database
                container.privateCloudDatabase.fetchAllRecordZones { zones, error in
                    if let zones = zones {
                        let zoneMsg = "✅ Private database accessible, zones: \(zones.count)"
                        print(zoneMsg)
                        self.logToFile(zoneMsg)
                        
                        // Try a test write to verify CloudKit actually works
                        self.verifyCloudKitWritable(container: container)
                    }
                    if let error = error {
                        let errorMsg = "❌ Error fetching zones: \(error.localizedDescription)"
                        print(errorMsg)
                        self.logToFile(errorMsg)
                    }
                }
            } else {
                let statusMsg = "❌ CloudKit container not accessible: \(status)"
                print(statusMsg)
                self.logToFile(statusMsg)
            }
            if let error = error {
                let errorMsg = "❌ Container error: \(error.localizedDescription)"
                print(errorMsg)
                self.logToFile(errorMsg)
            }
        }
    }
    
    private func verifyCloudKitWritable(container: CKContainer) {
        let testRecord = CKRecord(recordType: "_CloudKitWriteTest", recordID: CKRecordID(recordName: "writetest-\(UUID().uuidString)"))
        testRecord["timestamp"] = Date()
        
        container.privateCloudDatabase.save(testRecord) { record, error in
            if let error = error {
                let errorMsg = "❌ [CloudKit Write Test] Failed to write test record: \(error.localizedDescription)"
                print(errorMsg)
                self.logToFile(errorMsg)
                if let ckError = error as? CKError {
                    print("   CKError code: \(ckError.code)")
                    self.logToFile("   CKError code: \(ckError.code)")
                }
            } else if let record = record {
                print("✅ [CloudKit Write Test] Successfully wrote test record to Production")
                self.logToFile("✅ [CloudKit Write Test] Successfully wrote test record to Production")
                
                // Clean up the test record
                container.privateCloudDatabase.delete(withRecordID: record.recordID) { _, error in
                    if error == nil {
                        print("✅ [CloudKit Write Test] Cleaned up test record")
                    }
                }
            }
        }
    }
    
    /// Log messages to a file in the app's documents directory for TestFlight diagnostics
    private func logToFile(_ message: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFileURL = documentsDirectory.appendingPathComponent("CloudKitDiagnostics.log")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            // Append to existing file
            if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        } else {
            // Create new file
            try? logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
}
