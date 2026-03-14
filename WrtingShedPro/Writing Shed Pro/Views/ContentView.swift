import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CloudKit

struct ContentView: View {
    @Query(sort: \Project.creationDate) var projects: [Project]
    @State private var state = ContentViewState()
    @State private var refreshTrigger = false
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    /// Timestamp of the last foreground sync nudge, used to debounce rapid transitions
    @State private var lastForegroundSyncDate: Date = .distantPast
    
    /// Task handle for the periodic sync timer (cancelled when app goes to background)
    @State private var periodicSyncTask: Task<Void, Never>?

    /// Startup migrations must run at most once per app launch.
    /// ContentView can be rebuilt during sync reconciliation, and rerunning migrations
    /// during CloudKit activity can cause unnecessary write churn.
    @State private var hasRunStartupMigrations = false

    /// Last time we auto-normalized project userOrder values.
    /// Used to avoid repeated writes during prolonged CloudKit churn.
    @State private var lastAutoOrderNormalizationDate: Date = .distantPast

    /// Debounced task handle for remote-change reconciliation.
    @State private var remoteReconcileTask: Task<Void, Never>?
    
    var body: some View {
        ContentViewBody(
            projects: projects,
            state: state,
            onInitialize: initializeUserOrderIfNeeded,
            onInitializeStyleSheets: initializeStyleSheets,
            onSyncNow: syncNowFromSettings,
            onHandleImportMenu: handleImportMenu,
            onHandleJSONImport: handleJSONImport,
            onDeleteAllProjects: deleteAllProjects,
            onPrefetchProjectData: prefetchProjectData,
            onRunMigrations: runMigrations
        )
        .id(refreshTrigger)
        .task {
            if scenePhase == .active {
                syncOnForegroundResume()
                startPeriodicSyncTimer()
            }
            await monitorSyncAndRefreshIfNeeded()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                syncOnForegroundResume()
                startPeriodicSyncTimer()
            } else if newPhase != .active && oldPhase == .active {
                stopPeriodicSyncTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"))) { _ in
            scheduleRemoteReconcile(reason: "remote-change")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NSPersistentStoreCoordinatorStoresDidChangeNotification"))) { _ in
            scheduleRemoteReconcile(reason: "stores-did-change")
        }
    }
    
    // MARK: - Foreground Resume Sync
    
    /// When the app returns to the foreground, force a CloudKit zone fetch.
    /// NSPersistentCloudKitContainer relies on silent push notifications to trigger imports,
    /// but these pushes are unreliable on Mac Catalyst and can be delayed/dropped on iPad
    /// when the app was suspended. This ensures we always pick up remote changes.
    private func syncOnForegroundResume() {
        // Debounce: don't re-sync if we already did within the last 60 seconds
        let now = Date()
        guard now.timeIntervalSince(lastForegroundSyncDate) > 60 else {
            #if DEBUG
            print("🔄 [ContentView] Foreground sync skipped — last sync was \(Int(now.timeIntervalSince(lastForegroundSyncDate)))s ago")
            #endif
            return
        }
        lastForegroundSyncDate = now
        
        #if DEBUG
        print("🔄 [ContentView] App became active — forcing CloudKit zone fetch for missed changes")
        #endif
        forceCloudKitImport()
    }
    
