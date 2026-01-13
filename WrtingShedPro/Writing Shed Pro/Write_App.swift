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
            ProseSection.self
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
            
            // Check if CloudKit is actually syncing
            let mainContext = container.mainContext
            #if DEBUG
            print("✅ [Write_App] Main context ready")
            #endif
            
            // Monitor CloudKit sync errors at the transaction level
            mainContext.autosaveEnabled = true
            
            // Add observer for sync errors - runs asynchronously, won't block app launch
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
                object: nil,
                queue: OperationQueue()  // Run on background queue
            ) { notification in
                DispatchQueue.main.async {
                    #if DEBUG
                    print("🔄 [CloudKit] Remote change notification received")
                    #endif
                    Write_App.logErrorToFile("🔄 [CloudKit] Remote change notification received")
                }
            }
            
            // Monitor for CloudKit errors through transaction notifications - also async
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NSPersistentStoreCoordinatorStoresDidChangeNotification"),
                object: nil,
                queue: OperationQueue()  // Run on background queue
            ) { notification in
                DispatchQueue.main.async {
                    #if DEBUG
                    print("🔄 [CloudKit] Stores changed - possible sync event")
                    #endif
                    Write_App.logErrorToFile("🔄 [CloudKit] Stores changed - possible sync event")
                }
            }
            
            // Check the actual store URL and configuration
            #if DEBUG
            print("✅ [Write_App] Database configuration:")
            #endif
            #if DEBUG
            print("   Store URL: \(storeURL)")
            #endif
            
            // NOTE: StyleSheet initialization moved to ContentView.onAppear to avoid blocking app launch
            
            return container
        } catch let error as NSError {
            let errorMsg = "❌ [Write_App] CRITICAL: ModelContainer initialization failed"
            #if DEBUG
            print(errorMsg)
            #endif
            #if DEBUG
            print("   Error domain: \(error.domain)")
            #endif
            #if DEBUG
            print("   Error code: \(error.code)")
            #endif
            #if DEBUG
            print("   Error description: \(error.localizedDescription)")
            #endif
            #if DEBUG
            print("   Full error: \(error)")
            #endif
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                #if DEBUG
                print("   Underlying error: \(underlyingError)")
                #endif
            }
            // Log to file as well using direct file I/O
            Write_App.logErrorToFile(errorMsg)
            Write_App.logErrorToFile("   Error domain: \(error.domain)")
            Write_App.logErrorToFile("   Error code: \(error.code)")
            Write_App.logErrorToFile("   Error description: \(error.localizedDescription)")
            fatalError(errorMsg)
        } catch {
            let errorMsg = "❌ [Write_App] CRITICAL: ModelContainer initialization failed with unknown error: \(error)"
            #if DEBUG
            print(errorMsg)
            #endif
            Write_App.logErrorToFile(errorMsg)
            fatalError(errorMsg)
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
