import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CloudKit
import Combine

struct ContentView: View {
    @Query(sort: \Project.creationDate) var projects: [Project]
    @State private var state = ContentViewState()
    @State private var refreshTrigger = false
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(WriteCoalescer.self) private var writeCoalescer
    
    /// Timestamp of the last foreground sync nudge, used to debounce rapid transitions
    @State private var lastForegroundSyncDate: Date = .distantPast
    
    /// Task handle for the periodic sync timer (cancelled when app goes to background)
    @State private var periodicSyncTask: Task<Void, Never>?

    /// Last time we ran a lightweight CloudKit probe to wake stalled sync state.
    @State private var lastCloudKitProbeDate: Date = .distantPast

    /// Startup migrations must run at most once per app launch.
    /// ContentView can be rebuilt during sync reconciliation, and rerunning migrations
    /// during CloudKit activity can cause unnecessary write churn.
    @State private var hasRunStartupMigrations = false

    /// Stylesheet initialization must run at most once per app launch.
    /// Running this while CloudKit import is inflight can create duplicate system defaults.
    @State private var hasInitializedStyleSheets = false
    @State private var styleSheetInitTask: Task<Void, Never>?

    /// Last time we auto-normalized project userOrder values.
    /// Used to avoid repeated writes during prolonged CloudKit churn.
    @State private var lastAutoOrderNormalizationDate: Date = .distantPast

    /// Last time we attempted automatic duplicate cleanup.
    /// Keeps startup/reconcile paths from repeatedly scanning and mutating during bursts.
    @State private var lastAutoDedupDate: Date = .distantPast

    /// Last time we attempted post-import repair cleanup.
    /// Keeps reconcile/startup paths from repeatedly scanning the store after a sync storm.
    @State private var lastPostImportRepairDate: Date = .distantPast

    /// Debounced task handle for remote-change reconciliation.
    @State private var remoteReconcileTask: Task<Void, Never>?

    @State private var showSyncRecoveryBanner = false
    @State private var syncRecoveryBannerTask: Task<Void, Never>?

    @State private var offlinePurchaseBannerDismissed = false
    
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
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if showSyncRecoveryBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        Text(NSLocalizedString("sync.recovery.banner", comment: "Sync delayed, retrying"))
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if #available(macCatalyst 15, iOS 17.4, *) {
                    if EntitlementManager.shared.showOfflinePurchaseWarning && !offlinePurchaseBannerDismissed {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                            Text(NSLocalizedString("purchases.offline.banner", comment: "Purchases unavailable offline"))
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Button {
                                withAnimation { offlinePurchaseBannerDismissed = true }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .padding(.top, 8)
        }
        .id(refreshTrigger)
        .task {
            // DISABLED: All proactive sync interventions removed.
            // SwiftData + CloudKit handles sync automatically via
            // NSPersistentCloudKitContainer's mirroring delegate.
            // The watchdog, forced imports, and polling were causing
            // export retry storms that triggered sustained rate-limiting.
            //
            // Keeping: passive CloudKitSyncThrottler observation,
            // UI reconciliation on remote-change notifications.

            // Keep the passive watchdog running while foregrounded so UI reconciliation
            // and stale-sync diagnostics continue without opening Sync Diagnostics.
            if scenePhase == .active {
                startPeriodicSyncTimer()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                // Just reconcile the UI on foreground resume — don't
                // force any CloudKit operations.
                syncOnForegroundResume()
                startPeriodicSyncTimer()
                scheduleRemoteReconcile(reason: "foreground-resume")
            }
            if newPhase == .background {
                stopPeriodicSyncTimer()
                writeCoalescer.flush()
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            dismissSyncRecoveryBanner()
            scheduleRemoteReconcile(reason: "remote-change")
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSNotification.Name("NSPersistentStoreCoordinatorStoresDidChangeNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            dismissSyncRecoveryBanner()
            scheduleRemoteReconcile(reason: "stores-did-change")
        }
        // When EntitlementManager clears the offline warning (connectivity restored +
        // purchases verified), re-show the banner next time if it happens again.
        .task {
            if #available(macCatalyst 15, iOS 17.4, *) {
                for await _ in offlinePurchaseWarningStream() {
                    withAnimation { offlinePurchaseBannerDismissed = false }
                }
            }
        }
        // Handle files opened from Finder / Share sheet while the app is already running.
        .onReceive(NotificationCenter.default.publisher(for: .writingShedProOpenFile)) { notification in
            guard let url = notification.object as? URL else { return }
            #if DEBUG
            print("[ContentView] onReceive writingShedProOpenFile: \(url.lastPathComponent)")
            #endif
            handleOpenedFileURL(url)
        }
        // Handle File > Open... (Cmd+O) menu command — show the file importer picker.
        .onReceive(NotificationCenter.default.publisher(for: .writingShedProShowImportPicker)) { _ in
            #if DEBUG
            print("[ContentView] onReceive writingShedProShowImportPicker — presenting file importer")
            #endif
            state.showingJSONImportPicker = true
        }
        // Handle files opened at cold launch (URL stored by AppDelegate before this view appeared).
        .task {
            guard let delegate = UIApplication.shared.delegate as? AppDelegate,
                  let url = delegate.consumePendingOpenURL() else { return }
            #if DEBUG
            print("[ContentView] task: consuming pending open URL: \(url.lastPathComponent)")
            #endif
            handleOpenedFileURL(url)
        }
    }

    private func handleOpenedFileURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ext == "wsp" || ext == "wsd" || ext == "json" else { return }
        handleJSONImport(.success([url]))
    }
    