    /// Start an adaptive periodic sync watchdog while app is foregrounded.
    ///
    /// We intentionally run this frequently (every 60s), but only trigger expensive
    /// operations when CloudKit has been idle for a while. This gives us fast recovery
    /// when silent pushes are missed (common on Catalyst), without hammering CloudKit.
    private func startPeriodicSyncTimer() {
        stopPeriodicSyncTimer()  // cancel any existing timer
        periodicSyncTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)  // 60 seconds
                guard !Task.isCancelled else { break }
                performPeriodicSyncWatchdogTick()
            }
        }
    }
    
    /// Stop the periodic sync timer (called when the app goes to background).
    private func stopPeriodicSyncTimer() {
        periodicSyncTask?.cancel()
        periodicSyncTask = nil
    }

    /// Conservative periodic CloudKit maintenance.
    /// Forces a zone fetch only after extended idle time and never mutates local data.
    private func performPeriodicSyncWatchdogTick() {
        reconcileProjectListIfNeeded()

        let throttler = CloudKitSyncThrottler.shared
        if throttler.hasActiveCloudKitEvent {
            #if DEBUG
            print("⏳ [ContentView] Sync watchdog: CloudKit event in progress, skipping proactive sync actions")
            #endif
            return
        }
        let now = Date()
        let lastEvent = throttler.lastSyncTime ?? .distantPast
        let secondsSinceEvent = now.timeIntervalSince(lastEvent)

        guard secondsSinceEvent >= 180 else {
            #if DEBUG
            print("✅ [ContentView] Sync watchdog: recent CloudKit activity (\(Int(secondsSinceEvent))s ago), no action")
            #endif
            // If CloudKit isn't actively processing right now, still allow a conservative
            // order self-heal to run. This fixes userOrder collisions after conflict-heavy sync.
            if !throttler.hasActiveCloudKitEvent && !throttler.isSyncing {
                autoNormalizeProjectOrderIfNeeded()
            }
            return
        }

        autoNormalizeProjectOrderIfNeeded()

        #if DEBUG
        print("🔄 [ContentView] Sync watchdog: idle \(Int(secondsSinceEvent))s — forcing import")
        #endif
        forceCloudKitImport()
        lastForegroundSyncDate = now
    }

    /// Automatically normalize active project userOrder values when collisions are detected.
    /// This runs only when CloudKit is idle and is rate-limited to avoid write churn.
    private func autoNormalizeProjectOrderIfNeeded() {
        let throttler = CloudKitSyncThrottler.shared
        guard !throttler.hasActiveCloudKitEvent && !throttler.isSyncing else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAutoOrderNormalizationDate) > 300 else { return }

        let activeProjects = ProjectSortService.sortProjects(
            projects.filter { !$0.isTrashed },
            by: .byUserOrder
        )
        guard !activeProjects.isEmpty else { return }

        var seenOrders = Set<Int>()
        var hasCollisionOrMissingOrder = false
        for project in activeProjects {
            guard let order = project.userOrder else {
                hasCollisionOrMissingOrder = true
                break
            }
            if !seenOrders.insert(order).inserted {
                hasCollisionOrMissingOrder = true
                break
            }
        }

        guard hasCollisionOrMissingOrder else { return }

        for (index, project) in activeProjects.enumerated() {
            project.userOrder = index
        }

        do {
            try modelContext.save()
            lastAutoOrderNormalizationDate = now
            #if DEBUG
            print("✅ [ContentView] Auto-normalized userOrder for \(activeProjects.count) active projects")
            #endif
        } catch {
            #if DEBUG
            print("❌ [ContentView] Auto-normalize project order failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Debounced reconciliation triggered by CoreData/CloudKit notifications.
    /// This makes newly imported projects appear quickly during long import storms,
    /// instead of waiting for the periodic watchdog cadence.
    private func scheduleRemoteReconcile(reason: String) {
        guard scenePhase == .active else { return }

        remoteReconcileTask?.cancel()
        remoteReconcileTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000) // debounce notification bursts
            guard !Task.isCancelled else { return }
            reconcileProjectListIfNeeded()

            #if DEBUG
            print("🔄 [ContentView] Reconcile triggered by \(reason)")
            #endif
        }
    }

    /// Manual sync trigger exposed from Settings.
    /// Uses the same CloudKit zone-fetch nudge as foreground resume.
    private func syncNowFromSettings() {
        #if DEBUG
        print("🔄 [ContentView] Sync Now requested from Settings")
        #endif
        forceCloudKitImport()
        scheduleRemoteReconcile(reason: "sync-now")
    }

    /// `@Query` can occasionally miss newly imported CloudKit rows, or return
    /// in-memory Project objects whose properties (e.g. name) are stale relative
    /// to the underlying SQLite store after a CloudKit field update.
    ///
    /// modelContext.fetch() shares the same in-memory object graph as @Query, so it
    /// can't detect staleness either. Instead we create a fresh, throwaway ModelContext
    /// from the same container — this always reads directly from the persistent store.
    ///
    /// Reconcile against a direct fetch and force-refresh when:
    ///   a) the active project count differs, OR
    ///   b) any project's name in @Query doesn't match what's in the store.
    private func reconcileProjectListIfNeeded() {
        let freshContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Project>()
        guard let allProjects = try? freshContext.fetch(descriptor) else { return }

        let dbActiveCount = allProjects.filter { !$0.isTrashed }.count
        let uiActiveCount = projects.filter { !$0.isTrashed }.count

        if dbActiveCount != uiActiveCount {
            #if DEBUG
            print("🔄 [ContentView] Reconcile: DB has \(dbActiveCount) active projects, UI shows \(uiActiveCount). Forcing refresh.")
            #endif
            refreshTrigger.toggle()
            return
        }

        // Build a quick id→name lookup from the store and compare against @Query objects.
        // If any name is stale in the UI layer, refresh the whole view.
        let dbNameByID = Dictionary(uniqueKeysWithValues: allProjects.compactMap { p -> (UUID, String)? in
            guard let name = p.name else { return nil }
            return (p.id, name)
        })
        let hasStaleName = projects.contains { p in
            guard let dbName = dbNameByID[p.id] else { return false }
            return p.name != dbName
        }
        if hasStaleName {
            #if DEBUG
            print("🔄 [ContentView] Reconcile: stale project name(s) detected in @Query — forcing refresh.")
            #endif
            refreshTrigger.toggle()
        }
    }
    
    /// On fresh install, @Query may not update after CloudKit bulk import.
    /// Poll periodically and force a view refresh if data exists but @Query is empty.
    /// If no data arrives, repeatedly nudge CloudKit since Mac Catalyst often
    /// fails to receive push notifications that drive the import engine.
    private func monitorSyncAndRefreshIfNeeded() async {
        // Only needed on fresh install (no projects yet)
        guard projects.isEmpty else { return }
        
        // Simple strategy: poll every 10s for up to 5 minutes.
        // Re-kick CloudKit every 60s to keep the daemon awake.
        // The ONLY exit conditions are:
        //   a) Projects appear in the database → success, refresh view.
        //   b) 5 minutes elapse with no projects → show recovery alert.
        // We do NOT try to detect "stall" based on sync events — CloudKit can
        // go long stretches between notification bursts and importCompleted
        // fires after the first batch, not the last.
        
        // Initial kick: give APNs 2s to deliver token, then force a zone fetch
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        #if DEBUG
        print("🔄 [ContentView] Initial kick — forcing CloudKit zone fetch…")
        #endif
        forceCloudKitImport()
        
        let totalChecks = 30               // 30 × 10s = 5 minutes
        let reKickInterval = 6             // legacy debug cadence for status logging
        
        for check in 1...totalChecks {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            
            // --- Do we have projects yet? ---
            if !projects.isEmpty { return }
            
            let descriptor = FetchDescriptor<Project>()
            if let count = try? modelContext.fetchCount(descriptor), count > 0 {
                #if DEBUG
                print("🔄 [ContentView] Found \(count) projects at check \(check)/\(totalChecks) — refreshing")
                #endif
                refreshTrigger.toggle()
                return
            }
            
            #if DEBUG
            if check % 3 == 0 {
                let events = CloudKitSyncThrottler.shared.totalSyncEventCount
                print("⏳ [ContentView] Waiting for sync check \(check)/\(totalChecks): events=\(events)")
            }
            #endif
            
            // --- Re-kick CloudKit periodically to keep daemon active ---
            if check % reKickInterval == 0 && check == reKickInterval {
                #if DEBUG
                print("⏸️ [ContentView] Aggressive auto re-kicks disabled — relying on natural container retries")
                #endif
            }
        }
        
        #if DEBUG
        print("⚠️ [ContentView] 5 minutes elapsed with no projects — sync may still be in progress")
        #endif
    }
    
    /// Forcibly wake up the CloudKit daemon by fetching record zone changes.
    /// On Mac Catalyst the silent-push path is unreliable even after registering
    /// for remote notifications, so this acts as a belt-and-suspenders fallback
    /// that causes NSPersistentCloudKitContainer to notice outstanding changes.
    ///
    /// **Rate-limit aware**: Skips the operation if CloudKit recently returned
    /// a rate-limit or service-unavailable error, to avoid piling on requests
    /// and making the throttling worse.
    private func forceCloudKitImport() {
        guard !CloudKitSyncThrottler.shared.hasActiveCloudKitEvent else {
            #if DEBUG
            print("⏳ [ContentView] forceCloudKitImport skipped — CloudKit event in progress")
            #endif
            return
        }
        guard !CloudKitSyncThrottler.shared.isManualKickPaused else {
            #if DEBUG
            print("⏳ [ContentView] forceCloudKitImport skipped — manual kick backoff active")
            #endif
            return
        }
        // Don't fire if we're currently rate-limited — let the container's
        // internal retry handle it with proper server-provided backoff.
        guard !CloudKitSyncThrottler.shared.isRateLimited else {
            #if DEBUG
            print("⏳ [ContentView] forceCloudKitImport skipped — rate-limited until \(CloudKitSyncThrottler.shared.rateLimitedUntil?.description ?? "?")")
            #endif
            return
        }
        
        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        let database = ckContainer.privateCloudDatabase
        
        database.fetchAllRecordZones { zones, error in
            guard let zones = zones, !zones.isEmpty else {
                #if DEBUG
                print("⚠️ [ContentView] forceCloudKitImport: no zones or error: \(error?.localizedDescription ?? "nil")")
                #endif
                return
            }
            
            #if DEBUG
            print("🔄 [ContentView] forceCloudKitImport: fetching changes from \(zones.count) zone(s)")
            #endif
            
            // Build per-zone configs — passing nil for the server change token
            // forces a full fetch from the server which is exactly what we need
            // to wake up the mirroring engine.
            var configs = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
            for zone in zones {
                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                config.previousServerChangeToken = nil   // full fetch
                configs[zone.zoneID] = config
            }
            
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: zones.map(\.zoneID),
                configurationsByRecordZoneID: configs
            )
            
            // We don't process results ourselves — NSPersistentCloudKitContainer will
            // react to the daemon activity and import the records.
            operation.fetchRecordZoneChangesResultBlock = { result in
                #if DEBUG
                switch result {
                case .success:
                    print("✅ [ContentView] forceCloudKitImport: zone fetch completed — daemon should trigger import")
                case .failure(let err):
                    print("⚠️ [ContentView] forceCloudKitImport: zone fetch error: \(err.localizedDescription)")
                }
                #endif
            }
            
            operation.qualityOfService = .userInitiated
            database.add(operation)
        }
    }
    
    /// Run data migrations for new features, delayed to avoid CloudKit sync race conditions.
    /// When the app launches with a fresh database, CloudKit imports records immediately.
    /// Running migrations during that import can cause duplicate records because the
    /// migration modifies imported records, causing CloudKit to treat them as new local records.
    private func runMigrations() {
        guard !hasRunStartupMigrations else {
            #if DEBUG
            print("⏭️ [ContentView] Startup migrations already ran in this launch — skipping")
            #endif
            return
        }
        hasRunStartupMigrations = true

        let throttler = CloudKitSyncThrottler.shared
        
        Task { @MainActor in
            // Wait for any initial CloudKit import burst to settle.
            // On first launch / fresh database, CloudKit fires rapid notifications
            // as it imports records. We must not mutate those records during import.
            var waitCycles = 0
            let maxWait = 30  // Up to 30 seconds
            
            // Give CloudKit a moment to START syncing before we check
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            
            // If sync is active, wait for it to settle
            while throttler.isSyncing && waitCycles < maxWait {
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                waitCycles += 1
                #if DEBUG
                if waitCycles % 5 == 0 {
                    print("⏳ [ContentView] Waiting for CloudKit sync to settle before migration... (\(waitCycles)s)")
                }
                #endif
            }
            
            #if DEBUG
            if waitCycles > 0 {
                print("✅ [ContentView] CloudKit sync settled after \(waitCycles)s, running migrations")
            } else {
                print("✅ [ContentView] No active sync detected, running migrations immediately")
            }
            #endif
            
            // Now safe to run migrations
            MigrationService.runMigrations(context: modelContext)

            // IMPORTANT: Do not auto-delete "duplicate" projects on launch.
            // CloudKit may temporarily surface same-name records during staggered
            // relationship sync and automatic name-based deletion can remove valid
            // newly imported projects. Deduplication remains available from diagnostics.
        }
    }
    
    /// Prefetch project relationships async to warm up Swift type system
    /// This prevents UI freeze when tapping first project after app launch
    private func prefetchProjectData() {
        guard !projects.isEmpty else { return }
        
        // DIAGNOSTIC: Log all data to understand sync issues
        #if DEBUG
        print("========================================")
        print("📊 [SYNC DIAGNOSTIC] Starting data analysis...")
        print("========================================")
        
        // Check project details to see what differentiates working vs broken
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        print("📋 [SYNC] PROJECT DETAILS (checking for differences):")
        for project in projects.sorted(by: { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }) {
            let folderCount = project.folders?.count ?? 0
            let status = folderCount > 0 ? "✅" : "❌"
            let created = project.creationDate.map { dateFormatter.string(from: $0) } ?? "nil"
            let modified = project.modifiedDate.map { dateFormatter.string(from: $0) } ?? "nil"
            print("   \(status) '\(project.name ?? "?")' type:\(project.typeRaw ?? "nil") created:\(created) modified:\(modified) folders:\(folderCount)")
        }
        print("")
        
        // First, do a direct database query for ALL folders regardless of relationships
        let folderDescriptor = FetchDescriptor<Folder>()
        if let allFolders = try? modelContext.fetch(folderDescriptor) {
            print("📁 [SYNC] Total folders in database: \(allFolders.count)")
            
            var orphanedFolders: [Folder] = []
            var foldersWithProject: [Folder] = []
            var foldersWithParent: [Folder] = []
            var foldersWithBoth: [Folder] = []
            
            for folder in allFolders {
                let hasProject = folder.project != nil
                let hasParent = folder.parentFolder != nil
                
                if !hasProject && !hasParent {
                    orphanedFolders.append(folder)
                } else if hasProject && hasParent {
                    foldersWithBoth.append(folder)
                } else if hasProject {
                    foldersWithProject.append(folder)
                } else {
                    foldersWithParent.append(folder)
                }
            }
            
            print("   ├─ Folders with project relationship: \(foldersWithProject.count)")
            print("   ├─ Folders with parentFolder (subfolders): \(foldersWithParent.count)")
            print("   ├─ Folders with BOTH (error): \(foldersWithBoth.count)")
            print("   └─ Folders with NEITHER (orphaned): \(orphanedFolders.count)")
            
            if !orphanedFolders.isEmpty {
                print("⚠️ [SYNC] ORPHANED FOLDERS (no project, no parent):")
                for folder in orphanedFolders.prefix(20) {
                    print("   - '\(folder.name ?? "nil")' id:\(folder.persistentModelID)")
                }
                if orphanedFolders.count > 20 {
                    print("   ... and \(orphanedFolders.count - 20) more")
                }
            }
        }
        
        // Also query all files directly
        let fileDescriptor = FetchDescriptor<TextFile>()
        if let allFiles = try? modelContext.fetch(fileDescriptor) {
            print("📄 [SYNC] Total files in database: \(allFiles.count)")
            
            let orphanedFiles = allFiles.filter { $0.parentFolder == nil }
            print("   └─ Files with no folder (orphaned): \(orphanedFiles.count)")
            
            if !orphanedFiles.isEmpty {
                print("⚠️ [SYNC] ORPHANED FILES (no folder):")
                for file in orphanedFiles.prefix(10) {
                    print("   - '\(file.name)'")
                }
            }
        }
        
        print("----------------------------------------")
        print("📊 [SYNC] Projects visible to @Query: \(projects.count)")
        
        for project in projects {
            let folderCount = project.folders?.count ?? 0
            let rootFolders = project.folders?.filter { $0.parentFolder == nil } ?? []
            print("   📁 '\(project.name ?? "Untitled")' - \(folderCount) folders (\(rootFolders.count) root)")
            
            if folderCount == 0 {
                print("      ⚠️ NO FOLDERS - this is the problem!")
            } else {
                // Show root folders
                for folder in rootFolders.prefix(5) {
                    let fileCount = folder.textFiles?.count ?? 0
                    let subfolderCount = folder.folders?.count ?? 0
                    print("      ├─ '\(folder.name ?? "nil")' (\(fileCount) files, \(subfolderCount) subfolders)")
                }
                if rootFolders.count > 5 {
                    print("      └─ ... and \(rootFolders.count - 5) more root folders")
                }
            }
        }
        
        print("========================================")
        print("📊 [SYNC DIAGNOSTIC] Analysis complete")
        print("========================================")
        
        // Schedule a delayed re-check to see if CloudKit sync fixes relationships
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            await MainActor.run {
                runDelayedDiagnostic()
            }
        }
        #endif
        
        // Only do expensive prefetch in Debug builds where it matters
        #if DEBUG
        print("[ContentView] Starting async prefetch of project relationships...")
        
        Task(priority: .utility) {
            // Access relationships to force SwiftData to materialize them
            // Runs async on main thread (SwiftData objects must stay on their thread)
            for project in projects {
                // Touch each relationship to warm up the object graph
                _ = project.folders?.count ?? 0
                _ = project.publications?.count ?? 0
                _ = project.submissions?.count ?? 0
                _ = project.submittedFiles?.count ?? 0
                _ = project.trashedItems?.count ?? 0
                _ = project.styleSheet?.name
                _ = project.pageSetup?.paperSize
                
                // Access nested relationships in folders
                if let folders = project.folders {
                    for folder in folders {
                        _ = folder.textFiles?.count ?? 0
                        _ = folder.folders?.count ?? 0
                    }
                }
            }
            
            print("[ContentView] ✅ Prefetch complete")
        }
        #endif
    }
    
    /// Delayed diagnostic to check if CloudKit sync has fixed relationships
    private func runDelayedDiagnostic() {
        #if DEBUG
        print("")
        print("========================================")
        print("📊 [SYNC DIAGNOSTIC] 30-SECOND RECHECK")
        print("========================================")
        
        let folderDescriptor = FetchDescriptor<Folder>()
        let fileDescriptor = FetchDescriptor<TextFile>()
        
        if let allFolders = try? modelContext.fetch(folderDescriptor),
           let allFiles = try? modelContext.fetch(fileDescriptor) {
            
            let orphanedFolders = allFolders.filter { $0.project == nil && $0.parentFolder == nil }
            let orphanedFiles = allFiles.filter { $0.parentFolder == nil }
            
            print("📁 Folders: \(allFolders.count) total, \(orphanedFolders.count) orphaned")
            print("📄 Files: \(allFiles.count) total, \(orphanedFiles.count) orphaned")
            
            // Check if situation improved
            print("----------------------------------------")
            print("📊 Projects status:")
            for project in projects {
                let folderCount = project.folders?.count ?? 0
                let totalFiles = project.folders?.reduce(0) { $0 + ($1.textFiles?.count ?? 0) } ?? 0
                print("   '\(project.name ?? "?")': \(folderCount) folders, \(totalFiles) files linked")
            }
        }
        
        print("========================================")
        #endif
    }
    
    /// Initialize default stylesheets async on main thread (moved from Write_App to avoid blocking launch)
    private func initializeStyleSheets() {
        Task(priority: .utility) {
            // Run async on main thread (ModelContext must stay on its creation thread)
            StyleSheetService.initializeStyleSheetsIfNeeded(context: modelContext)
            #if DEBUG
            print("✅ [ContentView] Stylesheets initialized")
            #endif
            
            // Migrate heading styles to include TOC settings (for existing stylesheets)
            StyleSheetService.migrateHeadingStylesToTOC(context: modelContext)
            #if DEBUG
            print("✅ [ContentView] TOC migration complete")
            #endif
            
            // Migrate heading styles to bold (Title 1–3, Large Title were not bold previously)
            StyleSheetService.migrateHeadingStylesToBold(context: modelContext)
            #if DEBUG
            print("✅ [ContentView] Heading bold migration complete")
            #endif
            
            // One-time fix: Convert user guide files to markdown mode
            migrateUserGuideToMarkdown()
        }
    }
    
    /// One-time migration: Convert Writing Shed Pro Guide files to markdown mode
    /// These files were imported as markdown but contentType was not set correctly
    private func migrateUserGuideToMarkdown() {
        // v2: Also clears stale formattedContent from markdown files and recurses into subfolders
        let migrationKey = "userGuideMarkdownMigrationComplete_v2"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            #if DEBUG
            print("✅ [ContentView] User guide markdown migration already complete")
            #endif
            return
        }
        
        do {
            // Find the Writing Shed Pro Guide project
            let projectDescriptor = FetchDescriptor<Project>(
                predicate: #Predicate { $0.name == "Writing Shed Pro Guide" }
            )
            guard let guideProject = try modelContext.fetch(projectDescriptor).first else {
                #if DEBUG
                print("ℹ️ [ContentView] No 'Writing Shed Pro Guide' project found, skipping markdown migration")
                #endif
                // Mark as complete so we don't keep checking
                UserDefaults.standard.set(true, forKey: migrationKey)
                return
            }
            
            // Get all files in this project's folders (including subfolders)
            var migratedCount = 0
            func migrateFilesInFolder(_ folder: Folder) {
                for file in folder.textFiles ?? [] {
                    if file.contentTypeRaw == "richText" {
                        // Convert to markdown
                        file.contentTypeRaw = "markdown"
                        // Clear stale formattedContent — markdown files use plain text
                        if let version = file.currentVersion {
                            version.formattedContent = nil
                        }
                        migratedCount += 1
                    } else if file.contentTypeRaw == "markdown" {
                        // Already markdown but clear any stale formattedContent
                        if let version = file.currentVersion, version.formattedContent != nil {
                            version.formattedContent = nil
                            migratedCount += 1
                        }
                    }
                }
                for subfolder in folder.subfolders ?? [] {
                    migrateFilesInFolder(subfolder)
                }
            }
            if let folders = guideProject.folders {
                for folder in folders {
                    migrateFilesInFolder(folder)
                }
            }
            
            if migratedCount > 0 {
                try modelContext.save()
                #if DEBUG
                print("✅ [ContentView] Migrated \(migratedCount) files to markdown mode in 'Writing Shed Pro Guide'")
                #endif
            } else {
                #if DEBUG
                print("ℹ️ [ContentView] No files needed markdown migration")
                #endif
            }
            
            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            #if DEBUG
            print("❌ [ContentView] User guide markdown migration failed: \(error)")
            #endif
        }
    }
    
    /// Handle Import menu action - show file picker directly
    private func handleImportMenu() {
        #if DEBUG
        print("[ContentView] Import menu clicked - showing file picker")
        #endif
        state.showingJSONImportPicker = true
    }
    

    
    private func handleJSONImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            
            #if DEBUG
            print("[ContentView] Starting JSON import from: \(fileURL)")
            #endif
            
            Task {
                // CRITICAL: Start accessing security-scoped resource inside the Task
                guard fileURL.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        state.importErrorMessage = NSLocalizedString("contentView.importError.accessDenied", comment: "Unable to access the selected file")
                        state.showImportError = true
                    }
                    #if DEBUG
                    print("[ContentView] Failed to access security-scoped resource")
                    #endif
                    return
                }
                
                // Ensure we stop accessing when done
                defer {
                    fileURL.stopAccessingSecurityScopedResource()
                    #if DEBUG
                    print("[ContentView] Stopped accessing security-scoped resource")
                    #endif
                }
                
                do {
                    // Create error handler
                    let errorHandler = ImportErrorHandler()
                    
                    // JSON/WSP/WSD import
                    // Always generate new UUIDs to prevent CloudKit from merging
                    // duplicate-UUID folders/files across the original and imported projects
                    let jsonImporter = JSONImportService(
                        modelContext: modelContext,
                        errorHandler: errorHandler,
                        generateNewUUIDs: true
                    )
                    
                    // Perform import
                    let project = try jsonImporter.importFromJSON(fileURL: fileURL)
                    
                    #if DEBUG
                    print("[ContentView] JSON import succeeded: \(project.name ?? "Untitled")")
                    #endif
                    
                    // Show warnings if any
                    if !errorHandler.warnings.isEmpty {
                        #if DEBUG
                        print("[ContentView] Import completed with \(errorHandler.warnings.count) warnings:")
                        #endif
                        errorHandler.warnings.forEach { print("  - \($0)") }
                    }

                    // DISABLED: MigrationService was breaking CloudKit sync
                    // Run migration after import to ensure manuscript subfolders are present
                    // MigrationService.runMigrations(context: modelContext)
                    // #if DEBUG
                    // print("[ContentView] Ran MigrationService after import")
                    // #endif
                } catch ImportError.missingContent {
                    await MainActor.run {
                        state.importErrorMessage = NSLocalizedString("contentView.importError.emptyFile", comment: "The selected file is empty or corrupt")
                        state.showImportError = true
                    }
                } catch {
                    await MainActor.run {
                        state.importErrorMessage = String(format: NSLocalizedString("contentView.importError.failed", comment: "Failed to import project"), error.localizedDescription)
                        state.showImportError = true
                    }
                    #if DEBUG
                    print("[ContentView] JSON import failed: \(error)")
                    #endif
                }
            }
            
        case .failure(let error):
            state.importErrorMessage = String(format: NSLocalizedString("contentView.importError.selectFailed", comment: "Failed to select file"), error.localizedDescription)
            state.showImportError = true
            #if DEBUG
            print("[ContentView] File selection failed: \(error)")
            #endif
        }
    }
    
    private func initializeUserOrderIfNeeded() {
        // DISABLED: All migrations disabled - breaking CloudKit sync
        // ProjectFolderMigrationService.migrateIfNeeded(modelContext: modelContext)

        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\Project.creationDate)])
        guard let allProjects = try? modelContext.fetch(descriptor), !allProjects.isEmpty else {
            return
        }

        let projectsNeedingOrder = allProjects.filter { $0.userOrder == nil }
        guard !projectsNeedingOrder.isEmpty else {
            return
        }

        let throttler = CloudKitSyncThrottler.shared
        guard !throttler.hasActiveCloudKitEvent && !throttler.isSyncing else {
            #if DEBUG
            print("⏳ [ContentView] Skipping userOrder initialization while CloudKit sync is active")
            #endif
            return
        }

        guard projectsNeedingOrder.count == allProjects.count else {
            #if DEBUG
            print("⚠️ [ContentView] Skipping userOrder initialization because only \(projectsNeedingOrder.count) of \(allProjects.count) projects are missing order")
            #endif
            return
        }

        for (index, project) in allProjects.enumerated() {
            project.userOrder = index
        }

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ [ContentView] Initialized userOrder for \(allProjects.count) projects")
            #endif
        } catch {
            #if DEBUG
            print("❌ [ContentView] Failed to initialize userOrder: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func deleteAllProjects() {
        #if DEBUG
        print("[ContentView] DEBUG: Deleting all \(projects.count) projects")
        for project in projects {
            modelContext.delete(project)
        }
        do {
            try modelContext.save()
            #if DEBUG
            print("[ContentView] DEBUG: Successfully deleted all projects")
            #endif
        } catch {
            #if DEBUG
            print("[ContentView] DEBUG: Failed to delete projects: \(error)")
            #endif
        }
        #endif
    }
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Project.self, inMemory: true)
//}
