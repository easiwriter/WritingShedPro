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
        var groups: [String: [Project]] = [:]
        for project in allProjects {
            let name = (project.name ?? "Untitled").trimmingCharacters(in: .whitespaces).lowercased()
            groups[name, default: []].append(project)
        }
        
        var totalRemoved = 0
        var affectedNames: [String] = []
        var errors: [String] = []
        
        for (_, projectGroup) in groups where projectGroup.count > 1 {
            let projectName = projectGroup.first?.name ?? "Untitled"
            
            #if DEBUG
            print("🔍 [Dedup] Found \(projectGroup.count) copies of '\(projectName)'")
            #endif
            
            // Pick the "best" copy to keep — the one with the most content
            let sorted = projectGroup.sorted { lhs, rhs in
                let lhsScore = contentScore(for: lhs)
                let rhsScore = contentScore(for: rhs)
                return lhsScore > rhsScore
            }
            
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
        
        var groups: [String: Int] = [:]
        for project in allProjects {
            let name = (project.name ?? "Untitled").trimmingCharacters(in: .whitespaces).lowercased()
            groups[name, default: 0] += 1
        }
        
        // Count total excess copies (groups with count > 1)
        return groups.values.reduce(0) { $0 + max(0, $1 - 1) }
    }
    
    // MARK: - Scoring
    
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
