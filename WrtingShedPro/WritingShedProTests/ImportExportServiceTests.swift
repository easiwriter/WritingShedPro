//
//  ImportExportServiceTests.swift
//  Writing Shed ProTests
//
//  Created on 6 December 2025.
//  Tests for RTF import/export functionality via WordDocumentService
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

@MainActor
final class ImportExportServiceTests: XCTestCase {
    
    var testFileURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
    }
    
    override func tearDown() async throws {
        // Clean up test files
        if let url = testFileURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        testFileURL = nil
        try await super.tearDown()
    }
    
    // MARK: - RTF Export Tests
    
    func testExportToRTF_BasicText() throws {
        // Create attributed string with plain text
        let text = "Hello, World!"
        let attributedString = NSAttributedString(string: text)
        
        // Export to RTF
        let rtfData = try WordDocumentService.exportToRTF(attributedString, filename: "test")
        
        // Verify data is not empty
        XCTAssertFalse(rtfData.isEmpty)
        
        // Verify it's valid RTF (starts with RTF header)
        if let rtfString = String(data: rtfData, encoding: .ascii) {
            XCTAssertTrue(rtfString.hasPrefix("{\\rtf1"))
        }
    }
    
    func testExportToRTF_FormattedText() throws {
        // Create attributed string with formatting
        let text = "Bold and Italic"
        let attrString = NSMutableAttributedString(string: text)
        
        // Add bold to "Bold"
        attrString.addAttribute(.font, 
                               value: UIFont.boldSystemFont(ofSize: 17),
                               range: NSRange(location: 0, length: 4))
        
        // Add italic to "Italic"
        attrString.addAttribute(.font,
                               value: UIFont.italicSystemFont(ofSize: 17),
                               range: NSRange(location: 9, length: 6))
        
        // Export to RTF
        let rtfData = try WordDocumentService.exportToRTF(attrString, filename: "formatted")
        
        // Verify data is not empty and is valid RTF
        XCTAssertFalse(rtfData.isEmpty)
        if let rtfString = String(data: rtfData, encoding: .ascii) {
            XCTAssertTrue(rtfString.hasPrefix("{\\rtf1"))
        }
    }
    
    func testExportToRTF_EmptyString() throws {
        // Create empty attributed string
        let attributedString = NSAttributedString(string: "")
        
        // Export to RTF
        let rtfData = try WordDocumentService.exportToRTF(attributedString, filename: "empty")
        
        // Verify data is not empty (RTF header exists even for empty content)
        XCTAssertFalse(rtfData.isEmpty)
        if let rtfString = String(data: rtfData, encoding: .ascii) {
            XCTAssertTrue(rtfString.hasPrefix("{\\rtf1"))
        }
    }
    
    // MARK: - RTF Import Tests
    
    func testImportRTF_BasicText() throws {
        // Create a simple RTF file
        let text = "Test import content"
        let attributedString = NSAttributedString(string: text)
        let rtfData = try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        
        // Write to temporary file
        testFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_import.rtf")
        try rtfData.write(to: testFileURL)
        
        // Import the RTF
        let (plainText, rtfStorageData, filename) = try WordDocumentService.importWordDocument(from: testFileURL)
        
        // Verify results
        XCTAssertEqual(plainText, text)
        XCTAssertNotNil(rtfStorageData)
        XCTAssertEqual(filename, "test_import")
    }
    
    func testImportRTF_FormattedText() throws {
        // Create RTF with formatting
        let text = "Formatted Text"
        let attrString = NSMutableAttributedString(string: text)
        attrString.addAttribute(.font,
                               value: UIFont.boldSystemFont(ofSize: 17),
                               range: NSRange(location: 0, length: 9))
        
        let rtfData = try attrString.data(
            from: NSRange(location: 0, length: attrString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        
        // Write to temporary file
        testFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("formatted.rtf")
        try rtfData.write(to: testFileURL)
        
        // Import the RTF
        let (plainText, rtfStorageData, filename) = try WordDocumentService.importWordDocument(from: testFileURL)
        
        // Verify results
        XCTAssertEqual(plainText, text)
        XCTAssertNotNil(rtfStorageData)
        XCTAssertEqual(filename, "formatted")
        XCTAssertFalse(rtfStorageData!.isEmpty)
    }
    
    func testImportRTF_InvalidFile() throws {
        // Create invalid RTF file
        testFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid.rtf")
        let invalidData = "Not valid RTF".data(using: .utf8)!
        try invalidData.write(to: testFileURL)
        
        // Attempt to import should throw
        XCTAssertThrowsError(try WordDocumentService.importWordDocument(from: testFileURL))
    }
    
    func testImportDOCX_RejectsWithError() throws {
        // Create a fake .docx file (invalid format)
        testFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.docx")
        let fakeData = "Not a real docx".data(using: .utf8)!
        try fakeData.write(to: testFileURL)
        
        // Attempt to import invalid DOCX should throw error
        XCTAssertThrowsError(try WordDocumentService.importWordDocument(from: testFileURL)) { error in
            // Should get a parsing error since it's not valid DOCX
            XCTAssertNotNil(error)
        }
    }
    
    func testImportValidDOCX_Success() throws {
        // Create a valid DOCX file
        let helper = DOCXExportHelper()
        let attrString = NSAttributedString(string: "Test content")
        let docXML = helper.createDocumentXML(withAttributedString: attrString)
        let docxData = try helper.createDOCXPackage(documentXML: docXML)
        
        testFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("valid_test.docx")
        try docxData.write(to: testFileURL)
        
        // Import should succeed
        let result = try WordDocumentService.importWordDocument(from: testFileURL)
        
        XCTAssertTrue(result.plainText.contains("Test content"))
        XCTAssertNotNil(result.rtfData)
        XCTAssertEqual(result.filename, "valid_test")
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTrip_PlainText() throws {
        // Create original content
        let originalText = "This is a round-trip test"
        let originalAttrString = NSAttributedString(string: originalText)
        
        // Export to RTF
        let rtfData = try WordDocumentService.exportToRTF(originalAttrString, filename: "roundtrip")
        
        // Write to file
        testFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip.rtf")
        try rtfData.write(to: testFileURL)
        
        // Import back
        let (plainText, _, _) = try WordDocumentService.importWordDocument(from: testFileURL)
        
        // Verify text matches
        XCTAssertEqual(plainText, originalText)
    }
    
    func testRoundTrip_FormattedText() throws {
        // Create formatted content
        let text = "Bold Italic Normal"
        let attrString = NSMutableAttributedString(string: text)
        
        // Add bold
        attrString.addAttribute(.font,
                               value: UIFont.boldSystemFont(ofSize: 17),
                               range: NSRange(location: 0, length: 4))
        
        // Add italic
        attrString.addAttribute(.font,
                               value: UIFont.italicSystemFont(ofSize: 17),
                               range: NSRange(location: 5, length: 6))
        
        // Export to RTF
        let rtfData = try WordDocumentService.exportToRTF(attrString, filename: "formatted_roundtrip")
        
        // Write to file
        testFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("formatted_roundtrip.rtf")
        try rtfData.write(to: testFileURL)
        
        // Import back
        let (plainText, rtfStorageData, _) = try WordDocumentService.importWordDocument(from: testFileURL)
        
        // Verify text matches
        XCTAssertEqual(plainText, text)
        
        // Verify formatting is preserved (RTF data should not be nil)
        XCTAssertNotNil(rtfStorageData)
        XCTAssertFalse(rtfStorageData!.isEmpty)
    }
    
    // MARK: - exportToWordDocument Tests (fallback to RTF)
    
    func testExportToWordDocument_FallsBackToRTF() throws {
        // Create test content
        let text = "Test content"
        let attributedString = NSAttributedString(string: text)
        
        // Call exportToWordDocument (should fall back to RTF)
        let data = try WordDocumentService.exportToWordDocument(attributedString, filename: "test")
        
        // Verify it's RTF data
        XCTAssertFalse(data.isEmpty)
        if let rtfString = String(data: data, encoding: .ascii) {
            XCTAssertTrue(rtfString.hasPrefix("{\\rtf1"))
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testError_ExportFailed() {
        let error = WordDocumentError.exportFailed("Test error")
        XCTAssertEqual(error.errorDescription, "Failed to export Word document: Test error")
    }
    
    func testError_ImportFailed() {
        let error = WordDocumentError.importFailed("Test error")
        XCTAssertEqual(error.errorDescription, "Failed to import Word document: Test error")
    }
}
