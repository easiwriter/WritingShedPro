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

    // MARK: - Tombstone System
    //
    // When a project is permanently deleted, we record a "tombstone" in UserDefaults
    // so that if CloudKit re-imports the record (zombie), we can detect and re-delete it.
    // Tombstones expire after 90 days to avoid unbounded growth.

    private static let tombstoneDefaultsKey = "WSP_DeletedProjectTombstones"
    private static let tombstoneExpiryInterval: TimeInterval = 90 * 24 * 3600 // 90 days

    /// A lightweight record of a permanently deleted project.
    private struct Tombstone: Codable {
        let normalizedName: String
        let typeRaw: String?
        let deletedAt: Date
    }

    /// Record that a project has been permanently deleted.
    /// Called before `context.delete()` so we still have access to the project's properties.
    static func recordTombstone(for project: Project) {
        guard let key = normalizedNameKey(for: project.name) else { return }
        var tombstones = loadTombstones()
        // Avoid duplicating an existing tombstone for the same name+type
        tombstones.removeAll { $0.normalizedName == key && $0.typeRaw == project.typeRaw }
        tombstones.append(Tombstone(normalizedName: key, typeRaw: project.typeRaw, deletedAt: Date()))
        saveTombstones(tombstones)
        #if DEBUG
        print("🪦 [DeduplicationService] Recorded tombstone for '\(project.name ?? "?")' (type=\(project.typeRaw ?? "nil"))")
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

    /// After a CloudKit import, delete any projects that match an active tombstone.
    /// This prevents "zombie" records from reappearing after permanent deletion.
    @MainActor
    static func deleteZombieProjects(context: ModelContext) -> Int {
        let tombstones = loadTombstones()
        guard !tombstones.isEmpty else { return 0 }

        #if DEBUG
        print("🪦 [DeduplicationService] Active tombstones (\(tombstones.count)):")
        for t in tombstones {
            print("   - '\(t.normalizedName)' type=\(t.typeRaw ?? "nil") deleted=\(t.deletedAt)")
        }
        #endif

        let descriptor = FetchDescriptor<Project>()
        guard let allProjects = try? context.fetch(descriptor) else { return 0 }

        var deletedCount = 0
        for project in allProjects {
            guard let nameKey = normalizedNameKey(for: project.name) else { continue }
            let isZombie = tombstones.contains {
                $0.normalizedName == nameKey && $0.typeRaw == project.typeRaw
            }
            if isZombie {
                #if DEBUG
                print("🪦 [DeduplicationService] Deleting zombie project '\(project.name ?? "?")' id=\(project.id) (matched tombstone for '\(nameKey)')")
                #endif
                context.delete(project)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? context.save()
            #if DEBUG
            print("🪦 [DeduplicationService] Removed \(deletedCount) zombie project(s)")
            #endif
        }

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
    /// CloudKit can transiently leave duplicate `Project` records in the local store.
    /// We do not want to delete records automatically during sync churn, but we also
    /// do not want duplicate rows in the UI. This helper groups by normalized project
    /// name and keeps the strongest candidate for presentation.
    static func presentedProjects(from projects: [Project]) -> [Project] {
        let canonicalByKey = Dictionary(
            uniqueKeysWithValues: groupedProjects(projects).map { key, group in
                (key, preferredProject(in: group))
            }
        )

        var emittedKeys = Set<String>()
        var visibleProjects: [Project] = []

        for project in projects {
            let key = groupKey(for: project)
            guard !emittedKeys.contains(key) else { continue }
            guard let canonical = canonicalByKey[key], canonical.id == project.id else { continue }
            emittedKeys.insert(key)
            visibleProjects.append(project)
        }

        return visibleProjects
    }

    /// Returns whether a proposed name conflicts with any visible/canonical project.
    ///
    /// When `excluding` is supplied, all duplicates that belong to the same normalized
    /// name group as that project are ignored. This allows editing an existing project
    /// without a hidden duplicate record falsely tripping validation.
    static func hasProjectNameConflict(_ proposedName: String, in projects: [Project], excluding excludingProject: Project? = nil) -> Bool {
        guard let proposedKey = normalizedNameKey(for: proposedName) else { return false }

        let excludedGroupKey = excludingProject.map(groupKey(for:))

        return presentedProjects(from: projects).contains { candidate in
            let candidateKey = groupKey(for: candidate)
            guard candidateKey != excludedGroupKey else { return false }
            return normalizedNameKey(for: candidate.name) == proposedKey
        }
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
        }
    }

    @MainActor
    static func restoreProjectFamily(_ project: Project, context: ModelContext) {
        for candidate in syncedDuplicateFamily(for: project, context: context) {
            candidate.isTrashed = false
            candidate.deletedDate = nil
        }
    }

    @MainActor
    static func permanentlyDeleteProjectFamily(_ project: Project, context: ModelContext) {
        // Record tombstone BEFORE deleting so we can catch CloudKit zombies
        recordTombstone(for: project)
        for candidate in syncedDuplicateFamily(for: project, context: context) {
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
        
        // Group projects by name — duplicates from CloudKit sync may have
        // different creation dates (one from original, one from re-import)
        // so name-only matching is the safest approach.
        let groups = groupedProjects(allProjects)
        
        var totalRemoved = 0
        var affectedNames: [String] = []
        var errors: [String] = []
        
        for (_, projectGroup) in groups where projectGroup.count > 1 {
            let projectName = projectGroup.first?.name ?? "Untitled"
            
            #if DEBUG
            print("🔍 [Dedup] Found \(projectGroup.count) copies of '\(projectName)'")
            #endif
            
            // Pick the "best" copy to keep — the one with the most content
            let sorted = projectGroup.sorted(by: shouldPrefer(_:_:))
            
            let keeper = sorted[0]
            let duplicates = Array(sorted.dropFirst())
            
            #if DEBUG
            print("  ↳ Keeping PK with score \(contentScore(for: keeper)), removing \(duplicates.count) duplicate(s)")
            #endif
            
            for duplicate in duplicates {
                // SwiftData cascade delete rules will handle child objects
                // (Folders, TextFiles, Versions, etc.)
                context.delete(duplicate)
                totalRemoved += 1
            }
            
            affectedNames.append(projectName)
        }
        
        if totalRemoved > 0 {
            do {
                try context.save()
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
