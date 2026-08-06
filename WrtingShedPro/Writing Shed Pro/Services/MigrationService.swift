import Foundation
import SwiftData

/// Service for migrating existing data to support new features
/// Run once at app startup to update existing projects
class MigrationService {
    struct PostImportRepairResult {
        let orphanedVersionsRemoved: Int

        var totalRemoved: Int {
            orphanedVersionsRemoved
        }
    }
    
    
    /// Run all pending migrations
    /// - Parameters:
    ///   - context: The model context to use for migrations
    ///   - importConfirmed: Whether CloudKit import completed successfully.
    ///     When false, destructive operations (deleting old folders) are skipped
    ///     to avoid orphaning files that may still be syncing.
    static func runMigrations(context: ModelContext, importConfirmed: Bool = true) {
        deduplicateStyleSheets(context: context)
        cleanupOrphanedFolders(context: context)
        if importConfirmed {
            deduplicateManuscriptSubfolders(context: context)
            cleanupOrphanedTrashItems(context: context)
            cleanupOrphanedJoinLinks(context: context)
        }
        migrateManuscriptSubfolders(context: context, importConfirmed: importConfirmed)
        migrateFeature036(context: context, importConfirmed: importConfirmed)
    }

    /// Repairs obviously broken records left behind by CloudKit mirroring resets.
    ///
    /// This intentionally deletes only records that are impossible to keep safely:
    /// Version rows with no parent TextFile, no formatted content, no plain-text content,
    /// and no child relationships. These are empty import stubs, not user-authored data.
    @MainActor
    static func repairPostImportArtifacts(context: ModelContext) -> PostImportRepairResult {
        let removedVersions = cleanupEmptyOrphanedVersions(context: context)

        if removedVersions > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "migration-post-import-repair")
                #if DEBUG
                print("🧹 [MigrationService] Post-import repair removed \(removedVersions) empty orphaned version(s)")
                #endif
            } catch {
                #if DEBUG
                print("❌ [MigrationService] Failed post-import repair save: \(error)")
                #endif
                return PostImportRepairResult(orphanedVersionsRemoved: 0)
            }
        }

        return PostImportRepairResult(orphanedVersionsRemoved: removedVersions)
    }

    /// Merge duplicate custom stylesheets that can be produced by import/duplicate/CloudKit flows.
    /// First pass: merge byte-identical sheets (same signature).
    /// Second pass: merge same-name sheets that differ only in dates or minor property drift.
    /// Keeps one canonical sheet per group, reassigns projects, then removes redundant copies.
    private static func deduplicateStyleSheets(context: ModelContext) {
        let descriptor = FetchDescriptor<StyleSheet>()
        guard let allSheets = try? context.fetch(descriptor), !allSheets.isEmpty else { return }

        let customSheets = allSheets.filter { !$0.isSystemStyleSheet }
        guard customSheets.count > 1 else { return }

        var removedCount = 0

        // Pass 1: byte-identical signature merge
        var signatureGroups: [String: [StyleSheet]] = [:]
        for sheet in customSheets {
            let signature = stylesheetSignature(sheet)
            signatureGroups[signature, default: []].append(sheet)
        }

        for (_, group) in signatureGroups where group.count > 1 {
            removedCount += mergeStyleSheetGroup(group, context: context)
        }

        // Pass 2: name-based merge for near-duplicates (differ only in dates/minor drift)
        // Re-fetch to get the post-pass-1 state
        let remainingSheets = (try? context.fetch(descriptor))?.filter { !$0.isSystemStyleSheet } ?? []
        var nameGroups: [String: [StyleSheet]] = [:]
        for sheet in remainingSheets {
            let normalizedName = sheet.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            nameGroups[normalizedName, default: []].append(sheet)
        }

        for (_, group) in nameGroups where group.count > 1 {
            removedCount += mergeStyleSheetGroup(group, context: context)
        }

        if removedCount > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "migration-deduplicate-stylesheets")
                #if DEBUG
                print("🧹 [MigrationService] Deduplicated \(removedCount) custom stylesheets")
                #endif
            } catch {
                #if DEBUG
                print("❌ [MigrationService] Failed stylesheet deduplication save: \(error)")
                #endif
            }
        }
    }

    /// Merge a group of duplicate stylesheets, keeping the one with the most projects (or oldest).
    /// Returns the number of sheets removed.
    private static func mergeStyleSheetGroup(_ group: [StyleSheet], context: ModelContext) -> Int {
        let sorted = group.sorted { lhs, rhs in
            let lhsProjectCount = lhs.projects?.count ?? 0
            let rhsProjectCount = rhs.projects?.count ?? 0
            if lhsProjectCount != rhsProjectCount {
                return lhsProjectCount > rhsProjectCount
            }
            return lhs.createdDate <= rhs.createdDate
        }

        guard let keeper = sorted.first else { return 0 }
        var removed = 0

        for duplicate in sorted.dropFirst() {
            for project in duplicate.projects ?? [] {
                project.styleSheet = keeper
            }
            context.delete(duplicate)
            removed += 1
        }
        return removed
    }

    private static func stylesheetSignature(_ sheet: StyleSheet) -> String {
        let normalizedName = sheet.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let textStyles = sheet.textStyles ?? []
        let textStyleSignatures = textStyles
            .map { textStyleSignature($0) }
            .sorted()
            .joined(separator: "||")

        let imageStyles = sheet.imageStyles ?? []
        let imageStyleSignatures = imageStyles
            .map { imageStyleSignature($0) }
            .sorted()
            .joined(separator: "||")

        return "\(normalizedName)::\(textStyleSignatures)::\(imageStyleSignatures)"
    }

    private static func textStyleSignature(_ style: TextStyleModel) -> String {
        var parts: [String] = []
        parts.append(style.name)
        parts.append(style.displayName)
        parts.append(String(style.displayOrder))
        parts.append(style.fontFamily ?? "")
        parts.append(style.fontName ?? "")
        parts.append(String(describing: style.fontSize))
        parts.append(String(style.isBold))
        parts.append(String(style.isItalic))
        parts.append(String(style.isUnderlined))
        parts.append(String(style.isStrikethrough))
        parts.append(style.textColorHex ?? "")
        parts.append(String(style.alignmentRaw))
        parts.append(String(describing: style.lineSpacing))
        parts.append(String(describing: style.paragraphSpacingBefore))
        parts.append(String(describing: style.paragraphSpacingAfter))
        parts.append(String(describing: style.firstLineIndent))
        parts.append(String(describing: style.headIndent))
        parts.append(String(describing: style.tailIndent))
        parts.append(String(describing: style.lineHeightMultiple))
        parts.append(String(describing: style.minimumLineHeight))
        parts.append(String(describing: style.maximumLineHeight))
        parts.append(style.numberFormatRaw)
        parts.append(style.numberAdornmentRaw)
        parts.append(style.followOnStyleName ?? "")
        parts.append(style.parentStyleName ?? "")
        parts.append(style.styleCategoryRaw)
        parts.append(String(style.isSystemStyle))
        parts.append(String(style.includeInTOC))
        parts.append(String(style.tocLevel))
        return parts.joined(separator: "|")
    }

    private static func imageStyleSignature(_ style: ImageStyle) -> String {
        var parts: [String] = []
        parts.append(style.name)
        parts.append(style.displayName)
        parts.append(String(style.displayOrder))
        parts.append(String(describing: style.defaultScale))
        parts.append(style.defaultAlignmentRaw)
        parts.append(String(style.hasCaptionByDefault))
        parts.append(style.defaultCaptionStyle)
        parts.append(String(style.isSystemStyle))
        return parts.joined(separator: "|")
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
            do {
                try EnsemblesSaveGate.save(context, reason: "migration-cleanup-orphaned-folders")
            } catch {
                #if DEBUG
                print("❌ [MigrationService] Failed early folder cleanup save: \(error)")
                #endif
            }
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
    
    /// Remove TrashItem records whose relationships have all been nullified.
    /// TrashItem uses .nullify delete rules, so when the referenced TextFile,
    /// Folder, or Project is deleted, the TrashItem survives as an empty shell.
    /// Only runs when importConfirmed to avoid deleting items still awaiting sync.
    private static func cleanupOrphanedTrashItems(context: ModelContext) {
        let descriptor = FetchDescriptor<TrashItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }
        
        var removedCount = 0
        for item in allItems {
            if item.textFile == nil && item.originalFolder == nil && item.project == nil {
                context.delete(item)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "migration-cleanup-trash-items")
                #if DEBUG
                print("🧹 [MigrationService] Removed \(removedCount) orphaned TrashItem records")
                #endif
            } catch {
                #if DEBUG
                print("❌ [MigrationService] Failed to save TrashItem cleanup: \(error)")
                #endif
            }
        }
    }
    
    /// Remove orphaned join-table records whose parent entities have been deleted.
    /// With `.nullify` delete rules, deleting a parent sets the link's relationship
    /// to nil rather than cascade-deleting the link itself.  This prevents CloudKit
    /// export queue poisoning (CKErrorDomain code=2) from cross-device cascade echoes.
    /// Links where BOTH sides are nil are safe to remove — they serve no purpose.
    private static func cleanupOrphanedJoinLinks(context: ModelContext) {
        var removedCount = 0
        
        func removeOrphans<T: PersistentModel>(_ type: T.Type, bothNil: (T) -> Bool) {
            let descriptor = FetchDescriptor<T>()
            guard let all = try? context.fetch(descriptor) else { return }
            for link in all where bothNil(link) {
                context.delete(link)
                removedCount += 1
            }
        }
        
        removeOrphans(TextFileCollectionLink.self) { $0.textFile == nil && $0.poetryCollection == nil }
        removeOrphans(TextFileSectionLink.self) { $0.textFile == nil && $0.section == nil }
        removeOrphans(SceneChapterLink.self) { $0.scene == nil && $0.chapter == nil }
        removeOrphans(SceneActLink.self) { $0.scene == nil && $0.act == nil }
        removeOrphans(SceneBookLink.self) { $0.scene == nil && $0.book == nil }
        removeOrphans(ScenePlotElementLink.self) { $0.scene == nil && $0.plotElement == nil }
        removeOrphans(SceneCharacterLink.self) { $0.scene == nil && $0.character == nil }
        removeOrphans(CharacterPlotElementLink.self) { $0.character == nil && $0.plotElement == nil }
        removeOrphans(LocationPlotElementLink.self) { $0.location == nil && $0.plotElement == nil }
        
        if removedCount > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "migration-cleanup-join-links")
                #if DEBUG
                print("🧹 [MigrationService] Removed \(removedCount) orphaned join-link records")
                #endif
            } catch {
                #if DEBUG
                print("❌ [MigrationService] Failed to save join-link cleanup: \(error)")
                #endif
            }
        }
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
            
            // Snapshot surviving subfolders — dedup above may have deleted/invalidated entries
            let survivingSubfolders = Array(manuscriptFolder.folders ?? [])
            
            // Also deduplicate text files within each subfolder (e.g. duplicate "Front Cover")
            for subfolder in survivingSubfolders {
                totalRemoved += deduplicateTextFileChildren(subfolder, context: context)
            }
        }
        
        if totalRemoved > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "migration-deduplicate-manuscript-subfolders")
            } catch {
                #if DEBUG
                print("❌ [MigrationService] Failed manuscript subfolder deduplication save: \(error)")
                #endif
            }
            #if DEBUG
            print("🧹 [MigrationService] Removed \(totalRemoved) duplicate folders/files from Manuscript subfolders")
            #endif
        }
    }
    
    /// Remove duplicate-named child folders from a parent folder.
    /// Merges content from duplicates into the keeper before deleting.
    /// Returns number of duplicates removed.
    private static func deduplicateFolderChildren(_ parent: Folder, context: ModelContext) -> Int {
        guard let children = parent.folders, children.count > 1 else { return 0 }
        
        // Snapshot into a local array — mutations below invalidate the live relationship array
        let childrenSnapshot = Array(children)
        
        var groups: [String: [Folder]] = [:]
        for child in childrenSnapshot {
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
            guard let keeper = sorted.first else { continue }
            for dup in sorted.dropFirst() {
                // Snapshot children before delete — accessing relationships after delete crashes
                let dupFiles = Array(dup.textFiles ?? [])
                let dupFolders = Array(dup.folders ?? [])
                // Merge text files from duplicate into keeper to avoid data loss
                for file in dupFiles {
                    file.parentFolder = keeper
                }
                // Merge subfolders from duplicate into keeper
                for subfolder in dupFolders {
                    subfolder.parentFolder = keeper
                }
                #if DEBUG
                print("🧹 [MigrationService] Merging & removing duplicate subfolder '\(name)' (id=\(dup.id)) from '\(parent.name ?? "")'")
                #endif
                context.delete(dup)
                removed += 1
            }
        }
        return removed
    }
    
    /// Remove duplicate-named text files from a folder.
    /// Keeps the file with the most versions; merges versions from duplicates.
    /// Returns number of duplicates removed.
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
            guard let keeper = sorted.first else { continue }
            for dup in sorted.dropFirst() {
                // Snapshot versions before delete — accessing relationships after delete crashes
                let dupVersions = Array(dup.versions ?? [])
                // Merge versions from duplicate into keeper to avoid data loss
                for version in dupVersions {
                    version.textFile = keeper
                }
                #if DEBUG
                print("🧹 [MigrationService] Merging & removing duplicate file '\(name)' (id=\(dup.id)) from '\(folder.name ?? "")'")
                #endif
                context.delete(dup)
                removed += 1
            }
        }
        return removed
    }
    
    /// Feature 029: Add Front Matter, Body, Back Matter subfolders to existing Manuscript folders
    /// - Parameters:
    ///   - context: The model context
    ///   - importConfirmed: When false, skip deleting legacy folders to avoid orphaning files during sync
    private static func migrateManuscriptSubfolders(context: ModelContext, importConfirmed: Bool = true) {
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
                if importConfirmed {
                    #if DEBUG
                    print("  ↳ Deleting wrong body folder '\(folder.name ?? "")' from \(project.name ?? "Untitled")")
                    #endif
                    context.delete(folder)
                } else {
                    #if DEBUG
                    print("  ⏳ Skipping deletion of legacy folder '\(folder.name ?? "")' from \(project.name ?? "Untitled") — import not confirmed")
                    #endif
                }
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

            // Only create new folders when import is confirmed — if CloudKit
            // hasn't finished importing, these folders may already exist on
            // another device and are about to sync in. Creating them now with
            // different UUIDs produces duplicates that spread via CloudKit.
            guard importConfirmed else {
                #if DEBUG
                print("  ⏳ Skipping folder creation for \(project.name ?? "Untitled") — import not confirmed (missing: \(missingNames.sorted().joined(separator: ", ")))")
                #endif
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
    /// Opt-in key to allow legacy Submission -> PoetryCollection migration outside tests.
    /// Default is OFF to avoid CloudKit partial-sync conversion risks at app startup.
    private static let feature036LegacyPoetryMigrationOptInKey = "allowFeature036LegacyPoetryMigration"
    
    /// Feature 036: Migrate projects to new folder structure
    /// - Renames "All X" body subfolders to "Body Matter"
    /// - Populates isInBodyMatter/bodyMatterOrder on existing container entities
    /// - Migrates Poetry collection Submissions to PoetryCollection model
    /// - Migrates Verse Novel Chapter entities to Book entities
    /// - Removes Collections folder from non-Poetry projects
    /// - Repositions Collections folder in Poetry projects
    static func migrateFeature036(context: ModelContext, importConfirmed: Bool = true) {
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
                // CloudKit-safe default: do NOT auto-migrate Submission-based collections on launch.
                // Collection entities and SubmittedFile links can sync in separate phases,
                // and running conversion during partial sync can create duplicate/empty
                // PoetryCollection records on one device.
                //
                // However, unit tests and explicit opt-in flows need deterministic migration,
                // so we enable it in those contexts only.
                if shouldRunLegacyPoetryCollectionMigration {
                    migratePoetryCollections(project: project, context: context)
                }
                repositionCollectionsFolder(project: project)
                deduplicatePoetryCollections(project: project, context: context)
            } else {
                removeCollectionsFolder(project: project, context: context, importConfirmed: importConfirmed)
            }
            
            if project.type == .fiction && project.fictionClass == .verseNovel {
                migrateVerseNovelChaptersToBooks(project: project, context: context, importConfirmed: importConfirmed)
            }
        }
        
        // Only save if there are actual changes to avoid dirtying CloudKit records
        if context.hasChanges {
            do {
                try EnsemblesSaveGate.save(context, reason: "migration-feature-036")
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

    /// Legacy poetry collection migration should only run when tests need deterministic
    /// conversion, or when explicitly opted in by a developer/user action.
    private static var shouldRunLegacyPoetryCollectionMigration: Bool {
        if isRunningUnitTests {
            return true
        }
        return UserDefaults.standard.bool(forKey: feature036LegacyPoetryMigrationOptInKey)
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
            // No old collections to migrate — this is fine, poems without collections is valid
            #if DEBUG
            print("  ↳ No old collections to migrate for \(project.name ?? "Untitled"), skipping")
            #endif
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

    // MARK: - Poetry Collection Deduplication

    /// Merge duplicate PoetryCollection records that share the same display name.
    ///
    /// CloudKit can transiently produce duplicate container records on one device when
    /// entity and relationship sync phases are interrupted/retried. This pass is idempotent
    /// and conservative: it groups by normalized name, keeps one canonical collection,
    /// merges file links and body-matter flags, then deletes only redundant duplicates.
    private static func deduplicatePoetryCollections(project: Project, context: ModelContext) {
        let collections = project.poetryCollections ?? []
        guard collections.count > 1 else { return }

        // Group by case-insensitive trimmed name.
        var groups: [String: [PoetryCollection]] = [:]
        for collection in collections {
            let normalizedName = (collection.name ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            groups[normalizedName, default: []].append(collection)
        }

        var removedCount = 0

        for (_, group) in groups where group.count > 1 {
            // Prefer a keeper with existing poems; then lowest userOrder; then oldest createdDate.
            let sorted = group.sorted { lhs, rhs in
                let lhsHasPoems = (lhs.textFiles?.isEmpty == false)
                let rhsHasPoems = (rhs.textFiles?.isEmpty == false)
                if lhsHasPoems != rhsHasPoems { return lhsHasPoems }

                let lhsOrder = lhs.userOrder ?? Int.max
                let rhsOrder = rhs.userOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }

                return lhs.createdDate < rhs.createdDate
            }

            guard let keeper = sorted.first else { continue }
            let duplicates = sorted.dropFirst()

            // Merge metadata from duplicates into keeper.
            if keeper.synopsis == nil {
                keeper.synopsis = duplicates.first(where: { ($0.synopsis ?? "").isEmpty == false })?.synopsis
            }

            if !keeper.isInBodyMatter,
               let bodyMatterSource = duplicates.first(where: { $0.isInBodyMatter }) {
                keeper.isInBodyMatter = true
                keeper.bodyMatterOrder = bodyMatterSource.bodyMatterOrder
            }

            // Merge file links to avoid data loss.
            for duplicate in duplicates {
                for file in duplicate.textFiles ?? [] {
                    file.addToPoetryCollection(keeper)
                }
                context.delete(duplicate)
                removedCount += 1
            }
        }

        #if DEBUG
        if removedCount > 0 {
            print("🧹 [MigrationService] Deduplicated \(removedCount) duplicate PoetryCollection records in \(project.name ?? "Untitled")")
        }
        #endif
    }
    
    // MARK: - Task 8.4: Remove Collections Folder (Non-Poetry)
    
    private static func removeCollectionsFolder(project: Project, context: ModelContext, importConfirmed: Bool = true) {
        guard let collectionsFolder = project.folders?.first(where: { $0.name == "Collections" }) else { return }
        
        guard importConfirmed else {
            #if DEBUG
            print("  ⏳ Skipping removal of Collections folder from \(project.type.rawValue) project \(project.name ?? "Untitled") — import not confirmed")
            #endif
            return
        }
        
        // Check for any collection-type submissions that need preservation
        // (their data should remain in the Submission model — we just remove the folder)
        
        #if DEBUG
        print("  ↳ Removing Collections folder from \(project.type.rawValue) project \(project.name ?? "Untitled")")
        #endif
        
        context.delete(collectionsFolder)
    }
    
    // MARK: - Task 8.6: Verse Novel Chapter → Book Migration
    
    private static func migrateVerseNovelChaptersToBooks(project: Project, context: ModelContext, importConfirmed: Bool = true) {
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
        
        // Don't create Book entities until import is confirmed — another device
        // may have already created them and they're about to sync in
        guard importConfirmed else {
            #if DEBUG
            print("  ⏳ Skipping Chapter→Book migration for \(project.name ?? "Untitled") — import not confirmed")
            #endif
            return
        }
        
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

    /// Remove empty Version stubs created by a partial CloudKit re-import after mirroring reset.
    ///
    /// These rows have no owning TextFile and no content payload. Keeping them serves no purpose,
    /// but leaves extra CloudKit-tracked records that can contribute to later import failures.
    private static func cleanupEmptyOrphanedVersions(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Version>()
        guard let allVersions = try? context.fetch(descriptor) else { return 0 }

        let orphanedVersions = allVersions.filter { version in
            guard version.textFile == nil else { return false }
            guard version.effectiveFormattedContent == nil else { return false }
            guard version.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            guard (version.comments?.isEmpty ?? true) else { return false }
            guard (version.footnotes?.isEmpty ?? true) else { return false }
            guard (version.submittedFiles?.isEmpty ?? true) else { return false }
            return true
        }

        for version in orphanedVersions {
            context.delete(version)
        }

        return orphanedVersions.count
    }
}
