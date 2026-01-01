import XCTest
@testable import Writing_Shed_Pro

final class PoetryFormTests: XCTestCase {
    
    // MARK: - Model Initialization Tests
    
    func testPoetryFormInitialization() {
        let form = PoetryForm(
            name: "Test Form",
            category: .rhymed,
            lineCount: 10,
            syllablePattern: [5, 7, 5],
            rhymeScheme: "AABB",
            meterPattern: "iambic",
            description: "A test form",
            templateContent: "Line 1\nLine 2"
        )
        
        XCTAssertEqual(form.name, "Test Form")
        XCTAssertEqual(form.category, .rhymed)
        XCTAssertEqual(form.lineCount, 10)
        XCTAssertEqual(form.syllablePattern, [5, 7, 5])
        XCTAssertEqual(form.rhymeScheme, "AABB")
        XCTAssertEqual(form.meterPattern, "iambic")
        XCTAssertEqual(form.description, "A test form")
        XCTAssertEqual(form.templateContent, "Line 1\nLine 2")
        XCTAssertFalse(form.isCustom)
    }
    
    func testPoetryFormMinimalInitialization() {
        let form = PoetryForm(
            name: "Minimal",
            category: .free,
            description: "A minimal form"
        )
        
        XCTAssertEqual(form.name, "Minimal")
        XCTAssertNil(form.lineCount)
        XCTAssertNil(form.syllablePattern)
        XCTAssertNil(form.rhymeScheme)
        XCTAssertNil(form.meterPattern)
        XCTAssertEqual(form.templateContent, "")
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasSyllableRequirements() {
        let withSyllables = PoetryForm(
            name: "With Syllables",
            category: .japanese,
            syllablePattern: [5, 7, 5],
            description: "Has syllables"
        )
        XCTAssertTrue(withSyllables.hasSyllableRequirements)
        
        let withoutSyllables = PoetryForm(
            name: "Without Syllables",
            category: .free,
            description: "No syllables"
        )
        XCTAssertFalse(withoutSyllables.hasSyllableRequirements)
        
        let emptySyllables = PoetryForm(
            name: "Empty Syllables",
            category: .free,
            syllablePattern: [],
            description: "Empty array"
        )
        XCTAssertFalse(emptySyllables.hasSyllableRequirements)
    }
    
    func testHasMeterRequirements() {
        let withMeter = PoetryForm(
            name: "With Meter",
            category: .metered,
            meterPattern: "iambic pentameter",
            description: "Has meter"
        )
        XCTAssertTrue(withMeter.hasMeterRequirements)
        
        let withoutMeter = PoetryForm(
            name: "Without Meter",
            category: .free,
            description: "No meter"
        )
        XCTAssertFalse(withoutMeter.hasMeterRequirements)
        
        let emptyMeter = PoetryForm(
            name: "Empty Meter",
            category: .free,
            meterPattern: "",
            description: "Empty string"
        )
        XCTAssertFalse(emptyMeter.hasMeterRequirements)
    }
    
    func testHasRhymeScheme() {
        let withRhyme = PoetryForm(
            name: "With Rhyme",
            category: .rhymed,
            rhymeScheme: "ABAB",
            description: "Has rhyme"
        )
        XCTAssertTrue(withRhyme.hasRhymeScheme)
        
        let withoutRhyme = PoetryForm(
            name: "Without Rhyme",
            category: .free,
            description: "No rhyme"
        )
        XCTAssertFalse(withoutRhyme.hasRhymeScheme)
    }
    
    func testHasLineCountRequirement() {
        let withLines = PoetryForm(
            name: "With Lines",
            category: .metered,
            lineCount: 14,
            description: "Has line count"
        )
        XCTAssertTrue(withLines.hasLineCountRequirement)
        
        let withoutLines = PoetryForm(
            name: "Without Lines",
            category: .free,
            description: "No line count"
        )
        XCTAssertFalse(withoutLines.hasLineCountRequirement)
        
        let zeroLines = PoetryForm(
            name: "Zero Lines",
            category: .free,
            lineCount: 0,
            description: "Zero lines"
        )
        XCTAssertFalse(zeroLines.hasLineCountRequirement)
    }
    
    func testRequirementsSummary() {
        let haiku = PoetryForm(
            name: "Haiku",
            category: .japanese,
            lineCount: 3,
            syllablePattern: [5, 7, 5],
            description: "Haiku form"
        )
        let summary = haiku.requirementsSummary
        XCTAssertTrue(summary.contains("3 lines"))
        XCTAssertTrue(summary.contains("5-7-5 syllables"))
        
        let freeVerse = PoetryForm(
            name: "Free Verse",
            category: .free,
            description: "No requirements"
        )
        XCTAssertEqual(freeVerse.requirementsSummary, "No specific requirements")
    }
    
    // MARK: - Codable Tests
    
    func testPoetryFormEncodeDecode() throws {
        let original = PoetryForm(
            id: UUID(),
            name: "Test Sonnet",
            category: .metered,
            lineCount: 14,
            syllablePattern: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
            rhymeScheme: "ABAB CDCD EFEF GG",
            meterPattern: "iambic pentameter",
            description: "Test description",
            templateContent: "Line 1\nLine 2",
            isCustom: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PoetryForm.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.lineCount, original.lineCount)
        XCTAssertEqual(decoded.syllablePattern, original.syllablePattern)
        XCTAssertEqual(decoded.rhymeScheme, original.rhymeScheme)
        XCTAssertEqual(decoded.meterPattern, original.meterPattern)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.templateContent, original.templateContent)
        XCTAssertEqual(decoded.isCustom, original.isCustom)
    }
    