    // MARK: - Foreground Resume Sync
    
    /// When the app returns to the foreground, just resume passive observation.
    /// CloudKit recovery is left to NSPersistentCloudKitContainer.
    private func syncOnForegroundResume() {
        let now = Date()
        guard now.timeIntervalSince(lastForegroundSyncDate) > 60 else {
            #if DEBUG
            print("🔄 [ContentView] Foreground resume ignored — last observation was \(Int(now.timeIntervalSince(lastForegroundSyncDate)))s ago")
            #endif
            return
        }
        lastForegroundSyncDate = now

        #if DEBUG
        print("🔄 [ContentView] App became active — resuming passive CloudKit observation")
        #endif
    }
    
    /// Start a periodic passive sync watchdog while app is foregrounded.
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

    /// Passive periodic CloudKit maintenance.
    /// This performs only local reconciliation and diagnostics-safe self-healing.
    private func performPeriodicSyncWatchdogTick() {
        reconcileProjectListIfNeeded()
        maybeRunCloudKitLivenessProbe(reason: "periodic")

        let throttler = CloudKitSyncThrottler.shared
        let now = Date()
        guard let lastEvent = throttler.mostRecentActivityTime else {
            #if DEBUG
            print("⏳ [ContentView] Sync watchdog: no CloudKit activity recorded yet")
            #endif
            return
        }
        let secondsSinceEvent = now.timeIntervalSince(lastEvent)

        if throttler.hasActiveCloudKitEvent {
            if secondsSinceEvent >= 180 {
                showSyncRecoveryBannerTemporarily()
                #if DEBUG
                print("⚠️ [ContentView] Sync watchdog: CloudKit event appears idle for \(Int(secondsSinceEvent))s — observing only, no manual kick")
                #endif
            }
            #if DEBUG
            print("⏳ [ContentView] Sync watchdog: CloudKit event in progress")
            #endif
            return
        }

        guard secondsSinceEvent >= 180 else {
            #if DEBUG
            print("✅ [ContentView] Sync watchdog: recent CloudKit activity (\(Int(secondsSinceEvent))s ago), no action")
            #endif
            if !throttler.hasActiveCloudKitEvent && !throttler.isSyncing {
                autoNormalizeProjectOrderIfNeeded()
            }
            return
        }

        autoNormalizeProjectOrderIfNeeded()

        #if DEBUG
        print("🔄 [ContentView] Sync watchdog: idle \(Int(secondsSinceEvent))s — passive observation only")
        #endif
    }

    /// Lightweight CloudKit liveness probe while app is active.
    /// This is read-only and avoids manual imports/exports, but helps wake the
    /// CloudKit stack when silent pushes are delayed or dropped.
    private func maybeRunCloudKitLivenessProbe(reason: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCloudKitProbeDate) >= 60 else { return }
        lastCloudKitProbeDate = now

