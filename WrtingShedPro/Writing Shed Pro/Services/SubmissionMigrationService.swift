//
//  SubmissionMigrationService.swift
//  Writing Shed Pro
//
//  One-time migration to set isCollection flag for existing Submission objects
//

import Foundation
import SwiftData

class SubmissionMigrationService {
    
    /// Migrate existing Submission objects to set the isCollection flag
    /// This is needed because isCollection was added later, so existing objects have the default value of false
    /// 
    /// Logic:
    /// - If publication == nil, it's a collection → isCollection = true
    /// - If publication != nil, it's a submission → isCollection = false
    static func migrateIsCollectionFlags(modelContext: ModelContext) {
        print("[Migration] Starting isCollection flag migration...")
        
        let descriptor = FetchDescriptor<Submission>()
        guard let allSubmissions = try? modelContext.fetch(descriptor) else {
            print("[Migration] Failed to fetch submissions")
            return
        }
        
        var collectionsFixed = 0
        var submissionsFixed = 0
        
        for submission in allSubmissions {
            // Collections: publication is nil → should have isCollection = true
            if submission.publication == nil && !submission.isCollection {
                submission.isCollection = true
                collectionsFixed += 1
            }
            // Submissions: publication is not nil → should have isCollection = false
            else if submission.publication != nil && submission.isCollection {
                submission.isCollection = false
                submissionsFixed += 1
            }
        }
        
        if collectionsFixed > 0 || submissionsFixed > 0 {
            do {
                try modelContext.save()
                print("[Migration] ✅ Migration complete:")
                print("[Migration]    Collections fixed: \(collectionsFixed)")
                print("[Migration]    Submissions fixed: \(submissionsFixed)")
            } catch {
                print("[Migration] ❌ Failed to save: \(error)")
            }
        } else {
            print("[Migration] ✅ No migrations needed - all flags already correct")
        }
    }
    
    /// Check if migration is needed (returns true if any submissions have incorrect isCollection flags)
    static func isMigrationNeeded(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Submission>()
        guard let allSubmissions = try? modelContext.fetch(descriptor) else {
            return false
        }
        
        for submission in allSubmissions {
            // Check if any submission has wrong flag
            if (submission.publication == nil && !submission.isCollection) ||
               (submission.publication != nil && submission.isCollection) {
                return true
            }
        }
        
        return false
    }
}
