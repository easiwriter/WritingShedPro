//
//  DeduplicationService.swift
//  Writing Shed Pro
//
//  Detects and removes duplicate Project records caused by
//  CloudKit sync race conditions during fresh-database imports.
//

import Foundation
import SwiftData

/// Service that detects and removes duplicate Project records
/// that share the same name (case-insensitive) but have different UUIDs.
///
/// Duplicates arise when CloudKit re-imports records into a fresh
/// local database while MigrationService simultaneously modifies
/// those records, causing the sync layer to treat modified copies
/// as new local records. Some duplicates end up with different
/// creation dates, so matching is done by name only.
class DeduplicationService {
    
    // MARK: - Types
    
    struct DeduplicationResult {
        let duplicatesRemoved: Int
        let projectsAffected: [String]
        let errors: [String]
    }

    struct ExactDuplicateCleanupResult {
        let recordsRemoved: Int
        let groupsAffected: Int
        let errors: [String]
    }

    struct TemplateFolderCleanupResult {
        let recordsRemoved: Int
        let groupsAffected: Int
        let skippedNonEmptyGroups: Int
        let errors: [String]
    }

    // MARK: - Tombstone System
    //
    // When a project is permanently deleted, we record a "tombstone" in UserDefaults
    // so that if CloudKit re-imports the record (zombie), we can detect and re-delete it.
    // Tombstones expire after 90 days to avoid unbounded growth.

    private static let tombstoneDefaultsKey = "WSP_DeletedProjectTombstones"
    private static let tombstoneExpiryInterval: TimeInterval = 90 * 24 * 3600 // 90 days
    private static var zombieDeletionPausedUntil: Date?

    /// A lightweight record of a permanently deleted project.
    private struct Tombstone: Codable {
        let projectID: UUID?
        let normalizedName: String
        let typeRaw: String?
        let deletedAt: Date
    }

    /// Record that a project has been permanently deleted.
    /// Called before `context.delete()` so we still have access to the project's properties.
    static func recordTombstone(for project: Project) {
        guard let key = normalizedNameKey(for: project.name) else { return }
        var tombstones = loadTombstones()
        // Avoid duplicating an existing tombstone for the same project UUID.
        // Also prune legacy name+type tombstones so the new UUID tombstone becomes canonical.
        tombstones.removeAll {
            ($0.projectID != nil && $0.projectID == project.id) ||
            ($0.projectID == nil && $0.normalizedName == key && $0.typeRaw == project.typeRaw)
        }
        tombstones.append(Tombstone(projectID: project.id, normalizedName: key, typeRaw: project.typeRaw, deletedAt: Date()))
        saveTombstones(tombstones)
        #if DEBUG
        print("🪦 [DeduplicationService] Recorded tombstone for '\(project.name ?? "?")' id=\(project.id) (type=\(project.typeRaw ?? "nil"))")
        #endif
    }

    /// Remove the tombstone for a project name+type (e.g. if user creates a new project
    /// with the same name intentionally).
    static func clearTombstone(name: String, typeRaw: String?) {
        guard let key = normalizedNameKey(for: name) else { return }
        var tombstones = loadTombstones()
        let before = tombstones.count
        tombstones.removeAll { $0.normalizedName == key && $0.typeRaw == typeRaw }
        if tombstones.count != before {
            saveTombstones(tombstones)
            #if DEBUG
            print("🪦 [DeduplicationService] Cleared tombstone for '\(name)'")
            #endif
        }
    }

    /// Remove ALL tombstones. Used after recovery imports to prevent zombie detection
    /// from killing freshly re-imported projects.
    static func clearAllTombstones() {
        let existing = loadTombstones()
        guard !existing.isEmpty else { return }
        saveTombstones([])
        #if DEBUG
        print("🪦 [DeduplicationService] Cleared all \(existing.count) tombstone(s)")
        #endif
    }

    /// Return a human-readable list of active tombstones for diagnostics.
    static func tombstoneDescriptions() -> [(name: String, type: String, deletedAt: Date)] {
        loadTombstones().map { ($0.normalizedName, $0.typeRaw ?? "unknown", $0.deletedAt) }
    }

    /// Return the number of active tombstones.
    static var tombstoneCount: Int {
        loadTombstones().count
    }

    /// Temporarily pause zombie deletion while local imports are in progress.
    /// This prevents a race where a freshly inserted import can be deleted
    /// before tombstone-clearing and save complete.
    static func pauseZombieDeletion(for seconds: TimeInterval = 30) {
        let until = Date().addingTimeInterval(max(1, seconds))
        if let existing = zombieDeletionPausedUntil, existing > until {
            return
        }
        zombieDeletionPausedUntil = until
        #if DEBUG
        print("🪦 [DeduplicationService] Zombie deletion paused until \(until)")
        #endif
    }

