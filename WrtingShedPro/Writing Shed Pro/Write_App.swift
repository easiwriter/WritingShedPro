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
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .private("iCloud.com.appworks.writingshedpro")
        )

        do {
            print("✅ [Write_App] Creating ModelContainer...")
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [Write_App] ModelContainer created successfully with CloudKit enabled")
            
            // Check if CloudKit is actually syncing
            let mainContext = container.mainContext
            print("✅ [Write_App] Main context ready")
            
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
        
        print("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro")
        print("✅ [CloudKit Config] Database: private")
        print("✅ [CloudKit Config] aps-environment: production")
        
        // Log to file for TestFlight diagnostics
        logToFile("========================================")
        logToFile("🚀 Writing Shed Pro APP LAUNCHED")
        logToFile("========================================")
        logToFile("🚀 App initializing...")
        logToFile("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro")
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
        let container = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        
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
