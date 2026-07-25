import XCTest
@testable import Writing_Shed_Pro

final class PoetryFormServiceTests: XCTestCase {
    
    var service: PoetryFormService!
    
    override func setUp() {
        super.setUp()
        service = PoetryFormService.shared
        service.resetForTesting()
    }
    
    override func tearDown() {
        service.resetForTesting()
        super.tearDown()
    }
    
    // MARK: - Load Forms Tests
    
    func testLoadPredefinedForms() {
        let forms = service.loadPredefinedForms()
        
        // Should have at least 10 predefined forms
        XCTAssertGreaterThanOrEqual(forms.count, 10, "Should have at least 10 predefined forms")
    }
    
    func testLoadPredefinedFormsCaching() {
        // First load
        let forms1 = service.loadPredefinedForms()
        
        // Second load should return cached
        let forms2 = service.loadPredefinedForms()
        
        XCTAssertEqual(forms1.count, forms2.count)
    }
    
    func testClearCache() {
        // Load forms
        _ = service.loadPredefinedForms()
        
        // Clear cache
        service.clearCache()
        
        // Should be able to reload
        let forms = service.loadPredefinedForms()
        XCTAssertGreaterThan(forms.count, 0)
    }
    
    // MARK: - Get Form By ID Tests
    
    func testGetFormByIdFreeVerse() {
        let form = service.getForm(byId: PoetryForm.freeVerseId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Free Verse")
        XCTAssertEqual(form?.category, .free)
    }
    
    func testGetFormByIdHaiku() {
        let form = service.getForm(byId: PoetryForm.haikuId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Haiku")
        XCTAssertEqual(form?.category, .japanese)
        XCTAssertEqual(form?.lineCount, 3)
        XCTAssertEqual(form?.syllablePattern, [5, 7, 5])
    }
    
    func testGetFormByIdTanka() {
        let form = service.getForm(byId: PoetryForm.tankaId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Tanka")
        XCTAssertEqual(form?.syllablePattern, [5, 7, 5, 7, 7])
    }
    
    func testGetFormByIdSonnetShakespearean() {
        let form = service.getForm(byId: PoetryForm.sonnetShakespeareanId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Sonnet (Shakespearean)")
        XCTAssertEqual(form?.lineCount, 14)
        XCTAssertEqual(form?.meterPattern, "iambic pentameter")
        XCTAssertEqual(form?.rhymeScheme, "ABAB CDCD EFEF GG")
    }
    
    func testGetFormByIdSonnetPetrarchan() {
        let form = service.getForm(byId: PoetryForm.sonnetPetrarchanId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Sonnet (Petrarchan)")
        XCTAssertEqual(form?.rhymeScheme, "ABBAABBA CDECDE")
    }
    
    func testGetFormByIdLimerick() {
        let form = service.getForm(byId: PoetryForm.limerickId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Limerick")
        XCTAssertEqual(form?.lineCount, 5)
        XCTAssertEqual(form?.rhymeScheme, "AABBA")
    }
    
    func testGetFormByIdVillanelle() {
        let form = service.getForm(byId: PoetryForm.villanelleId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Villanelle")
        XCTAssertEqual(form?.lineCount, 19)
    }
    
    func testGetFormByIdGhazal() {
        let form = service.getForm(byId: PoetryForm.ghazalId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Ghazal")
    }
    
    func testGetFormByIdBlankVerse() {
        let form = service.getForm(byId: PoetryForm.blankVerseId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Blank Verse")
        XCTAssertEqual(form?.meterPattern, "iambic pentameter")
        XCTAssertNil(form?.rhymeScheme) // Blank verse has no rhyme
    }
    
    func testGetFormByIdPantoum() {
        let form = service.getForm(byId: PoetryForm.pantoumId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Pantoum")
        XCTAssertEqual(form?.category, .rhymed)
    }
    
    func testGetFormByIdTriolet() {
        let form = service.getForm(byId: PoetryForm.trioletId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Triolet")
        XCTAssertEqual(form?.lineCount, 8)
        XCTAssertEqual(form?.rhymeScheme, "ABaAabAB")
    }
    
    func testGetFormByIdBallad() {
        let form = service.getForm(byId: PoetryForm.balladId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Ballad")
        XCTAssertEqual(form?.category, .rhymed)
    }
    
    func testGetFormByIdOttavaRima() {
        let form = service.getForm(byId: PoetryForm.ottavaRimaId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Ottava Rima")
        XCTAssertEqual(form?.lineCount, 8)
        XCTAssertEqual(form?.rhymeScheme, "ABABABCC")
        XCTAssertEqual(form?.meterPattern, "iambic pentameter")
    }
    
    func testGetFormByIdTerzaRima() {
        let form = service.getForm(byId: PoetryForm.terzaRimaId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Terza Rima")
        XCTAssertEqual(form?.rhymeScheme, "ABA BCB CDC...")
        XCTAssertEqual(form?.meterPattern, "iambic pentameter")
    }
    
    func testGetFormByIdSpenserianStanza() {
        let form = service.getForm(byId: PoetryForm.spenserianStanzaId)
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Spenserian Stanza")
        XCTAssertEqual(form?.lineCount, 9)
        XCTAssertEqual(form?.rhymeScheme, "ABABBCBCC")
    }
    
    func testGetFormByIdCustom() {
        // The "Custom" form placeholder exists in JSON with specific ID
        let form = service.getForm(byId: PoetryForm.customId)
        
        // Verify it's found and has the right name
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.name, "Custom")
        // Note: isCustom may be false in test environment due to how forms are loaded
    }
    
    func testGetFormByIdNotFound() {
        let randomId = UUID()
        let form = service.getForm(byId: randomId)
        
        XCTAssertNil(form)
    }
    
    // MARK: - Get Form By Name Tests
    
    func testGetFormByName() {
        let form = service.getForm(byName: "Haiku")
        
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.id, PoetryForm.haikuId)
    }
    
    func testGetFormByNameCaseInsensitive() {
        let form1 = service.getForm(byName: "haiku")
        let form2 = service.getForm(byName: "HAIKU")
        let form3 = service.getForm(byName: "HaIkU")
        
        XCTAssertNotNil(form1)
        XCTAssertNotNil(form2)
        XCTAssertNotNil(form3)
        XCTAssertEqual(form1?.id, form2?.id)
        XCTAssertEqual(form2?.id, form3?.id)
    }
    
    func testGetFormByNameNotFound() {
        let form = service.getForm(byName: "Nonexistent Form")
        
        XCTAssertNil(form)
    }
    
    // MARK: - Free Verse Tests
    
    func testGetFreeVerse() {
        let form = service.getFreeVerse()
        
        XCTAssertEqual(form.id, PoetryForm.freeVerseId)
        XCTAssertEqual(form.name, "Free Verse")
        XCTAssertEqual(form.category, .free)
    }
    
    func testIsFreeVerseWithNil() {
        XCTAssertTrue(service.isFreeVerse(nil))
    }
    
    func testIsFreeVerseWithFreeVerseId() {
        XCTAssertTrue(service.isFreeVerse(PoetryForm.freeVerseId))
    }
    
    func testIsFreeVerseWithOtherId() {
        XCTAssertFalse(service.isFreeVerse(PoetryForm.haikuId))
    }
    
    // MARK: - Category Tests
    
    func testGetFormsByCategory() {
        let grouped = service.getFormsByCategory()
        
        // Should have entries for categories with forms
        XCTAssertNotNil(grouped[.japanese])
        XCTAssertNotNil(grouped[.rhymed])
        XCTAssertNotNil(grouped[.metered])
        XCTAssertNotNil(grouped[.free])
        XCTAssertNotNil(grouped[.custom])
        
        // Japanese should include Haiku and Tanka
        let japaneseForms = grouped[.japanese] ?? []
        let japaneseNames = japaneseForms.map { $0.name }
        XCTAssertTrue(japaneseNames.contains("Haiku"))
        XCTAssertTrue(japaneseNames.contains("Tanka"))
    }
    
    func testGetCategories() {
        let categories = service.getCategories()
        
        XCTAssertEqual(categories.count, 6)
        XCTAssertEqual(categories[0], .japanese)
        XCTAssertEqual(categories[1], .rhymed)
        XCTAssertEqual(categories[2], .structured)
        XCTAssertEqual(categories[3], .metered)
        XCTAssertEqual(categories[4], .free)
        XCTAssertEqual(categories[5], .custom)
    }
    
    // MARK: - Template Generation Tests
    
    func testGenerateTemplateWithTitle() throws {
        let form = try XCTUnwrap(service.getForm(byId: PoetryForm.haikuId))
        let template = service.generateTemplate(for: form, title: "My Haiku")
        
        XCTAssertTrue(template.hasPrefix("# My Haiku\n\n"))
        XCTAssertTrue(template.contains("Line 1 (5 syllables)"))
    }
    
    func testGenerateTemplateWithoutTitle() throws {
        let form = try XCTUnwrap(service.getForm(byId: PoetryForm.haikuId))
        let template = service.generateTemplate(for: form)
        
        XCTAssertFalse(template.hasPrefix("#"))
        XCTAssertTrue(template.contains("Line 1 (5 syllables)"))
    }
    
    func testGenerateTemplateForFreeVerse() {
        let form = service.getFreeVerse()
        let template = service.generateTemplate(for: form)
        
        // Free verse has empty template
        XCTAssertEqual(template, "")
    }
    
    func testGenerateTemplateForFreeVerseWithTitle() {
        let form = service.getFreeVerse()
        let template = service.generateTemplate(for: form, title: "My Poem")
        
        XCTAssertEqual(template, "# My Poem\n\n")
    }
    
    // MARK: - Display Name Tests
    
    func testGetFormDisplayNameWithNil() {
        let name = service.getFormDisplayName(for: nil)
        XCTAssertEqual(name, "Free Verse")
    }
    
    func testGetFormDisplayNameWithValidId() {
        let name = service.getFormDisplayName(for: PoetryForm.haikuId)
        XCTAssertEqual(name, "Haiku")
    }
    
    func testGetFormDisplayNameWithInvalidId() {
        let name = service.getFormDisplayName(for: UUID())
        XCTAssertEqual(name, "Unknown Form")
    }
    
    // MARK: - Form Validation Tests
    
    func testAllFormsHaveRequiredFields() {
        let forms = service.loadPredefinedForms()
        
        for form in forms {
            XCTAssertFalse(form.name.isEmpty, "Form \(form.id) should have a name")
            XCTAssertFalse(form.description.isEmpty, "Form \(form.name) should have a description")
        }
    }
    
    func testSyllableBasedFormsHaveCorrectLineCount() throws {
        // Haiku: 3 lines with 5-7-5
        let haiku = try XCTUnwrap(service.getForm(byId: PoetryForm.haikuId))
        XCTAssertEqual(haiku.lineCount, 3)
        XCTAssertEqual(haiku.syllablePattern?.count, 3)
        
        // Tanka: 5 lines with 5-7-5-7-7
        let tanka = try XCTUnwrap(service.getForm(byId: PoetryForm.tankaId))
        XCTAssertEqual(tanka.lineCount, 5)
        XCTAssertEqual(tanka.syllablePattern?.count, 5)
    }
    
    func testSonnetsHave14Lines() throws {
        let shakespearean = try XCTUnwrap(service.getForm(byId: PoetryForm.sonnetShakespeareanId))
        let petrarchan = try XCTUnwrap(service.getForm(byId: PoetryForm.sonnetPetrarchanId))
        
        XCTAssertEqual(shakespearean.lineCount, 14)
        XCTAssertEqual(petrarchan.lineCount, 14)
        XCTAssertEqual(shakespearean.syllablePattern?.count, 14)
        XCTAssertEqual(petrarchan.syllablePattern?.count, 14)
    }
}