    // MARK: - Category Tests
    
    func testPoetryFormCategorySortOrder() {
        let categories = PoetryFormCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }
        
        XCTAssertEqual(categories[0], .japanese)
        XCTAssertEqual(categories[1], .rhymed)
        XCTAssertEqual(categories[2], .metered)
        XCTAssertEqual(categories[3], .free)
        XCTAssertEqual(categories[4], .custom)
    }
    
    func testPoetryFormCategoryDisplayName() {
        XCTAssertEqual(PoetryFormCategory.japanese.displayName, "Japanese")
        XCTAssertEqual(PoetryFormCategory.rhymed.displayName, "Rhymed")
        XCTAssertEqual(PoetryFormCategory.metered.displayName, "Metered")
        XCTAssertEqual(PoetryFormCategory.free.displayName, "Free")
        XCTAssertEqual(PoetryFormCategory.custom.displayName, "Custom")
    }
    
    // MARK: - Predefined ID Tests
    
    func testPredefinedFormIds() {
        // Verify predefined IDs are valid UUIDs
        XCTAssertNotNil(PoetryForm.freeVerseId)
        XCTAssertNotNil(PoetryForm.haikuId)
        XCTAssertNotNil(PoetryForm.tankaId)
        XCTAssertNotNil(PoetryForm.sonnetShakespeareanId)
        XCTAssertNotNil(PoetryForm.sonnetPetrarchanId)
        XCTAssertNotNil(PoetryForm.limerickId)
        XCTAssertNotNil(PoetryForm.villanelleId)
        XCTAssertNotNil(PoetryForm.ghazalId)
        XCTAssertNotNil(PoetryForm.blankVerseId)
        XCTAssertNotNil(PoetryForm.customId)
        
        // Verify all IDs are unique
        let ids = [
            PoetryForm.freeVerseId,
            PoetryForm.haikuId,
            PoetryForm.tankaId,
            PoetryForm.sonnetShakespeareanId,
            PoetryForm.sonnetPetrarchanId,
            PoetryForm.limerickId,
            PoetryForm.villanelleId,
            PoetryForm.ghazalId,
            PoetryForm.blankVerseId,
            PoetryForm.customId
        ]
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All predefined form IDs should be unique")
    }
    
    // MARK: - Hashable Tests
    
    func testPoetryFormHashable() {
        let form1 = PoetryForm(
            id: PoetryForm.haikuId,
            name: "Haiku",
            category: .japanese,
            description: "Test"
        )
        let form2 = PoetryForm(
            id: PoetryForm.haikuId,
            name: "Haiku",
            category: .japanese,
            description: "Test"
        )
        let form3 = PoetryForm(
            id: PoetryForm.tankaId,
            name: "Tanka",
            category: .japanese,
            description: "Test"
        )
        
        // Same ID should be equal
        XCTAssertEqual(form1, form2)
        XCTAssertEqual(form1.hashValue, form2.hashValue)
        
        // Different ID should not be equal
        XCTAssertNotEqual(form1, form3)
    }
}
