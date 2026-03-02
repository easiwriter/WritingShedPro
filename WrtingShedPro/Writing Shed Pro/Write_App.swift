//
//  Write_App.swift
//  Write!
//
//  Created by Keith Lander on 21/10/2025.
//

import SwiftUI
import SwiftData
import CloudKit
import CoreData
import os

@main
struct Write_App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        // CRITICAL: Register for remote notifications BEFORE creating the container.
        // NSPersistentCloudKitContainer needs the APNs device token to set up its
        // CKDatabaseSubscription.  If the token isn't available in time the container
        // logs "Giving up waiting to register for remote notifications" and the initial
        // import stalls permanently (especially on Mac Catalyst where push delivery
        // is slower than iOS).  Calling this here — before the ModelContainer is even
        // constructed — gives APNs the maximum head-start to deliver the token.
        if Thread.isMainThread {
            UIApplication.shared.registerForRemoteNotifications()
        } else {
            DispatchQueue.main.sync {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        #if DEBUG
        print("📱 [Write_App] registerForRemoteNotifications called BEFORE container init")
        #endif
        
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
            FootnoteModel.self,
            // Feature 021 Phase 2: Custom Poetry Forms
            PoetryFormModel.self,
            // Feature 022: Smart Fiction Creation
            StoryScene.self,
            Chapter.self,
            Character.self,
            Location.self,
            CustomAttribute.self,
            PlotElement.self,
            // Drama
            Act.self,
            // Prose
            ProseSection.self,
            // Feature 036: Project Folder Revamp
            PoetryCollection.self,
            Book.self
        ])
        
        #if DEBUG
        print("☁️ [Write_App] Initializing ModelContainer with CloudKit")
        #endif
        
        let storeURL = URL.documentsDirectory.appending(path: "writingshed.sqlite")
        let modelConfiguration = ModelConfiguration(
            "WritingShedProConfiguration",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
        )

        do {
            #if DEBUG
            print("✅ [Write_App] Creating ModelContainer...")
            #endif
            #if DEBUG
            print("   Container ID: iCloud.com.appworks.writingshedpro")
            #endif
            #if DEBUG
            print("   Database URL: \(storeURL.path)")
            #endif
            #if DEBUG
            print("   Configuration: WritingShedProConfiguration")
            #endif
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            #if DEBUG
            print("✅ [Write_App] ModelContainer created successfully with CloudKit enabled")
            #endif
            
            // DISABLED: MigrationService was breaking CloudKit sync
            // Run critical cleanup BEFORE any views load to prevent crashes
            // from invalidated folder objects
            let mainContext = container.mainContext
            // MigrationService.cleanupOrphanedFoldersEarly(context: mainContext)
            
            #if DEBUG
            print("✅ [Write_App] Main context ready")
            #endif
            
            // Monitor CloudKit sync errors at the transaction level
            mainContext.autosaveEnabled = true
            
            // Initialize the sync throttler early - it will observe CloudKit notifications
            // and coalesce rapid-fire events to prevent UI disruption
            _ = CloudKitSyncThrottler.shared
            
            #if DEBUG
            print("✅ [Write_App] CloudKitSyncThrottler initialized")
            #endif
            
            // Monitor CloudKit sync events for diagnostics and auto-retry
            let syncRetryContext = mainContext
            NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: nil
            ) { notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return }
                
                let typeStr: String
                switch event.type {
                case .setup: typeStr = "setup"
                case .import: typeStr = "import"
                case .export: typeStr = "export"
                @unknown default: typeStr = "unknown(\(event.type.rawValue))"
                }
                
                let endDateStr = event.endDate?.description ?? "in-progress"
                let startDateStr = event.startDate.description
                
                if event.endDate == nil {
                    #if DEBUG
                    print("⏳ [CloudKit Sync] STARTED: type=\(typeStr) at=\(startDateStr)")
                    #endif
                } else if !event.succeeded {
                    let nsError = event.error as? NSError
                    let errorMsg = nsError?.localizedDescription ?? "no error description"
                    let errorDomain = nsError?.domain ?? "unknown"
                    let errorCode = nsError?.code ?? -1
                    let msg = "❌ [CloudKit Sync] FAILED: type=\(typeStr) domain=\(errorDomain) code=\(errorCode) error=\(errorMsg)"
                    Write_App.logToFile(msg)
                    #if DEBUG
                    print(msg)
                    if let underlying = nsError?.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("   Underlying: domain=\(underlying.domain) code=\(underlying.code) \(underlying.localizedDescription)")
                    }
                    #endif
                    
                    // Auto-retry for export failures: the delegate's internal recovery
                    // often stalls in debug sessions. Nudge it with a real data mutation
                    // after a generous delay (90s) to ensure we're past the server's backoff.
                    if event.type == .export {
                        #if DEBUG
                        print("🔄 [CloudKit Sync] Will nudge delegate in 90s if it hasn't retried...")
                        #endif
                        DispatchQueue.main.asyncAfter(deadline: .now() + 90) {
                            var descriptor = FetchDescriptor<Project>()
                            descriptor.fetchLimit = 1
                            if let project = try? syncRetryContext.fetch(descriptor).first {
                                project.modifiedDate = Date()
                                try? syncRetryContext.save()
                                #if DEBUG
                                print("🔄 [CloudKit Sync] Nudged: touched '\(project.name ?? "")' modifiedDate")
                                #endif
                            }
                        }
                    }
                } else {
                    #if DEBUG
                    print("☁️ [CloudKit Sync] OK: type=\(typeStr) endDate=\(endDateStr)")
                    #endif
                }
            }
            
            Write_App.logToFile("✅ CloudKit event monitoring active")
            
            // Check the actual store URL and configuration
            #if DEBUG
            print("✅ [Write_App] Database configuration:")
            #endif
            #if DEBUG
            print("   Store URL: \(storeURL)")
            #endif
            
            // NOTE: StyleSheet initialization moved to ContentView.onAppear to avoid blocking app launch
            
            return container
        } catch {
            let nsError = error as NSError
            let errorMsg = "⚠️ [Write_App] ModelContainer initialization failed — attempting recovery"
            #if DEBUG
            print(errorMsg)
            print("   Error domain: \(nsError.domain)")
            print("   Error code: \(nsError.code)")
            print("   Error description: \(nsError.localizedDescription)")
            print("   Full error: \(nsError)")
            #endif
            Write_App.logErrorToFile(errorMsg)
            Write_App.logErrorToFile("   Error: \(nsError.localizedDescription)")
            
            // Migration failure recovery: delete the local SQLite store files
            // and let CloudKit re-sync all data from the cloud.
            // This handles schema migration conflicts (e.g. "table already exists")
            // that lightweight migration cannot resolve automatically.
            let filesToDelete = [
                storeURL,
                storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"),
                // Also remove the ckAssets metadata used by CloudKit mirroring
                storeURL.deletingLastPathComponent().appending(path: "writingshed.sqlite-ckAssets"),
                storeURL.deletingLastPathComponent().appending(path: ".writingshed.sqlite-ckAssets")
            ]
            
            for fileURL in filesToDelete {
                do {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                        #if DEBUG
                        print("🗑️ [Write_App] Deleted: \(fileURL.lastPathComponent)")
                        #endif
                        Write_App.logErrorToFile("🗑️ Deleted: \(fileURL.lastPathComponent)")
                    }
                } catch {
                    #if DEBUG
                    print("⚠️ [Write_App] Could not delete \(fileURL.lastPathComponent): \(error)")
                    #endif
                }
            }
            
            // Retry creating the container with a fresh database
            do {
                let freshConfig = ModelConfiguration(
                    "WritingShedProConfiguration",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .automatic
                )
                let container = try ModelContainer(for: schema, configurations: [freshConfig])
                #if DEBUG
                print("✅ [Write_App] Recovery succeeded — fresh database created, CloudKit will re-sync")
                #endif
                Write_App.logErrorToFile("✅ Recovery succeeded — fresh database created")
                container.mainContext.autosaveEnabled = true
                _ = CloudKitSyncThrottler.shared
                return container
            } catch {
                let fatalMsg = "❌ [Write_App] CRITICAL: Recovery also failed — \(error)"
                #if DEBUG
                print(fatalMsg)
                #endif
                Write_App.logErrorToFile(fatalMsg)
                fatalError(fatalMsg)
            }
        }
    }()

    init() {
        // Log CloudKit configuration for debugging
        #if DEBUG
        print("========================================")
        #endif
        #if DEBUG
        print("🚀 Writing Shed Pro APP LAUNCHED")
        #endif
        #if DEBUG
        print("========================================")
        #endif
        #if DEBUG
        print("🚀 App initializing...")
        #endif
        
        #if DEBUG
        print("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro")
        #endif
        #if DEBUG
        print("✅ [CloudKit Config] Database: private")
        #endif
        #if DEBUG
        print("✅ [CloudKit Config] aps-environment: production")
        #endif
        
        // Log to file for TestFlight diagnostics
        Write_App.logToFile("========================================")
        Write_App.logToFile("🚀 Writing Shed Pro APP LAUNCHED")
        Write_App.logToFile("========================================")
        Write_App.logToFile("🚀 App initializing...")
        Write_App.logToFile("✅ [CloudKit Config] Container: iCloud.com.appworks.writingshedpro")
        Write_App.logToFile("✅ [CloudKit Config] Database: private")
        Write_App.logToFile("✅ [CloudKit Config] aps-environment: production")
        
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Configure PoetryFormService with model context for database access
                    PoetryFormService.shared.configureWithContext(sharedModelContainer.mainContext)
                    
                    // Configure EntitlementManager for in-app purchases
                    if #available(macCatalyst 15, macOS 14.4, iOS 17.4, *) {
                        await EntitlementManager.shared.configure()
                    }
                    
                    // Defer CloudKit status check to avoid blocking app launch
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    checkCloudKitStatus()
                }
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
                checkContainerStatus()
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
            #if DEBUG
            print(statusMsg)
            #endif
            Write_App.logToFile(statusMsg)
            
            if let error = error {
                let errorMsg = "❌ Error checking account: \(error.localizedDescription)"
                #if DEBUG
                print(errorMsg)
                #endif
                Write_App.logToFile(errorMsg)
            }
        }
    }
    
    private func checkContainerStatus() {
        let container = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        
        container.accountStatus { status, error in
            if status == .available {
                #if DEBUG
                print("✅ CloudKit container accessible")
                #endif
                Write_App.logToFile("✅ CloudKit container accessible")
                
                // Try to access the private database
                container.privateCloudDatabase.fetchAllRecordZones { zones, error in
                    if let zones = zones {
                        let zoneMsg = "✅ Private database accessible, zones: \(zones.count)"
                        #if DEBUG
                        print(zoneMsg)
                        #endif
                        Write_App.logToFile(zoneMsg)
                    }
                    if let error = error {
                        let errorMsg = "❌ Error fetching zones: \(error.localizedDescription)"
                        #if DEBUG
                        print(errorMsg)
                        #endif
                        Write_App.logToFile(errorMsg)
                    }
                }
            } else {
                let statusMsg = "❌ CloudKit container not accessible: \(status)"
                #if DEBUG
                print(statusMsg)
                #endif
                Write_App.logToFile(statusMsg)
            }
            if let error = error {
                let errorMsg = "❌ Container error: \(error.localizedDescription)"
                #if DEBUG
                print(errorMsg)
                #endif
                Write_App.logToFile(errorMsg)
            }
        }
    }
    
    
    /// Log messages to a file in the app's documents directory for TestFlight diagnostics
    private static func logToFile(_ message: String) {
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
    
    /// Static helper to log errors during initialization
    private static func logErrorToFile(_ message: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFileURL = documentsDirectory.appendingPathComponent("CloudKitDiagnostics.log")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        } else {
            try? logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
}
