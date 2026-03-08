import Foundation
import SwiftData

/// Service for migrating existing data to support new features
/// Run once at app startup to update existing projects
class MigrationService {
    
    
    /// Run all pending migrations
    /// - Parameter context: The model context to use for migrations
    static func runMigrations(context: ModelContext) {
        cleanupOrphanedFolders(context: context)
        deduplicateManuscriptSubfolders(context: context)
        migrateManuscriptSubfolders(context: context)
        migrateFeature036(context: context)
    }
    
    /// CRITICAL: Run this BEFORE any views load to prevent crashes from invalidated folder objects
    /// Called from Write_App immediately after ModelContainer creation
    static func cleanupOrphanedFoldersEarly(context: ModelContext) {
        #if DEBUG
        print("🧹 [MigrationService] Early cleanup: Checking for orphaned folder references...")
        #endif
        
        // Fetch all folders directly - this uses the database, not relationships
        let descriptor = FetchDescriptor<Folder>()
        guard let allFolders = try? context.fetch(descriptor) else {
            #if DEBUG
            print("❌ [MigrationService] Failed to fetch folders for cleanup")
            #endif
            return
        }
        
        #if DEBUG
        print("🧹 [MigrationService] Found \(allFolders.count) total folders in database")
        #endif
        
        var cleanedCount = 0
        // DISABLED: Don't delete orphaned folders - they may be waiting for CloudKit relationship sync
        // var deletedCount = 0
        
        for folder in allFolders {
            // Check if folder has both project AND parentFolder set (should only have one)
            if folder.project != nil && folder.parentFolder != nil {
                #if DEBUG
                print("🔧 Fixing folder '\(folder.name ?? "unnamed")' - removing project reference (is a subfolder)")
                #endif
                folder.project = nil
                cleanedCount += 1
            }
            
            // DISABLED: This was deleting folders before CloudKit synced their relationships!
            // With CloudKit, a folder entity might sync before its project relationship,
            // causing it to appear "orphaned" when it's actually just waiting for sync.
            // if folder.project == nil && folder.parentFolder == nil {
            //     #if DEBUG
            //     print("🗑️ Deleting orphaned folder '\(folder.name ?? "unnamed")'")
            //     #endif
            //     context.delete(folder)
            //     deletedCount += 1
            // }
            
            #if DEBUG
            // Log folder relationship status for debugging
            if folder.project == nil && folder.parentFolder == nil {
                print("⚠️ [MigrationService] Folder '\(folder.name ?? "unnamed")' has no project or parent (possible CloudKit sync delay)")
            }
            #endif
        }
        
        if cleanedCount > 0 {
            try? context.save()
            #if DEBUG
            print("✅ [MigrationService] Early cleanup: Fixed \(cleanedCount) folders with dual relationships")
            #endif
        } else {
            #if DEBUG
            print("✅ [MigrationService] Early cleanup: No orphaned folders found")
            #endif
        }
    }
    
    /// Clean up folders with invalidated/orphaned relationships
    /// This fixes crashes caused by accessing deleted folder objects
    private static func cleanupOrphanedFolders(context: ModelContext) {
        // Just call the early cleanup - it's the same logic
        cleanupOrphanedFoldersEarly(context: context)
    }
    
    /// Remove duplicate-named subfolders within Manuscript folders across all projects.
    /// Keeps the subfolder with the most content (files + subfolders); deletes empty duplicates.
    /// This cleans up data that may have been corrupted by CloudKit sync or bad imports.
    private static func deduplicateManuscriptSubfolders(context: ModelContext) {
        let descriptor = FetchDescriptor<Project>()
        guard let projects = try? context.fetch(descriptor) else { return }
        
        var totalRemoved = 0
        
        for project in projects where !project.isTrashed {
            guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }) else {
                continue
            }
            
            // Deduplicate subfolders of Manuscript
            totalRemoved += deduplicateFolderChildren(manuscriptFolder, context: context)
            
