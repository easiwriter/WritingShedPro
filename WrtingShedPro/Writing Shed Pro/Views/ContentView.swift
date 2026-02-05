import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Query var projects: [Project]
    @State private var state = ContentViewState()
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ContentViewBody(
            projects: projects,
            state: state,
            onInitialize: initializeUserOrderIfNeeded,
            onInitializeStyleSheets: initializeStyleSheets,
            onHandleImportMenu: handleImportMenu,
            onHandleJSONImport: handleJSONImport,
            onDeleteAllProjects: deleteAllProjects,
            onPrefetchProjectData: prefetchProjectData,
            onRunMigrations: runMigrations
        )
    }
    
    /// Run data migrations for new features
    /// DISABLED: MigrationService was breaking CloudKit sync
    private func runMigrations() {
        // Task(priority: .utility) {
        //     MigrationService.runMigrations(context: modelContext)
        // }
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
            
            // One-time fix: Convert user guide files to markdown mode
            migrateUserGuideToMarkdown()
        }
    }
    
    /// One-time migration: Convert Writing Shed Pro Guide files to markdown mode
    /// These files were imported as markdown but contentType was not set correctly
    private func migrateUserGuideToMarkdown() {
        let migrationKey = "userGuideMarkdownMigrationComplete"
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
            
            // Get all files in this project's folders
            var migratedCount = 0
            if let folders = guideProject.folders {
                for folder in folders {
                    if let files = folder.textFiles {
                        for file in files {
                            // Only convert files that are currently richText
                            if file.contentTypeRaw == "richText" {
                                file.contentTypeRaw = "markdown"
                                migratedCount += 1
                            }
                        }
                    }
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
                    
                    // Create JSON importer
                    let jsonImporter = JSONImportService(
                        modelContext: modelContext,
                        errorHandler: errorHandler
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
        
        // Ensure all existing projects have a userOrder
        let projectsNeedingOrder = projects.filter { $0.userOrder == nil }
        if !projectsNeedingOrder.isEmpty {
            for (index, project) in projects.enumerated() {
                if project.userOrder == nil {
                    project.userOrder = index
                }
            }
            try? modelContext.save()
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
