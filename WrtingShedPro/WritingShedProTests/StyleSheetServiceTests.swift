//
//  StyleSheetServiceTests.swift
//  WritingShedProTests
//
//  Tests for StyleSheetService initialization and lookup logic
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class StyleSheetServiceTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            StyleSheet.self,
            TextStyleModel.self,
            Project.self,
            Folder.self,
            File.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }
    
    override func tearDown() {
        container = nil
        context = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitializeStyleSheetsCreatesDefault() throws {
        // Given - Empty database
        var descriptor = FetchDescriptor<StyleSheet>()
        var sheets = try context.fetch(descriptor)
        XCTAssertEqual(sheets.count, 0)
        
        // When
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        // Then
        descriptor = FetchDescriptor<StyleSheet>()
        sheets = try context.fetch(descriptor)
        XCTAssertEqual(sheets.count, 1)
        
        let defaultSheet = sheets.first
        XCTAssertNotNil(defaultSheet)
        XCTAssertTrue(defaultSheet?.isSystemStyleSheet ?? false)
        XCTAssertEqual(defaultSheet?.name, "Default")
    }
    
    func testInitializeStyleSheetsCreatesTextStyles() throws {
        // When
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        // Then
        let descriptor = FetchDescriptor<TextStyleModel>()
        let styles = try context.fetch(descriptor)
        
        // Should have 11 text styles + 4 list styles = 15 total
        XCTAssertGreaterThanOrEqual(styles.count, 11)
        
        // Check for key styles
        let styleNames = styles.map { $0.name }
        XCTAssertTrue(styleNames.contains(UIFont.TextStyle.body.rawValue))
        XCTAssertTrue(styleNames.contains(UIFont.TextStyle.title1.rawValue))
        XCTAssertTrue(styleNames.contains(UIFont.TextStyle.headline.rawValue))
        XCTAssertTrue(styleNames.contains(UIFont.TextStyle.caption1.rawValue))
    }
    
    func testInitializeStyleSheetsOnlyRunsOnce() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        var descriptor = FetchDescriptor<StyleSheet>()
        let firstCount = try context.fetch(descriptor).count
        
        // When - Call again
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        // Then - No duplicates
        descriptor = FetchDescriptor<StyleSheet>()
        let secondCount = try context.fetch(descriptor).count
        XCTAssertEqual(firstCount, secondCount)
    }
    
    func testCreateDefaultStyleSheet() throws {
        // When
        let stylesheet = StyleSheetService.createDefaultStyleSheet()
        
        // Then
        XCTAssertEqual(stylesheet.name, "Default")
        XCTAssertTrue(stylesheet.isSystemStyleSheet)
        
        // Check text styles
        let styles = stylesheet.textStyles ?? []
        XCTAssertGreaterThanOrEqual(styles.count, 11)
        
        // Verify styles are properly configured
        let bodyStyle = styles.first(where: { $0.name == UIFont.TextStyle.body.rawValue })
        XCTAssertNotNil(bodyStyle)
        XCTAssertEqual(bodyStyle?.displayName, "Body")
        XCTAssertTrue(bodyStyle?.isSystemStyle ?? false)
        
        let title1Style = styles.first(where: { $0.name == UIFont.TextStyle.title1.rawValue })
        XCTAssertNotNil(title1Style)
        XCTAssertEqual(title1Style?.displayName, "Title 1")
        XCTAssertGreaterThan(title1Style?.fontSize ?? 0, 17) // Title should be larger than body
    }
    
    // MARK: - Lookup Tests
    
    func testGetDefaultStyleSheet() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        // When
        let defaultSheet = StyleSheetService.getDefaultStyleSheet(context: context)
        
        // Then
        XCTAssertNotNil(defaultSheet)
        XCTAssertTrue(defaultSheet?.isSystemStyleSheet ?? false)
    }
    
    func testGetStyleSheetForProject() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        try context.save()
        
        // When
        let stylesheet = StyleSheetService.getStyleSheet(for: project, context: context)
        
        // Then
        XCTAssertNotNil(stylesheet)
        XCTAssertEqual(project.styleSheet?.id, stylesheet?.id)
    }
    
    func testGetStyleSheetForProjectReturnsExisting() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        let customSheet = StyleSheet(name: "Custom", isSystemStyleSheet: false)
        context.insert(customSheet)
        
        let project = Project(name: "Test Project", type: .blank)
        project.styleSheet = customSheet
        context.insert(project)
        try context.save()
        
        // When
        let stylesheet = StyleSheetService.getStyleSheet(for: project, context: context)
        
        // Then
        XCTAssertEqual(stylesheet?.id, customSheet.id)
        XCTAssertEqual(stylesheet?.name, "Custom")
    }
    
    func testResolveStyleByName() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        try context.save()
        
        // When
        let bodyStyle = StyleSheetService.resolveStyle(named: "body", for: project, context: context)
        
        // Then
        XCTAssertNotNil(bodyStyle)
        XCTAssertEqual(bodyStyle?.name, UIFont.TextStyle.body.rawValue)
        XCTAssertEqual(bodyStyle?.displayName, "Body")
    }
    
    func testResolveStyleByUIFontTextStyle() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        try context.save()
        
        // When
        let headlineStyle = StyleSheetService.resolveStyle(.headline, for: project, context: context)
        
        // Then
        XCTAssertNotNil(headlineStyle)
        XCTAssertEqual(headlineStyle?.name, UIFont.TextStyle.headline.rawValue)
    }
    
    func testResolveStyleFallsBackToDefault() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        let customSheet = StyleSheet(name: "Custom", isSystemStyleSheet: false)
        // Don't add any styles to custom sheet
        context.insert(customSheet)
        
        let project = Project(name: "Test Project", type: .blank)
        project.styleSheet = customSheet
        context.insert(project)
        try context.save()
        
        // When - Try to resolve a style not in custom sheet
        let bodyStyle = StyleSheetService.resolveStyle(named: "body", for: project, context: context)
        
        // Then - Should fall back to default stylesheet
        XCTAssertNotNil(bodyStyle)
        XCTAssertEqual(bodyStyle?.name, UIFont.TextStyle.body.rawValue)
    }
    
    func testResolveStyleFallsBackToBody() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        let project = Project(name: "Test Project", type: .blank)
        context.insert(project)
        try context.save()
        
        // When - Try to resolve non-existent style
        let style = StyleSheetService.resolveStyle(named: "nonexistent", for: project, context: context)
        
        // Then - Should fall back to body
        XCTAssertNotNil(style)
        XCTAssertEqual(style?.name, UIFont.TextStyle.body.rawValue)
    }
    
    // MARK: - Custom Stylesheet Tests
    
    func testCustomStylesheetWithProjectStyles() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        let customSheet = StyleSheet(name: "Novel Stylesheet", isSystemStyleSheet: false)
        let chapterStyle = TextStyleModel(
            name: "chapter-title",
            displayName: "Chapter Title",
            displayOrder: 0,
            fontSize: 28,
            isBold: true
        )
        chapterStyle.alignment = .center
        chapterStyle.styleSheet = customSheet
        context.insert(customSheet)
        
        let project = Project(name: "My Novel", type: .novel)
        project.styleSheet = customSheet
        context.insert(project)
        try context.save()
        
        // When
        let resolvedStyle = StyleSheetService.resolveStyle(named: "chapter-title", for: project, context: context)
        
        // Then
        XCTAssertNotNil(resolvedStyle)
        XCTAssertEqual(resolvedStyle?.displayName, "Chapter Title")
        XCTAssertEqual(resolvedStyle?.fontSize, 28)
        XCTAssertTrue(resolvedStyle?.isBold ?? false)
        XCTAssertEqual(resolvedStyle?.alignment, .center)
    }
    
    func testMultipleProjectsWithDifferentStylesheets() throws {
        // Given
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
        
        let novelSheet = StyleSheet(name: "Novel Style", isSystemStyleSheet: false)
        let poetrySheet = StyleSheet(name: "Poetry Style", isSystemStyleSheet: false)
        
        context.insert(novelSheet)
        context.insert(poetrySheet)
        
        let novelProject = Project(name: "Novel", type: .novel)
        novelProject.styleSheet = novelSheet
        
        let poetryProject = Project(name: "Poetry", type: .poetry)
        poetryProject.styleSheet = poetrySheet
        
        context.insert(novelProject)
        context.insert(poetryProject)
        try context.save()
        
        // When
        let novelStylesheet = StyleSheetService.getStyleSheet(for: novelProject, context: context)
        let poetryStylesheet = StyleSheetService.getStyleSheet(for: poetryProject, context: context)
        
        // Then
        XCTAssertNotEqual(novelStylesheet?.id, poetryStylesheet?.id)
        XCTAssertEqual(novelStylesheet?.name, "Novel Style")
        XCTAssertEqual(poetryStylesheet?.name, "Poetry Style")
    }
}