    /// After a CloudKit import, handle any projects that match an active tombstone.
    ///
    /// SAFETY: Never auto-delete active projects. CloudKit can transiently reintroduce
    /// records during sync churn, and name/key matches can be false-positives.
    /// Only auto-delete already-trashed records that match a tombstone.
    @MainActor
    static func deleteZombieProjects(context: ModelContext) -> Int {
        if let pauseUntil = zombieDeletionPausedUntil, Date() < pauseUntil {
            #if DEBUG
            print("🪦 [DeduplicationService] Skipping zombie delete while pause is active")
            #endif
            return 0
        }

        let tombstones = loadTombstones()
        guard !tombstones.isEmpty else { return 0 }

        let descriptor = FetchDescriptor<Project>()
        guard let allProjects = try? context.fetch(descriptor) else { return 0 }

        var deletedCount = 0
        var skippedActiveCount = 0
        for project in allProjects {
            guard let nameKey = normalizedNameKey(for: project.name) else { continue }
            // Prefer UUID tombstones when available. This is a safe exact match and
            // allows deleting resurrected zombies even if CloudKit marks them active.
            let idMatchedZombie = tombstones.contains { $0.projectID == project.id }
            let legacyNameMatchedZombie = tombstones.contains {
                $0.projectID == nil && $0.normalizedName == nameKey && $0.typeRaw == project.typeRaw
            }
            if idMatchedZombie || legacyNameMatchedZombie {
                // Never auto-delete active projects. CloudKit can transiently
                // resurrect a record during sync, and the tombstone may be stale.
                // Only auto-delete records that are already trashed.
                if !project.isTrashed {
                    skippedActiveCount += 1
                    #if DEBUG
                    print("🪦 [DeduplicationService] ⚠️ Matched tombstone but skipped ACTIVE project '\(project.name ?? "?")' id=\(project.id) [Zombie Safety]")
                    #endif
                    continue
                }
                #if DEBUG
                let matchType = idMatchedZombie ? "id" : "legacy-name"
                print("🪦 [DeduplicationService] 🗑️  DELETING ZOMBIE: '\(project.name ?? "?")' id=\(project.id) (matched tombstone via \(matchType), key='\(nameKey)') [Zombie]")
                #endif
                context.delete(project)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "deduplication-delete-zombies")
            } catch {
                #if DEBUG
                print("❌ [DeduplicationService] Failed zombie project save: \(error)")
                #endif
            }
            #if DEBUG
            print("🪦 [DeduplicationService] Removed \(deletedCount) zombie project(s)")
            #endif
        } else {
            #if DEBUG
            print("🪦 [DeduplicationService] \(tombstones.count) active tombstone(s), no zombies found")
            #endif
        }

        #if DEBUG
        if skippedActiveCount > 0 {
            print("🪦 [DeduplicationService] Skipped \(skippedActiveCount) active tombstone match(es) for safety")
        }
        #endif

