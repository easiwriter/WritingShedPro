//
//  PoetryFormModelTests.swift
//  WritingShedProTests
//
//  Created by AI Assistant on 2026-01-01.
//  Feature 021 Phase 2: Custom Poetry Form Editor
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class PoetryFormModelTests: XCTestCase {
    
    var modelContext: ModelContext!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        let schema = Schema([
            PoetryFormModel.self,
            TextFile.self,
            Folder.self,
            Project.self,
            Version.self,
            TrashItem.self,
            StyleSheet.self,
            TextStyleModel.self,
            PageSetup.self,
            PrinterPaper.self,
            Publication.self,
            Submission.self,
            SubmittedFile.self,
            CommentModel.self,
            FootnoteModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        container = nil
    }
    
    // MARK: - PoetryFormModel Tests
    
    func testPoetryFormModelInitialization() {
        let model = PoetryFormModel(
            name: "Test Custom Form",
            category: .custom,
            lineCount: 8,
            syllablePattern: [5, 7, 5, 7, 7],
            rhymeScheme: "ABAB CDCD",
            meterPattern: "trochaic",
            formDescription: "A test custom form",
            templateContent: "Line 1\nLine 2",
            isCustom: true
        )
        
        XCTAssertEqual(model.name, "Test Custom Form")
        XCTAssertEqual(model.category, .custom)
        XCTAssertEqual(model.lineCount, 8)
        XCTAssertEqual(model.syllablePattern, [5, 7, 5, 7, 7])
        XCTAssertEqual(model.rhymeScheme, "ABAB CDCD")
        XCTAssertEqual(model.meterPattern, "trochaic")
        XCTAssertEqual(model.formDescription, "A test custom form")
        XCTAssertEqual(model.templateContent, "Line 1\nLine 2")
        XCTAssertTrue(model.isCustom)
        XCTAssertFalse(model.isPredefined)
    }
    
    func testPoetryFormModelSyllablePatternEncoding() {
        let model = PoetryFormModel(
            name: "Haiku",
            category: .japanese,
            syllablePattern: [5, 7, 5]
        )
        
        // Verify pattern is encoded to data
        XCTAssertNotNil(model.syllablePatternData)
        
        // Verify pattern can be read back
        XCTAssertEqual(model.syllablePattern, [5, 7, 5])
    }
    
    func testPoetryFormModelToPoetryFormConversion() {
        let model = PoetryFormModel(
            id: UUID(),
            name: "Sonnet",
            category: .rhymed,
            lineCount: 14,
            syllablePattern: nil,
            rhymeScheme: "ABAB CDCD EFEF GG",
            meterPattern: "iambic pentameter",
            formDescription: "14-line poem",
            templateContent: "",
            isCustom: false,
            isPredefined: true
        )
        
        let form = model.toPoetryForm()
        
        XCTAssertEqual(form.id, model.id)
        XCTAssertEqual(form.name, model.name)
        XCTAssertEqual(form.category, model.category)
        XCTAssertEqual(form.lineCount, model.lineCount)
        XCTAssertEqual(form.rhymeScheme, model.rhymeScheme)
        XCTAssertEqual(form.meterPattern, model.meterPattern)
        XCTAssertEqual(form.description, model.formDescription)
        XCTAssertFalse(form.isCustom)
    }
    
    func testPoetryFormToModelConversion() {
        let form = PoetryForm(
            id: UUID(),
            name: "Limerick",
            category: .rhymed,
            lineCount: 5,
            syllablePattern: [8, 8, 5, 5, 8],
            rhymeScheme: "AABBA",
            meterPattern: "anapestic",
            description: "A humorous 5-line poem",
            templateContent: "",
            isCustom: true
        )
        
        let model = PoetryFormModel.from(form, isPredefined: false)
        
        XCTAssertEqual(model.id, form.id)
        XCTAssertEqual(model.name, form.name)
        XCTAssertEqual(model.category, form.category)
        XCTAssertEqual(model.lineCount, form.lineCount)
        XCTAssertEqual(model.syllablePattern, form.syllablePattern)
        XCTAssertEqual(model.rhymeScheme, form.rhymeScheme)
        XCTAssertEqual(model.meterPattern, form.meterPattern)
        XCTAssertEqual(model.formDescription, form.description)
        XCTAssertTrue(model.isCustom)
        XCTAssertFalse(model.isPredefined)
    }
    
    func testDuplicateAsCustom() {
        let original = PoetryFormModel(
            name: "Original Form",
            category: .metered,
            lineCount: 10,
            rhymeScheme: "ABBA",
            formDescription: "Original description",
            isCustom: false,
            isPredefined: true
        )
        
        let duplicate = original.duplicateAsCustom()
        
        // Should have new ID
        XCTAssertNotEqual(duplicate.id, original.id)
        
        // Should have "(Copy)" appended to name
        XCTAssertEqual(duplicate.name, "Original Form (Copy)")
        
        // Should be custom, not predefined
        XCTAssertTrue(duplicate.isCustom)
        XCTAssertFalse(duplicate.isPredefined)
        
        // Other properties should be copied
        XCTAssertEqual(duplicate.category, original.category)
        XCTAssertEqual(duplicate.lineCount, original.lineCount)
        XCTAssertEqual(duplicate.rhymeScheme, original.rhymeScheme)
        XCTAssertEqual(duplicate.formDescription, original.formDescription)
    }
    
    // MARK: - SwiftData Persistence Tests
    
    func testPoetryFormModelPersistence() throws {
        let model = PoetryFormModel(
            name: "Persistent Form",
            category: .custom,
            formDescription: "This form should persist"
        )
        
        modelContext.insert(model)
        try modelContext.save()
        
        // Fetch back
        let descriptor = FetchDescriptor<PoetryFormModel>()
        let fetched = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Persistent Form")
        XCTAssertEqual(fetched.first?.category, .custom)
    }
    
    func testPoetryFormModelCRUD() throws {
        // Create
        let model = PoetryFormModel(
            name: "CRUD Test Form",
            category: .rhymed,
            formDescription: "Testing CRUD"
        )
        modelContext.insert(model)
        try modelContext.save()
        
        // Read
        var descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.name == "CRUD Test Form" }
        )
        var fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        
        // Update
        fetched.first?.name = "Updated Form Name"
        fetched.first?.modifiedDate = Date()
        try modelContext.save()
        
        descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.name == "Updated Form Name" }
        )
        fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Updated Form Name")
        
        // Delete
        if let toDelete = fetched.first {
            modelContext.delete(toDelete)
            try modelContext.save()
        }
        
        descriptor = FetchDescriptor<PoetryFormModel>()
        fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 0)
    }
    
    func testFetchPredefinedFormsOnly() throws {
        // Insert mix of predefined and custom forms
        let predefined1 = PoetryFormModel(
            name: "Predefined 1",
            category: .japanese,
            formDescription: "A predefined form",
            isCustom: false,
            isPredefined: true
        )
        let predefined2 = PoetryFormModel(
            name: "Predefined 2",
            category: .metered,
            formDescription: "Another predefined form",
            isCustom: false,
            isPredefined: true
        )
        let custom1 = PoetryFormModel(
            name: "Custom 1",
            category: .custom,
            formDescription: "A custom form",
            isCustom: true,
            isPredefined: false
        )
        
        modelContext.insert(predefined1)
        modelContext.insert(predefined2)
        modelContext.insert(custom1)
        try modelContext.save()
        
        // Fetch only predefined
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.isPredefined == true }
        )
        let fetched = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(fetched.allSatisfy { $0.isPredefined })
    }
    
    func testFetchCustomFormsOnly() throws {
        // Insert mix of predefined and custom forms
        let predefined = PoetryFormModel(
            name: "Predefined",
            category: .japanese,
            formDescription: "A predefined form",
            isCustom: false,
            isPredefined: true
        )
        let custom1 = PoetryFormModel(
            name: "Custom 1",
            category: .custom,
            formDescription: "A custom form",
            isCustom: true,
            isPredefined: false
        )
        let custom2 = PoetryFormModel(
            name: "Custom 2",
            category: .rhymed,
            formDescription: "Another custom form",
            isCustom: true,
            isPredefined: false
        )
        
        modelContext.insert(predefined)
        modelContext.insert(custom1)
        modelContext.insert(custom2)
        try modelContext.save()
        
        // Fetch only custom
        let descriptor = FetchDescriptor<PoetryFormModel>(
            predicate: #Predicate { $0.isCustom == true }
        )
        let fetched = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(fetched.allSatisfy { $0.isCustom })
    }
    
    // MARK: - Category Tests
    
    func testCategoryRawValueRoundTrip() {
        for category in PoetryFormCategory.allCases {
            let model = PoetryFormModel(name: "Test", category: category, formDescription: "Test")
            XCTAssertEqual(model.category, category)
            XCTAssertEqual(model.categoryRaw, category.rawValue)
        }
    }
    
    func testInvalidCategoryRawDefaultsToCustom() {
        let model = PoetryFormModel()
        model.categoryRaw = "InvalidCategory"
        
        // Should default to .custom
        XCTAssertEqual(model.category, .custom)
    }
}