        let ckContainer = CKContainer(identifier: "iCloud.com.appworks.writingshedpro")
        ckContainer.privateCloudDatabase.fetchAllSubscriptions { subscriptions, error in
            #if DEBUG
            if let error {
                print("⚠️ [ContentView] CloudKit probe (\(reason)) failed: \(error.localizedDescription)")
            } else {
                let count = subscriptions?.count ?? 0
                print("✅ [ContentView] CloudKit probe (\(reason)) completed: subscriptions=\(count)")
            }
            #endif

            // Follow with a cheap zone list fetch. In practice this helps kick
            // CloudKit activity on devices that missed silent pushes.
            ckContainer.privateCloudDatabase.fetchAllRecordZones { zones, zoneError in
                #if DEBUG
                if let zoneError {
                    print("⚠️ [ContentView] CloudKit zone probe (\(reason)) failed: \(zoneError.localizedDescription)")
                } else {
                    print("✅ [ContentView] CloudKit zone probe (\(reason)) completed: zones=\(zones?.count ?? 0)")
                }
                #endif

                DispatchQueue.main.async {
                    scheduleRemoteReconcile(reason: "cloudkit-liveness-probe")
                }
            }
        }
    }

    /// Assign userOrder to projects that don't have one yet.
    /// CRITICAL: Never overwrite existing userOrder values — they may have been
    /// set by the user on another device and synced via CloudKit. Overwriting
    /// causes a ping-pong effect where each device renumbers independently.
    private func autoNormalizeProjectOrderIfNeeded() {
        let throttler = CloudKitSyncThrottler.shared
        guard !throttler.hasActiveCloudKitEvent && !throttler.isSyncing else { return }
        guard throttler.importCompleted else { return }
        guard !throttler.isRateLimited else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAutoOrderNormalizationDate) > 600 else { return }

        let activeProjects = projects.filter { !$0.isTrashed }
        guard !activeProjects.isEmpty else { return }

        // Only touch projects that have nil userOrder — never overwrite synced values
        let unordered = activeProjects.filter { $0.userOrder == nil }
        guard !unordered.isEmpty else { return }

        // Find the next available order slot (after all existing ordered projects)
        let maxExisting = activeProjects.compactMap(\.userOrder).max() ?? -1
        var nextOrder = maxExisting + 1
        var changedCount = 0

        // Sort unordered projects by creation date so they appear in a sensible order
        let sortedUnordered = unordered.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
        for project in sortedUnordered {
            project.userOrder = nextOrder
            nextOrder += 1
            changedCount += 1
        }

        do {
            try modelContext.save()
            lastAutoOrderNormalizationDate = now
            #if DEBUG
            print("✅ [ContentView] Assigned userOrder to \(changedCount) new project(s), starting at \(maxExisting + 1)")
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
    /// Only reconciles the UI — does not force CloudKit operations.
    /// SwiftData's mirroring delegate handles actual sync.
    private func syncNowFromSettings() {
        #if DEBUG
        print("🔄 [ContentView] Sync Now requested from Settings")
        #endif
        // Reset any accumulated backoff so the mirroring delegate can
        // retry naturally without the throttler blocking UI updates.
        CloudKitSyncThrottler.shared.resetBackoffState()
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
        // Only run zombie cleanup when exports can actually propagate — otherwise
        // we generate local deletes that queue exports and deepen rate-limiting.
        if !CloudKitSyncThrottler.shared.isRateLimited {
            let zombies = DeduplicationService.deleteZombieProjects(context: modelContext)
            if zombies > 0 {
                #if DEBUG
                print("🪦 [ContentView] Reconcile: removed \(zombies) zombie project(s)")
                #endif
                refreshTrigger.toggle()
                return
            }
        }

        // Automatically clean up CloudKit clone rows once sync is settled.
        performAutomaticDedupIfSafe(reason: "reconcile")
        performPostImportRepairIfSafe(reason: "reconcile")

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
    private func monitorSyncAndRefreshIfNeeded() async {
        // Only needed on fresh install (no projects yet)
        guard projects.isEmpty else { return }

        // Simple strategy: poll every 10s for up to 5 minutes.
        // The ONLY exit conditions are:
        //   a) Projects appear in the database → success, refresh view.
        //   b) 5 minutes elapse with no projects → show recovery alert.
        // We intentionally avoid app-driven CloudKit nudges here.
        
        let totalChecks = 30               // 30 × 10s = 5 minutes
        let reKickInterval = 6             // legacy debug cadence for status logging
        
        for check in 1...totalChecks {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            
            // --- Do we have projects yet? ---
            if !projects.isEmpty { return }
            
            let freshContext = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<Project>()
            if let count = try? freshContext.fetchCount(descriptor), count > 0 {
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
    
    private func showSyncRecoveryBannerTemporarily() {
        syncRecoveryBannerTask?.cancel()
        withAnimation {
            showSyncRecoveryBanner = true
        }

        syncRecoveryBannerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            withAnimation {
                showSyncRecoveryBanner = false
            }
        }
    }

    private func dismissSyncRecoveryBanner() {
        syncRecoveryBannerTask?.cancel()
        syncRecoveryBannerTask = nil
        guard showSyncRecoveryBanner else { return }
        withAnimation {
            showSyncRecoveryBanner = false
        }
    }

    /// AsyncStream that emits whenever EntitlementManager clears the offline warning,
    /// so the banner can be shown again if it reappears on a subsequent connection loss.
    @available(macCatalyst 15, iOS 17.4, *)
    private func offlinePurchaseWarningStream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            Task { @MainActor in
                var previousValue = EntitlementManager.shared.showOfflinePurchaseWarning
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000) // poll every 0.5s
                    let current = EntitlementManager.shared.showOfflinePurchaseWarning
                    // Re-enable dismissed banner if a NEW offline warning fires
                    if current && !previousValue {
                        continuation.yield()
                    }
                    previousValue = current
                }
                continuation.finish()
            }
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
            // On a relaunch with existing data, the import end-event often arrives
            // very late (or never) because there is nothing to import.  Use a short
            // timeout so we don't block migrations for 30s on every relaunch.
            let isFreshDatabase = projects.isEmpty
            let maxWait = isFreshDatabase ? 30 : 5  // fresh install: 30s, relaunch: 5s
            
            // Give CloudKit a moment to START syncing before we check
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            
            // Wait for sync burst to settle AND for import to complete.
            // isSyncing alone clears after 1.5s of quiet, but import may still
            // be in progress between notification batches.
            while (throttler.isSyncing || throttler.hasActiveCloudKitEvent) && waitCycles < maxWait {
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                waitCycles += 1
                #if DEBUG
                if waitCycles % 5 == 0 {
                    print("⏳ [ContentView] Waiting for CloudKit sync to settle before migration... (\(waitCycles)s, isSyncing=\(throttler.isSyncing), activeEvent=\(throttler.hasActiveCloudKitEvent), fresh=\(isFreshDatabase))")
                }
                #endif
            }
            
            let importConfirmed = throttler.importCompleted && throttler.importSucceeded
            
            #if DEBUG
            if waitCycles > 0 {
                print("✅ [ContentView] CloudKit sync settled after \(waitCycles)s, importConfirmed=\(importConfirmed), running migrations")
            } else {
                print("✅ [ContentView] No active sync detected, importConfirmed=\(importConfirmed), running migrations immediately")
            }
            #endif
            
            // Pass importConfirmed so migrations can skip destructive operations
            // when CloudKit relationships may still be arriving.
            MigrationService.runMigrations(context: modelContext, importConfirmed: importConfirmed)

            // Auto-cleanup synced clone rows after migration when sync is settled.
            // This uses DeduplicationService's strict clone checks (same name/type/creation date)
            // and runs only when CloudKit is idle.
            performAutomaticDedupIfSafe(reason: "startup-migration")
            performPostImportRepairIfSafe(reason: "startup-migration")

            // After import, delete any zombie projects that match tombstones
            // (projects the user permanently deleted but CloudKit re-imported).
            // Skip while rate-limited — deletes queue exports that deepen the backoff.
            if importConfirmed && !throttler.isRateLimited {
                let zombies = DeduplicationService.deleteZombieProjects(context: modelContext)
                #if DEBUG
                if zombies > 0 {
                    print("🪦 [ContentView] Cleaned up \(zombies) zombie project(s) after import")
                }
                #endif
            }
        }
    }

    private func performAutomaticDedupIfSafe(reason: String) {
        let throttler = CloudKitSyncThrottler.shared
        guard scenePhase == .active else { return }
        guard !throttler.isRateLimited else { return }
        guard !throttler.hasActiveCloudKitEvent else { return }

        // Debounce automatic dedup scans/writes.
        let now = Date()
        guard now.timeIntervalSince(lastAutoDedupDate) >= 30 else { return }
        lastAutoDedupDate = now

        let duplicateCount = DeduplicationService.countDuplicateProjects(context: modelContext)
        guard duplicateCount > 0 else { return }

        let result = DeduplicationService.deduplicateProjects(context: modelContext)
        guard result.duplicatesRemoved > 0 else { return }

        #if DEBUG
        print("🧹 [ContentView] Auto-dedup removed \(result.duplicatesRemoved) duplicate project(s) via \(reason)")
        #endif
        refreshTrigger.toggle()
    }

    private func performPostImportRepairIfSafe(reason: String) {
        let throttler = CloudKitSyncThrottler.shared
        guard scenePhase == .active else { return }
        guard throttler.importCompleted && throttler.importSucceeded else { return }
        guard !throttler.hasActiveCloudKitEvent else { return }
        guard !throttler.isSyncing else { return }

        let now = Date()
        guard now.timeIntervalSince(lastPostImportRepairDate) >= 30 else { return }
        lastPostImportRepairDate = now

        let result = MigrationService.repairPostImportArtifacts(context: modelContext)
        guard result.totalRemoved > 0 else { return }

        #if DEBUG
        print("🧹 [ContentView] Post-import repair removed \(result.totalRemoved) record(s) via \(reason)")
        #endif
        refreshTrigger.toggle()
    }
    
    /// Prefetch project relationships async to warm up Swift type system
    /// This prevents UI freeze when tapping first project after app launch
    private func prefetchProjectData() {
        guard !projects.isEmpty else { return }

        // Keep launch-time prefetch relationship-safe.
        // Remote CloudKit deletes can invalidate stale in-memory folder objects;
        // touching deep relationships here can crash before reconciliation runs.
        #if DEBUG
        let freshContext = ModelContext(modelContext.container)
        let projectDescriptor = FetchDescriptor<Project>()
        if let count = try? freshContext.fetchCount(projectDescriptor) {
            print("[ContentView] Prefetch snapshot: \(count) project(s) in store")
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
        guard !hasInitializedStyleSheets else {
            #if DEBUG
            print("⏭️ [ContentView] Stylesheets already initialized in this launch — skipping")
            #endif
            return
        }

        guard styleSheetInitTask == nil else {
            #if DEBUG
            print("⏳ [ContentView] Stylesheet initialization already pending")
            #endif
            return
        }

        styleSheetInitTask = Task { @MainActor in
            defer { styleSheetInitTask = nil }

            let throttler = CloudKitSyncThrottler.shared

            // Give CloudKit a brief chance to start initial import before we initialize defaults.
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            var waitCycles = 0
            let isFreshDatabase = projects.isEmpty
            let maxWait = isFreshDatabase ? 60 : 5  // fresh install: 60s, relaunch: 5s
            
            if isFreshDatabase {
                // On a fresh install, wait for CloudKit import to deliver stylesheets
                // rather than creating them locally. Creating local records before import
                // completes causes export failures (code=2) that block all sync.
                while waitCycles < maxWait {
                    // Check if CloudKit has already imported stylesheets
                    let freshCtx = ModelContext(modelContext.container)
                    let sheetDescriptor = FetchDescriptor<StyleSheet>()
                    if let count = try? freshCtx.fetchCount(sheetDescriptor), count > 0 {
                        #if DEBUG
                        print("✅ [ContentView] CloudKit imported \(count) stylesheet(s) — skipping local creation")
                        #endif
                        break
                    }
                    
                    // Also break if import completed successfully (zone might have no stylesheets)
                    if throttler.importCompleted && throttler.importSucceeded {
                        #if DEBUG
                        print("✅ [ContentView] Import completed successfully — proceeding with stylesheet init")
                        #endif
                        break
                    }
                    
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    waitCycles += 1
                    #if DEBUG
                    if waitCycles % 5 == 0 {
                        print("⏳ [ContentView] Waiting for CloudKit import before stylesheet init... (\(waitCycles)s)")
                    }
                    #endif
                }
            } else {
                // Existing database: just wait for active events to settle
                while (throttler.hasActiveCloudKitEvent || throttler.isSyncing) && waitCycles < maxWait {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    waitCycles += 1
                    #if DEBUG
                    if waitCycles % 5 == 0 {
                        print("⏳ [ContentView] Waiting for CloudKit to settle before stylesheet init... (\(waitCycles)s)")
                    }
                    #endif
                }
            }

            // Run async on main thread (ModelContext must stay on its creation thread)
            StyleSheetService.initializeStyleSheetsIfNeeded(context: modelContext)
            #if DEBUG
            if waitCycles > 0 {
                print("✅ [ContentView] Stylesheets initialized after waiting \(waitCycles)s for sync to settle")
            } else {
                print("✅ [ContentView] Stylesheets initialized")
            }
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

            hasInitializedStyleSheets = true

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

                    // Guard against import-vs-zombie cleanup races.
                    DeduplicationService.pauseZombieDeletion(for: 45)
                    
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
                    
                    // Clear any tombstone for this project name+type so zombie
                    // cleanup doesn't immediately delete the freshly imported project.
                    if let name = project.name {
                        DeduplicationService.clearTombstone(name: name, typeRaw: project.typeRaw)
                    }
                    
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
