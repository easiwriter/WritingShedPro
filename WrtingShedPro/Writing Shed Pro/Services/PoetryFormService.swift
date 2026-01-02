import Foundation
import SwiftData

/// Service for loading and managing poetry form definitions
/// Provides form lookup, template generation, and caching
/// Phase 2: Now supports database-backed forms (predefined + custom)
@Observable
final class PoetryFormService {
    
    // MARK: - Singleton
    
    static let shared = PoetryFormService()
    
    // MARK: - Properties
    
    /// Cached forms loaded from database (predefined + custom)
    private var cachedForms: [PoetryForm]?
    
    /// Cached predefined forms only
    private var cachedPredefinedForms: [PoetryForm]?
    
    /// Cached custom forms only
    private var cachedCustomForms: [PoetryForm]?
    
    /// Forms grouped by category for picker display
    private var formsByCategory: [PoetryFormCategory: [PoetryForm]]?
    
    /// Reference to model context for database operations
    /// Set this after app launch via configureWithContext
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure the service with a model context for database access
    /// Call this after ModelContainer is ready
    func configureWithContext(_ context: ModelContext) {
        self.modelContext = context
        clearCache()
        
        // Ensure migration has run
        PoetryFormMigrationService.migrateIfNeeded(modelContext: context)
    }
    
    // MARK: - Public Methods
    
    /// Load all poetry forms (predefined + custom) from the database
    /// Falls back to JSON if database is not configured
    /// Results are cached for subsequent calls
    func loadAllForms() -> [PoetryForm] {
        // Return cached if available
        if let cached = cachedForms {
            return cached
        }
        
        // Try database first
        if let context = modelContext {
            let forms = loadFormsFromDatabase(context: context)
            cachedForms = forms
            buildCategoryCache(from: forms)
            return forms
        }
        
        // Fallback to JSON
        return loadPredefinedForms()
    }
    
    /// Load all predefined poetry forms
    /// Uses database if configured, otherwise falls back to JSON
    /// Results are cached for subsequent calls
    func loadPredefinedForms() -> [PoetryForm] {
        // Return cached if available
        if let cached = cachedPredefinedForms {
            return cached
        }
        
        // Try database first
        if let context = modelContext {
            let forms = loadPredefinedFormsFromDatabase(context: context)
            cachedPredefinedForms = forms
            return forms
        }
        
        // Fallback to JSON
        return loadPredefinedFormsFromJSON()
    }
    
    /// Load only custom (user-created) poetry forms from the database
    func loadCustomForms() -> [PoetryForm] {
        // Return cached if available
        if let cached = cachedCustomForms {
            return cached
        }
        
        guard let context = modelContext else {
            #if DEBUG
            print("[PoetryFormService] ⚠️ No model context, custom forms unavailable")
            #endif
            return []
        }
        
        let forms = loadCustomFormsFromDatabase(context: context)
        cachedCustomForms = forms
        return forms
    }
    
    /// Get a poetry form by its ID
    /// Searches both predefined and custom forms
    /// - Parameter id: The UUID of the form to find
    /// - Returns: The matching form, or nil if not found
    func getForm(byId id: UUID) -> PoetryForm? {
        let forms = loadAllForms()
        return forms.first { $0.id == id }
    }
    
