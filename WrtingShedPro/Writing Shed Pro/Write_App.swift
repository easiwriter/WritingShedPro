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
        let logger = OSLog(subsystem: "com.appworks.writingshedpro", category: "CloudKit")
        
        print("========================================")
        print("🚀 Writing Shed Pro APP LAUNCHED")
        print("========================================")
        print("🚀 App initializing...")
        
        print("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro")
        print("✅ [CloudKit Config] Database: private")
        print("✅ [CloudKit Config] aps-environment: production")
        
        checkCloudKitStatus()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func checkCloudKitStatus() {
        let logger = OSLog(subsystem: "com.appworks.writingshedpro", category: "CloudKit")
        
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
            
            if let error = error {
                let errorMsg = "❌ Error checking account: \(error.localizedDescription)"
                print(errorMsg)
            }
        }
    }
    
    private func checkContainerStatus() {
        let container = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        
        container.accountStatus { status, error in
            if status == .available {
                print("✅ CloudKit container accessible")
                
                // Try to access the private database
                container.privateCloudDatabase.fetchAllRecordZones { zones, error in
                    if let zones = zones {
                        let zoneMsg = "✅ Private database accessible, zones: \(zones.count)"
                        print(zoneMsg)
                    }
                    if let error = error {
                        let errorMsg = "❌ Error fetching zones: \(error.localizedDescription)"
                        print(errorMsg)
                    }
                }
            } else {
                let statusMsg = "❌ CloudKit container not accessible: \(status)"
                print(statusMsg)
            }
            if let error = error {
                let errorMsg = "❌ Container error: \(error.localizedDescription)"
                print(errorMsg)
            }
        }
    }
}
