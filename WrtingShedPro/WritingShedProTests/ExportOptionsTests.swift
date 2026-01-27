//
//  ExportOptionsTests.swift
//  WritingShedProTests
//
//  Unit tests for Feature 029: ExportOptions back matter settings
//

import XCTest
@testable import Writing_Shed_Pro

final class ExportOptionsTests: XCTestCase {
    
    // MARK: - Default Values Tests
    
    func testExportOptionsDefaultValues() {
        let options = ExportOptions()
        
        XCTAssertEqual(options.format, .pdf)
        XCTAssertTrue(options.includeFrontMatter)
        XCTAssertTrue(options.includeBody)
        XCTAssertTrue(options.includeBackMatter)
        XCTAssertTrue(options.includeTableOfContents)
        XCTAssertTrue(options.includeTitlePage)
        XCTAssertEqual(options.filename, "Manuscript")
    }
    
    func testExportOptionsBackMatterDefaults() {
        let options = ExportOptions()
        
        // Feature 029: Back matter reference options
        XCTAssertTrue(options.includeNotes)
        XCTAssertTrue(options.includeGlossary)
        XCTAssertTrue(options.includeBibliography)
        XCTAssertTrue(options.includeIndex)
    }
    
    // MARK: - Custom Values Tests
    
    func testExportOptionsCustomBackMatterSettings() {
        var options = ExportOptions()
        
        options.includeNotes = false
        options.includeGlossary = true
        options.includeBibliography = false
        options.includeIndex = true
        
        XCTAssertFalse(options.includeNotes)
        XCTAssertTrue(options.includeGlossary)
        XCTAssertFalse(options.includeBibliography)
        XCTAssertTrue(options.includeIndex)
    }
    
    func testExportOptionsCustomFormat() {
        var options = ExportOptions()
        
        options.format = .rtf
        XCTAssertEqual(options.format, .rtf)
        
        options.format = .plainText
        XCTAssertEqual(options.format, .plainText)
        
        options.format = .epub
        XCTAssertEqual(options.format, .epub)
    }
    
    // MARK: - Equatable Tests
    
    func testExportOptionsEquatable() {
        let options1 = ExportOptions()
        let options2 = ExportOptions()
        
        XCTAssertEqual(options1, options2)
    }
    
    func testExportOptionsNotEqualWhenDifferent() {
        var options1 = ExportOptions()
        var options2 = ExportOptions()
        
        options1.includeNotes = true
        options2.includeNotes = false
        
        XCTAssertNotEqual(options1, options2)
    }
    
    func testExportOptionsNotEqualWithDifferentBackMatter() {
        var options1 = ExportOptions()
        var options2 = ExportOptions()
        
        options1.includeGlossary = true
        options1.includeBibliography = true
        options1.includeIndex = true
        
        options2.includeGlossary = false
        options2.includeBibliography = true
        options2.includeIndex = true
        
        XCTAssertNotEqual(options1, options2)
    }
    
    // MARK: - ExportFormat Tests
    
    func testExportFormatFileExtensions() {
        XCTAssertEqual(ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportFormat.rtf.fileExtension, "rtf")
        XCTAssertEqual(ExportFormat.plainText.fileExtension, "txt")
        XCTAssertEqual(ExportFormat.word.fileExtension, "docx")
        XCTAssertEqual(ExportFormat.html.fileExtension, "html")
        XCTAssertEqual(ExportFormat.epub.fileExtension, "epub")
        XCTAssertEqual(ExportFormat.markdown.fileExtension, "md")
    }
    
    func testExportFormatMimeTypes() {
        XCTAssertEqual(ExportFormat.pdf.mimeType, "application/pdf")
        XCTAssertEqual(ExportFormat.rtf.mimeType, "application/rtf")
        XCTAssertEqual(ExportFormat.plainText.mimeType, "text/plain")
        XCTAssertEqual(ExportFormat.word.mimeType, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        XCTAssertEqual(ExportFormat.html.mimeType, "text/html")
        XCTAssertEqual(ExportFormat.epub.mimeType, "application/epub+zip")
        XCTAssertEqual(ExportFormat.markdown.mimeType, "text/markdown")
    }
    
    func testExportFormatIcons() {
        XCTAssertEqual(ExportFormat.pdf.icon, "doc.fill")
        XCTAssertEqual(ExportFormat.rtf.icon, "doc.richtext")
        XCTAssertEqual(ExportFormat.plainText.icon, "doc.text")
        XCTAssertEqual(ExportFormat.word.icon, "doc")
        XCTAssertEqual(ExportFormat.html.icon, "chevron.left.slash.chevron.right")
        XCTAssertEqual(ExportFormat.epub.icon, "book")
        XCTAssertEqual(ExportFormat.markdown.icon, "text.badge.checkmark")
    }
    
    func testExportFormatLocalizedNames() {
        // Just verify they return non-empty strings
        XCTAssertFalse(ExportFormat.pdf.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.rtf.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.plainText.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.word.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.html.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.epub.localizedName.isEmpty)
    }
    
    func testExportFormatIdentifiable() {
        let formats = ExportFormat.allCases
        
        // Each format should have a unique id
        let ids = Set(formats.map { $0.id })
        XCTAssertEqual(ids.count, formats.count)
    }
    
    func testExportFormatAllCases() {
        let allCases = ExportFormat.allCases
        
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.pdf))
        XCTAssertTrue(allCases.contains(.rtf))
        XCTAssertTrue(allCases.contains(.plainText))
        XCTAssertTrue(allCases.contains(.word))
        XCTAssertTrue(allCases.contains(.html))
        XCTAssertTrue(allCases.contains(.epub))
        XCTAssertTrue(allCases.contains(.markdown))
    }
}
