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
import Ensembles
import EnsemblesCloudKit
import EnsemblesSwiftData
import os

@main
struct Write_App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var writeCoalescer: WriteCoalescer
    @State private var syncHealthMonitor: SyncHealthMonitor
    static private(set) var activeEnsemblesContainer: SwiftDataEnsembleContainer?
    static private(set) var activeEnsemblesContainerActivatedAt: Date?
    static private(set) var hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch = false
    static let minimumEnsemblesStartupWriteDelay: TimeInterval = 15
    private static let ensemblesAutoSyncUserDefaultsKey = "ensemblesAutoSyncEnabled"
    static let resetLocalEnsemblesStoreOnNextLaunchKey = "resetLocalEnsemblesStoreOnNextLaunch"
    static let detachLocalEnsemblesBeforeResetOnNextLaunchKey = "detachLocalEnsemblesBeforeResetOnNextLaunch"

    private static var shouldAutoSyncEnsembles: Bool {
        if UserDefaults.standard.bool(forKey: detachLocalEnsemblesBeforeResetOnNextLaunchKey) { return false }
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ensembles-manual-sync") { return false }
        if arguments.contains("--ensembles-auto-sync") { return true }
        if environment["WSP_ENSEMBLES_AUTOSYNC"] == "1" { return true }
        if environment["WSP_ENSEMBLES_AUTOSYNC"] == "0" { return false }
        if UserDefaults.standard.object(forKey: ensemblesAutoSyncUserDefaultsKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: ensemblesAutoSyncUserDefaultsKey)
    }

    private static var isUsingEnsemblesSync: Bool {
        activeEnsemblesContainer != nil
    }

    private static let modelTypes: [any PersistentModel.Type] = [
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
        LocationPlotElementLink.self,
        SceneLocationLink.self,
        // Reference & metadata models (explicit registration for CloudKit schema deployment)
        NoteEntry.self,
        GlossaryEntry.self,
        ReferenceEntry.self,
        CitationEntry.self,
        IndexEntry.self,
        ContributorEntry.self,
        ImageStyle.self
    ]
    
    var sharedModelContainer: ModelContainer = {
        EnsemblesConfiguration.activateLicense()

        // Register early so the CloudKit-backed sync layer can receive pushes.
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

        if UserDefaults.standard.bool(forKey: "resetSyncOnNextLaunch") {
            UserDefaults.standard.removeObject(forKey: "resetSyncOnNextLaunch")
            Write_App.logToFile("ℹ️ [Ensembles] Ignored legacy resetSyncOnNextLaunch flag")
        }
        
        let schema = Schema(Write_App.modelTypes)
        
        #if DEBUG
        print("☁️ [Write_App] Initializing ModelContainer with Ensembles CloudKit sync")
        #endif
        
        let storeURL = URL.documentsDirectory.appending(path: "writingshed.sqlite")
        let eventDataDirectory = URL.documentsDirectory.appending(path: "EnsemblesEventData", directoryHint: .isDirectory)

        if UserDefaults.standard.bool(forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey) {
            UserDefaults.standard.removeObject(forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey)
            Write_App.backupAndResetLocalEnsemblesStore(storeURL: storeURL, eventDataDirectory: eventDataDirectory)
        }

        #if DEBUG
        print("☁️ [Write_App] Initializing SwiftDataEnsembleContainer with CloudKit backend")
        #endif
        Write_App.logToFile("☁️ [Ensembles] Initializing SwiftDataEnsembleContainer")

        let cloudFileSystem = CloudKitFileSystem(
            privateDatabaseForUbiquityContainerIdentifier: "iCloud.com.appworks.writingshedpro",
            schemaVersion: .v2
        )
        let configuration = EnsembleContainerConfiguration(
            autoSyncPolicy: Write_App.shouldAutoSyncEnsembles ? .all : .manual,
            timerInterval: 120,
            seedPolicy: .mergeAllData,
            compatibilityMode: .ensembles3,
            localDataRootDirectoryURL: eventDataDirectory
        )

        if let ensemblesContainer = SwiftDataEnsembleContainer(
            name: "WritingShedProConfiguration",
            storeURL: storeURL,
            modelTypes: Write_App.modelTypes,
            cloudFileSystem: cloudFileSystem,
            configuration: configuration
        ) {
            let stableGlobalIdentifiers: @Sendable ([NSManagedObject]) -> [String] = { objects in
                objects.map { object in
                    if let id = object.value(forKey: "id") as? NSUUID {
                        return id.uuidString
                    }
                    if let id = object.value(forKey: "id") as? UUID {
                        return id.uuidString
                    }

                    let entityName = object.entity.name ?? "UnknownEntity"
                    Task { @MainActor in
                        Write_App.logErrorToFile("❌ [Ensembles] Missing stable UUID for global identifier: \(entityName)")
                    }
                    return "missing-global-id-\(entityName)"
                }
            }
            ensemblesContainer.globalIdentifiers = stableGlobalIdentifiers
            ensemblesContainer.ensemble.globalIdentifiers = stableGlobalIdentifiers
            ensemblesContainer.didEncounterError = { error in
                Task { @MainActor in
                    Write_App.logErrorToFile("❌ [Ensembles] Encountered error: \(Write_App.detailedErrorDescription(error))")
                }
            }
            ensemblesContainer.didForceDetach = { error in
                Task { @MainActor in
                    Write_App.logErrorToFile("⚠️ [Ensembles] Forced detach: \(Write_App.detailedErrorDescription(error))")
                }
            }
            ensemblesContainer.didSaveMergeChanges = { _ in
                Task { @MainActor in
                    Write_App.logToFile("✅ [Ensembles] Merge changes saved")
                }
            }
            Write_App.activeEnsemblesContainer = ensemblesContainer
            Write_App.activeEnsemblesContainerActivatedAt = Date()
            Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch = false
            let container = ensemblesContainer.modelContainer
            container.mainContext.autosaveEnabled = false
            #if DEBUG
            print("✅ [Write_App] SwiftDataEnsembleContainer active")
            #endif
            Write_App.logToFile("✅ [Ensembles] SwiftDataEnsembleContainer active")
            if UserDefaults.standard.bool(forKey: Write_App.detachLocalEnsemblesBeforeResetOnNextLaunchKey) {
                Task { @MainActor in
                    await Write_App.detachForQueuedLocalReset(ensemblesContainer)
                }
            }
            return container
        }

        Write_App.logErrorToFile("⚠️ [Ensembles] SwiftDataEnsembleContainer initialization failed; opening local store without sync")
        #if DEBUG
        print("⚠️ [Write_App] Ensembles container initialization failed; opening local store without sync")
        #endif

        do {
            let container = try Write_App.makeLocalModelContainer(schema: schema, storeURL: storeURL)
            #if DEBUG
            print("✅ [Write_App] Local ModelContainer created successfully")
            #endif
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

            #if DEBUG
            print("🔄 [Write_App] Recovery: Backing up database and creating fresh local store...")
            #endif
            Write_App.logErrorToFile("🔄 Recovery: Backup + fresh local store (last resort)")
            
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
                let container = try Write_App.makeLocalModelContainer(schema: schema, storeURL: storeURL)
                #if DEBUG
                print("✅ [Write_App] Recovery succeeded — fresh local database")
                print("   💾 Old database backed up to: \(backupDir.lastPathComponent)/")
                #endif
                Write_App.logErrorToFile("✅ Recovery succeeded — fresh local DB, backup at \(backupDir.lastPathComponent)/")
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
        let coalescer = WriteCoalescer(modelContext: sharedModelContainer.mainContext)
        WriteCoalescer.shared = coalescer
        _writeCoalescer = State(initialValue: coalescer)

        let monitor = SyncHealthMonitor(modelContainer: sharedModelContainer)
        coalescer.syncHealthMonitor = monitor
        _syncHealthMonitor = State(initialValue: monitor)
        
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
        print("✅ [Ensembles Config] CloudKit container: iCloud.com.appworks.writingshedpro")
        #endif
        #if DEBUG
        print("✅ [Ensembles Config] Database: private")
        #endif
        #if DEBUG
        print("✅ [CloudKit Config] aps-environment: production")
        #endif
        
        // Log to file for TestFlight diagnostics
        Write_App.logToFile("========================================")
        Write_App.logToFile("🚀 Writing Shed Pro APP LAUNCHED")
        Write_App.logToFile("========================================")
        Write_App.logToFile("🚀 App initializing...")
        Write_App.logToFile("✅ [Ensembles Config] CloudKit container: iCloud.com.appworks.writingshedpro")
        Write_App.logToFile("✅ [Ensembles Config] Database: private")
        Write_App.logToFile("✅ [CloudKit Config] aps-environment: production")
        
    }

    private static func makeLocalModelContainer(schema: Schema, storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "WritingShedProConfiguration",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = true
        return container
    }

    private static func backupAndResetLocalEnsemblesStore(storeURL: URL, eventDataDirectory: URL) {
        let fileManager = FileManager.default
        let documentsDirectory = storeURL.deletingLastPathComponent()
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupDirectory = documentsDirectory.appending(path: "LocalSyncResetBackup_\(timestamp)", directoryHint: .isDirectory)

        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            Write_App.logErrorToFile("❌ [Ensembles] Local reset backup directory failed: \(error.localizedDescription)")
            return
        }

        let storeFiles = [
            storeURL,
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        ]

        for sourceURL in storeFiles where fileManager.fileExists(atPath: sourceURL.path) {
            let destinationURL = backupDirectory.appending(path: sourceURL.lastPathComponent)
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                Write_App.logToFile("💾 [Ensembles] Backed up \(sourceURL.lastPathComponent) for local reset")
            } catch {
                Write_App.logErrorToFile("❌ [Ensembles] Failed to back up \(sourceURL.lastPathComponent): \(error.localizedDescription)")
                return
            }
        }

        if fileManager.fileExists(atPath: eventDataDirectory.path) {
            let eventBackupURL = backupDirectory.appending(path: eventDataDirectory.lastPathComponent, directoryHint: .isDirectory)
            do {
                try fileManager.copyItem(at: eventDataDirectory, to: eventBackupURL)
                Write_App.logToFile("💾 [Ensembles] Backed up EnsemblesEventData for local reset")
            } catch {
                Write_App.logErrorToFile("❌ [Ensembles] Failed to back up EnsemblesEventData: \(error.localizedDescription)")
                return
            }
        }

        for sourceURL in storeFiles where fileManager.fileExists(atPath: sourceURL.path) {
            do {
                try fileManager.removeItem(at: sourceURL)
                Write_App.logToFile("🗑️ [Ensembles] Removed local \(sourceURL.lastPathComponent) for sync reset")
            } catch {
                Write_App.logErrorToFile("❌ [Ensembles] Failed to remove \(sourceURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if fileManager.fileExists(atPath: eventDataDirectory.path) {
            do {
                try fileManager.removeItem(at: eventDataDirectory)
                Write_App.logToFile("🗑️ [Ensembles] Removed local EnsemblesEventData for sync reset")
            } catch {
                Write_App.logErrorToFile("❌ [Ensembles] Failed to remove EnsemblesEventData: \(error.localizedDescription)")
            }
        }

        Write_App.logToFile("✅ [Ensembles] Local sync reset completed; backup=\(backupDirectory.lastPathComponent)")
    }

    @MainActor
    private static func detachForQueuedLocalReset(_ ensemblesContainer: SwiftDataEnsembleContainer) async {
        Write_App.logToFile("🔌 [Ensembles] Launch-time detach before local reset started (isAttached=\(ensemblesContainer.isAttached), activity=\(String(describing: ensemblesContainer.currentActivity)))")
        do {
            if ensemblesContainer.isAttached {
                try await ensemblesContainer.detach()
            }
            UserDefaults.standard.removeObject(forKey: Write_App.detachLocalEnsemblesBeforeResetOnNextLaunchKey)
            UserDefaults.standard.set(true, forKey: Write_App.resetLocalEnsemblesStoreOnNextLaunchKey)
            Write_App.logToFile("✅ [Ensembles] Launch-time detach completed; local reset queued for next launch")
        } catch {
            Write_App.logErrorToFile("❌ [Ensembles] Launch-time detach before local reset failed: \(Write_App.detailedErrorDescription(error))")
        }
    }

    static func detailedErrorDescription(_ error: Error) -> String {
        detailedNSErrorDescription(error as NSError)
    }

    private static func detailedNSErrorDescription(_ error: NSError, depth: Int = 0) -> String {
        let indent = String(repeating: "  ", count: depth)
        var parts: [String] = [
            "\(indent)\(error.localizedDescription) domain=\(error.domain) code=\(error.code)"
        ]

        if let ensembleError = error as? EnsembleError {
            parts[0] += " raw=\(ensembleError.rawValue) case=\(ensembleError)"
        }

        let filteredUserInfo = error.userInfo
            .filter { key, _ in key != NSUnderlyingErrorKey && key != NSDetailedErrorsKey }
            .map { key, value in "\(key)=\(value)" }
            .sorted()
        if !filteredUserInfo.isEmpty {
            parts.append("\(indent)userInfo={\(filteredUserInfo.joined(separator: ", "))}")
        }

        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("\(indent)underlying: \(detailedNSErrorDescription(underlyingError, depth: depth + 1))")
        }

        if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError], !detailedErrors.isEmpty {
            for detailedError in detailedErrors {
                parts.append("\(indent)detailed: \(detailedNSErrorDescription(detailedError, depth: depth + 1))")
            }
        }

        return parts.joined(separator: " | ")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(writeCoalescer)
                .environment(syncHealthMonitor)
                .task {
                    // Configure EntitlementManager for in-app purchases
                    if #available(macCatalyst 15, macOS 14.4, iOS 17.4, *) {
                        await EntitlementManager.shared.configure()
                    }
                    
                    // Defer iCloud status check to avoid blocking app launch
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    checkCloudKitStatus()

                    if Write_App.isUsingEnsemblesSync {
                        await runManualEnsemblesSync(reason: "app launch")
                    }

                    // Configure PoetryFormService with model context for database access.
                    // This can write, so keep it behind the Ensembles idle gate.
                    if await waitForEnsemblesStartupWritesIfNeeded(reason: "poetry form migration") {
                        PoetryFormService.shared.configureWithContext(sharedModelContainer.mainContext)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // Remove menus we don't need
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .sidebar) { }
            
            // Add Open WSP File to File menu
            CommandGroup(after: .newItem) {
                Button("Open WSP File...") {
                    NotificationCenter.default.post(name: .writingShedProShowImportPicker, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            
            // Replace default Help content with our User Guide
            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("menu.help.userGuide", comment: "User Guide")) {
                    NotificationCenter.default.post(
                        name: GuideNavigationService.openGuideSectionNotification,
                        object: nil,
                        userInfo: nil
                    )
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }

    private func runManualEnsemblesSync(reason: String) async {
        guard let container = Write_App.activeEnsemblesContainer else { return }
        Write_App.logToFile("🔄 [Ensembles] Manual sync started (reason=\(reason), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        let didSync = await container.sync()
        if didSync {
            Write_App.recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: reason)
            syncHealthMonitor.recordExportSuccess()
            Write_App.logToFile("✅ [Ensembles] Manual sync completed (reason=\(reason), didSync=true, isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        } else {
            syncHealthMonitor.recordExportFailure(isBlocking: false)
            Write_App.logToFile("⚠️ [Ensembles] Manual sync stopped with no successful transfer (reason=\(reason), didSync=false, isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        }
    }

    static func recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: String) {
        guard !hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch else { return }
        hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch = true
        logToFile("✅ [Ensembles] First successful sync completed this launch (reason=\(reason))")
    }

    static func recordFirstEnsemblesDataAvailableIfNeeded(modelContainer: ModelContainer, reason: String) -> Bool {
        guard activeEnsemblesContainer != nil,
              !hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch else {
            return hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch
        }

        let context = ModelContext(modelContainer)
        let projectCount = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
        let folderCount = (try? context.fetchCount(FetchDescriptor<Folder>())) ?? 0
        let fileCount = (try? context.fetchCount(FetchDescriptor<TextFile>())) ?? 0
        let versionCount = (try? context.fetchCount(FetchDescriptor<Version>())) ?? 0
        let publicationCount = (try? context.fetchCount(FetchDescriptor<Publication>())) ?? 0
        let sceneCount = (try? context.fetchCount(FetchDescriptor<StoryScene>())) ?? 0

        guard projectCount > 0 || folderCount > 0 || fileCount > 0 || versionCount > 0 || publicationCount > 0 || sceneCount > 0 else {
            return false
        }

        hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch = true
        logToFile("✅ [Ensembles] First synced data available locally (reason=\(reason), projects=\(projectCount), folders=\(folderCount), files=\(fileCount), versions=\(versionCount), publications=\(publicationCount), scenes=\(sceneCount))")
        return true
    }

    private func waitForEnsemblesStartupWritesIfNeeded(reason: String) async -> Bool {
        guard let ensemblesContainer = Write_App.activeEnsemblesContainer else { return true }

        let maxWaitSeconds = 60
        for second in 0..<maxWaitSeconds {
            let activity = String(describing: ensemblesContainer.currentActivity)
            if Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch {
                return true
            }

            if Write_App.recordFirstEnsemblesDataAvailableIfNeeded(
                modelContainer: sharedModelContainer,
                reason: "\(reason) store populated"
            ) {
                return true
            }

            #if DEBUG
            if second == 0 || second % 5 == 0 {
                print("⏳ [Write_App] Waiting for first successful Ensembles sync before \(reason)... attached=\(ensemblesContainer.isAttached) activity=\(activity)")
            }
            #endif
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        #if DEBUG
        let activity = String(describing: ensemblesContainer.currentActivity)
        print("⚠️ [Write_App] Skipping \(reason); first successful Ensembles sync did not complete after \(maxWaitSeconds)s attached=\(ensemblesContainer.isAttached) activity=\(activity)")
        #endif
        return false
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
                        let zoneNames = zones
                            .map { $0.zoneID.zoneName }
                            .sorted()
                            .joined(separator: ", ")
                        let zoneMsg = "✅ Private database accessible, zones: \(zones.count) [\(zoneNames)]"
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
    static func logToFile(_ message: String) {
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
    static func logErrorToFile(_ message: String) {
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
