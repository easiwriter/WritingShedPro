//
//  ProjectFolderMigrationService.swift
//  Writing Shed Pro
//
//  Created by AI Assistant on 2026-01-05.
//  Handles migration of folder structures for existing projects when new folders are added.
//

import Foundation
import SwiftData

/// Service responsible for adding missing folders to existing projects when folder structure changes.
/// Uses versioned migration to track which updates have been applied.
struct ProjectFolderMigrationService {
    
    // MARK: - Migration Version
    
    private static let migrationVersionKey = "projectFolderMigrationVersion"
    // Version 18: Convert legacy Commissions publication folders/types to Other
    private static let currentMigrationVersion = 18
    private static let publicationTargetMigrationVersionKey = "publicationTargetMigrationVersion"
    private static let currentPublicationTargetMigrationVersion = 1
    
    // MARK: - Public Methods
    
    /// Check if folder migration is needed and perform it for all projects
    /// Call this on app launch after ModelContainer is ready
    /// - Parameter modelContext: The SwiftData context to use
    static func migrateIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        
        #if DEBUG
        print("[ProjectFolderMigration] Checking migration: lastVersion=\(lastVersion), currentVersion=\(currentMigrationVersion)")
        #endif
        
        if lastVersion < currentMigrationVersion {
            performMigration(from: lastVersion, to: currentMigrationVersion, modelContext: modelContext)
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
            
            #if DEBUG
            print("[ProjectFolderMigration] Migration complete, updated to version \(currentMigrationVersion)")
            #endif
        } else {
            #if DEBUG
            print("[ProjectFolderMigration] No migration needed")
            #endif
        }
    }

    /// Runs only the safe publication-target folder/type migration.
    /// This is separate from the older folder migrations, which remain disabled at app launch.
    static func migratePublicationTargetsIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: publicationTargetMigrationVersionKey)
        let hasLegacyCommissions = hasLegacyCommissionData(modelContext: modelContext)
        let hasMissingPublicationFolders = hasMissingStandardPublicationFolders(modelContext: modelContext)

        guard lastVersion < currentPublicationTargetMigrationVersion || hasLegacyCommissions || hasMissingPublicationFolders else {
            #if DEBUG
            print("[ProjectFolderMigration] Publication target migration not needed")
            #endif
            return
        }

        #if DEBUG
        print("[ProjectFolderMigration] Running publication target migration: lastVersion=\(lastVersion), currentVersion=\(currentPublicationTargetMigrationVersion), hasLegacyCommissions=\(hasLegacyCommissions), hasMissingPublicationFolders=\(hasMissingPublicationFolders)")
        #endif

        addStandardPublicationFoldersToAllProjects(modelContext: modelContext)
        migrateCommissionsToOther(modelContext: modelContext)

        do {
            try EnsemblesSaveGate.save(modelContext, reason: "publication-target-migration")
            UserDefaults.standard.set(currentPublicationTargetMigrationVersion, forKey: publicationTargetMigrationVersionKey)

            #if DEBUG
            print("[ProjectFolderMigration] ✅ Publication target migration saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to save publication target migration: \(error)")
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private static func performMigration(from oldVersion: Int, to newVersion: Int, modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] Performing migration from version \(oldVersion) to \(newVersion)")
        #endif
        
        // Version 1: Add Manuscript folder to existing Poetry projects
        if oldVersion < 1 {
            addManuscriptFolderToPoetryProjects(modelContext: modelContext)
        }
        
        // Version 2: Fix folder ordering for all projects
        if oldVersion < 2 {
            fixFolderOrderingForAllProjects(modelContext: modelContext)
        }
        
        // Version 3: Add new folder structure to Prose projects (formerly General Purpose)
        if oldVersion < 3 {
            migrateProseProjectFolders(modelContext: modelContext)
        }
        
        // Version 4/5: Fix Manuscript Body folders - rename Body to correct name and delete duplicates
        // Combined into version 5 to run the comprehensive fix
        if oldVersion < 5 {
            renameManuscriptBodyFolders(modelContext: modelContext)
        }
        
        // Version 6: Delete orphan body folders at root level (runs same fix as V5)
        if oldVersion < 6 {
            renameManuscriptBodyFolders(modelContext: modelContext)
        }
        
        // Version 7: Rename body folders to use "All" prefix (All Poems, All Chapters, etc.)
        if oldVersion < 7 {
            renameManuscriptBodyFolders(modelContext: modelContext)
        }
        
        // Version 8: Restore deleted root-level content folders (Poems, Chapters, Sections, Acts, Stories)
        if oldVersion < 8 {
            restoreRootLevelContentFolders(modelContext: modelContext)
        }
        
        // Version 9: Safe migration - only rename Body to "All X" inside Manuscript, NO deletions
        if oldVersion < 9 {
            safeRenameManuscriptBodyFolder(modelContext: modelContext)
        }
        
        // Version 10: Clean up root-level manuscript folders (All Sections, Front Matter, etc.)
        if oldVersion < 10 {
            cleanupRootLevelManuscriptFolders(modelContext: modelContext)
        }
        
        // Version 11: Clean up old body folder names at root (Poems, Chapters, etc.)
        if oldVersion < 11 {
            cleanupRootLevelManuscriptFolders(modelContext: modelContext)
        }
        
        // Version 12: Re-run cleanup, now only deletes EMPTY folders
        if oldVersion < 12 {
            cleanupRootLevelManuscriptFolders(modelContext: modelContext)
        }
        
        // Version 13: Restore content folders incorrectly deleted by v10-12
        // The cleanup was deleting Poems, Chapters, Sections, Acts, Stories at root
        // but these ARE valid root-level folders for their project types
        if oldVersion < 13 {
            restoreRootLevelContentFolders(modelContext: modelContext)
        }
        
        // Version 14: Re-run cleanup with corrected folder list
        // v10-12 incorrectly included content folders in cleanup list
        // Now cleanup only removes manuscript-only folders (Front Matter, Back Matter, All X)
        if oldVersion < 14 {
            cleanupRootLevelManuscriptFolders(modelContext: modelContext)
        }
        
        // Version 15: Re-run cleanup - previous version had wrong property names
        if oldVersion < 15 {
            cleanupRootLevelManuscriptFolders(modelContext: modelContext)
        }
        
        // Version 16: Fix parent relationships for manuscript subfolders
        // Some folders appear in Manuscript's folders array but have parentFolder = nil
        // This causes them to appear at both root level and inside Manuscript
        if oldVersion < 16 {
            fixManuscriptSubfolderRelationships(modelContext: modelContext)
            cleanupRootLevelManuscriptFolders(modelContext: modelContext)
        }
        
        // Version 17: All project types support Magazines, Competitions, Publishers, Agents, Other
        if oldVersion < 17 {
            addStandardPublicationFoldersToAllProjects(modelContext: modelContext)
        }

        // Version 18: Commissions is now covered by Other
        if oldVersion < 18 {
            migrateCommissionsToOther(modelContext: modelContext)
        }

        // Future migrations go here:
        // if oldVersion < 19 { ... }
        
        do {
            try EnsemblesSaveGate.save(modelContext, reason: "project-folder-migration")
            #if DEBUG
            print("[ProjectFolderMigration] ✅ Migration saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to save migration: \(error)")
            #endif
        }
    }

    private static func hasLegacyCommissionData(modelContext: ModelContext) -> Bool {
        do {
            let folders = try modelContext.fetch(FetchDescriptor<Folder>())
            if folders.contains(where: { $0.name == "Commissions" }) {
                return true
            }

            let publications = try modelContext.fetch(FetchDescriptor<Publication>())
            return publications.contains { $0.typeRaw.lowercased().contains("commission") }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to check legacy commission data: \(error)")
            #endif
            return false
        }
    }

    private static func hasMissingStandardPublicationFolders(modelContext: ModelContext) -> Bool {
        let requiredFolderNames = [
            NSLocalizedString("folder.magazines", comment: "Magazines folder name"),
            NSLocalizedString("folder.competitions", comment: "Competitions folder name"),
            NSLocalizedString("folder.publishers", comment: "Publishers folder name"),
            NSLocalizedString("folder.agents", comment: "Agents folder name"),
            NSLocalizedString("folder.other", comment: "Other folder name")
        ]

        do {
            let projects = try modelContext.fetch(FetchDescriptor<Project>())

            for project in projects {
                let rootFolders = try fetchRootFolders(for: project, modelContext: modelContext)
                let rootFolderNames = Set(rootFolders.compactMap { $0.name })

                if requiredFolderNames.contains(where: { !rootFolderNames.contains($0) }) {
                    return true
                }
            }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to check standard publication folders: \(error)")
            #endif
        }

        return false
    }

    /// Version 17 Migration: Ensure every project has all standard publication target folders.
    /// This is additive only: it never deletes legacy folders.
    private static func addStandardPublicationFoldersToAllProjects(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V17: Adding standard publication folders to all projects...")
        #endif

        let descriptor = FetchDescriptor<Project>()
        let foldersToAdd = [
            "folder.magazines",
            "folder.competitions",
            "folder.publishers",
            "folder.agents",
            "folder.other"
        ]

        do {
            let projects = try modelContext.fetch(descriptor)

            for project in projects {
                var addedCount = 0

                for folderKey in foldersToAdd {
                    if addFolderIfMissing(folderKey: folderKey, to: project, modelContext: modelContext) {
                        addedCount += 1
                    }
                }

                fixFolderOrdering(for: project)

                #if DEBUG
                if addedCount > 0 {
                    print("[ProjectFolderMigration] Added \(addedCount) publication folders to project: \(project.name ?? "Untitled")")
                }
                #endif
            }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to add standard publication folders: \(error)")
            #endif
        }
    }

    /// Version 18 Migration: Convert legacy Commissions folders and publication records to Other.
    /// This avoids deleting folders so late-arriving relationship data cannot be cascaded away during sync.
    private static func migrateCommissionsToOther(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V18: Migrating Commissions to Other...")
        #endif

        let otherName = NSLocalizedString("folder.other", comment: "Other folder name")
        let commissionsName = "Commissions"

        do {
            let projects = try modelContext.fetch(FetchDescriptor<Project>())
            var renamedFolderCount = 0

            for project in projects {
                _ = addFolderIfMissing(folderKey: "folder.other", to: project, modelContext: modelContext)

                fixFolderOrdering(for: project)
            }

            let folders = try modelContext.fetch(FetchDescriptor<Folder>())
            for folder in folders where folder.name == commissionsName {
                folder.name = otherName
                renamedFolderCount += 1
            }

            let publications = try modelContext.fetch(FetchDescriptor<Publication>())
            var migratedPublicationCount = 0

            for publication in publications where publication.typeRaw.lowercased().contains("commission") {
                publication.typeRaw = PublicationType.other.rawValue
                publication.modifiedDate = Date()
                migratedPublicationCount += 1
            }

            #if DEBUG
            print("[ProjectFolderMigration] Migrated \(renamedFolderCount) Commissions folders and \(migratedPublicationCount) commission publications to Other")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to migrate Commissions to Other: \(error)")
            #endif
        }
    }
    
    /// Version 1 Migration: Add Manuscript folder to existing Poetry projects that don't have one
    private static func addManuscriptFolderToPoetryProjects(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V1: Adding Manuscript folder to Poetry projects...")
        #endif
        
        // Fetch all Poetry projects
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.typeRaw == "poetry" }
        )
        
        do {
            let poetryProjects = try modelContext.fetch(descriptor)
            
            #if DEBUG
            print("[ProjectFolderMigration] Found \(poetryProjects.count) Poetry projects to check")
            #endif
            
            let manuscriptName = NSLocalizedString("folder.manuscript", comment: "Manuscript folder name")
            
            for project in poetryProjects {
                // Check if Manuscript folder already exists
                let hasManuscript = project.folders?.contains { $0.name == manuscriptName } ?? false
                
                if !hasManuscript {
                    // Create Manuscript folder
                    let manuscriptFolder = Folder(name: manuscriptName, project: project)
                    modelContext.insert(manuscriptFolder)
                    
                    #if DEBUG
                    print("[ProjectFolderMigration] Added Manuscript folder to project: \(project.name ?? "Untitled")")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to fetch Poetry projects: \(error)")
            #endif
        }
    }
    
    /// Version 2 Migration: Fix folder ordering for all existing projects
    private static func fixFolderOrderingForAllProjects(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V2: Fixing folder ordering for all projects...")
        #endif
        
        let descriptor = FetchDescriptor<Project>()
        
        do {
            let allProjects = try modelContext.fetch(descriptor)
            
            #if DEBUG
            print("[ProjectFolderMigration] Found \(allProjects.count) projects to fix folder ordering")
            #endif
            
            for project in allProjects {
                fixFolderOrdering(for: project)
            }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to fetch projects: \(error)")
            #endif
        }
    }
    
    /// Version 3 Migration: Add new folder structure to Prose projects (formerly General Purpose)
    /// Old structure: Folders, Trash
    /// New structure: Manuscript, Sections, Prose, Collections, Submissions, Research, Publishers, Agents, Other, Trash
    private static func migrateProseProjectFolders(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V3: Adding new folder structure to Prose projects...")
        #endif
        
        // Fetch all Prose projects (includes legacy "generalPurpose" type)
        let proseType: String = "prose"
        let gpType: String = "generalPurpose"
        let prosePredicate: Predicate<Project> = #Predicate<Project> { (project: Project) in
            project.typeRaw == proseType || project.typeRaw == gpType
        }
        let descriptor = FetchDescriptor<Project>(
            predicate: prosePredicate
        )
        
        do {
            let proseProjects = try modelContext.fetch(descriptor)
            
            #if DEBUG
            print("[ProjectFolderMigration] Found \(proseProjects.count) Prose projects to migrate")
            #endif
            
            // Folders to add (localization keys)
            let foldersToAdd = [
                "folder.manuscript",
                "folder.sections",
                "folder.prose",
                "folder.collections",
                "folder.submissions",
                "folder.research",
                "folder.magazines",
                "folder.competitions",
                "folder.publishers",
                "folder.agents",
                "folder.other"
                // Note: Trash should already exist
            ]
            
            for project in proseProjects {
                var addedCount = 0
                
                for folderKey in foldersToAdd {
                    if addFolderIfMissing(folderKey: folderKey, to: project, modelContext: modelContext) {
                        addedCount += 1
                    }
                }
                
                // Create Manuscript subfolders if Manuscript was added
                let manuscriptName = NSLocalizedString("folder.manuscript", comment: "Manuscript")
                if let manuscriptFolder = project.folders?.first(where: { $0.name == manuscriptName }) {
                    // Check if subfolders exist
                    let existingSubfolders = manuscriptFolder.folders ?? []
                    if existingSubfolders.isEmpty {
                        ProjectTemplateService.createManuscriptSubfolders(in: manuscriptFolder, context: modelContext)
                    }
                }
                
                // Fix folder ordering after adding new folders
                fixFolderOrdering(for: project)
                
                #if DEBUG
                print("[ProjectFolderMigration] Added \(addedCount) folders to Prose project: \(project.name ?? "Untitled")")
                #endif
            }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to fetch Prose projects: \(error)")
            #endif
        }
    }
    
    /// Fix folder ordering for a single project based on the expected order
    private static func fixFolderOrdering(for project: Project) {
        guard let folders = project.folders else { return }
        
        // Get the expected folder order for this project type
        let expectedOrder = getExpectedFolderOrder(for: project)
        
        // Create a lookup of folder name to expected order index
        var orderLookup: [String: Int] = [:]
        for (index, key) in expectedOrder.enumerated() {
            let name = NSLocalizedString(key, comment: "Folder name")
            orderLookup[name] = index
        }
        
        // Assign userOrder to each folder based on expected order
        for folder in folders where folder.parentFolder == nil {  // Only top-level folders
            if let name = folder.name, let expectedIndex = orderLookup[name] {
                folder.userOrder = expectedIndex
            } else {
                // Unknown folder - put at end
                folder.userOrder = expectedOrder.count + 100
            }
        }
        
        #if DEBUG
        print("[ProjectFolderMigration] Fixed folder ordering for project: \(project.name ?? "Untitled")")
        #endif
    }
    
    /// Returns the expected folder order keys for a project type
    private static func getExpectedFolderOrder(for project: Project) -> [String] {
        switch project.type {
        case .prose:
            return [
                "folder.manuscript", "folder.sections", "folder.prose",
                "folder.collections", "folder.submissions", "folder.research",
                "folder.magazines", "folder.competitions", "folder.publishers", "folder.agents", "folder.other",
                "folder.trash"
            ]
            
        case .poetry:
            return [
                "folder.all", "folder.draft", "folder.ready", "folder.submissions",
                "folder.setAside", "folder.published", "folder.collections", "folder.manuscript",
                "folder.research",
                "folder.magazines", "folder.competitions", "folder.publishers", "folder.agents", "folder.other",
                "folder.trash"
            ]
            
        case .fiction:
            var keys = [
                "folder.all", "folder.draft", "folder.ready", "folder.submissions", "folder.setAside",
                "folder.characters", "folder.locations", "folder.chapters", "folder.plot",
                "folder.research"
            ]
            keys.append(contentsOf: ["folder.magazines", "folder.competitions", "folder.publishers", "folder.agents", "folder.other"])
            keys.append("folder.trash")
            return keys
            
        case .drama:
            return [
                "folder.all", "folder.draft", "folder.ready", "folder.setAside",
                "folder.research",
                "folder.magazines", "folder.competitions", "folder.publishers", "folder.agents", "folder.other",
                "folder.trash"
            ]
        }
    }
    
    /// Utility: Add a folder to a project if it doesn't already exist
    /// - Parameters:
    ///   - folderKey: The localization key for the folder name (e.g., "folder.manuscript")
    ///   - project: The project to add the folder to
    ///   - modelContext: The SwiftData context
    /// - Returns: True if folder was added, false if it already existed
    @discardableResult
    static func addFolderIfMissing(folderKey: String, to project: Project, modelContext: ModelContext) -> Bool {
        let folderName = NSLocalizedString(folderKey, comment: "Folder name")
        
        let exists = rootFolderExists(named: folderName, in: project, modelContext: modelContext)
        
        if !exists {
            let folder = Folder(name: folderName, project: project)
            modelContext.insert(folder)
            return true
        }
        
        return false
    }

    private static func rootFolderExists(named folderName: String, in project: Project, modelContext: ModelContext) -> Bool {
        do {
            return try fetchRootFolders(for: project, modelContext: modelContext)
                .contains { $0.name == folderName }
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to check root folder '\(folderName)': \(error)")
            #endif
            return project.folders?.contains { $0.name == folderName && $0.parentFolder == nil } ?? false
        }
    }

    private static func fetchRootFolders(for project: Project, modelContext: ModelContext) throws -> [Folder] {
        let projectID = project.id
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { folder in
                folder.project?.id == projectID && folder.parentFolder == nil
            }
        )

        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Version 5 Migration: Fix Manuscript Body folders
    
    /// Version 5 Migration: Fix Manuscript subfolders
    /// - Renames "Body" folders to project-type-specific names (Acts, Poems, Sections, Chapters, Stories)
    /// - Removes duplicate folders inside Manuscript
    /// - Removes root-level folders that should only exist inside Manuscript
    /// - Ensures only Front Matter, [Body Type], and Back Matter exist inside Manuscript
    private static func renameManuscriptBodyFolders(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V5: Fixing Manuscript Body folders...")
        #endif
        
        let descriptor = FetchDescriptor<Project>()
        
        do {
            let allProjects = try modelContext.fetch(descriptor)
            #if DEBUG
            print("[ProjectFolderMigration] Found \(allProjects.count) projects to check")
            #endif
            var fixedCount = 0
            
            for project in allProjects {
                #if DEBUG
                print("[ProjectFolderMigration] Checking project: \(project.name ?? "Untitled") (type: \(project.type.rawValue))")
                #endif
                
                let allFolders = project.folders ?? []
                #if DEBUG
                print("[ProjectFolderMigration]   Project has \(allFolders.count) folders")
                for f in allFolders {
                    print("[ProjectFolderMigration]     - '\(f.name ?? "nil")' parentFolder=\(f.parentFolder?.name ?? "nil")")
                }
                #endif
                
                // Determine the correct body folder name based on project type
                // Feature 036: All project types now use "Body Matter"
                let correctBodyName = "Body Matter"
                
                #if DEBUG
                print("[ProjectFolderMigration]   Correct body name for this project: '\(correctBodyName)'")
                #endif
                
                // Folder names that should ONLY exist inside Manuscript (not at root level)
                // Includes all variations of Body, Front Matter, Back Matter and legacy "All X" folders
                let manuscriptOnlyNames: Set<String> = [
                    "Body", "Body Matter", "Front Matter", "Back Matter",
                    "All Acts", "All Poems", "All Sections", "All Chapters", "All Stories",
                    "Acts", "Poems", "Sections", "Chapters", "Stories"
                ]
                
                // Old body folder names (without "All" prefix) that should be renamed inside Manuscript
                let oldBodyFolderNames: Set<String> = ["Acts", "Poems", "Sections", "Chapters", "Stories"]
                
                // Legacy "All X" body folder names that should be renamed to "Body Matter"
                let allBodyFolderNames: Set<String> = ["All Acts", "All Poems", "All Sections", "All Chapters", "All Stories"]
                
                var madeChanges = false
                var foldersToDelete: [Folder] = []
                
                // Step 1: Delete root-level folders that shouldn't exist at root
                // ONLY delete Body, Front Matter, Back Matter at root - NOT content folders like Poems, Chapters
                for folder in allFolders {
                    let name = folder.name ?? ""
                    if folder.parentFolder == nil && manuscriptOnlyNames.contains(name) {
                        #if DEBUG
                        print("[ProjectFolderMigration]   Marking root-level '\(name)' for deletion (should only be in Manuscript)")
                        #endif
                        foldersToDelete.append(folder)
                    }
                }
                
                // Find the Manuscript folder
                guard let manuscriptFolder = allFolders.first(where: { $0.name == "Manuscript" && $0.parentFolder == nil }) else {
                    #if DEBUG
                    print("[ProjectFolderMigration]   No Manuscript folder found")
                    #endif
                    // Still delete root-level manuscript-only folders if found
                    for folder in foldersToDelete {
                        #if DEBUG
                        print("[ProjectFolderMigration]   Deleting: '\(folder.name ?? "nil")'")
                        #endif
                        modelContext.delete(folder)
                        madeChanges = true
                    }
                    if madeChanges { fixedCount += 1 }
                    continue
                }
                
                let subfolders = manuscriptFolder.folders ?? []
                #if DEBUG
                print("[ProjectFolderMigration]   Manuscript has \(subfolders.count) subfolders:")
                for sf in subfolders {
                    print("[ProjectFolderMigration]     - '\(sf.name ?? "nil")'")
                }
                #endif
                
                // Track which valid folders we've seen (to detect duplicates)
                var seenFrontMatter = false
                var seenBackMatter = false
                
                // Step 2: First pass - check if correct body folder already exists
                var hasCorrectBodyFolder = false
                for subfolder in subfolders {
                    let name = subfolder.name ?? ""
                    if name == correctBodyName {
                        hasCorrectBodyFolder = true
                        #if DEBUG
                        print("[ProjectFolderMigration]   Found existing '\(correctBodyName)' folder")
                        #endif
                        break
                    }
                }
                
                _ = hasCorrectBodyFolder // Silence unused variable warning
                // Step 3: Process Manuscript subfolders
                for subfolder in subfolders {
                    let name = subfolder.name ?? ""
                    
                    if name == "Front Matter" {
                        if seenFrontMatter {
                            #if DEBUG
                            print("[ProjectFolderMigration]   Marking duplicate 'Front Matter' for deletion")
                            #endif
                            foldersToDelete.append(subfolder)
                        } else {
                            seenFrontMatter = true
                            #if DEBUG
                            print("[ProjectFolderMigration]   Keeping 'Front Matter'")
                            #endif
                        }
                    } else if name == "Back Matter" {
                        if seenBackMatter {
                            #if DEBUG
                            print("[ProjectFolderMigration]   Marking duplicate 'Back Matter' for deletion")
                            #endif
                            foldersToDelete.append(subfolder)
                        } else {
                            seenBackMatter = true
                            #if DEBUG
                            print("[ProjectFolderMigration]   Keeping 'Back Matter'")
                            #endif
                        }
                    } else if name == "Body" {
                        // Rename "Body" to the correct project-type-specific name
                        #if DEBUG
                        print("[ProjectFolderMigration]   Renaming 'Body' to '\(correctBodyName)'")
                        #endif
                        subfolder.name = correctBodyName
                        subfolder.userOrder = 1
                        madeChanges = true
                    } else if oldBodyFolderNames.contains(name) {
                        // Old body folder name without "All" prefix - rename to correct name
                        #if DEBUG
                        print("[ProjectFolderMigration]   Renaming '\(name)' to '\(correctBodyName)'")
                        #endif
                        subfolder.name = correctBodyName
                        subfolder.userOrder = 1
                        madeChanges = true
                    } else if allBodyFolderNames.contains(name) {
                        // This is a legacy "All X" body folder — rename to "Body Matter"
                        #if DEBUG
                        print("[ProjectFolderMigration]   Renaming '\(name)' to '\(correctBodyName)'")
                        #endif
                        subfolder.name = correctBodyName
                        subfolder.userOrder = 1
                        madeChanges = true
                    } else if name == correctBodyName {
                        // Already correct — keep as-is
                        #if DEBUG
                        print("[ProjectFolderMigration]   Keeping '\(correctBodyName)'")
                        #endif
                    }
                    // Other folders (not manuscript-related) are left alone
                }
                
                // Step 4: Delete all marked folders
                for folder in foldersToDelete {
                    #if DEBUG
                    print("[ProjectFolderMigration]   Deleting folder: '\(folder.name ?? "nil")'")
                    #endif
                    modelContext.delete(folder)
                    madeChanges = true
                }
                
                // Step 5: Fix userOrder for remaining Manuscript subfolders
                // Assign correct order: Front Matter=0, Body=1, Back Matter=2
                let remainingFolders = manuscriptFolder.folders ?? []
                for folder in remainingFolders {
                    let correctOrder: Int
                    if folder.name == "Front Matter" {
                        correctOrder = 0
                    } else if folder.name == correctBodyName {
                        correctOrder = 1
                    } else if folder.name == "Back Matter" {
                        correctOrder = 2
                    } else {
                        // Other folders (shouldn't exist, but just in case)
                        correctOrder = 3
                    }
                    if folder.userOrder != correctOrder {
                        folder.userOrder = correctOrder
                        madeChanges = true
                    }
                }
                
                if madeChanges {
                    fixedCount += 1
                    #if DEBUG
                    print("[ProjectFolderMigration]   ✅ Fixed project: \(project.name ?? "Untitled")")
                    #endif
                }
            }
            
            #if DEBUG
            print("[ProjectFolderMigration] V5: Fixed \(fixedCount) projects")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to fetch projects: \(error)")
            #endif
        }
    }
    
    // MARK: - Version 8: Restore deleted root-level content folders
    
    /// Restore root-level content folders that were accidentally deleted in V6
    /// These are: Poems (poetry), Sections/Prose (prose), Chapters/Stories (fiction), Acts (drama)
    private static func restoreRootLevelContentFolders(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V8: Restoring root-level content folders...")
        #endif
        
        do {
            let descriptor = FetchDescriptor<Project>()
            let projects = try modelContext.fetch(descriptor)
            
            var restoredCount = 0
            
            for project in projects {
                let existingFolders = project.folders ?? []
                let existingNames = Set(existingFolders.filter { $0.parentFolder == nil }.compactMap { $0.name })
                
                // Determine which content folders should exist at root level for this project type
                var requiredFolders: [(name: String, order: Int)] = []
                
                switch project.type {
                case .poetry:
                    // Poetry needs: Poems folder after Manuscript
                    requiredFolders = [("Poems", 1)]
                    
                case .prose:
                    // Prose needs: Sections, Prose folders after Manuscript
                    requiredFolders = [("Sections", 1), ("Prose", 2)]
                    
                case .fiction:
                    // Fiction needs: Chapters/Stories/Books (based on fictionClass), Scenes/Episodes, Characters, Locations, Plot
                    if project.fictionClass == .shortFiction {
                        requiredFolders = [
                            ("Stories", 1),
                            ("Scenes", 2),
                            ("Characters", 3),
                            ("Locations", 4),
                            ("Plot", 5)
                        ]
                    } else if project.fictionClass == .verseNovel {
                        requiredFolders = [
                            ("Books", 1),
                            ("Episodes", 2),
                            ("Characters", 3),
                            ("Locations", 4),
                            ("Plot", 5)
                        ]
                    } else {
                        requiredFolders = [
                            ("Chapters", 1),
                            ("Scenes", 2),
                            ("Characters", 3),
                            ("Locations", 4),
                            ("Plot", 5)
                        ]
                    }
                    
                case .drama:
                    // Drama needs: Acts, Scenes, Characters, Locations, Plot
                    requiredFolders = [
                        ("Acts", 1),
                        ("Scenes", 2),
                        ("Characters", 3),
                        ("Locations", 4),
                        ("Plot", 5)
                    ]
                }
                
                var madeChanges = false
                
                for (name, order) in requiredFolders {
                    if !existingNames.contains(name) {
                        #if DEBUG
                        print("[ProjectFolderMigration]   Creating missing '\(name)' folder for \(project.name ?? "Untitled")")
                        #endif
                        
                        let folder = Folder(name: name, project: project, userOrder: order)
                        folder.parentFolder = nil  // Root level
                        modelContext.insert(folder)
                        madeChanges = true
                    }
                }
                
                if madeChanges {
                    restoredCount += 1
                }
            }
            
            #if DEBUG
            print("[ProjectFolderMigration] V8: Restored folders for \(restoredCount) projects")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to restore folders: \(error)")
            #endif
        }
    }
    
    // MARK: - Version 9: Safe rename (NO deletions)
    
    /// Safely rename Body folder inside Manuscript to project-type-specific name with "All" prefix
    /// This function ONLY renames, it does NOT delete any folders
    private static func safeRenameManuscriptBodyFolder(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] V9: Safe rename of Manuscript Body folders...")
        #endif
        
        do {
            let descriptor = FetchDescriptor<Project>()
            let projects = try modelContext.fetch(descriptor)
            
            var renamedCount = 0
            
            for project in projects {
                // Determine the correct body folder name for this project type
                // Feature 036: All project types now use "Body Matter"
                let correctBodyName = "Body Matter"
                
                // Find Manuscript folder
                guard let manuscriptFolder = project.folders?.first(where: { 
                    $0.name == "Manuscript" && $0.parentFolder == nil 
                }) else {
                    continue
                }
                
                // Look for Body folder to rename (ONLY rename, never delete)
                let subfolders = manuscriptFolder.folders ?? []
                var madeChanges = false
                
                for subfolder in subfolders {
                    let name = subfolder.name ?? ""
                    
                    if name == "Body" {
                        // Rename Body to the correct name
                        #if DEBUG
                        print("[ProjectFolderMigration]   Renaming 'Body' to '\(correctBodyName)' in \(project.name ?? "Untitled")")
                        #endif
                        subfolder.name = correctBodyName
                        subfolder.userOrder = 1
                        madeChanges = true
                    }
                }
                
                if madeChanges {
                    renamedCount += 1
                }
            }
            
            #if DEBUG
            print("[ProjectFolderMigration] V9: Renamed Body folders in \(renamedCount) projects")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Failed to rename folders: \(error)")
            #endif
        }
    }
    
    // MARK: - Version 10: Cleanup root-level manuscript folders
    
    /// Removes folders at root level that should only exist inside Manuscript
    /// This fixes a bug where "Front Matter", "Back Matter", "All Sections" etc. appeared at root
    private static func cleanupRootLevelManuscriptFolders(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] 🧹 Starting cleanup of root-level manuscript folders")
        #endif
        
        // Names that should ONLY exist inside Manuscript folder, never at root
        // NOTE: Do NOT include "Poems", "Chapters", "Sections", "Acts", "Stories" here
        // - those are legitimate root-level content folders for their project types
        // Only include folders that are exclusively Manuscript subfolders
        let manuscriptOnlyNames: Set<String> = [
            "Body",                 // Old name, should have been renamed to "All X"
            "Front Matter",         // Only exists inside Manuscript
            "Back Matter",          // Only exists inside Manuscript
            "All Acts",             // Renamed Body folder inside Manuscript
            "All Poems",            // Renamed Body folder inside Manuscript
            "All Sections",         // Renamed Body folder inside Manuscript
            "All Chapters",         // Renamed Body folder inside Manuscript
            "All Stories"           // Renamed Body folder inside Manuscript
        ]
        
        do {
            // Fetch all projects
            let projectDescriptor = FetchDescriptor<Project>()
            let projects = try modelContext.fetch(projectDescriptor)
            
            for project in projects {
                #if DEBUG
                print("[ProjectFolderMigration] Checking project: \(project.name ?? "Untitled")")
                #endif
                
                // Get root-level folders directly from project
                let rootFolders = project.folders?.filter { $0.parentFolder == nil } ?? []
                
                for folder in rootFolders {
                    let folderName = folder.name ?? ""
                    if manuscriptOnlyNames.contains(folderName) {
                        // Only delete if folder is empty (no files and no subfolders)
                        let fileCount = folder.textFiles?.count ?? 0
                        let subfolderCount = folder.folders?.count ?? 0
                        
                        if fileCount == 0 && subfolderCount == 0 {
                            #if DEBUG
                            print("[ProjectFolderMigration] 🗑️ Deleting empty root-level folder: '\(folderName)' from project '\(project.name ?? "Untitled")'")
                            #endif
                            modelContext.delete(folder)
                        } else {
                            #if DEBUG
                            print("[ProjectFolderMigration] ⚠️ Skipping root-level folder '\(folderName)' - has \(fileCount) files, \(subfolderCount) subfolders")
                            #endif
                        }
                    }
                }
            }
            
            try EnsemblesSaveGate.save(modelContext, reason: "project-folder-cleanup-root-manuscript")
            #if DEBUG
            print("[ProjectFolderMigration] ✅ Cleanup complete")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Cleanup failed: \(error)")
            #endif
        }
    }
    
    /// Version 16 Migration: Fix parent relationships for manuscript subfolders
    /// Some folders appear in Manuscript's folders array but have parentFolder = nil
    /// This causes them to appear at both root level AND inside Manuscript
    private static func fixManuscriptSubfolderRelationships(modelContext: ModelContext) {
        #if DEBUG
        print("[ProjectFolderMigration] 🔧 Starting fix for manuscript subfolder relationships")
        #endif
        
        do {
            let projectDescriptor = FetchDescriptor<Project>()
            let projects = try modelContext.fetch(projectDescriptor)
            
            for project in projects {
                // Find the Manuscript folder
                guard let manuscriptFolder = project.folders?.first(where: { $0.name == "Manuscript" }) else {
                    continue
                }
                
                // Check each subfolder in Manuscript's folders array
                guard let manuscriptSubfolders = manuscriptFolder.folders else { continue }
                
                for subfolder in manuscriptSubfolders {
                    // If the subfolder's parentFolder is nil, set it to Manuscript
                    if subfolder.parentFolder == nil {
                        #if DEBUG
                        print("[ProjectFolderMigration] 🔗 Fixing parent relationship for '\(subfolder.name ?? "")' in project '\(project.name ?? "")'")
                        #endif
                        subfolder.parentFolder = manuscriptFolder
                    }
                }
            }
            
            try EnsemblesSaveGate.save(modelContext, reason: "project-folder-fix-manuscript-subfolders")
            #if DEBUG
            print("[ProjectFolderMigration] ✅ Parent relationship fix complete")
            #endif
        } catch {
            #if DEBUG
            print("[ProjectFolderMigration] ❌ Parent relationship fix failed: \(error)")
            #endif
        }
    }
}