        return deletedCount
    }

    private static func loadTombstones() -> [Tombstone] {
        guard let data = UserDefaults.standard.data(forKey: tombstoneDefaultsKey) else { return [] }
        let all = (try? JSONDecoder().decode([Tombstone].self, from: data)) ?? []
        // Prune expired entries on read
        let cutoff = Date().addingTimeInterval(-tombstoneExpiryInterval)
        let valid = all.filter { $0.deletedAt > cutoff }
        if valid.count != all.count {
            saveTombstones(valid)
        }
        return valid
    }

    private static func saveTombstones(_ tombstones: [Tombstone]) {
        guard let data = try? JSONEncoder().encode(tombstones) else { return }
        UserDefaults.standard.set(data, forKey: tombstoneDefaultsKey)
    }

    // MARK: - Non-Destructive Presentation Helpers

    /// Returns a stable, non-destructive view of projects for UI presentation.
    ///
    /// DO NOT use this for actual data decisions. This is UI-ONLY filtering.
    /// Simply removes exact duplicates from display without touching the database.
    /// If you need to decide which project to keep, do that EXPLICITLY through user action.
    static func presentedProjects(from projects: [Project]) -> [Project] {
        guard !projects.isEmpty else { return [] }

        let exactIDGroups = Dictionary(grouping: projects, by: \Project.id)
        let exactIDKeepers = Set(exactIDGroups.map { _, group in preferredProject(in: group).persistentModelID })
        let exactIDCollapsedProjects = projects.filter { exactIDKeepers.contains($0.persistentModelID) }

        // Collapse active rows that have the same normalized name and type. This is
        // presentation-only and never mutates storage. Project-name validation blocks
        // creating same-name/same-type projects, so visible duplicates here are sync
        // clone rows even when recovery changed metadata or relationships are mid-sync.
        // This is a presentation-only filter and never mutates storage.
        let groups = Dictionary(grouping: exactIDCollapsedProjects, by: presentationFamilyKey(for:))
        var keptPersistentIDs = Set<PersistentIdentifier>()

        for (_, group) in groups {
            if group.count == 1, let only = group.first {
                keptPersistentIDs.insert(only.persistentModelID)
                continue
            }

            let keeper = preferredProject(in: group)
            keptPersistentIDs.insert(keeper.persistentModelID)
        }

        // Preserve the incoming order from callers.
        return exactIDCollapsedProjects.filter { keptPersistentIDs.contains($0.persistentModelID) }
    }

    /// Returns whether a proposed name conflicts with ANY project (including hidden/trashed duplicates).
    ///
    /// CRITICAL: Checks ALL projects in the database, not just presented ones.
    /// This prevents users from renaming to a name that another project has,
    /// even if that other project is trashed or hidden as a duplicate.
    /// CloudKit sync can later re-import the hidden project, causing both projects
    /// to have the same name → deduplication deletes the weaker one.
    ///
    /// When `excluding` is supplied, that project is ignored. This allows editing
    /// an existing project without its own name tripping validation.
    static func hasProjectNameConflict(_ proposedName: String, in projects: [Project], excluding excludingProject: Project? = nil) -> Bool {
        guard let proposedKey = normalizedNameKey(for: proposedName) else { return false }

        for project in projects {
            // Skip the project being edited
            if let excluding = excludingProject, project.id == excluding.id {
                continue
            }
            
            // Check if ANY project has this name (including hidden duplicates, trashed, etc.)
            if normalizedNameKey(for: project.name) == proposedKey {
                #if DEBUG
                let existingName = project.name ?? "<nil>"
                print("⚠️  [DeduplicationService] Name conflict detected: proposed '\(proposedName)' matches existing project '\(existingName)' id=\(project.id) isTrashed=\(project.isTrashed)")
                #endif
                return true
            }
        }
        
        return false
    }

    /// Returns the selected project plus obvious CloudKit clone rows that represent
    /// the same logical project. Matching is intentionally conservative: same
    /// normalized name, same type, and identical creation timestamp.
    @MainActor
    static func syncedDuplicateFamily(for project: Project, context: ModelContext) -> [Project] {
        let descriptor = FetchDescriptor<Project>()
        guard let allProjects = try? context.fetch(descriptor) else {
            return [project]
        }

        let family = allProjects.filter { candidate in
            isSameSyncedDuplicateFamily(candidate, as: project)
        }

        return family.isEmpty ? [project] : family
    }

    @MainActor
    static func trashProjectFamily(_ project: Project, context: ModelContext, deletedAt: Date = Date()) {
        for candidate in syncedDuplicateFamily(for: project, context: context) {
            candidate.isTrashed = true
            candidate.deletedDate = deletedAt
            candidate.modifiedDate = deletedAt
        }
    }

    @MainActor
    static func restoreProjectFamily(_ project: Project, context: ModelContext) {
        let restoredAt = Date()
        for candidate in syncedDuplicateFamily(for: project, context: context) {
            candidate.isTrashed = false
            candidate.deletedDate = nil
            candidate.modifiedDate = restoredAt
        }
    }

    @MainActor
    static func permanentlyDeleteProjectFamily(_ project: Project, context: ModelContext) {
        #if DEBUG
        let projectName = project.name ?? "<nil>"
        print("🗑️  PERMANENTLY DELETING PROJECT FAMILY: '\(projectName)' id=\(project.id)")
        #endif
        for candidate in syncedDuplicateFamily(for: project, context: context) {
            // Record a tombstone for each concrete row being deleted so CloudKit
            // re-imports of any family member can be recognized by UUID.
            recordTombstone(for: candidate)
            #if DEBUG
            let candidateName = candidate.name ?? "<nil>"
            print("   ↳ deleting candidate: '\(candidateName)' id=\(candidate.id) [Permanent Delete]")
            #endif
            context.delete(candidate)
        }
    }
    
    // MARK: - Main Entry Point
    
    /// Detect and remove duplicate projects.
    /// Keeps the project with the most content (most folders/files)
    /// and deletes the others.
    ///
    /// - Parameter context: The model context to use
    /// - Returns: A result describing what was removed
    @MainActor
    static func deduplicateProjects(context: ModelContext) -> DeduplicationResult {
        let descriptor = FetchDescriptor<Project>()
        guard let allProjects = try? context.fetch(descriptor) else {
            return DeduplicationResult(duplicatesRemoved: 0, projectsAffected: [], errors: ["Failed to fetch projects"])
        }
        
        #if DEBUG
        print("🔍 [Dedup] Checking \(allProjects.count) projects for duplicates...")
        #endif
        
        // Group projects by name
        let groups = groupedProjects(allProjects)
        
        var totalRemoved = 0
        var affectedNames: [String] = []
        var errors: [String] = []
        
        for (_, projectGroup) in groups where projectGroup.count > 1 {
            let projectName = projectGroup.first?.name ?? "Untitled"
            
            #if DEBUG
            print("🔍 [Dedup] Found \(projectGroup.count) copies of '\(projectName)'")
            #endif
            
            // CRITICAL: Only deduplicate projects that are likely CloudKit clones.
            // CloudKit clones have identical creation dates from the sync operation.
            // If creation dates differ (e.g., renamed project gets same name as old one),
            // they are NOT clones and should NOT be merged.
            let sortedByCreationDate = projectGroup.sorted { a, b in
                (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
            }
            
            // Group by creation date (with 2-second tolerance for sync timing)
            var dateGroups: [[Project]] = []
            var currentGroup: [Project] = []
            var lastDate: Date?
            
            for project in sortedByCreationDate {
                let projDate = project.creationDate ?? .distantPast
                if let last = lastDate, abs(projDate.timeIntervalSince(last)) > 2 {
                    if !currentGroup.isEmpty {
                        dateGroups.append(currentGroup)
                    }
                    currentGroup = [project]
                } else {
                    currentGroup.append(project)
                }
                lastDate = projDate
            }
            if !currentGroup.isEmpty {
                dateGroups.append(currentGroup)
            }
            
            // Only deduplicate within same-creation-date groups
            for dateGroup in dateGroups where dateGroup.count > 1 {
                let sorted = dateGroup.sorted(by: shouldPrefer(_:_:))
                let keeper = sorted[0]
                let duplicates = Array(sorted.dropFirst())
                
                #if DEBUG
                let keeperName = keeper.name ?? "<nil>"
                print("  ↳ Keeping: '\(keeperName)' id=\(keeper.id) isTrashed=\(keeper.isTrashed) created=\(keeper.creationDate?.formatted() ?? "?") score=\(contentScore(for: keeper))")
                #endif
                
                for duplicate in duplicates {
                    #if DEBUG
                    let duplicateName = duplicate.name ?? "<nil>"
                    print("  🗑️  DELETING DUPLICATE: '\(duplicateName)' id=\(duplicate.id) isTrashed=\(duplicate.isTrashed) created=\(duplicate.creationDate?.formatted() ?? "?") score=\(contentScore(for: duplicate)) [CloudKit Clone]")
                    #endif
                    context.delete(duplicate)
                    totalRemoved += 1
                }
                
                affectedNames.append(projectName)
            }
        }
        
        if totalRemoved > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "deduplication-remove-duplicates")
                #if DEBUG
                print("✅ [Dedup] Removed \(totalRemoved) duplicate project(s) across \(affectedNames.count) name(s)")
                #endif
            } catch {
                let msg = "Failed to save after deduplication: \(error.localizedDescription)"
                errors.append(msg)
                #if DEBUG
                print("❌ [Dedup] \(msg)")
                #endif
            }
        } else {
            #if DEBUG
            print("✅ [Dedup] No duplicate projects found")
            #endif
        }
        
        return DeduplicationResult(
            duplicatesRemoved: totalRemoved,
            projectsAffected: affectedNames,
            errors: errors
        )
    }

    @MainActor
    static func cleanupExactIDDuplicates(context: ModelContext) -> ExactDuplicateCleanupResult {
        guard EnsemblesSaveGate.canSaveNow(reason: "deduplication-exact-id") else {
            return ExactDuplicateCleanupResult(recordsRemoved: 0, groupsAffected: 0, errors: ["Skipped exact-ID duplicate cleanup because Ensembles is not idle"])
        }

        var totalRemoved = 0
        var totalGroups = 0
        var errors: [String] = []

        func cleanup<T: PersistentModel>(
            _ type: T.Type,
            label: String,
            id: (T) -> UUID,
            shouldPrefer: (T, T) -> Bool
        ) {
            let descriptor = FetchDescriptor<T>()
            guard let records = try? context.fetch(descriptor) else {
                errors.append("Failed to fetch \(label)")
                return
            }

            let groups = Dictionary(grouping: records, by: id)
            for (recordID, group) in groups where group.count > 1 {
                let sorted = group.sorted(by: shouldPrefer)
                let keeper = sorted[0]
                let duplicates = Array(sorted.dropFirst())
                totalGroups += 1

                #if DEBUG
                print("🧹 [Dedup] Exact-ID duplicate \(label) id=\(recordID) count=\(group.count), deleting \(duplicates.count), keeping \(keeper.persistentModelID)")
                #endif

                for duplicate in duplicates {
                    context.delete(duplicate)
                    totalRemoved += 1
                }
            }
        }

        cleanup(Project.self, label: "Project", id: { $0.id }, shouldPrefer: shouldPrefer(_:_:))
        cleanup(Folder.self, label: "Folder", id: { $0.id }, shouldPrefer: shouldPreferFolder(_:_:))
        cleanup(TextFile.self, label: "TextFile", id: { $0.id }, shouldPrefer: shouldPreferTextFile(_:_:))
        cleanup(Version.self, label: "Version", id: { $0.id }, shouldPrefer: shouldPreferVersion(_:_:))
        cleanup(Publication.self, label: "Publication", id: { $0.id }, shouldPrefer: shouldPreferPublication(_:_:))
        cleanup(Submission.self, label: "Submission", id: { $0.id }, shouldPrefer: shouldPreferSubmission(_:_:))
        cleanup(SubmittedFile.self, label: "SubmittedFile", id: { $0.id }, shouldPrefer: shouldPreferSubmittedFile(_:_:))
        cleanup(PoetryCollection.self, label: "PoetryCollection", id: { $0.id }, shouldPrefer: shouldPreferPoetryCollection(_:_:))
        cleanup(Book.self, label: "Book", id: { $0.id }, shouldPrefer: shouldPreferBook(_:_:))
        cleanup(StoryScene.self, label: "StoryScene", id: { $0.id }, shouldPrefer: shouldPreferStoryScene(_:_:))
        cleanup(Chapter.self, label: "Chapter", id: { $0.id }, shouldPrefer: shouldPreferChapter(_:_:))
        cleanup(Act.self, label: "Act", id: { $0.id }, shouldPrefer: shouldPreferAct(_:_:))
        cleanup(ProseSection.self, label: "ProseSection", id: { $0.id }, shouldPrefer: shouldPreferProseSection(_:_:))
        cleanup(Character.self, label: "Character", id: { $0.id }, shouldPrefer: shouldPreferCharacter(_:_:))
        cleanup(Location.self, label: "Location", id: { $0.id }, shouldPrefer: shouldPreferLocation(_:_:))
        cleanup(PlotElement.self, label: "PlotElement", id: { $0.id }, shouldPrefer: shouldPreferPlotElement(_:_:))
        cleanup(StyleSheet.self, label: "StyleSheet", id: { $0.id }, shouldPrefer: shouldPreferStyleSheet(_:_:))
        cleanup(TextStyleModel.self, label: "TextStyleModel", id: { $0.id }, shouldPrefer: shouldPreferTextStyle(_:_:))
        cleanup(ImageStyle.self, label: "ImageStyle", id: { $0.id }, shouldPrefer: shouldPreferImageStyle(_:_:))
        cleanup(PoetryFormModel.self, label: "PoetryFormModel", id: { $0.id }, shouldPrefer: shouldPreferPoetryForm(_:_:))
        cleanup(PageSetup.self, label: "PageSetup", id: { $0.id }, shouldPrefer: shouldPreferPageSetup(_:_:))
        cleanup(TextFileSectionLink.self, label: "TextFileSectionLink", id: { $0.id }, shouldPrefer: shouldPreferTextFileSectionLink(_:_:))
        cleanup(TextFileCollectionLink.self, label: "TextFileCollectionLink", id: { $0.id }, shouldPrefer: shouldPreferTextFileCollectionLink(_:_:))
        cleanup(SceneChapterLink.self, label: "SceneChapterLink", id: { $0.id }, shouldPrefer: shouldPreferSceneChapterLink(_:_:))
        cleanup(SceneActLink.self, label: "SceneActLink", id: { $0.id }, shouldPrefer: shouldPreferSceneActLink(_:_:))
        cleanup(SceneBookLink.self, label: "SceneBookLink", id: { $0.id }, shouldPrefer: shouldPreferSceneBookLink(_:_:))
        cleanup(ScenePlotElementLink.self, label: "ScenePlotElementLink", id: { $0.id }, shouldPrefer: shouldPreferScenePlotElementLink(_:_:))
        cleanup(SceneCharacterLink.self, label: "SceneCharacterLink", id: { $0.id }, shouldPrefer: shouldPreferSceneCharacterLink(_:_:))
        cleanup(SceneLocationLink.self, label: "SceneLocationLink", id: { $0.id }, shouldPrefer: shouldPreferSceneLocationLink(_:_:))
        cleanup(CharacterPlotElementLink.self, label: "CharacterPlotElementLink", id: { $0.id }, shouldPrefer: shouldPreferCharacterPlotElementLink(_:_:))
        cleanup(LocationPlotElementLink.self, label: "LocationPlotElementLink", id: { $0.id }, shouldPrefer: shouldPreferLocationPlotElementLink(_:_:))

        if totalRemoved > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "deduplication-exact-id")
                #if DEBUG
                print("✅ [Dedup] Removed \(totalRemoved) exact-ID duplicate record(s) across \(totalGroups) group(s)")
                #endif
            } catch {
                errors.append("Failed to save exact-ID duplicate cleanup: \(error.localizedDescription)")
                #if DEBUG
                print("❌ [Dedup] Failed exact-ID duplicate cleanup save: \(error)")
                #endif
            }
        }

        return ExactDuplicateCleanupResult(recordsRemoved: totalRemoved, groupsAffected: totalGroups, errors: errors)
    }

    @MainActor
    static func countExactIDDuplicateRecords(context: ModelContext) -> Int {
        var duplicateCount = 0

        func count<T: PersistentModel>(_ type: T.Type, id: (T) -> UUID) {
            let descriptor = FetchDescriptor<T>()
            guard let records = try? context.fetch(descriptor) else { return }
            let groups = Dictionary(grouping: records, by: id)
            duplicateCount += groups.values.reduce(0) { $0 + max(0, $1.count - 1) }
        }

        count(Project.self) { $0.id }
        count(Folder.self) { $0.id }
        count(TextFile.self) { $0.id }
        count(Version.self) { $0.id }
        count(Publication.self) { $0.id }
        count(Submission.self) { $0.id }
        count(SubmittedFile.self) { $0.id }
        count(PoetryCollection.self) { $0.id }
        count(Book.self) { $0.id }
        count(StoryScene.self) { $0.id }
        count(Chapter.self) { $0.id }
        count(Act.self) { $0.id }
        count(ProseSection.self) { $0.id }
        count(Character.self) { $0.id }
        count(Location.self) { $0.id }
        count(PlotElement.self) { $0.id }
        count(StyleSheet.self) { $0.id }
        count(TextStyleModel.self) { $0.id }
        count(ImageStyle.self) { $0.id }
        count(PoetryFormModel.self) { $0.id }
        count(PageSetup.self) { $0.id }
        count(TextFileSectionLink.self) { $0.id }
        count(TextFileCollectionLink.self) { $0.id }
        count(SceneChapterLink.self) { $0.id }
        count(SceneActLink.self) { $0.id }
        count(SceneBookLink.self) { $0.id }
        count(ScenePlotElementLink.self) { $0.id }
        count(SceneCharacterLink.self) { $0.id }
        count(SceneLocationLink.self) { $0.id }
        count(CharacterPlotElementLink.self) { $0.id }
        count(LocationPlotElementLink.self) { $0.id }

        return duplicateCount
    }

    @MainActor
    static func exactIDDuplicateSummaryLines(context: ModelContext) -> [String] {
        var lines: [String] = []

        func summarize<T: PersistentModel>(_ type: T.Type, label: String, id: (T) -> UUID) {
            let descriptor = FetchDescriptor<T>()
            guard let records = try? context.fetch(descriptor) else { return }
            let groups = Dictionary(grouping: records, by: id).filter { $0.value.count > 1 }
            guard !groups.isEmpty else { return }

            let duplicateRecords = groups.values.reduce(0) { $0 + max(0, $1.count - 1) }
            lines.append("- \(label): duplicateRecords=\(duplicateRecords) groups=\(groups.count)")
        }

        summarize(Project.self, label: "Project") { $0.id }
        summarize(Folder.self, label: "Folder") { $0.id }
        summarize(TextFile.self, label: "TextFile") { $0.id }
        summarize(Version.self, label: "Version") { $0.id }
        summarize(Publication.self, label: "Publication") { $0.id }
        summarize(Submission.self, label: "Submission") { $0.id }
        summarize(SubmittedFile.self, label: "SubmittedFile") { $0.id }
        summarize(PoetryCollection.self, label: "PoetryCollection") { $0.id }
        summarize(Book.self, label: "Book") { $0.id }
        summarize(StoryScene.self, label: "StoryScene") { $0.id }
        summarize(Chapter.self, label: "Chapter") { $0.id }
        summarize(Act.self, label: "Act") { $0.id }
        summarize(ProseSection.self, label: "ProseSection") { $0.id }
        summarize(Character.self, label: "Character") { $0.id }
        summarize(Location.self, label: "Location") { $0.id }
        summarize(PlotElement.self, label: "PlotElement") { $0.id }
        summarize(StyleSheet.self, label: "StyleSheet") { $0.id }
        summarize(TextStyleModel.self, label: "TextStyleModel") { $0.id }
        summarize(ImageStyle.self, label: "ImageStyle") { $0.id }
        summarize(PoetryFormModel.self, label: "PoetryFormModel") { $0.id }
        summarize(PageSetup.self, label: "PageSetup") { $0.id }
        summarize(TextFileSectionLink.self, label: "TextFileSectionLink") { $0.id }
        summarize(TextFileCollectionLink.self, label: "TextFileCollectionLink") { $0.id }
        summarize(SceneChapterLink.self, label: "SceneChapterLink") { $0.id }
        summarize(SceneActLink.self, label: "SceneActLink") { $0.id }
        summarize(SceneBookLink.self, label: "SceneBookLink") { $0.id }
        summarize(ScenePlotElementLink.self, label: "ScenePlotElementLink") { $0.id }
        summarize(SceneCharacterLink.self, label: "SceneCharacterLink") { $0.id }
        summarize(SceneLocationLink.self, label: "SceneLocationLink") { $0.id }
        summarize(CharacterPlotElementLink.self, label: "CharacterPlotElementLink") { $0.id }
        summarize(LocationPlotElementLink.self, label: "LocationPlotElementLink") { $0.id }

        return lines
    }

    @MainActor
    static func cleanupDuplicateTemplateFolders(context: ModelContext) -> TemplateFolderCleanupResult {
        guard EnsemblesSaveGate.canSaveNow(reason: "deduplication-template-folders") else {
            return TemplateFolderCleanupResult(recordsRemoved: 0, groupsAffected: 0, skippedNonEmptyGroups: 0, errors: ["Skipped template folder cleanup because Ensembles is not idle"])
        }

        let descriptor = FetchDescriptor<Folder>()
        guard let folders = try? context.fetch(descriptor) else {
            return TemplateFolderCleanupResult(recordsRemoved: 0, groupsAffected: 0, skippedNonEmptyGroups: 0, errors: ["Failed to fetch folders"])
        }

        var recordsRemoved = 0
        var groupsAffected = 0
        var skippedNonEmptyGroups = 0
        var errors: [String] = []

        let groups = Dictionary(grouping: folders.compactMap(templateFolderEntry(for:)), by: \.key)
        for (_, entries) in groups where entries.count > 1 {
            let sorted = entries.sorted { shouldPreferTemplateFolder($0.folder, $1.folder) }
            let keeper = sorted[0].folder
            let duplicates = sorted.dropFirst().map(\.folder)
            let deletableDuplicates = duplicates.filter(isEmptyTemplateFolder(_:))

            guard deletableDuplicates.count == duplicates.count else {
                skippedNonEmptyGroups += 1
                continue
            }

            groupsAffected += 1
            #if DEBUG
            print("🧹 [Dedup] Duplicate template folder name=\(keeper.name ?? "?") count=\(entries.count), deleting \(deletableDuplicates.count), keeping \(keeper.persistentModelID)")
            #endif

            for duplicate in deletableDuplicates {
                context.delete(duplicate)
                recordsRemoved += 1
            }
        }

        if recordsRemoved > 0 {
            do {
                try EnsemblesSaveGate.save(context, reason: "deduplication-template-folders")
            } catch {
                errors.append("Failed to save template folder cleanup: \(error.localizedDescription)")
            }
        }

        return TemplateFolderCleanupResult(recordsRemoved: recordsRemoved, groupsAffected: groupsAffected, skippedNonEmptyGroups: skippedNonEmptyGroups, errors: errors)
    }

    @MainActor
    static func countDuplicateTemplateFolderRecords(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Folder>()
        guard let folders = try? context.fetch(descriptor) else { return 0 }
        let groups = Dictionary(grouping: folders.compactMap(templateFolderEntry(for:)), by: \.key)
        return groups.values.reduce(0) { $0 + max(0, $1.count - 1) }
    }

    private struct TemplateFolderEntry {
        let key: String
        let folder: Folder
    }

    private static func templateFolderEntry(for folder: Folder) -> TemplateFolderEntry? {
        guard let name = folder.name, FolderCapabilityService.isTemplateFolder(name) else { return nil }

        if let parentID = folder.parentFolder?.id {
            return TemplateFolderEntry(key: "parent:\(parentID.uuidString)|\(name)", folder: folder)
        }

        if let projectID = folder.project?.id {
            return TemplateFolderEntry(key: "project:\(projectID.uuidString)|root|\(name)", folder: folder)
        }

        return nil
    }

    private static func isEmptyTemplateFolder(_ folder: Folder) -> Bool {
        (folder.textFiles?.isEmpty ?? true) && (folder.folders?.isEmpty ?? true)
    }

    private static func shouldPreferTemplateFolder(_ lhs: Folder, _ rhs: Folder) -> Bool {
        let lhsScore = (lhs.textFiles?.count ?? 0) + (lhs.folders?.count ?? 0)
        let rhsScore = (rhs.textFiles?.count ?? 0) + (rhs.folders?.count ?? 0)
        if lhsScore != rhsScore { return lhsScore > rhsScore }

        let lhsOrder = lhs.userOrder ?? Int.max
        let rhsOrder = rhs.userOrder ?? Int.max
        if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }

        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }
    
    /// Check if duplicates exist without removing them
    @MainActor
    static func countDuplicateProjects(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Project>()
        guard let allProjects = try? context.fetch(descriptor) else { return 0 }

        let groups = groupedProjects(allProjects).mapValues(\.count)
        
        // Count total excess copies (groups with count > 1)
        return groups.values.reduce(0) { $0 + max(0, $1 - 1) }
    }
    
    // MARK: - Duplicate Detection for UI

    /// Returns the set of project IDs that belong to a duplicate group
    /// (i.e., share a normalized name with at least one other project).
    static func duplicateProjectIDs(in projects: [Project]) -> Set<UUID> {
        let groups = groupedProjects(projects)
        var ids = Set<UUID>()
        for (_, group) in groups where group.count > 1 {
            for project in group {
                ids.insert(project.id)
            }
        }
        return ids
    }

    // MARK: - Scoring

    private static func groupedProjects(_ projects: [Project]) -> [String: [Project]] {
        var groups: [String: [Project]] = [:]
        for project in projects {
            groups[groupKey(for: project), default: []].append(project)
        }
        return groups
    }

    private static func groupKey(for project: Project) -> String {
        normalizedNameKey(for: project.name) ?? "__project_id__:\(project.id.uuidString)"
    }

    private static func presentationFamilyKey(for project: Project) -> String {
        guard let nameKey = normalizedNameKey(for: project.name) else {
            return "__project_id__:\(project.id.uuidString)"
        }

        let typeKey = project.typeRaw ?? ""
        return "\(nameKey)|\(typeKey)"
    }

    private static func normalizedNameKey(for name: String?) -> String? {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func preferredProject(in projects: [Project]) -> Project {
        projects.sorted(by: shouldPrefer(_:_:)).first ?? projects[0]
    }

    private static func shouldPrefer(_ lhs: Project, _ rhs: Project) -> Bool {
        if lhs.isTrashed != rhs.isTrashed {
            return !lhs.isTrashed
        }

        let lhsScore = contentScore(for: lhs)
        let rhsScore = contentScore(for: rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }

        let lhsMetadata = metadataScore(for: lhs)
        let rhsMetadata = metadataScore(for: rhs)
        if lhsMetadata != rhsMetadata {
            return lhsMetadata > rhsMetadata
        }

        let lhsModified = lhs.modifiedDate ?? lhs.creationDate ?? .distantPast
        let rhsModified = rhs.modifiedDate ?? rhs.creationDate ?? .distantPast
        if lhsModified != rhsModified {
            return lhsModified > rhsModified
        }

        let lhsCreated = lhs.creationDate ?? .distantPast
        let rhsCreated = rhs.creationDate ?? .distantPast
        if lhsCreated != rhsCreated {
            return lhsCreated < rhsCreated
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func shouldPreferStyleSheet(_ lhs: StyleSheet, _ rhs: StyleSheet) -> Bool {
        let lhsRelationshipScore = (lhs.projects?.count ?? 0) + (lhs.textStyles?.count ?? 0) + (lhs.imageStyles?.count ?? 0)
        let rhsRelationshipScore = (rhs.projects?.count ?? 0) + (rhs.textStyles?.count ?? 0) + (rhs.imageStyles?.count ?? 0)
        if lhsRelationshipScore != rhsRelationshipScore {
            return lhsRelationshipScore > rhsRelationshipScore
        }

        if lhs.modifiedDate != rhs.modifiedDate {
            return lhs.modifiedDate > rhs.modifiedDate
        }

        if lhs.createdDate != rhs.createdDate {
            return lhs.createdDate < rhs.createdDate
        }

        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferFolder(_ lhs: Folder, _ rhs: Folder) -> Bool {
        let lhsScore = (lhs.folders?.count ?? 0) + (lhs.textFiles?.count ?? 0) + (lhs.project == nil ? 0 : 1) + (lhs.parentFolder == nil ? 0 : 1)
        let rhsScore = (rhs.folders?.count ?? 0) + (rhs.textFiles?.count ?? 0) + (rhs.project == nil ? 0 : 1) + (rhs.parentFolder == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferTextFile(_ lhs: TextFile, _ rhs: TextFile) -> Bool {
        let lhsScore = (lhs.versions?.count ?? 0) + (lhs.submittedFiles?.count ?? 0) + (lhs.sectionLinks?.count ?? 0) + (lhs.poetryCollectionLinks?.count ?? 0) + (lhs.parentFolder == nil ? 0 : 1) + (lhs.scene == nil ? 0 : 1)
        let rhsScore = (rhs.versions?.count ?? 0) + (rhs.submittedFiles?.count ?? 0) + (rhs.sectionLinks?.count ?? 0) + (rhs.poetryCollectionLinks?.count ?? 0) + (rhs.parentFolder == nil ? 0 : 1) + (rhs.scene == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferVersion(_ lhs: Version, _ rhs: Version) -> Bool {
        let lhsScore = (lhs.comments?.count ?? 0) + (lhs.footnotes?.count ?? 0) + (lhs.submittedFiles?.count ?? 0) + (lhs.textFile == nil ? 0 : 1)
        let rhsScore = (rhs.comments?.count ?? 0) + (rhs.footnotes?.count ?? 0) + (rhs.submittedFiles?.count ?? 0) + (rhs.textFile == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferPublication(_ lhs: Publication, _ rhs: Publication) -> Bool {
        let lhsScore = (lhs.submissions?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.submissions?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferSubmission(_ lhs: Submission, _ rhs: Submission) -> Bool {
        let lhsScore = (lhs.submittedFiles?.count ?? 0) + (lhs.publication == nil ? 0 : 1) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.submittedFiles?.count ?? 0) + (rhs.publication == nil ? 0 : 1) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferSubmittedFile(_ lhs: SubmittedFile, _ rhs: SubmittedFile) -> Bool {
        let lhsScore = (lhs.submission == nil ? 0 : 1) + (lhs.textFile == nil ? 0 : 1) + (lhs.version == nil ? 0 : 1) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.submission == nil ? 0 : 1) + (rhs.textFile == nil ? 0 : 1) + (rhs.version == nil ? 0 : 1) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferPoetryCollection(_ lhs: PoetryCollection, _ rhs: PoetryCollection) -> Bool {
        let lhsScore = (lhs.textFileLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.textFileLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferBook(_ lhs: Book, _ rhs: Book) -> Bool {
        let lhsScore = (lhs.sceneLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.sceneLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferStoryScene(_ lhs: StoryScene, _ rhs: StoryScene) -> Bool {
        let lhsScore = relationshipScore(for: lhs)
        let rhsScore = relationshipScore(for: rhs)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func relationshipScore(for scene: StoryScene) -> Int {
        var score = 0
        if scene.textFile != nil { score += 1 }
        if scene.project != nil { score += 1 }
        score += scene.chapterLinks?.count ?? 0
        score += scene.actLinks?.count ?? 0
        score += scene.bookLinks?.count ?? 0
        score += scene.plotElementLinks?.count ?? 0
        score += scene.characterLinks?.count ?? 0
        score += scene.locationLinks?.count ?? 0
        return score
    }

    private static func shouldPreferChapter(_ lhs: Chapter, _ rhs: Chapter) -> Bool {
        let lhsScore = (lhs.sceneLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.sceneLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferAct(_ lhs: Act, _ rhs: Act) -> Bool {
        let lhsScore = (lhs.sceneLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.sceneLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferProseSection(_ lhs: ProseSection, _ rhs: ProseSection) -> Bool {
        let lhsScore = (lhs.textFileLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.textFileLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferCharacter(_ lhs: Character, _ rhs: Character) -> Bool {
        let lhsScore = (lhs.sceneLinks?.count ?? 0) + (lhs.plotElementLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.sceneLinks?.count ?? 0) + (rhs.plotElementLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferLocation(_ lhs: Location, _ rhs: Location) -> Bool {
        let lhsScore = (lhs.sceneLinks?.count ?? 0) + (lhs.plotElementLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.sceneLinks?.count ?? 0) + (rhs.plotElementLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferPlotElement(_ lhs: PlotElement, _ rhs: PlotElement) -> Bool {
        let lhsScore = (lhs.sceneLinks?.count ?? 0) + (lhs.characterLinks?.count ?? 0) + (lhs.locationLinks?.count ?? 0) + (lhs.project == nil ? 0 : 1)
        let rhsScore = (rhs.sceneLinks?.count ?? 0) + (rhs.characterLinks?.count ?? 0) + (rhs.locationLinks?.count ?? 0) + (rhs.project == nil ? 0 : 1)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferTextStyle(_ lhs: TextStyleModel, _ rhs: TextStyleModel) -> Bool {
        let lhsScore = lhs.styleSheet == nil ? 0 : 1
        let rhsScore = rhs.styleSheet == nil ? 0 : 1
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferImageStyle(_ lhs: ImageStyle, _ rhs: ImageStyle) -> Bool {
        let lhsScore = lhs.styleSheet == nil ? 0 : 1
        let rhsScore = rhs.styleSheet == nil ? 0 : 1
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate > rhs.modifiedDate }
        if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferPageSetup(_ lhs: PageSetup, _ rhs: PageSetup) -> Bool {
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferTextFileSectionLink(_ lhs: TextFileSectionLink, _ rhs: TextFileSectionLink) -> Bool {
        let lhsScore = (lhs.textFile == nil ? 0 : 1) + (lhs.section == nil ? 0 : 1)
        let rhsScore = (rhs.textFile == nil ? 0 : 1) + (rhs.section == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferTextFileCollectionLink(_ lhs: TextFileCollectionLink, _ rhs: TextFileCollectionLink) -> Bool {
        let lhsScore = (lhs.textFile == nil ? 0 : 1) + (lhs.poetryCollection == nil ? 0 : 1)
        let rhsScore = (rhs.textFile == nil ? 0 : 1) + (rhs.poetryCollection == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferSceneChapterLink(_ lhs: SceneChapterLink, _ rhs: SceneChapterLink) -> Bool {
        let lhsScore = (lhs.scene == nil ? 0 : 1) + (lhs.chapter == nil ? 0 : 1)
        let rhsScore = (rhs.scene == nil ? 0 : 1) + (rhs.chapter == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferSceneActLink(_ lhs: SceneActLink, _ rhs: SceneActLink) -> Bool {
        let lhsScore = (lhs.scene == nil ? 0 : 1) + (lhs.act == nil ? 0 : 1)
        let rhsScore = (rhs.scene == nil ? 0 : 1) + (rhs.act == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferSceneBookLink(_ lhs: SceneBookLink, _ rhs: SceneBookLink) -> Bool {
        let lhsScore = (lhs.scene == nil ? 0 : 1) + (lhs.book == nil ? 0 : 1)
        let rhsScore = (rhs.scene == nil ? 0 : 1) + (rhs.book == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferScenePlotElementLink(_ lhs: ScenePlotElementLink, _ rhs: ScenePlotElementLink) -> Bool {
        let lhsScore = (lhs.scene == nil ? 0 : 1) + (lhs.plotElement == nil ? 0 : 1)
        let rhsScore = (rhs.scene == nil ? 0 : 1) + (rhs.plotElement == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferSceneCharacterLink(_ lhs: SceneCharacterLink, _ rhs: SceneCharacterLink) -> Bool {
        let lhsScore = (lhs.scene == nil ? 0 : 1) + (lhs.character == nil ? 0 : 1)
        let rhsScore = (rhs.scene == nil ? 0 : 1) + (rhs.character == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferSceneLocationLink(_ lhs: SceneLocationLink, _ rhs: SceneLocationLink) -> Bool {
        let lhsScore = (lhs.scene == nil ? 0 : 1) + (lhs.location == nil ? 0 : 1)
        let rhsScore = (rhs.scene == nil ? 0 : 1) + (rhs.location == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferCharacterPlotElementLink(_ lhs: CharacterPlotElementLink, _ rhs: CharacterPlotElementLink) -> Bool {
        let lhsScore = (lhs.character == nil ? 0 : 1) + (lhs.plotElement == nil ? 0 : 1)
        let rhsScore = (rhs.character == nil ? 0 : 1) + (rhs.plotElement == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func shouldPreferLocationPlotElementLink(_ lhs: LocationPlotElementLink, _ rhs: LocationPlotElementLink) -> Bool {
        let lhsScore = (lhs.location == nil ? 0 : 1) + (lhs.plotElement == nil ? 0 : 1)
        let rhsScore = (rhs.location == nil ? 0 : 1) + (rhs.plotElement == nil ? 0 : 1)
        return preferByScore(lhs, rhs, lhsScore: lhsScore, rhsScore: rhsScore)
    }

    private static func preferByScore<T: PersistentModel>(_ lhs: T, _ rhs: T, lhsScore: Int, rhsScore: Int) -> Bool {
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func shouldPreferPoetryForm(_ lhs: PoetryFormModel, _ rhs: PoetryFormModel) -> Bool {
        if lhs.isCustom != rhs.isCustom {
            return lhs.isCustom
        }

        if lhs.modifiedDate != rhs.modifiedDate {
            return lhs.modifiedDate > rhs.modifiedDate
        }

        if lhs.createdDate != rhs.createdDate {
            return lhs.createdDate < rhs.createdDate
        }

        return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
    }

    private static func metadataScore(for project: Project) -> Int {
        var score = 0
        if let details = project.details, !details.isEmpty { score += 1 }
        if let notes = project.notes, !notes.isEmpty { score += 1 }
        if let author = project.author, !author.isEmpty { score += 1 }
        if project.styleSheet != nil { score += 1 }
        if project.pageSetup != nil { score += 1 }
        return score
    }

    private static func isSameSyncedDuplicateFamily(_ lhs: Project, as rhs: Project) -> Bool {
        guard lhs.type == rhs.type else { return false }
        guard normalizedNameKey(for: lhs.name) == normalizedNameKey(for: rhs.name) else { return false }

        switch (lhs.creationDate, rhs.creationDate) {
        case let (.some(lhsDate), .some(rhsDate)):
            return lhsDate == rhsDate
        case (.none, .none):
            return lhs.id == rhs.id
        default:
            return lhs.id == rhs.id
        }
    }
    
    /// Score a project by how much content it has.
    /// Higher score = more content = better candidate to keep.
    private static func contentScore(for project: Project) -> Int {
        var score = 0
        
        // Count root folders
        let folders = project.folders ?? []
        score += folders.count * 10
        
        // Count all text files across folders
        for folder in folders {
            score += countFilesRecursive(folder)
        }
        
        // Count scenes, chapters, etc.
        score += (project.scenes?.count ?? 0) * 5
        score += (project.chapters?.count ?? 0) * 5
        score += (project.acts?.count ?? 0) * 5
        score += (project.sections?.count ?? 0) * 5
        score += (project.poetryCollections?.count ?? 0) * 5
        score += (project.publications?.count ?? 0) * 3
        score += (project.submissions?.count ?? 0) * 3
        
        return score
    }
    
    /// Recursively count text files in a folder tree
    private static func countFilesRecursive(_ folder: Folder) -> Int {
        var count = folder.textFiles?.count ?? 0
        for subfolder in folder.folders ?? [] {
            count += countFilesRecursive(subfolder)
        }
        return count
    }
}