    /// Get a poetry form by its name (case-insensitive)
    /// Searches both predefined and custom forms
    /// - Parameter name: The name of the form to find
    /// - Returns: The matching form, or nil if not found
    func getForm(byName name: String) -> PoetryForm? {
        let forms = loadAllForms()
        return forms.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Get the Free Verse form (default form)
    func getFreeVerse() -> PoetryForm {
        getForm(byId: PoetryForm.freeVerseId) ?? createDefaultFreeVerse()
    }
    
    /// Get forms grouped by category for picker display
    /// Includes both predefined and custom forms
    func getFormsByCategory() -> [PoetryFormCategory: [PoetryForm]] {
        if let cached = formsByCategory {
            return cached
        }
        
        let forms = loadAllForms()
        buildCategoryCache(from: forms)
        return formsByCategory ?? [:]
    }
    
    /// Get all categories in display order
    func getCategories() -> [PoetryFormCategory] {
        PoetryFormCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// Generate template content for a form, optionally with a title
    /// - Parameters:
    ///   - form: The poetry form to generate template for
    ///   - title: Optional title to include at the top
    /// - Returns: The template string
    func generateTemplate(for form: PoetryForm, title: String? = nil) -> String {
        var template = ""
        
        // Add title if provided
        if let title = title, !title.isEmpty {
            template = "# \(title)\n\n"
        }
        
        // If form has template content, use it
        if !form.templateContent.isEmpty {
            template += form.templateContent
        }
        
        return template
    }
    
    /// Clear cached forms (useful for testing or when forms are modified)
    func clearCache() {
        cachedForms = nil
        cachedPredefinedForms = nil
        cachedCustomForms = nil
        formsByCategory = nil
    }
    
    // MARK: - Custom Form CRUD Operations
    
    /// Save a new custom form to the database
    /// - Parameter form: The form to save
    /// - Returns: True if save was successful
    @discardableResult
    func saveCustomForm(_ form: PoetryForm) -> Bool {
        guard let context = modelContext else {
            #if DEBUG
            print("[PoetryFormService] ❌ Cannot save form: no model context")
            #endif
            return false
        }
        
        let model = PoetryFormModel.from(form, isPredefined: false)
        model.isCustom = true
        context.insert(model)
        
        do {
            try context.save()
            clearCache()
            
            #if DEBUG
            print("[PoetryFormService] ✅ Saved custom form: \(form.name)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to save custom form: \(error)")
            #endif
            return false
        }
    }
    
    /// Update an existing custom form in the database
    /// - Parameter form: The form with updated values
    /// - Returns: True if update was successful
    @discardableResult
    func updateCustomForm(_ form: PoetryForm) -> Bool {
        guard let context = modelContext else {
            #if DEBUG
            print("[PoetryFormService] ❌ Cannot update form: no model context")
            #endif
            return false
        }
        
        // Find existing model
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.id == form.id }
        )
        
        do {
            let results = try context.fetch(descriptor)
            guard let existingModel = results.first else {
                #if DEBUG
                print("[PoetryFormService] ❌ Form not found for update: \(form.id)")
                #endif
                return false
            }
            
            // Prevent editing predefined forms
            if existingModel.isPredefined {
                #if DEBUG
                print("[PoetryFormService] ❌ Cannot edit predefined form: \(form.name)")
                #endif
                return false
            }
            
            // Update properties
            existingModel.name = form.name
            existingModel.category = form.category
            existingModel.lineCount = form.lineCount
            existingModel.syllablePattern = form.syllablePattern
            existingModel.rhymeScheme = form.rhymeScheme
            existingModel.meterPattern = form.meterPattern
            existingModel.formDescription = form.description
            existingModel.templateContent = form.templateContent
            existingModel.modifiedDate = Date()
            
            try context.save()
            clearCache()
            
            #if DEBUG
            print("[PoetryFormService] ✅ Updated custom form: \(form.name)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to update custom form: \(error)")
            #endif
            return false
        }
    }
    