            // Also deduplicate text files within each subfolder (e.g. duplicate "Front Cover")
            for subfolder in manuscriptFolder.folders ?? [] {
                totalRemoved += deduplicateTextFileChildren(subfolder, context: context)
            }
        }
        
        if totalRemoved > 0 {
            try? context.save()
            #if DEBUG
            print("🧹 [MigrationService] Removed \(totalRemoved) duplicate folders/files from Manuscript subfolders")
            #endif
        }
    }
    
    /// Remove duplicate-named child folders from a parent folder.
    /// Keeps the child with the most content. Returns number of duplicates removed.
    private static func deduplicateFolderChildren(_ parent: Folder, context: ModelContext) -> Int {
        guard let children = parent.folders, children.count > 1 else { return 0 }
        
        var groups: [String: [Folder]] = [:]
        for child in children {
            let name = child.name ?? ""
            groups[name, default: []].append(child)
        }
        
        var removed = 0
        for (name, group) in groups where group.count > 1 {
            // Keep the folder with the most content
            let sorted = group.sorted { lhs, rhs in
                let lhsScore = (lhs.textFiles?.count ?? 0) + (lhs.folders?.count ?? 0)
                let rhsScore = (rhs.textFiles?.count ?? 0) + (rhs.folders?.count ?? 0)
                return lhsScore > rhsScore
            }
            for dup in sorted.dropFirst() {
                #if DEBUG
                print("🧹 [MigrationService] Removing duplicate subfolder '\(name)' (id=\(dup.id)) from '\(parent.name ?? "")'")
                #endif
                context.delete(dup)
                removed += 1
            }
        }
        return removed
    }
    
    /// Remove duplicate-named text files from a folder.
    /// Keeps the file with the most versions. Returns number of duplicates removed.
    private static func deduplicateTextFileChildren(_ folder: Folder, context: ModelContext) -> Int {
        guard let files = folder.textFiles, files.count > 1 else { return 0 }
        
        var groups: [String: [TextFile]] = [:]
        for file in files {
            groups[file.name, default: []].append(file)
        }
        
        var removed = 0
        for (name, group) in groups where group.count > 1 {
            let sorted = group.sorted { lhs, rhs in
                (lhs.versions?.count ?? 0) > (rhs.versions?.count ?? 0)
            }
            for dup in sorted.dropFirst() {
                #if DEBUG
                print("🧹 [MigrationService] Removing duplicate file '\(name)' (id=\(dup.id)) from '\(folder.name ?? "")'")
                #endif
                context.delete(dup)
                removed += 1
            }
        }
        return removed
    }
    
    /// Feature 029: Add Front Matter, Body, Back Matter subfolders to existing Manuscript folders
    /// - Parameter context: The model context
    private static func migrateManuscriptSubfolders(context: ModelContext) {
        #if DEBUG
        print("🔄 [MigrationService] Starting manuscript subfolders migration...")
        #endif

        // Fetch all projects
        let descriptor = FetchDescriptor<Project>()
        guard let projects = try? context.fetch(descriptor) else {
            #if DEBUG
            print("❌ [MigrationService] Failed to fetch projects")
            #endif
            return
        }

        var migratedCount = 0

        // Skip trashed projects to avoid CloudKit sync conflicts
        for project in projects where !project.isTrashed {
            // Find Manuscript folder
            guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }) else {
                continue
            }

            // Determine the correct body folder name for this project type
            // Feature 036: All project types now use "Body Matter"
            let bodyFolderName = "Body Matter"

            // Check which subfolders already exist
            let existingSubfolders = manuscriptFolder.folders ?? []
            let requiredNames: Set<String> = ["Front Matter", bodyFolderName, "Back Matter"]
            let existingNames = Set(existingSubfolders.compactMap { $0.name })
            let missingNames = requiredNames.subtracting(existingNames)
            
            // Delete any "Body" folder if it exists (we now use "Body Matter" for all project types)
            // Also delete any wrong body type folders (old names without "All" prefix)
            let oldBodyFolderNames: Set<String> = ["Body", "Acts", "Poems", "Sections", "Chapters", "Stories"]
            let legacyAllBodyNames: Set<String> = ["All Acts", "All Poems", "All Sections", "All Chapters", "All Stories", "All Books"]
            let wrongBodyFolders = existingSubfolders.filter { folder in
                guard let name = folder.name else { return false }
                // Delete if it's an old body folder name OR legacy "All X" name
                if oldBodyFolderNames.contains(name) { return true }
                return legacyAllBodyNames.contains(name)
            }
            
            for folder in wrongBodyFolders {
                #if DEBUG
                print("  ↳ Deleting wrong body folder '\(folder.name ?? "")' from \(project.name ?? "Untitled")")
                #endif
                context.delete(folder)
            }

            if missingNames.isEmpty && wrongBodyFolders.isEmpty {
                #if DEBUG
                print("  ↳ Skipping \(project.name ?? "Untitled") - all manuscript subfolders exist")
                #endif
                continue
            }
            
            // If we deleted folders but nothing is missing, still count as migrated
            if missingNames.isEmpty && !wrongBodyFolders.isEmpty {
                migratedCount += 1
                continue
            }

            // Define correct order: Front Matter = 0, Body = 1, Back Matter = 2
            let orderedSubfolders: [(name: String, order: Int)] = [
                ("Front Matter", 0),
                (bodyFolderName, 1),
                ("Back Matter", 2)
            ]
            
            // Add only missing subfolders with correct userOrder
            for (name, order) in orderedSubfolders where missingNames.contains(name) {
                // Subfolders should NOT have project set - they get linked via parentFolder only
                let subfolder = Folder(name: name, project: nil)
                subfolder.parentFolder = manuscriptFolder
                subfolder.userOrder = order
                if manuscriptFolder.folders == nil {
                    manuscriptFolder.folders = []
                }
                manuscriptFolder.folders?.append(subfolder)
                context.insert(subfolder)
            }
            
            // Also fix userOrder on existing subfolders to ensure correct order
            for subfolder in existingSubfolders {
                if subfolder.name == "Front Matter" {
                    subfolder.userOrder = 0
                } else if subfolder.name == bodyFolderName {
                    subfolder.userOrder = 1
                } else if subfolder.name == "Back Matter" {
                    subfolder.userOrder = 2
                }
            }
            
            migratedCount += 1
            #if DEBUG
            print("  ↳ Added missing manuscript subfolders to \(project.name ?? "Untitled"): \(missingNames.sorted().joined(separator: ", "))")
            #endif
        }

        #if DEBUG
        print("✅ [MigrationService] Manuscript subfolders migration complete. Migrated \(migratedCount) projects.")
        #endif
    }
        
    // (Migration flag code removed; migration is now always idempotent and project-aware)
    
    // MARK: - Feature 036: Project Folder Revamp Migration
    
    /// Feature 036 migration key for UserDefaults
    private static let feature036MigrationKey = "hasRunFeature036Migration"
    
    /// Feature 036: Migrate projects to new folder structure
    /// - Renames "All X" body subfolders to "Body Matter"
    /// - Populates isInBodyMatter/bodyMatterOrder on existing container entities
    /// - Migrates Poetry collection Submissions to PoetryCollection model
    /// - Migrates Verse Novel Chapter entities to Book entities
    /// - Removes Collections folder from non-Poetry projects
    /// - Repositions Collections folder in Poetry projects
    static func migrateFeature036(context: ModelContext) {
        // Migration is idempotent — each sub-function checks if work is needed.
        // No UserDefaults guard so that newly synced projects get migrated too.
        
        #if DEBUG
        print("🔄 [MigrationService] Starting Feature 036 migration...")
        #endif
        
        let descriptor = FetchDescriptor<Project>()
        guard let projects = try? context.fetch(descriptor) else {
            #if DEBUG
            print("❌ [MigrationService] Failed to fetch projects for Feature 036 migration")
            #endif
            return
        }
        
        // Skip trashed projects — modifying them during migration can cause CloudKit
        // sync conflicts that resurrect deleted projects on other devices
        let activeProjects = projects.filter { !$0.isTrashed }
        
        for project in activeProjects {
            renameBodySubfolder(project: project, context: context)
            populateBodyMatter(project: project, context: context)
            
            if project.type == .poetry {
                migratePoetryCollections(project: project, context: context)
                repositionCollectionsFolder(project: project)
            } else {
                removeCollectionsFolder(project: project, context: context)
            }
            
            if project.type == .fiction && project.fictionClass == .verseNovel {
                migrateVerseNovelChaptersToBooks(project: project, context: context)
            }
        }
        
        // Only save if there are actual changes to avoid dirtying CloudKit records
        if context.hasChanges {
            do {
                try context.save()
                UserDefaults.standard.set(true, forKey: feature036MigrationKey)
                #if DEBUG
                print("✅ [MigrationService] Feature 036 migration complete for \(activeProjects.count) projects (saved changes)")
                #endif
            } catch {
                #if DEBUG
                print("❌ [MigrationService] Feature 036 migration save failed: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("✅ [MigrationService] Feature 036 migration complete — no changes needed")
            #endif
        }
    }
    
    // MARK: - Task 8.1: Rename "All X" to "Body Matter"
    
    private static func renameBodySubfolder(project: Project, context: ModelContext) {
        guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }) else { return }
        
        let legacyBodyNames: Set<String> = [
            "All Poems", "All Sections", "All Chapters", "All Stories", "All Books", "All Acts", "Body"
        ]
        
        for subfolder in manuscriptFolder.folders ?? [] {
            if let name = subfolder.name, legacyBodyNames.contains(name) {
                #if DEBUG
                print("  ↳ Renaming '\(name)' → 'Body Matter' in \(project.name ?? "Untitled")")
                #endif
                subfolder.name = "Body Matter"
            }
        }
    }
    
    // MARK: - Task 8.5: Populate Body Matter for all project types
    
    private static func populateBodyMatter(project: Project, context: ModelContext) {
        switch project.type {
        case .poetry:
            // Poetry: set all PoetryCollections as body matter
            let collections = (project.poetryCollections ?? [])
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            guard collections.contains(where: { !$0.isInBodyMatter }) || collections.allSatisfy({ !$0.isInBodyMatter }) else { return }
            for (index, collection) in collections.enumerated() where !collection.isInBodyMatter {
                collection.isInBodyMatter = true
                collection.bodyMatterOrder = index
            }
            #if DEBUG
            if !collections.isEmpty {
                print("  ↳ Set \(collections.count) poetry collections as body matter in \(project.name ?? "Untitled")")
            }
            #endif
            
        case .prose:
            let sections = (project.sections ?? [])
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            guard !sections.isEmpty else { return }
            let needsMigration = sections.contains { !$0.isInBodyMatter }
            guard needsMigration else { return }
            for (index, section) in sections.enumerated() {
                section.isInBodyMatter = true
                section.bodyMatterOrder = index
            }
            #if DEBUG
            print("  ↳ Set \(sections.count) prose sections as body matter in \(project.name ?? "Untitled")")
            #endif
            
        case .fiction:
            switch project.fictionClass {
            case .novel:
                let chapters = (project.chapters ?? [])
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                guard !chapters.isEmpty else { return }
                let needsMigration = chapters.contains { !$0.isInBodyMatter }
                guard needsMigration else { return }
                for (index, chapter) in chapters.enumerated() {
                    chapter.isInBodyMatter = true
                    chapter.bodyMatterOrder = index
                }
                #if DEBUG
                print("  ↳ Set \(chapters.count) chapters as body matter in \(project.name ?? "Untitled")")
                #endif
                
            case .shortFiction, .none:
                let scenes = (project.scenes ?? [])
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                guard !scenes.isEmpty else { return }
                let needsMigration = scenes.contains { !$0.isInBodyMatter }
                guard needsMigration else { return }
                for (index, scene) in scenes.enumerated() {
                    scene.isInBodyMatter = true
                    scene.bodyMatterOrder = index
                }
                #if DEBUG
                print("  ↳ Set \(scenes.count) scenes as body matter in \(project.name ?? "Untitled")")
                #endif
                
            case .verseNovel:
                // Books will be created from Chapters in migrateVerseNovelChaptersToBooks
                // If books already exist (post-migration), populate them
                let books = (project.books ?? [])
                    .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
                if !books.isEmpty {
                    let needsMigration = books.contains { !$0.isInBodyMatter }
                    guard needsMigration else { return }
                    for (index, book) in books.enumerated() {
                        book.isInBodyMatter = true
                        book.bodyMatterOrder = index
                    }
                    #if DEBUG
                    print("  ↳ Set \(books.count) books as body matter in \(project.name ?? "Untitled")")
                    #endif
                }
            }
            
        case .drama:
            let acts = (project.acts ?? [])
                .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
            guard !acts.isEmpty else { return }
            let needsMigration = acts.contains { !$0.isInBodyMatter }
            guard needsMigration else { return }
            for (index, act) in acts.enumerated() {
                act.isInBodyMatter = true
                act.bodyMatterOrder = index
            }
            #if DEBUG
            print("  ↳ Set \(acts.count) acts as body matter in \(project.name ?? "Untitled")")
            #endif
        }
    }
    
    // MARK: - Task 8.2: Poetry Collection Migration
    
    /// Migrate old Submission-based collections to PoetryCollection model
    private static func migratePoetryCollections(project: Project, context: ModelContext) {
        // Only migrate if no PoetryCollections exist yet
        let existingCollections = project.poetryCollections ?? []
        guard existingCollections.isEmpty else {
            #if DEBUG
            print("  ↳ Poetry collections already exist for \(project.name ?? "Untitled"), skipping")
            #endif
            return
        }
        
        // Find old collection-type Submissions for this project
        let projectId = project.id
        let descriptor = FetchDescriptor<Submission>(
            predicate: #Predicate { submission in
                submission.isCollection == true && submission.project?.id == projectId
            }
        )
        
        guard let oldCollections = try? context.fetch(descriptor), !oldCollections.isEmpty else {
            // No old collections — create a default "Collection 1" with all poems
            createDefaultPoetryCollection(project: project, context: context)
            return
        }
        
        // Migrate each old collection to PoetryCollection
        let sortedOld = oldCollections.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        for (index, oldCollection) in sortedOld.enumerated() {
            let newCollection = PoetryCollection(
                name: oldCollection.name ?? "Collection \(index + 1)",
                synopsis: oldCollection.collectionDescription,
                userOrder: index
            )
            newCollection.project = project
            newCollection.isInBodyMatter = true
            newCollection.bodyMatterOrder = index
            context.insert(newCollection)
            
            // Migrate submitted files to poetry collection assignment
            for submittedFile in oldCollection.submittedFiles ?? [] {
                if let textFile = submittedFile.textFile {
                    textFile.poetryCollection = newCollection
                }
            }
            
            #if DEBUG
            print("  ↳ Migrated collection '\(oldCollection.name ?? "unnamed")' with \(oldCollection.submittedFiles?.count ?? 0) files")
            #endif
            
            // Delete old collection submission and its submitted files
            // (cascade will handle SubmittedFile deletion)
            context.delete(oldCollection)
        }
    }
    
    /// Create a default "Collection 1" containing all poems from the Poems folder
    private static func createDefaultPoetryCollection(project: Project, context: ModelContext) {
        let poemsFolder = project.folders?.first { $0.name == "Poems" }
        let poems = poemsFolder?.textFiles ?? []
        
        guard !poems.isEmpty else {
            #if DEBUG
            print("  ↳ No poems found for default collection in \(project.name ?? "Untitled")")
            #endif
            return
        }
        
        let collection = PoetryCollection(
            name: String(format: NSLocalizedString("poetry.collection.defaultTitle", comment: "Collection 1"), 1),
            userOrder: 0
        )
        collection.project = project
        collection.isInBodyMatter = true
        collection.bodyMatterOrder = 0
        context.insert(collection)
        
        // Assign all poems to the default collection
        let sortedPoems = poems.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        for poem in sortedPoems {
            poem.poetryCollection = collection
        }
        
        #if DEBUG
        print("  ↳ Created default 'Collection 1' with \(sortedPoems.count) poems in \(project.name ?? "Untitled")")
        #endif
    }
    
    // MARK: - Task 8.3: Reposition Collections Folder (Poetry)
    
    private static func repositionCollectionsFolder(project: Project) {
        guard let collectionsFolder = project.folders?.first(where: { $0.name == "Collections" }) else { return }
        
        // Position Collections between Manuscript and Poems
        // Manuscript is typically at order 0, so Collections should be 1
        let manuscriptOrder = project.folders?.first(where: { $0.name == "Manuscript" })?.userOrder ?? 0
        let newOrder = manuscriptOrder + 1
        
        // Skip if Collections is already at the correct position
        if collectionsFolder.userOrder == newOrder {
            return
        }
        
        // Shift folders that are at or after the new position
        for folder in project.folders ?? [] {
            if folder.name != "Collections" && (folder.userOrder ?? 0) >= newOrder {
                folder.userOrder = (folder.userOrder ?? 0) + 1
            }
        }
        
        collectionsFolder.userOrder = newOrder
        
        #if DEBUG
        print("  ↳ Repositioned Collections folder to order \(newOrder) in \(project.name ?? "Untitled")")
        #endif
    }
    
    // MARK: - Task 8.4: Remove Collections Folder (Non-Poetry)
    
    private static func removeCollectionsFolder(project: Project, context: ModelContext) {
        guard let collectionsFolder = project.folders?.first(where: { $0.name == "Collections" }) else { return }
        
        // Check for any collection-type submissions that need preservation
        // (their data should remain in the Submission model — we just remove the folder)
        
        #if DEBUG
        print("  ↳ Removing Collections folder from \(project.type.rawValue) project \(project.name ?? "Untitled")")
        #endif
        
        context.delete(collectionsFolder)
    }
    
    // MARK: - Task 8.6: Verse Novel Chapter → Book Migration
    
    private static func migrateVerseNovelChaptersToBooks(project: Project, context: ModelContext) {
        // Only migrate if no Books exist yet
        let existingBooks = project.books ?? []
        guard existingBooks.isEmpty else {
            #if DEBUG
            print("  ↳ Books already exist for Verse Novel \(project.name ?? "Untitled"), skipping")
            #endif
            return
        }
        
        let chapters = (project.chapters ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        guard !chapters.isEmpty else { return }
        
        for (index, chapter) in chapters.enumerated() {
            let book = Book(
                name: chapter.name,
                synopsis: chapter.synopsis,
                userOrder: index
            )
            book.project = project
            book.isInBodyMatter = true
            book.bodyMatterOrder = index
            context.insert(book)
            
            // Move scene assignments from chapter to book
            for scene in chapter.scenes ?? [] {
                scene.book = book
                // Don't remove chapter relationship yet — CloudKit safety
                // The chapter will become orphaned but won't be deleted
            }
            
            #if DEBUG
            print("  ↳ Migrated Chapter '\(chapter.name ?? "unnamed")' → Book with \(chapter.scenes?.count ?? 0) episodes")
            #endif
        }
        
        // Note: We do NOT delete old Chapter entities here.
        // CloudKit may still be syncing relationships. The Chapter entities
        // will remain but become unused once scenes point to Books instead.
        // This is intentional CloudKit-safe behaviour per project guidelines.
    }
}
