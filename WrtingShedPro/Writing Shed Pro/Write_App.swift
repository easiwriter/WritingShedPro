//
//  Write_App.swift
//  Write!
//
//  Created by Keith Lander on 21/10/2025.
//

import SwiftUI
import SwiftData
import CloudKit
import os.log

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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .private("iCloud.com.appworks.writingshedpro")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Initialize default stylesheets on first launch
            let context = container.mainContext
            StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Log CloudKit configuration for debugging
        let logger = os.log.init(subsystem: "com.appworks.writingshedpro", category: "CloudKit")
        os_log("🚀 App initializing...", log: logger, type: .info)
        print("🚀 App initializing...")
        
        print("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro")
        print("✅ [CloudKit Config] Database: private")
        print("✅ [CloudKit Config] aps-environment: production")
        os_log("✅ [CloudKit Config] Configured for production", log: logger, type: .info)
        
        checkCloudKitStatus()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func checkCloudKitStatus() {
        let logger = os.log.init(subsystem: "com.appworks.writingshedpro", category: "CloudKit")
        
        // Check iCloud account status
        CKContainer.default().accountStatus { status, error in
            let statusMsg: String
            switch status {
            case .available:
                statusMsg = "✅ iCloud account available"
                os_log("✅ iCloud account available", log: logger, type: .info)
                self.checkContainerStatus()
            case .noAccount:
                statusMsg = "❌ No iCloud account signed in"
                os_log("❌ No iCloud account", log: logger, type: .error)
            case .restricted:
                statusMsg = "⚠️ iCloud restricted (parental controls?)"
                os_log("⚠️ iCloud restricted", log: logger, type: .warning)
            case .couldNotDetermine:
                statusMsg = "❓ Could not determine iCloud status"
                os_log("❓ iCloud status unknown", log: logger, type: .debug)
            case .temporarilyUnavailable:
                statusMsg = "⏳ iCloud temporarily unavailable"
                os_log("⏳ iCloud temporarily unavailable", log: logger, type: .warning)
            @unknown default:
                statusMsg = "❓ Unknown iCloud status"
                os_log("❓ Unknown iCloud status", log: logger, type: .debug)
            }
            print(statusMsg)
            
            if let error = error {
                let errorMsg = "❌ Error checking account: \(error.localizedDescription)"
                print(errorMsg)
                os_log("❌ Account error: %@", log: logger, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func checkContainerStatus() {
        let logger = os.log.init(subsystem: "com.appworks.writingshedpro", category: "CloudKit")
        let container = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        
        container.accountStatus { status, error in
            if status == .available {
                print("✅ CloudKit container accessible")
                os_log("✅ CloudKit container accessible", log: logger, type: .info)
                
                // Try to access the private database
                container.privateCloudDatabase.fetchAllRecordZones { zones, error in
                    if let zones = zones {
                        let zoneMsg = "✅ Private database accessible, zones: \(zones.count)"
                        print(zoneMsg)
                        os_log("✅ Private DB accessible: %d zones", log: logger, type: .info, zones.count)
                    }
                    if let error = error {
                        let errorMsg = "❌ Error fetching zones: \(error.localizedDescription)"
                        print(errorMsg)
                        os_log("❌ Zone fetch error: %@", log: logger, type: .error, error.localizedDescription)
                    }
                }
            } else {
                let statusMsg = "❌ CloudKit container not accessible: \(status)"
                print(statusMsg)
                os_log("❌ CloudKit container not accessible", log: logger, type: .error)
            }
            if let error = error {
                let errorMsg = "❌ Container error: \(error.localizedDescription)"
                print(errorMsg)
                os_log("❌ Container error: %@", log: logger, type: .error, error.localizedDescription)
            }
        }
    }
}
