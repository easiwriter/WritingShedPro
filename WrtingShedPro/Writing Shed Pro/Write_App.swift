//
//  Write_App.swift
//  Write!
//
//  Created by Keith Lander on 21/10/2025.
//

import SwiftUI
import SwiftData
import CloudKit

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
            
            // Log CloudKit configuration for debugging
            #if DEBUG
            print("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro")
            print("✅ [CloudKit Config] Database: private")
            print("✅ [CloudKit Config] aps-environment: production")
            checkCloudKitStatus()
            #endif
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func checkCloudKitStatus() {
        // Check iCloud account status
        CKContainer.default().accountStatus { status, error in
            switch status {
            case .available:
                print("✅ iCloud account available")
                self.checkContainerStatus()
            case .noAccount:
                print("❌ No iCloud account signed in")
            case .restricted:
                print("⚠️ iCloud restricted (parental controls?)")
            case .couldNotDetermine:
                print("❓ Could not determine iCloud status")
            case .temporarilyUnavailable:
                print("⏳ iCloud temporarily unavailable")
            @unknown default:
                print("❓ Unknown iCloud status")
            }
            if let error = error {
                print("❌ Error checking account: \(error.localizedDescription)")
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
                        print("✅ Private database accessible, zones: \(zones.count)")
                    }
                    if let error = error {
                        print("❌ Error fetching zones: \(error.localizedDescription)")
                    }
                }
            } else {
                print("❌ CloudKit container not accessible: \(status)")
            }
            if let error = error {
                print("❌ Container error: \(error.localizedDescription)")
            }
        }
    }
}
