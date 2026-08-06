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
    static private(set) var hasObservedEnsemblesDataThisLaunch = false
    static private(set) var initialEnsemblesImportUnavailable = false
    static private(set) var hasObservedPartialEnsemblesStoreThisLaunch = false
    static private(set) var ensemblesMergeSaveCooldownUntil: Date?
    private static var pendingLocalChangeSyncTask: Task<Void, Never>?
    private static var localChangeSyncInProgress = false
    static let minimumEnsemblesStartupWriteDelay: TimeInterval = 15
    static let ensemblesPostMergeSaveCooldown: TimeInterval = 10
    static let ensemblesMergeConflictSaveCooldown: TimeInterval = 90
    private static let ensemblesAutoSyncUserDefaultsKey = "ensemblesAutoSyncEnabled"
    static let localRecoveryModeOnNextLaunchKey = "localRecoveryModeOnNextLaunch"
    static let resetLocalEnsemblesStoreOnNextLaunchKey = "resetLocalEnsemblesStoreOnNextLaunch"
    static let detachLocalEnsemblesBeforeResetOnNextLaunchKey = "detachLocalEnsemblesBeforeResetOnNextLaunch"
    static let ensembleIdentifier = "WritingShedProConfigurationV2"

    static var isLocalRecoveryModeEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--wsp-local-recovery") ||
            environment["WSP_LOCAL_RECOVERY"] == "1" ||
            UserDefaults.standard.bool(forKey: localRecoveryModeOnNextLaunchKey)
    }

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

        if Write_App.isLocalRecoveryModeEnabled {
            do {
                let container = try Write_App.makeLocalModelContainer(schema: schema, storeURL: storeURL)
                #if DEBUG
                print("🛟 [Write_App] Local recovery mode active — opening local store without Ensembles")
                #endif
                Write_App.logToFile("🛟 [Ensembles] Local recovery mode active; opening local store without sync")
                return container
            } catch {
                let nsError = error as NSError
                Write_App.logErrorToFile("❌ [Ensembles] Local recovery mode failed to open local store: domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription)")
            }
        }

        #if DEBUG
        print("☁️ [Write_App] Initializing SwiftDataEnsembleContainer with CloudKit backend")
        #endif
        Write_App.logToFile("☁️ [Ensembles] Initializing SwiftDataEnsembleContainer")

        do {
            try FileManager.default.createDirectory(at: eventDataDirectory, withIntermediateDirectories: true)
        } catch {
            Write_App.logErrorToFile("❌ [Ensembles] Failed to create local event data directory: \(error.localizedDescription)")
        }

        let cloudFileSystem = CloudKitFileSystem(
            privateDatabaseForUbiquityContainerIdentifier: "iCloud.com.appworks.writingshedpro",
            schemaVersion: .v2
        )
        let localStoreWasMissingAtLaunch = !FileManager.default.fileExists(atPath: storeURL.path)
        if localStoreWasMissingAtLaunch {
            Write_App.logToFile("🛟 [Ensembles] Local store file missing; letting Ensembles create and sync the store")
        }
        let configuration = EnsembleContainerConfiguration(
            autoSyncPolicy: Write_App.shouldAutoSyncEnsembles ? .all : .manual,
            timerInterval: 120,
            seedPolicy: .mergeAllData,
            compatibilityMode: .ensembles3,
            localDataRootDirectoryURL: eventDataDirectory
        )

        let ensemblesContainer = SwiftDataEnsembleContainer(
            name: Write_App.ensembleIdentifier,
            storeURL: storeURL,
            modelTypes: Write_App.modelTypes,
            cloudFileSystem: cloudFileSystem,
            configuration: configuration
        ) ?? Write_App.makePreopenedEnsemblesContainer(
            schema: schema,
            storeURL: storeURL,
            cloudFileSystem: cloudFileSystem,
            configuration: configuration
        )

        if let ensemblesContainer {
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
                    Write_App.deferLocalSavesIfMergeConflict(error)
                }
            }
            ensemblesContainer.didForceDetach = { error in
                Task { @MainActor in
                    Write_App.logErrorToFile("⚠️ [Ensembles] Forced detach: \(Write_App.detailedErrorDescription(error))")
                    Write_App.handleForcedEnsemblesDetach(error, modelContainer: ensemblesContainer.modelContainer)
                }
            }
            ensemblesContainer.didSaveMergeChanges = { _ in
                Task { @MainActor in
                    Write_App.logToFile("✅ [Ensembles] Merge changes saved")
                    NotificationCenter.default.post(name: .writingShedProSyncDidUpdateLocalData, object: nil)
                    Write_App.deferLocalSavesForEnsemblesMerge(
                        reason: "merge changes saved",
                        duration: Write_App.ensemblesPostMergeSaveCooldown
                    )
                    await Write_App.recordAutoSyncSuccessAfterIdle(ensemblesContainer, reason: "merge changes saved")
                }
            }
            Write_App.activeEnsemblesContainer = ensemblesContainer
            Write_App.activeEnsemblesContainerActivatedAt = Date()
            Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch = false
            Write_App.hasObservedEnsemblesDataThisLaunch = false
            Write_App.initialEnsemblesImportUnavailable = false
            Write_App.hasObservedPartialEnsemblesStoreThisLaunch = false
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
        if localStoreWasMissingAtLaunch {
            Write_App.logFreshStoreEnsembleConstructionDiagnostic(
                storeURL: storeURL,
                cloudFileSystem: cloudFileSystem,
                eventDataDirectory: eventDataDirectory
            )
            Write_App.initialEnsemblesImportUnavailable = true
            Write_App.logErrorToFile("⚠️ [Ensembles] Initial sync import unavailable; suppressing local seed data until sync attach is fixed")
        }
        #if DEBUG
        print("⚠️ [Write_App] Ensembles container initialization failed; opening local store without sync")
        #endif

        do {
            return try Write_App.makeLocalModelContainer(schema: schema, storeURL: storeURL)
        } catch {
            fatalError("❌ [Write_App] Unable to open local ModelContainer: \(error)")
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
            Write_App.ensembleIdentifier,
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = true
        return container
    }

    private static func logFreshStoreEnsembleConstructionDiagnostic(
        storeURL: URL,
        cloudFileSystem: CloudFileSystem,
        eventDataDirectory: URL
    ) {
        let storeExists = FileManager.default.fileExists(atPath: storeURL.path)
        let eventDataExists = FileManager.default.fileExists(atPath: eventDataDirectory.path)
        let diagnosticEnsemble = SwiftDataEnsemble(
            ensembleIdentifier: Write_App.ensembleIdentifier,
            persistentStoreURL: storeURL,
            modelTypes: Write_App.modelTypes,
            cloudFileSystem: cloudFileSystem,
            localDataRootDirectoryURL: eventDataDirectory
        )

        if diagnosticEnsemble == nil {
            Write_App.logErrorToFile("❌ [Ensembles] Lower-level SwiftDataEnsemble construction also failed (storeExists=\(storeExists), eventDataExists=\(eventDataExists), storeURL=\(storeURL.path), eventDataURL=\(eventDataDirectory.path))")
        } else {
            Write_App.logToFile("ℹ️ [Ensembles] Lower-level SwiftDataEnsemble construction succeeded; failure is in SwiftDataEnsembleContainer wrapper setup (storeExists=\(storeExists), eventDataExists=\(eventDataExists))")
        }
    }

    private static func makePreopenedEnsemblesContainer(
        schema: Schema,
        storeURL: URL,
        cloudFileSystem: CloudFileSystem,
        configuration: EnsembleContainerConfiguration
    ) -> SwiftDataEnsembleContainer? {
        Write_App.logToFile("⚠️ [Ensembles] StoreURL initializer failed; trying pre-opened ModelContainer fallback")
        do {
            let localContainer = try Write_App.makeLocalModelContainer(schema: schema, storeURL: storeURL)
            localContainer.mainContext.autosaveEnabled = false
            Write_App.logToFile("✅ [Ensembles] Local ModelContainer opened before Ensembles attach")
            return SwiftDataEnsembleContainer(
                name: Write_App.ensembleIdentifier,
                modelContainer: localContainer,
                modelTypes: Write_App.modelTypes,
                cloudFileSystem: cloudFileSystem,
                configuration: configuration
            )
        } catch {
            let nsError = error as NSError
            Write_App.logErrorToFile("❌ [Ensembles] Local ModelContainer fallback failed: domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription)")
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                Write_App.logErrorToFile("   underlying: domain=\(underlying.domain) code=\(underlying.code) \(underlying.localizedDescription)")
            }
            return nil
        }
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

        let storeFiles = ((try? fileManager.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil
        )) ?? [])
            .filter { url in
                let name = url.lastPathComponent
                return name.hasPrefix("writingshed.sqlite") || name.hasPrefix(".writingshed.sqlite")
            }

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

        DeduplicationService.clearAllTombstones()
        Write_App.logToFile("🪦 [Ensembles] Cleared tombstones during local sync reset")

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

    @MainActor
    private static func handleForcedEnsemblesDetach(_ error: Error, modelContainer: ModelContainer) {
        hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch = false
        hasObservedEnsemblesDataThisLaunch = false

        let nsError = error as NSError
        let description = detailedErrorDescription(error)
        guard nsError.code == 205 || description.contains("storeUnregistered") else {
            return
        }

        let context = ModelContext(modelContainer)
        let projectCount = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
        let folderCount = (try? context.fetchCount(FetchDescriptor<Folder>())) ?? 0
        let fileCount = (try? context.fetchCount(FetchDescriptor<TextFile>())) ?? 0
        let versionCount = (try? context.fetchCount(FetchDescriptor<Version>())) ?? 0
        let publicationCount = (try? context.fetchCount(FetchDescriptor<Publication>())) ?? 0
        let sceneCount = (try? context.fetchCount(FetchDescriptor<StoryScene>())) ?? 0
        let childCount = folderCount + fileCount + versionCount + publicationCount + sceneCount

        guard projectCount == 0 && childCount > 0 else {
            Write_App.logErrorToFile("⚠️ [Ensembles] Store unregistered without partial child-only store projectCount=\(projectCount), childCount=\(childCount)")
            return
        }

        hasObservedPartialEnsemblesStoreThisLaunch = true
        Write_App.logErrorToFile("⚠️ [Ensembles] Store unregistered with partial local store; waiting for Ensembles self-recovery (projects=0, folders=\(folderCount), files=\(fileCount), versions=\(versionCount), publications=\(publicationCount), scenes=\(sceneCount))")
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

                    if Write_App.isUsingEnsemblesSync && !Write_App.shouldAutoSyncEnsembles {
                        await runManualEnsemblesSync(reason: "app launch")
                    }

                    // Configure PoetryFormService with model context for database access.
                    // Under Ensembles, this must be read-only at launch. Migrations/cleanup
                    // save in response to merged data and can abort active merge passes.
                    if Write_App.isUsingEnsemblesSync {
                        PoetryFormService.shared.configureWithContext(sharedModelContainer.mainContext, runMigrations: false)
                    } else if Write_App.initialEnsemblesImportUnavailable {
                        Write_App.logToFile("⏸️ [Ensembles] Skipping PoetryFormService migrations while initial sync import is unavailable")
                        PoetryFormService.shared.configureWithContext(sharedModelContainer.mainContext, runMigrations: false)
                    } else if await waitForEnsemblesStartupWritesIfNeeded(reason: "poetry form migration") {
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

        guard await waitForEnsemblesIdleBeforeManualSync(container, reason: reason) else {
            return
        }

        Write_App.logToFile("🔄 [Ensembles] Manual sync started (reason=\(reason), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        let didSync = await container.sync()
        if didSync {
            Write_App.recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: reason)
            syncHealthMonitor.recordExportSuccess()
            NotificationCenter.default.post(name: .writingShedProSyncDidUpdateLocalData, object: nil)
            Write_App.logToFile("✅ [Ensembles] Manual sync completed (reason=\(reason), didSync=true, isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        } else {
            syncHealthMonitor.recordExportFailure(isBlocking: false)
            Write_App.logToFile("⚠️ [Ensembles] Manual sync stopped with no successful transfer (reason=\(reason), didSync=false, isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        }
    }

    private func waitForEnsemblesIdleBeforeManualSync(_ container: SwiftDataEnsembleContainer, reason: String) async -> Bool {
        guard container.isAttached else {
            Write_App.logToFile("⚠️ [Ensembles] Skipping manual sync while detached (reason=\(reason), activity=\(String(describing: container.currentActivity)))")
            return false
        }

        let maxWaitSeconds = 60
        for second in 0..<maxWaitSeconds {
            let activity = String(describing: container.currentActivity)
            if container.isAttached && activity.lowercased() == "none" {
                return true
            }

            #if DEBUG
            if second == 0 || second % 5 == 0 {
                print("⏳ [Write_App] Waiting for Ensembles to become idle before manual sync reason=\(reason) attached=\(container.isAttached) activity=\(activity)")
            }
            #endif
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        Write_App.logToFile("⚠️ [Ensembles] Skipping manual sync because Ensembles stayed busy (reason=\(reason), isAttached=\(container.isAttached), activity=\(String(describing: container.currentActivity)))")
        return false
    }

    static func recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: String) {
        guard !hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch else { return }
        hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch = true
        logToFile("✅ [Ensembles] First successful sync completed this launch (reason=\(reason))")
        NotificationCenter.default.post(name: .writingShedProSyncDidUpdateLocalData, object: nil)
    }

    @MainActor
    private static func canTreatAttachedIdleStoreAsStable(modelContainer: ModelContainer, reason: String) -> Bool {
        let context = ModelContext(modelContainer)
        let projectCount = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
        let folderCount = (try? context.fetchCount(FetchDescriptor<Folder>())) ?? 0
        let fileCount = (try? context.fetchCount(FetchDescriptor<TextFile>())) ?? 0
        let versionCount = (try? context.fetchCount(FetchDescriptor<Version>())) ?? 0
        let publicationCount = (try? context.fetchCount(FetchDescriptor<Publication>())) ?? 0
        let sceneCount = (try? context.fetchCount(FetchDescriptor<StoryScene>())) ?? 0
        let childCount = folderCount + fileCount + versionCount + publicationCount + sceneCount

        if projectCount == 0 && childCount > 0 {
            hasObservedPartialEnsemblesStoreThisLaunch = true
            logToFile("⚠️ [Ensembles] Refusing first-sync success for partial store reason=\(reason) projects=0 folders=\(folderCount) files=\(fileCount) versions=\(versionCount) publications=\(publicationCount) scenes=\(sceneCount)")
            return false
        }

        return true
    }

    @MainActor
    private static func recordAutoSyncSuccessAfterIdle(_ ensemblesContainer: SwiftDataEnsembleContainer, reason: String) async {
        guard !hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch else { return }

        for second in 0..<30 {
            let activity = String(describing: ensemblesContainer.currentActivity)
            if ensemblesContainer.isAttached && activity.lowercased() == "none" {
                guard canTreatAttachedIdleStoreAsStable(modelContainer: ensemblesContainer.modelContainer, reason: reason) else { return }
                recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: reason)
                return
            }

            #if DEBUG
            if second == 0 || second % 5 == 0 {
                print("⏳ [Ensembles] Merge saved; waiting for idle before first-sync unlock attached=\(ensemblesContainer.isAttached) activity=\(activity)")
            }
            #endif
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        Write_App.logToFile("⚠️ [Ensembles] Merge saved but sync did not become idle before first-sync unlock attached=\(ensemblesContainer.isAttached) activity=\(String(describing: ensemblesContainer.currentActivity))")
    }

    static func recordFirstEnsemblesDataAvailableIfNeeded(modelContainer: ModelContainer, reason: String) -> Bool {
        guard activeEnsemblesContainer != nil,
              !hasObservedEnsemblesDataThisLaunch else {
            return hasObservedEnsemblesDataThisLaunch
        }

        let context = ModelContext(modelContainer)
        let projectCount = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
        let folderCount = (try? context.fetchCount(FetchDescriptor<Folder>())) ?? 0
        let fileCount = (try? context.fetchCount(FetchDescriptor<TextFile>())) ?? 0
        let versionCount = (try? context.fetchCount(FetchDescriptor<Version>())) ?? 0
        let publicationCount = (try? context.fetchCount(FetchDescriptor<Publication>())) ?? 0
        let sceneCount = (try? context.fetchCount(FetchDescriptor<StoryScene>())) ?? 0

        let childCount = folderCount + fileCount + versionCount + publicationCount + sceneCount
        if projectCount == 0 && childCount > 0 {
            hasObservedPartialEnsemblesStoreThisLaunch = true
            logToFile("⚠️ [Ensembles] Partial store observed but not accepted as synced data (reason=\(reason), projects=0, folders=\(folderCount), files=\(fileCount), versions=\(versionCount), publications=\(publicationCount), scenes=\(sceneCount))")
            return false
        }

        guard projectCount > 0 else {
            return false
        }

        hasObservedEnsemblesDataThisLaunch = true
        logToFile("✅ [Ensembles] Synced data observed locally (reason=\(reason), projects=\(projectCount), folders=\(folderCount), files=\(fileCount), versions=\(versionCount), publications=\(publicationCount), scenes=\(sceneCount))")
        return true
    }

    static func isInEnsemblesMergeSaveCooldown() -> Bool {
        guard let ensemblesMergeSaveCooldownUntil else { return false }
        if ensemblesMergeSaveCooldownUntil > Date() {
            return true
        }
        self.ensemblesMergeSaveCooldownUntil = nil
        return false
    }

    static func deferLocalSavesForEnsemblesMerge(reason: String, duration: TimeInterval) {
        let cooldownUntil = Date().addingTimeInterval(duration)
        if let existingCooldown = ensemblesMergeSaveCooldownUntil,
           existingCooldown >= cooldownUntil {
            return
        }

        ensemblesMergeSaveCooldownUntil = cooldownUntil
        logToFile("⏳ [EnsemblesSaveGate] Deferring local saves for \(Int(duration))s after Ensembles merge activity reason=\(reason)")
    }

    static func deferLocalSavesIfMergeConflict(_ error: Error) {
        let nsError = error as NSError
        let description = detailedErrorDescription(error)
        guard nsError.code == 207 || description.contains("saveOccurredDuringMerge") else { return }
        deferLocalSavesForEnsemblesMerge(
            reason: "saveOccurredDuringMerge",
            duration: ensemblesMergeConflictSaveCooldown
        )
    }

    @MainActor
    static func scheduleEnsemblesSyncAfterLocalSave(reason: String) {
        guard shouldAutoSyncEnsembles,
              let ensemblesContainer = activeEnsemblesContainer else {
            return
        }

        pendingLocalChangeSyncTask?.cancel()
        pendingLocalChangeSyncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await runDebouncedEnsemblesSyncAfterLocalSave(ensemblesContainer, reason: reason)
        }
    }

    @MainActor
    private static func runDebouncedEnsemblesSyncAfterLocalSave(_ ensemblesContainer: SwiftDataEnsembleContainer, reason: String) async {
        guard !localChangeSyncInProgress else { return }
        guard ensemblesContainer.isAttached else { return }

        localChangeSyncInProgress = true
        defer { localChangeSyncInProgress = false }

        for _ in 0..<15 {
            guard !Task.isCancelled else { return }
            let activity = String(describing: ensemblesContainer.currentActivity)
            if activity.lowercased() == "none" {
                logToFile("🔄 [Ensembles] Local-change sync started (reason=\(reason), attached=\(ensemblesContainer.isAttached))")
                let didSync = await ensemblesContainer.sync()
                if didSync {
                    recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: "local save: \(reason)")
                    logToFile("✅ [Ensembles] Local-change sync completed (reason=\(reason))")
                } else {
                    logToFile("⚠️ [Ensembles] Local-change sync completed without transfer (reason=\(reason), attached=\(ensemblesContainer.isAttached), activity=\(String(describing: ensemblesContainer.currentActivity)))")
                }
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        logToFile("⚠️ [Ensembles] Local-change sync skipped because Ensembles stayed busy (reason=\(reason), attached=\(ensemblesContainer.isAttached), activity=\(String(describing: ensemblesContainer.currentActivity)))")
    }

    static func canProceedWithStartupMaintenanceAfterIdle(modelContainer: ModelContainer, reason: String) -> Bool {
        guard let ensemblesContainer = activeEnsemblesContainer else { return true }
        let activity = String(describing: ensemblesContainer.currentActivity)
        guard ensemblesContainer.isAttached,
              activity.lowercased() == "none",
              !EnsemblesSaveGate.isInStartupAttachGracePeriod() else {
            return false
        }

        guard recordFirstEnsemblesDataAvailableIfNeeded(
            modelContainer: modelContainer,
            reason: "\(reason) attached idle store populated"
        ) else {
            return false
        }

        recordFirstSuccessfulEnsemblesSyncThisLaunch(reason: "\(reason) attached idle store populated")
        logToFile("✅ [Ensembles] Attached idle store observed (reason=\(reason))")
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

            if Write_App.canProceedWithStartupMaintenanceAfterIdle(
                modelContainer: sharedModelContainer,
                reason: reason
            ) {
                return true
            }

            _ = Write_App.recordFirstEnsemblesDataAvailableIfNeeded(
                modelContainer: sharedModelContainer,
                reason: "\(reason) store populated"
            )

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
