//
//  PoetryFormMigrationService.swift
//  Writing Shed Pro
//
//  Created by AI Assistant on 2026-01-01.
//  Feature 021 Phase 2: Custom Poetry Form Editor
//

import Foundation
import SwiftData

/// Service responsible for migrating predefined poetry forms from JSON to SwiftData
/// Handles first-launch seeding and upgrades when new predefined forms are added
struct PoetryFormMigrationService {
    
    // MARK: - UserDefaults Keys
    
    private static let migrationVersionKey = "poetryFormMigrationVersion"
    private static let currentMigrationVersion = 4  // Added Senryū, Spenserian Sonnet, Rondeau, Ballade, Cywydd, Englyn, Heroic Couplets, Prose Poetry, Concrete Poetry, Crown of Sonnets
    
    // MARK: - Public Methods
    
    /// Check if migration is needed and perform it
    /// Call this on app launch after ModelContainer is ready
    /// - Parameter modelContext: The SwiftData context to use
    static func migrateIfNeeded(modelContext: ModelContext) {
        let lastVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        
        #if DEBUG
        print("[PoetryFormMigration] Checking migration: lastVersion=\(lastVersion), currentVersion=\(currentMigrationVersion)")
        #endif
        
        if lastVersion < currentMigrationVersion {
            performMigration(from: lastVersion, modelContext: modelContext)
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
            
            #if DEBUG
            print("[PoetryFormMigration] Migration complete, updated to version \(currentMigrationVersion)")
            #endif
        } else {
            #if DEBUG
            print("[PoetryFormMigration] No migration needed")
            #endif
        }
    }
    
