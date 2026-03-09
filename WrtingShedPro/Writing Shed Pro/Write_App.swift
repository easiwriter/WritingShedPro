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
            Book.self,
            // Join tables for CloudKit-compatible many-to-many relationships
            TextFileSectionLink.self,
            TextFileCollectionLink.self,
            SceneChapterLink.self,
            SceneActLink.self,
            SceneBookLink.self,
            ScenePlotElementLink.self,
            SceneCharacterLink.self,
            CharacterPlotElementLink.self,
            LocationPlotElementLink.self
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
            // Track consecutive export failures to limit nudge attempts.
            // Box so the closure can mutate it.
            let exportFailureCount = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            exportFailureCount.initialize(to: 0)
            let maxNudgeAttempts = 3
            
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
                    
                    // Auto-retry for export failures.
                    // CKError code 6 = requestRateLimited — the container's internal
                    // retry handles this automatically with proper backoff.
                    // We only nudge for NON-rate-limit failures where the container may stall.
                    if event.type == .export {
                        let isRateLimited = (errorDomain == "CKErrorDomain" && errorCode == 6)
                        let failCount = exportFailureCount.pointee + 1
                        exportFailureCount.pointee = failCount
                        
                        if isRateLimited {
                            // Extract server-provided retry-after, if any
                            let retryAfter = nsError?.userInfo[CKError.errorUserInfoPartialErrorsKey] != nil
                                ? 30.0 // default backoff
                                : (nsError?.userInfo["CKRetryAfter"] as? Double ?? 30.0)
                            #if DEBUG
                            print("⏳ [CloudKit Sync] Rate limited (attempt \(failCount)). Container will auto-retry. Server suggests \(retryAfter)s backoff.")
                            #endif
                            Write_App.logToFile("⏳ Rate limited (attempt \(failCount)), backoff \(retryAfter)s – letting container retry")
                            // Do NOT nudge — the container handles rate-limit retries internally.
                            // Nudging adds mutations to the export queue, making rate limiting worse.
                        } else if failCount <= maxNudgeAttempts {
                            // Non-rate-limit failure: nudge with a mutation after delay.
                            // Use exponential backoff: 90s, 180s, 360s
                            let delay = 90.0 * pow(2.0, Double(failCount - 1))
                            #if DEBUG
                            print("🔄 [CloudKit Sync] Will nudge delegate in \(Int(delay))s (attempt \(failCount)/\(maxNudgeAttempts))...")
                            #endif
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                var descriptor = FetchDescriptor<Project>()
                                descriptor.fetchLimit = 1
                                if let project = try? syncRetryContext.fetch(descriptor).first {
                                    project.modifiedDate = Date()
                                    try? syncRetryContext.save()
                                    #if DEBUG
                                    print("🔄 [CloudKit Sync] Nudged: touched '\(project.name ?? "")' modifiedDate (attempt \(failCount))")
                                    #endif
                                }
                            }
                        } else {
                            #if DEBUG
                            print("⚠️ [CloudKit Sync] Export failed \(failCount) times – no more nudge attempts. Will rely on container's internal retry.")
                            #endif
                            Write_App.logToFile("⚠️ Export failed \(failCount) times – nudge limit reached")
                        }
                    }
                } else {
                    #if DEBUG
                    print("☁️ [CloudKit Sync] OK: type=\(typeStr) endDate=\(endDateStr)")
                    #endif
                    // Reset failure counter on any successful event
                    if event.type == .export {
                        exportFailureCount.pointee = 0
                    }
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
            let errorMsg = "⚠️ [Write_App] ModelContainer initialization failed (domain=\(nsError.domain) code=\(nsError.code))"
            #if DEBUG
            print(errorMsg)
            print("   Error description: \(nsError.localizedDescription)")
            print("   Full error: \(nsError)")
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   Underlying: domain=\(underlying.domain) code=\(underlying.code) \(underlying.localizedDescription)")
            }
            #endif
            Write_App.logErrorToFile(errorMsg)
            Write_App.logErrorToFile("   Error: \(nsError.localizedDescription)")
            
            // ── STEP 1: Simple retry (transient failures, file locks, etc.) ──
            #if DEBUG
            print("🔄 [Write_App] Recovery Step 1: Simple retry...")
            #endif
            Write_App.logErrorToFile("🔄 Recovery Step 1: Simple retry")
            do {
                let retryConfig = ModelConfiguration(
                    "WritingShedProConfiguration",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .automatic
                )
                let container = try ModelContainer(for: schema, configurations: [retryConfig])
                #if DEBUG
                print("✅ [Write_App] Recovery Step 1 succeeded — simple retry worked")
                #endif
                Write_App.logErrorToFile("✅ Recovery Step 1 succeeded — simple retry worked")
                container.mainContext.autosaveEnabled = true
                _ = CloudKitSyncThrottler.shared
                return container
            } catch {
                #if DEBUG
                print("⚠️ [Write_App] Recovery Step 1 failed: \(error.localizedDescription)")
                #endif
                Write_App.logErrorToFile("⚠️ Recovery Step 1 failed: \(error.localizedDescription)")
            }
            
            // ── STEP 2: Try without CloudKit (preserves all local data) ──
            // If the schema change broke CloudKit mirroring but the store itself
            // is fine, this keeps the user's data accessible in offline mode.
            #if DEBUG
            print("🔄 [Write_App] Recovery Step 2: Opening store without CloudKit...")
            #endif
            Write_App.logErrorToFile("🔄 Recovery Step 2: Opening without CloudKit (preserves data)")
            do {
                let offlineConfig = ModelConfiguration(
                    "WritingShedProConfiguration",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: [offlineConfig])
                #if DEBUG
                print("✅ [Write_App] Recovery Step 2 succeeded — running without CloudKit sync")
                print("   ⚠️ Data is preserved locally but CloudKit sync is disabled this session")
                #endif
                Write_App.logErrorToFile("✅ Recovery Step 2 succeeded — offline mode, data preserved")
                container.mainContext.autosaveEnabled = true
                // Don't initialize CloudKitSyncThrottler since we're offline
                return container
            } catch {
                #if DEBUG
                print("⚠️ [Write_App] Recovery Step 2 failed: \(error.localizedDescription)")
                #endif
                Write_App.logErrorToFile("⚠️ Recovery Step 2 failed: \(error.localizedDescription)")
            }
            
            // ── STEP 3: Back up database, then create fresh store ──
            // Only reached if the SQLite file itself is corrupted beyond repair.
            // Back up first so data can potentially be recovered manually.
            #if DEBUG
            print("🔄 [Write_App] Recovery Step 3: Backing up database and creating fresh store...")
            #endif
            Write_App.logErrorToFile("🔄 Recovery Step 3: Backup + fresh store (last resort)")
            
            let backupDir = storeURL.deletingLastPathComponent().appending(path: "backup_\(Int(Date().timeIntervalSince1970))")
            let storeFiles = [
                storeURL,
                storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
                storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            ]
            
            // Create backup directory
            do {
                try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
                for fileURL in storeFiles where FileManager.default.fileExists(atPath: fileURL.path) {
                    let dest = backupDir.appending(component: fileURL.lastPathComponent)
                    try FileManager.default.copyItem(at: fileURL, to: dest)
                    #if DEBUG
                    print("💾 [Write_App] Backed up: \(fileURL.lastPathComponent) → backup/")
                    #endif
                    Write_App.logErrorToFile("💾 Backed up: \(fileURL.lastPathComponent)")
                }
            } catch {
                #if DEBUG
                print("⚠️ [Write_App] Backup failed (proceeding anyway): \(error.localizedDescription)")
                #endif
                Write_App.logErrorToFile("⚠️ Backup failed: \(error.localizedDescription)")
            }
            
            // Delete store files
            let filesToDelete = storeFiles + [
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
            
            // Create fresh container
            do {
                let freshConfig = ModelConfiguration(
                    "WritingShedProConfiguration",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .automatic
                )
                let container = try ModelContainer(for: schema, configurations: [freshConfig])
                #if DEBUG
                print("✅ [Write_App] Recovery Step 3 succeeded — fresh database, CloudKit will re-sync")
                print("   💾 Old database backed up to: \(backupDir.lastPathComponent)/")
                #endif
                Write_App.logErrorToFile("✅ Recovery Step 3 succeeded — fresh DB, backup at \(backupDir.lastPathComponent)/")
                container.mainContext.autosaveEnabled = true
                _ = CloudKitSyncThrottler.shared
                return container
            } catch {
                let fatalMsg = "❌ [Write_App] CRITICAL: All recovery steps failed — \(error)"
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