    /// Delete a custom form from the database
    /// - Parameter form: The form to delete
    /// - Returns: True if deletion was successful
    @discardableResult
    func deleteCustomForm(_ form: PoetryForm) -> Bool {
        guard let context = modelContext else {
            #if DEBUG
            print("[PoetryFormService] ❌ Cannot delete form: no model context")
            #endif
            return false
        }
        
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.id == form.id }
        )
        
        do {
            let results = try context.fetch(descriptor)
            guard let existingModel = results.first else {
                #if DEBUG
                print("[PoetryFormService] ❌ Form not found for deletion: \(form.id)")
                #endif
                return false
            }
            
            // Prevent deleting predefined forms
            if existingModel.isPredefined {
                #if DEBUG
                print("[PoetryFormService] ❌ Cannot delete predefined form: \(form.name)")
                #endif
                return false
            }
            
            context.delete(existingModel)
            try context.save()
            clearCache()
            
            #if DEBUG
            print("[PoetryFormService] ✅ Deleted custom form: \(form.name)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to delete custom form: \(error)")
            #endif
            return false
        }
    }
    
    /// Count files using a specific poetry form
    /// Used to warn users before deleting a form
    func countFilesUsingForm(_ formId: UUID, in context: ModelContext? = nil) -> Int {
        let ctx = context ?? modelContext
        guard let context = ctx else { return 0 }
        
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate { $0.poetryFormId == formId }
        )
        
        do {
            return try context.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to count files: \(error)")
            #endif
            return 0
        }
    }
    
    /// Update files referencing a deleted form to use Free Verse
    func reassignFilesToFreeVerse(fromFormId: UUID) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate { $0.poetryFormId == fromFormId }
        )
        
        do {
            let files = try context.fetch(descriptor)
            for file in files {
                file.poetryFormId = PoetryForm.freeVerseId
                file.poetryFormName = "Free Verse"
            }
            try context.save()
            
            #if DEBUG
            print("[PoetryFormService] ✅ Reassigned \(files.count) files to Free Verse")
            #endif
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to reassign files: \(error)")
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    /// Load all forms from database
    private func loadFormsFromDatabase(context: ModelContext) -> [PoetryForm] {
        let descriptor = FetchDescriptor<PoetryFormModel>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            let models = try context.fetch(descriptor)
            let forms = models.map { $0.toPoetryForm() }
            
            #if DEBUG
            print("[PoetryFormService] ✅ Loaded \(forms.count) forms from database")
            #endif
            
            return forms
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to load forms from database: \(error)")
            #endif
            return loadPredefinedFormsFromJSON()
        }
    }
    
    /// Load predefined forms from database
    private func loadPredefinedFormsFromDatabase(context: ModelContext) -> [PoetryForm] {
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.isPredefined == true },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            let models = try context.fetch(descriptor)
            return models.map { $0.toPoetryForm() }
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to load predefined forms: \(error)")
            #endif
            return loadPredefinedFormsFromJSON()
        }
    }
    
    /// Load custom forms from database
    private func loadCustomFormsFromDatabase(context: ModelContext) -> [PoetryForm] {
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.isCustom == true },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            let models = try context.fetch(descriptor)
            return models.map { $0.toPoetryForm() }
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to load custom forms: \(error)")
            #endif
            return []
        }
    }
    
    /// Fallback: Load predefined forms from JSON bundle
    private func loadPredefinedFormsFromJSON() -> [PoetryForm] {
        guard let url = Bundle.main.url(forResource: "PoetryForms", withExtension: "json") else {
            #if DEBUG
            print("[PoetryFormService] ❌ PoetryForms.json not found in bundle")
            #endif
            return [createDefaultFreeVerse()]
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let forms = try decoder.decode([PoetryForm].self, from: data)
            
            #if DEBUG
            print("[PoetryFormService] ✅ Loaded \(forms.count) forms from JSON (fallback)")
            #endif
            
            return forms
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to decode PoetryForms.json: \(error)")
            #endif
            return [createDefaultFreeVerse()]
        }
    }
    
    private func buildCategoryCache(from forms: [PoetryForm]) {
        var grouped: [PoetryFormCategory: [PoetryForm]] = [:]
        
        for form in forms {
            if grouped[form.category] == nil {
                grouped[form.category] = []
            }
            grouped[form.category]?.append(form)
        }
        
        // Sort forms within each category by name
        for (category, categoryForms) in grouped {
            grouped[category] = categoryForms.sorted { $0.name < $1.name }
        }
        
        formsByCategory = grouped
    }
    
    private func createDefaultFreeVerse() -> PoetryForm {
        PoetryForm(
            id: PoetryForm.freeVerseId,
            name: "Free Verse",
            category: .free,
            description: "Poetry without regular meter, rhyme, or other traditional patterns.",
            templateContent: ""
        )
    }
}

// MARK: - Convenience Extensions

extension PoetryFormService {
    
    /// Check if a form ID is the Free Verse form
    func isFreeVerse(_ formId: UUID?) -> Bool {
        formId == nil || formId == PoetryForm.freeVerseId
    }
    
    /// Get display name for a form ID, returns "Free Verse" for nil
    /// Falls back to "Unknown Form" if form doesn't exist
    func getFormDisplayName(for formId: UUID?) -> String {
        guard let id = formId else { return "Free Verse" }
        return getForm(byId: id)?.name ?? NSLocalizedString("poetryForms.reference.unknownForm", comment: "Unknown Form")
    }
    
    /// Check if a form is a predefined (non-editable) form
    func isPredefinedForm(_ formId: UUID) -> Bool {
        guard let context = modelContext else { return false }
        
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.id == formId && $0.isPredefined == true }
        )
        
        do {
            return try context.fetchCount(descriptor) > 0
        } catch {
            return false
        }
    }
}
