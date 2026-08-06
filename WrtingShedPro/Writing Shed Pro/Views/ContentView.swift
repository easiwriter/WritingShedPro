import SwiftUI
import SwiftData
import UniformTypeIdentifiers
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

    /// Startup migrations must run at most once per app launch.
    /// ContentView can be rebuilt during sync reconciliation.
    @State private var hasRunStartupMigrations = false

    /// Stylesheet initialization must run at most once per app launch.
    /// Running this too early can create duplicate system defaults.
    @State private var hasInitializedStyleSheets = false
    @State private var styleSheetInitTask: Task<Void, Never>?
    @State private var onboardingCoordinator = OnboardingCoordinator()
    @State private var hasEvaluatedOnboardingThisLaunch = false
    @State private var onboardingEligibilityTask: Task<Void, Never>?

    /// Last time we auto-normalized project userOrder values.
    /// Used to avoid repeated writes during sync churn.
    @State private var lastAutoOrderNormalizationDate: Date = .distantPast

    /// Last time we attempted automatic duplicate cleanup.
    /// Keeps startup/reconcile paths from repeatedly scanning and mutating during bursts.
    @State private var lastAutoDedupDate: Date = .distantPast

    /// Last time we attempted post-import repair cleanup.
    /// Keeps reconcile/startup paths from repeatedly scanning the store after a sync storm.
    @State private var lastPostImportRepairDate: Date = .distantPast

    /// Debounced task handle for remote-change reconciliation.
    @State private var remoteReconcileTask: Task<Void, Never>?
    @State private var lastReconcileTriggerLogDate: Date = .distantPast

    @State private var showSyncRecoveryBanner = false
    @State private var syncRecoveryBannerKey = "sync.recovery.banner"
    @State private var syncRecoveryBannerIsBlocking = false
    @State private var syncRecoveryBannerTask: Task<Void, Never>?

    @State private var offlinePurchaseBannerDismissed = false

    /// SAFETY SWITCH: hard-disable app-driven sync mutations during reconcile/watchdog.
    /// This avoids local write storms.
    private let disableRiskySyncMutationPaths = true
    
    var body: some View {
        ContentViewBody(
            projects: projects,
            state: state,
            onInitialize: initializeUserOrderIfNeeded,
            onInitializeStyleSheets: initializeStyleSheets,
            onSyncNow: syncNowFromSettings,
            onHandleImportMenu: handleImportMenu,
            onHandleJSONImport: handleJSONImport,
            onPrefetchProjectData: prefetchProjectData,
            onRunMigrations: runMigrations,
            onboardingCoordinator: onboardingCoordinator,
            onEvaluateOnboarding: evaluateOnboardingIfNeeded,
            onRestartOnboarding: restartOnboardingFromSettings,
            onOpenProject: { project in
                state.showProject(project)
            }
        )
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if showSyncRecoveryBanner {
                    HStack(spacing: 8) {
                        Image(systemName: syncRecoveryBannerIsBlocking ? "xmark.icloud.fill" : "arrow.triangle.2.circlepath.icloud")
                            .foregroundStyle(syncRecoveryBannerIsBlocking ? .red : .primary)
                        Text(NSLocalizedString(syncRecoveryBannerKey, comment: "Sync recovery status"))
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
            if scenePhase == .active {
                startPeriodicSyncTimer()
            }

            await checkForNewSupportMessagesIfNeeded()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                let shouldReconcile = syncOnForegroundResume()
                startPeriodicSyncTimer()
                if shouldReconcile {
                    scheduleRemoteReconcile(reason: "foreground-resume")
                }
                Task {
                    await checkForNewSupportMessagesIfNeeded()
                }
            }
            if newPhase == .background {
                stopPeriodicSyncTimer()
                writeCoalescer.flush()
            }
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

    private func evaluateOnboardingIfNeeded() {
        guard !hasEvaluatedOnboardingThisLaunch else { return }
        let forceNewUserMode = OnboardingCoordinator.debugForceNewUserModeEnabled
        guard forceNewUserMode || !onboardingCoordinator.hasCompletedOnboarding else { return }
        guard !onboardingCoordinator.skippedForCurrentLaunch else { return }

        hasEvaluatedOnboardingThisLaunch = true
        onboardingEligibilityTask?.cancel()
        onboardingEligibilityTask = Task { @MainActor in
            if forceNewUserMode {
                state.showOnboarding = true
                return
            }

            let timeout: TimeInterval = 60
            let deadline = Date().addingTimeInterval(timeout)

            while Date() < deadline {
                guard !Task.isCancelled else { return }
                guard !onboardingCoordinator.hasCompletedOnboarding else { return }
                guard !onboardingCoordinator.skippedForCurrentLaunch else { return }

                if activeProjectCountFromPersistentStore() > 0 {
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard !Task.isCancelled else { return }
            guard !onboardingCoordinator.hasCompletedOnboarding else { return }
            guard !onboardingCoordinator.skippedForCurrentLaunch else { return }
            guard activeProjectCountFromPersistentStore() == 0 else { return }

            state.showOnboarding = true
        }
    }

    private func restartOnboardingFromSettings() {
        onboardingCoordinator.resetCompletionForRestart()
        hasEvaluatedOnboardingThisLaunch = true
        state.showSettings = false
        state.showOnboarding = true
    }

    private func activeProjectCountFromPersistentStore() -> Int {
        let freshContext = ModelContext(modelContext.container)
        let descriptor = FetchDescriptor<Project>()
        guard let projects = try? freshContext.fetch(descriptor) else { return projects.filter { !$0.isTrashed }.count }
        return projects.filter { !$0.isTrashed }.count
    }
    
    // MARK: - Foreground Resume Sync
    
    /// When the app returns to the foreground, reconcile the visible project list.
    private func syncOnForegroundResume() -> Bool {
        let now = Date()
        guard !isEditorInputActiveForReconcile() else {
            #if DEBUG
            if now.timeIntervalSince(lastReconcileTriggerLogDate) >= 10 {
                print("🔄 [ContentView] Foreground resume ignored — editor input active")
                lastReconcileTriggerLogDate = now
            }
            #endif
            return false
        }

        guard now.timeIntervalSince(lastForegroundSyncDate) > 60 else {
            #if DEBUG
            print("🔄 [ContentView] Foreground resume ignored — last observation was \(Int(now.timeIntervalSince(lastForegroundSyncDate)))s ago")
            #endif
            return false
        }
        lastForegroundSyncDate = now

        #if DEBUG
        print("🔄 [ContentView] App became active — reconciling local store")
        #endif
        return true
    }

    private func isEditorInputActiveForReconcile() -> Bool {
        writeCoalescer.editingActivity != .idle || writeCoalescer.hasRecentEditingActivity(within: 20)
    }

    @MainActor
    private func checkForNewSupportMessagesIfNeeded() async {
        let service = SupportMessagesService()
        let pendingVersions = await service.pendingNewMessageAlertVersions()
        if !pendingVersions.isEmpty {
            state.pendingSupportMessageAlertVersions = pendingVersions
            state.showNewSupportMessagesAlert = true
        }
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

    /// Passive periodic local maintenance.
    private func performPeriodicSyncWatchdogTick() {
        reconcileProjectListIfNeeded()
        autoNormalizeProjectOrderIfNeeded()
    }

    /// Assign userOrder to projects that don't have one yet.
    /// CRITICAL: Never overwrite existing userOrder values — they may have been
    /// set by the user on another device and synced. Overwriting
    /// causes a ping-pong effect where each device renumbers independently.
    private func autoNormalizeProjectOrderIfNeeded() {
        guard !disableRiskySyncMutationPaths else {
            #if DEBUG
            print("⏸️ [ContentView] autoNormalizeProjectOrderIfNeeded disabled (safety mode)")
            #endif
            return
        }

        if let ensemblesContainer = Write_App.activeEnsemblesContainer {
            #if DEBUG
            print("⏸️ [ContentView] Skipping auto project-order normalization under Ensembles attached=\(ensemblesContainer.isAttached) activity=\(String(describing: ensemblesContainer.currentActivity))")
            #endif
            return
        }

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
            project.modifiedDate = Date()
            nextOrder += 1
            changedCount += 1
        }

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "content-auto-normalize-project-order")
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

    /// Debounced reconciliation triggered by foreground/manual refresh.
    private func scheduleRemoteReconcile(reason: String) {
        guard scenePhase == .active else { return }

        remoteReconcileTask?.cancel()
        remoteReconcileTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000) // debounce notification bursts
            guard !Task.isCancelled else { return }
            guard !isEditorInputActiveForReconcile() else {
                #if DEBUG
                let now = Date()
                if now.timeIntervalSince(lastReconcileTriggerLogDate) >= 10 {
                    print("⏸️ [ContentView] Reconcile deferred during active editor input (\(reason))")
                    lastReconcileTriggerLogDate = now
                }
                #endif

                try? await Task.sleep(nanoseconds: 5_500_000_000)
                guard !Task.isCancelled else { return }
                scheduleRemoteReconcile(reason: reason)
                return
            }
            reconcileProjectListIfNeeded()

            #if DEBUG
            let now = Date()
            if now.timeIntervalSince(lastReconcileTriggerLogDate) >= 10 {
                print("🔄 [ContentView] Reconcile triggered by \(reason)")
                lastReconcileTriggerLogDate = now
            }
            #endif
        }
    }

    /// Manual refresh trigger exposed from Settings.
    private func syncNowFromSettings() {
        #if DEBUG
        print("🔄 [ContentView] Refresh requested from Settings")
        #endif
        scheduleRemoteReconcile(reason: "sync-now")
    }

    /// `@Query` can occasionally miss newly synced rows, or return
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
        if !disableRiskySyncMutationPaths {
            let zombies = DeduplicationService.deleteZombieProjects(context: modelContext)
            if zombies > 0 {
                #if DEBUG
                print("🪦 [ContentView] Reconcile: removed \(zombies) zombie project(s)")
                #endif
                refreshTrigger.toggle()
                return
            }
        }

        if !disableRiskySyncMutationPaths && Write_App.activeEnsemblesContainer == nil {
            let exactDuplicateResult = DeduplicationService.cleanupExactIDDuplicates(context: modelContext)
            if exactDuplicateResult.recordsRemoved > 0 {
                #if DEBUG
                print("🧹 [ContentView] Reconcile: removed \(exactDuplicateResult.recordsRemoved) exact-ID duplicate record(s)")
                #endif
                refreshTrigger.toggle()
                return
            }

            let templateFolderResult = DeduplicationService.cleanupDuplicateTemplateFolders(context: modelContext)
            if templateFolderResult.recordsRemoved > 0 {
                #if DEBUG
                print("🧹 [ContentView] Reconcile: removed \(templateFolderResult.recordsRemoved) duplicate template folder(s)")
                #endif
                refreshTrigger.toggle()
                return
            }
        }

        // Automatically clean up strict clone rows once sync is settled.
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
        var dbNameByID: [UUID: String] = [:]
        for project in allProjects {
            guard let name = project.name else { continue }
            if dbNameByID[project.id] == nil {
                dbNameByID[project.id] = name
            } else {
                #if DEBUG
                print("⚠️ [ContentView] Reconcile: duplicate project id=\(project.id.uuidString) name='\(name)' detected; keeping first name for stale-name check.")
                #endif
            }
        }
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
    
    /// On fresh install, @Query may not update after a bulk sync.
    /// Poll periodically and force a view refresh if data exists but @Query is empty.
    private func monitorSyncAndRefreshIfNeeded() async {
        // Only needed on fresh install (no projects yet)
        guard projects.isEmpty else { return }

        // Simple strategy: poll every 10s for up to 5 minutes.
        // The ONLY exit conditions are:
        //   a) Projects appear in the database → success, refresh view.
        //   b) 5 minutes elapse with no projects → show recovery alert.
        let totalChecks = 30               // 30 × 10s = 5 minutes
        
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
                print("⏳ [ContentView] Waiting for sync check \(check)/\(totalChecks)")
            }
            #endif
        }
        
        #if DEBUG
        print("⚠️ [ContentView] 5 minutes elapsed with no projects — sync may still be in progress")
        #endif
    }
    
    private func showSyncRecoveryBannerTemporarily(messageKey: String = "sync.recovery.banner", isBlocking: Bool = false) {
        syncRecoveryBannerTask?.cancel()
        withAnimation {
            syncRecoveryBannerKey = messageKey
            syncRecoveryBannerIsBlocking = isBlocking
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

    /// Run data migrations for new features.
    private func runMigrations() {
        guard !hasRunStartupMigrations else {
            #if DEBUG
            print("⏭️ [ContentView] Startup migrations already ran in this launch — skipping")
            #endif
            return
        }

        guard Write_App.activeEnsemblesContainer == nil else {
            hasRunStartupMigrations = true
            #if DEBUG
            print("⏸️ [ContentView] Skipping automatic startup migrations under Ensembles")
            #endif
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            guard await waitForEnsemblesStartupWritesIfNeeded(reason: "startup migrations") else {
                return
            }
            hasRunStartupMigrations = true

            #if DEBUG
            print("✅ [ContentView] Running startup migrations")
            #endif
            
            MigrationService.runMigrations(context: modelContext, importConfirmed: true)

            // Auto-cleanup strict clone rows after migration.
            // This uses DeduplicationService's strict clone checks (same name/type/creation date)
            performAutomaticDedupIfSafe(reason: "startup-migration")
            performPostImportRepairIfSafe(reason: "startup-migration")

            if !disableRiskySyncMutationPaths {
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
        guard !disableRiskySyncMutationPaths else {
            return
        }
        guard scenePhase == .active else { return }

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
        guard !disableRiskySyncMutationPaths else {
            return
        }
        guard scenePhase == .active else { return }

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
        guard !Write_App.initialEnsemblesImportUnavailable else {
            hasInitializedStyleSheets = true
            #if DEBUG
            print("⏸️ [ContentView] Skipping stylesheet initialization while initial sync import is unavailable")
            #endif
            return
        }

        guard Write_App.activeEnsemblesContainer == nil else {
            hasInitializedStyleSheets = true
            #if DEBUG
            print("⏸️ [ContentView] Skipping automatic stylesheet maintenance under Ensembles")
            #endif
            return
        }

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

            // Give sync a brief chance to deliver existing stylesheets before we initialize defaults.
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            guard await waitForEnsemblesStartupWritesIfNeeded(reason: "stylesheet initialization") else {
                return
            }

            var waitCycles = 0
            let isFreshDatabase = isStoreEmptyForInitialSync()
            let isUsingEnsembles = Write_App.activeEnsemblesContainer != nil
            let maxWait = isFreshDatabase && isUsingEnsembles ? 60 : (isFreshDatabase ? 10 : 0)
            
            if isFreshDatabase {
                while waitCycles < maxWait {
                    let freshCtx = ModelContext(modelContext.container)
                    let sheetDescriptor = FetchDescriptor<StyleSheet>()
                    if let count = try? freshCtx.fetchCount(sheetDescriptor), count > 0 {
                        #if DEBUG
                        print("✅ [ContentView] Found \(count) synced stylesheet(s) — skipping local creation")
                        #endif
                        break
                    }

                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    waitCycles += 1
                    #if DEBUG
                    if waitCycles % 5 == 0 {
                        print("⏳ [ContentView] Waiting before stylesheet init... (\(waitCycles)s)")
                    }
                    #endif
                }
            }

            if isFreshDatabase && isUsingEnsembles && isStoreEmptyForInitialSync() {
                #if DEBUG
                print("⏳ [ContentView] Deferring stylesheet initialization — empty Ensembles store is still waiting for import")
                #endif
                return
            }

            if isUsingEnsembles {
                hasInitializedStyleSheets = true
                #if DEBUG
                print("⏸️ [ContentView] Skipping automatic stylesheet maintenance under Ensembles")
                #endif
                return
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

    private func waitForEnsemblesStartupWritesIfNeeded(reason: String) async -> Bool {
        guard let ensemblesContainer = Write_App.activeEnsemblesContainer else { return true }

        let maxWaitSeconds = 60
        for second in 0..<maxWaitSeconds {
            let activity = String(describing: ensemblesContainer.currentActivity)
            if Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch {
                return true
            }

            if Write_App.canProceedWithStartupMaintenanceAfterIdle(
                modelContainer: modelContext.container,
                reason: reason
            ) {
                return true
            }

            _ = Write_App.recordFirstEnsemblesDataAvailableIfNeeded(
                modelContainer: modelContext.container,
                reason: "\(reason) store populated"
            )

            #if DEBUG
            if second == 0 || second % 5 == 0 {
                print("⏳ [ContentView] Waiting for first successful Ensembles sync before \(reason)... attached=\(ensemblesContainer.isAttached) activity=\(activity)")
            }
            #endif
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        #if DEBUG
        let activity = String(describing: ensemblesContainer.currentActivity)
        print("⚠️ [ContentView] Deferring \(reason); first successful Ensembles sync did not complete after \(maxWaitSeconds)s attached=\(ensemblesContainer.isAttached) activity=\(activity)")
        #endif
        return false
    }

    private func isStoreEmptyForInitialSync() -> Bool {
        let freshContext = ModelContext(modelContext.container)
        let projectCount = (try? freshContext.fetchCount(FetchDescriptor<Project>())) ?? 0
        let folderCount = (try? freshContext.fetchCount(FetchDescriptor<Folder>())) ?? 0
        let fileCount = (try? freshContext.fetchCount(FetchDescriptor<TextFile>())) ?? 0
        let versionCount = (try? freshContext.fetchCount(FetchDescriptor<Version>())) ?? 0
        let publicationCount = (try? freshContext.fetchCount(FetchDescriptor<Publication>())) ?? 0
        let sceneCount = (try? freshContext.fetchCount(FetchDescriptor<StoryScene>())) ?? 0
        return projectCount == 0 && folderCount == 0 && fileCount == 0 && versionCount == 0 && publicationCount == 0 && sceneCount == 0
    }
    
    /// One-time migration: Convert Writing Shed Pro Guide files to markdown mode
    /// These files were imported as markdown but contentType was not set correctly
    private func migrateUserGuideToMarkdown() {
        guard Write_App.activeEnsemblesContainer == nil else {
            #if DEBUG
            print("⏸️ [ContentView] Skipping user guide markdown migration under Ensembles")
            #endif
            return
        }

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
                            version.setFormattedContentData(nil)
                        }
                        migratedCount += 1
                    } else if file.contentTypeRaw == "markdown" {
                        // Already markdown but clear any stale formattedContent
                        if let version = file.currentVersion, version.effectiveFormattedContent != nil {
                            version.setFormattedContentData(nil)
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
                try WriteCoalescer.shared.requestSaveAndFlush(reason: "content-user-guide-markdown-migration")
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
                    guard await waitForEnsemblesUserImportWindow(reason: "JSON/WSP import") else {
                        await MainActor.run {
                            state.importErrorMessage = "Ensembles is still preparing sync. Please wait a minute, then try importing the WSP file again."
                            state.showImportError = true
                        }
                        return
                    }

                    // Create error handler
                    let errorHandler = ImportErrorHandler()

                    // Guard against import-vs-zombie cleanup races.
                    DeduplicationService.pauseZombieDeletion(for: 180)
                    
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

    private func waitForEnsemblesUserImportWindow(reason: String) async -> Bool {
        guard let ensemblesContainer = Write_App.activeEnsemblesContainer else { return true }

        let maxWaitSeconds = 120
        for second in 0..<maxWaitSeconds {
            let activity = String(describing: ensemblesContainer.currentActivity)
            if Write_App.hasCompletedFirstSuccessfulEnsemblesSyncThisLaunch || activity.lowercased() == "none" {
                return true
            }

            if !ensemblesContainer.isAttached,
               activity.lowercased() == "attaching",
               !EnsemblesSaveGate.isInStartupAttachGracePeriod() {
                #if DEBUG
                print("⚠️ [ContentView] Allowing \(reason) while Ensembles is unavailable attached=\(ensemblesContainer.isAttached) activity=\(activity)")
                #endif
                return true
            }

            #if DEBUG
            if second == 0 || second % 10 == 0 {
                print("⏳ [ContentView] Waiting for Ensembles before \(reason)... attached=\(ensemblesContainer.isAttached) activity=\(activity)")
            }
            #endif
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        #if DEBUG
        print("⚠️ [ContentView] Timed out waiting for Ensembles before \(reason); attached=\(ensemblesContainer.isAttached) activity=\(String(describing: ensemblesContainer.currentActivity))")
        #endif
        return false
    }
    
    private func initializeUserOrderIfNeeded() {
        // Only run the safe publication-target migration here. Historical folder migrations stay disabled.
        ProjectFolderMigrationService.migratePublicationTargetsIfNeeded(modelContext: modelContext)

        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\Project.creationDate)])
        guard let allProjects = try? modelContext.fetch(descriptor), !allProjects.isEmpty else {
            return
        }

        if let preferredSortOrder = ProjectSortService.preferredDefaultSortOrder(
            for: allProjects,
            hasStoredSortOrder: state.hasStoredSortOrder
        ), state.selectedSortOrder != preferredSortOrder {
            state.selectedSortOrder = preferredSortOrder
        }

        guard Write_App.activeEnsemblesContainer == nil else {
            #if DEBUG
            print("⏸️ [ContentView] Skipping userOrder initialization under Ensembles")
            #endif
            return
        }

        let projectsNeedingOrder = allProjects.filter { $0.userOrder == nil }
        guard !projectsNeedingOrder.isEmpty else {
            return
        }

        guard projectsNeedingOrder.count == allProjects.count else {
            #if DEBUG
            print("⚠️ [ContentView] Skipping userOrder initialization because only \(projectsNeedingOrder.count) of \(allProjects.count) projects are missing order")
            #endif
            return
        }

        Task { @MainActor in
            guard await waitForEnsemblesStartupWritesIfNeeded(reason: "userOrder initialization") else {
                return
            }

            let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\Project.creationDate)])
            guard let allProjects = try? modelContext.fetch(descriptor), !allProjects.isEmpty else {
                return
            }

            let projectsNeedingOrder = allProjects.filter { $0.userOrder == nil }
            guard projectsNeedingOrder.count == allProjects.count else {
                return
            }

            for (index, project) in allProjects.enumerated() {
                project.userOrder = index
            }

            if state.selectedSortOrder != .byUserOrder {
                state.selectedSortOrder = .byUserOrder
            }

            do {
                try WriteCoalescer.shared.requestSaveAndFlush(reason: "content-initialize-user-order")
                #if DEBUG
                print("✅ [ContentView] Initialized userOrder for \(allProjects.count) projects")
                #endif
            } catch {
                #if DEBUG
                print("❌ [ContentView] Failed to initialize userOrder: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    private func deleteAllProjects() {
        #if DEBUG
        print("[ContentView] DEBUG: Deleting all \(projects.count) projects")
        for project in projects {
            modelContext.delete(project)
        }
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "content-debug-delete-all-projects")
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
