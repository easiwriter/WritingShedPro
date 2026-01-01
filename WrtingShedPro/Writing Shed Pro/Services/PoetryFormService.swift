import Foundation

/// Service for loading and managing poetry form definitions
/// Provides form lookup, template generation, and caching
@Observable
final class PoetryFormService {
    
    // MARK: - Singleton
    
    static let shared = PoetryFormService()
    
    // MARK: - Properties
    
    /// Cached predefined forms loaded from JSON
    private var cachedForms: [PoetryForm]?
    
    /// Forms grouped by category for picker display
    private var formsByCategory: [PoetryFormCategory: [PoetryForm]]?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Load all predefined poetry forms from the bundled JSON file
    /// Results are cached for subsequent calls
    func loadPredefinedForms() -> [PoetryForm] {
        // Return cached if available
        if let cached = cachedForms {
            return cached
        }
        
        // Load from bundle
        guard let url = Bundle.main.url(forResource: "PoetryForms", withExtension: "json") else {
            #if DEBUG
            print("[PoetryFormService] ❌ PoetryForms.json not found in bundle - check Copy Bundle Resources")
            #endif
            // Minimal fallback so app doesn't break
            let fallback = [PoetryForm(id: PoetryForm.freeVerseId, name: "Free Verse", category: .free, description: "Poetry without regular meter, rhyme, or other traditional patterns.", templateContent: "")]
            cachedForms = fallback
            buildCategoryCache(from: fallback)
            return fallback
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let forms = try decoder.decode([PoetryForm].self, from: data)
            
            // Cache the results
            cachedForms = forms
            buildCategoryCache(from: forms)
            
            #if DEBUG
            print("[PoetryFormService] ✅ Loaded \(forms.count) poetry forms from JSON")
            #endif
            
            return forms
        } catch {
            #if DEBUG
            print("[PoetryFormService] ❌ Failed to decode PoetryForms.json: \(error)")
            #endif
            // Minimal fallback so app doesn't break
            let fallback = [PoetryForm(id: PoetryForm.freeVerseId, name: "Free Verse", category: .free, description: "Poetry without regular meter, rhyme, or other traditional patterns.", templateContent: "")]
            cachedForms = fallback
            buildCategoryCache(from: fallback)
            return fallback
        }
    }
    
    /// Get a poetry form by its ID
    /// - Parameter id: The UUID of the form to find
    /// - Returns: The matching form, or nil if not found
    func getForm(byId id: UUID) -> PoetryForm? {
        let forms = loadPredefinedForms()
        return forms.first { $0.id == id }
    }
    
    /// Get a poetry form by its name (case-insensitive)
    /// - Parameter name: The name of the form to find
    /// - Returns: The matching form, or nil if not found
    func getForm(byName name: String) -> PoetryForm? {
        let forms = loadPredefinedForms()
        return forms.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Get the Free Verse form (default form)
    func getFreeVerse() -> PoetryForm {
        getForm(byId: PoetryForm.freeVerseId) ?? createDefaultFreeVerse()
    }
    
    /// Get forms grouped by category for picker display
    func getFormsByCategory() -> [PoetryFormCategory: [PoetryForm]] {
        if let cached = formsByCategory {
            return cached
        }
        
        let forms = loadPredefinedForms()
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
    
    /// Clear cached forms (useful for testing or if JSON is updated)
    func clearCache() {
        cachedForms = nil
        formsByCategory = nil
    }
    
    // MARK: - Private Methods
    
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
    func getFormDisplayName(for formId: UUID?) -> String {
        guard let id = formId else { return "Free Verse" }
        return getForm(byId: id)?.name ?? "Free Verse"
    }
}