    /// Force reset all predefined forms to JSON defaults
    /// Useful for troubleshooting or when JSON is updated significantly
    /// - Parameter modelContext: The SwiftData context to use
    static func resetPredefinedForms(modelContext: ModelContext) {
        #if DEBUG
        print("[PoetryFormMigration] Resetting predefined forms to JSON defaults")
        #endif
        
        // Delete all predefined forms
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.isPredefined == true }
        )
        
        do {
            let existingForms = try modelContext.fetch(descriptor)
            for form in existingForms {
                modelContext.delete(form)
            }
            try modelContext.save()
            
            #if DEBUG
            print("[PoetryFormMigration] Deleted \(existingForms.count) predefined forms")
            #endif
        } catch {
            #if DEBUG
            print("[PoetryFormMigration] ❌ Failed to delete predefined forms: \(error)")
            #endif
        }
        
        // Re-seed from JSON
        seedPredefinedForms(modelContext: modelContext)
        
        // Reset migration version to force re-check
        UserDefaults.standard.set(0, forKey: migrationVersionKey)
    }
    
    /// Seed all predefined forms from JSON
    /// - Parameter modelContext: The SwiftData context to use
    static func seedPredefinedForms(modelContext: ModelContext) {
        let forms = loadFormsFromJSON()
        
        #if DEBUG
        print("[PoetryFormMigration] Seeding \(forms.count) predefined forms from JSON")
        #endif
        
        for form in forms {
            // Check if form already exists to prevent duplicates
            if !formExists(id: form.id, modelContext: modelContext) {
                let model = PoetryFormModel.from(form, isPredefined: true)
                model.isCustom = false
                modelContext.insert(model)
            }
        }
        
        do {
            try modelContext.save()
            #if DEBUG
            print("[PoetryFormMigration] ✅ Successfully seeded predefined forms")
            #endif
        } catch {
            #if DEBUG
            print("[PoetryFormMigration] ❌ Failed to save predefined forms: \(error)")
            #endif
        }
    }
    
    /// Remove duplicate predefined forms, keeping only one of each
    /// - Parameter modelContext: The SwiftData context to use
    static func removeDuplicatePredefinedForms(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.isPredefined == true },
            sortBy: [SortDescriptor(\.id), SortDescriptor(\.createdDate)]
        )
        
        do {
            let allPredefined = try modelContext.fetch(descriptor)
            
            // Group by UUID
            var seen = Set<UUID>()
            var duplicatesToDelete: [PoetryFormModel] = []
            
            for form in allPredefined {
                if seen.contains(form.id) {
                    duplicatesToDelete.append(form)
                } else {
                    seen.insert(form.id)
                }
            }
            
            if duplicatesToDelete.isEmpty {
                #if DEBUG
                print("[PoetryFormMigration] No duplicate predefined forms found")
                #endif
                return
            }
            
            for form in duplicatesToDelete {
                modelContext.delete(form)
            }
            
            try modelContext.save()
            
            #if DEBUG
            print("[PoetryFormMigration] ✅ Removed \(duplicatesToDelete.count) duplicate predefined forms")
            #endif
        } catch {
            #if DEBUG
            print("[PoetryFormMigration] ❌ Failed to remove duplicates: \(error)")
            #endif
        }
    }
    
    /// Remove duplicate custom forms, keeping only one of each (earliest created)
    /// Handles duplicates caused by CloudKit sync
    /// - Parameter modelContext: The SwiftData context to use
    static func removeDuplicateCustomForms(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.isCustom == true },
            sortBy: [SortDescriptor(\.id), SortDescriptor(\.createdDate)]
        )
        
        do {
            let allCustom = try modelContext.fetch(descriptor)
            
            var seen = Set<UUID>()
            var duplicatesToDelete: [PoetryFormModel] = []
            
            for form in allCustom {
                if seen.contains(form.id) {
                    duplicatesToDelete.append(form)
                } else {
                    seen.insert(form.id)
                }
            }
            
            guard !duplicatesToDelete.isEmpty else { return }
            
            for form in duplicatesToDelete {
                modelContext.delete(form)
            }
            
            try modelContext.save()
            
            #if DEBUG
            print("[PoetryFormMigration] ✅ Removed \(duplicatesToDelete.count) duplicate custom forms")
            #endif
        } catch {
            #if DEBUG
            print("[PoetryFormMigration] ❌ Failed to remove custom duplicates: \(error)")
            #endif
        }
    }
    
    /// Check if a form with the given ID exists in the database
    /// - Parameters:
    ///   - id: The UUID to check
    ///   - modelContext: The SwiftData context to use
    /// - Returns: True if the form exists
    static func formExists(id: UUID, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let count = try modelContext.fetchCount(descriptor)
            return count > 0
        } catch {
            #if DEBUG
            print("[PoetryFormMigration] ❌ Failed to check form existence: \(error)")
            #endif
            return false
        }
    }
    
    /// Add any new predefined forms that exist in JSON but not in database
    /// Called during upgrade migrations
    /// - Parameter modelContext: The SwiftData context to use
    static func addMissingPredefinedForms(modelContext: ModelContext) {
        let jsonForms = loadFormsFromJSON()
        var addedCount = 0
        
        for form in jsonForms {
            if !formExists(id: form.id, modelContext: modelContext) {
                let model = PoetryFormModel.from(form, isPredefined: true)
                model.isCustom = false
                modelContext.insert(model)
                addedCount += 1
                
                #if DEBUG
                print("[PoetryFormMigration] Adding new predefined form: \(form.name)")
                #endif
            }
        }
        
        if addedCount > 0 {
            do {
                try modelContext.save()
                #if DEBUG
                print("[PoetryFormMigration] ✅ Added \(addedCount) new predefined forms")
                #endif
            } catch {
                #if DEBUG
                print("[PoetryFormMigration] ❌ Failed to save new forms: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Private Methods
    
    private static func performMigration(from version: Int, modelContext: ModelContext) {
        switch version {
        case 0:
            // First launch - seed all predefined forms
            seedPredefinedForms(modelContext: modelContext)
            
        case 1:
            // Fix duplicate forms bug and add any new predefined forms
            removeDuplicatePredefinedForms(modelContext: modelContext)
            addMissingPredefinedForms(modelContext: modelContext)
            
        case 2, 3:
            // Version 4: Full reset to fix duplicate forms issue and add new forms
            // (Senryū, Spenserian Sonnet, Rondeau, Ballade, Cywydd, Englyn, 
            // Heroic Couplets, Prose Poetry, Concrete Poetry, Crown of Sonnets)
            #if DEBUG
            print("[PoetryFormMigration] Version 4: Full reset of predefined forms to fix duplicates")
            #endif
            // resetPredefinedForms already calls seedPredefinedForms internally
            resetPredefinedForms(modelContext: modelContext)
            
        default:
            // Future versions: add incremental migrations here
            addMissingPredefinedForms(modelContext: modelContext)
        }
    }
    
    private static func loadFormsFromJSON() -> [PoetryForm] {
        guard let url = Bundle.main.url(forResource: "PoetryForms", withExtension: "json") else {
            #if DEBUG
            print("[PoetryFormMigration] ❌ PoetryForms.json not found in bundle")
            #endif
            return [createDefaultFreeVerse()]
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let forms = try decoder.decode([PoetryForm].self, from: data)
            return forms
        } catch {
            #if DEBUG
            print("[PoetryFormMigration] ❌ Failed to decode PoetryForms.json: \(error)")
            #endif
            return [createDefaultFreeVerse()]
        }
    }
    
    private static func createDefaultFreeVerse() -> PoetryForm {
        PoetryForm(
            id: PoetryForm.freeVerseId,
            name: "Free Verse",
            category: .free,
            description: "Poetry without regular meter, rhyme, or other traditional patterns.",
            templateContent: ""
        )
    }
}
