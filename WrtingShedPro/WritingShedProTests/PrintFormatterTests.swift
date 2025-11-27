//
//  PrintFormatterTests.swift
//  Writing Shed Pro Tests
//
//  Tests for PrintFormatter service
//  Feature 020: Printing Support
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class PrintFormatterTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            StyleSheet.self,
            TextStyleModel.self,
            PageSetup.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Single File Formatting Tests
    
    func testFormatFile_WithValidContent_ReturnsAttributedString() throws {
        // Given: A text file with content
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "Test File", initialContent: "Hello, World!", parentFolder: folder)
        modelContext.insert(textFile)
        
        // When: Formatting the file
        let result = PrintFormatter.formatFile(textFile)
        
        // Then: Should return attributed string
        XCTAssertNotNil(result, "Should return attributed string")
        XCTAssertEqual(result?.string, "Hello, World!", "Content should match")
    }
    
    func testFormatFile_WithEmptyContent_ReturnsAttributedString() throws {
        // Given: A text file with empty content
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "Empty File", initialContent: "", parentFolder: folder)
        modelContext.insert(textFile)
        
        // When: Formatting the file
        let result = PrintFormatter.formatFile(textFile)
        
        // Then: Should return empty attributed string
        XCTAssertNotNil(result, "Should return attributed string even for empty content")
        XCTAssertEqual(result?.string, "", "Content should be empty")
    }
    
    func testFormatFile_WithNoCurrentVersion_ReturnsNil() throws {
        // Given: A text file with no versions
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "No Version File", initialContent: "", parentFolder: folder)
        textFile.versions = []
        modelContext.insert(textFile)
        
        // When: Formatting the file
        let result = PrintFormatter.formatFile(textFile)
        
        // Then: Should return nil
        XCTAssertNil(result, "Should return nil when no version exists")
    }
    
    // MARK: - Multiple File Formatting Tests
    
    func testFormatMultipleFiles_WithValidFiles_CombinesContent() throws {
        // Given: Multiple text files
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let file1 = TextFile(name: "File 1", initialContent: "First file", parentFolder: folder)
        let file2 = TextFile(name: "File 2", initialContent: "Second file", parentFolder: folder)
        let file3 = TextFile(name: "File 3", initialContent: "Third file", parentFolder: folder)
        
        modelContext.insert(file1)
        modelContext.insert(file2)
        modelContext.insert(file3)
        
        // When: Formatting multiple files
        let result = PrintFormatter.formatMultipleFiles([file1, file2, file3])
        
        // Then: Should combine all content with separators
        XCTAssertNotNil(result, "Should return combined attributed string")
        XCTAssertTrue(result!.string.contains("First file"), "Should contain first file content")
        XCTAssertTrue(result!.string.contains("Second file"), "Should contain second file content")
        XCTAssertTrue(result!.string.contains("Third file"), "Should contain third file content")
        XCTAssertTrue(result!.string.contains("\n\n"), "Should have separators between files")
    }
    
    func testFormatMultipleFiles_WithEmptyArray_ReturnsNil() throws {
        // Given: Empty file array
        let files: [TextFile] = []
        
        // When: Formatting multiple files
        let result = PrintFormatter.formatMultipleFiles(files)
        
        // Then: Should return nil
        XCTAssertNil(result, "Should return nil for empty file array")
    }
    
    func testFormatMultipleFiles_WithSingleFile_ReturnsContent() throws {
        // Given: Single text file
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let file = TextFile(name: "Single File", initialContent: "Only content", parentFolder: folder)
        modelContext.insert(file)
        
        // When: Formatting single file in array
        let result = PrintFormatter.formatMultipleFiles([file])
        
        // Then: Should return content without extra separators
        XCTAssertNotNil(result, "Should return attributed string")
        XCTAssertEqual(result?.string, "Only content", "Content should match without separators")
    }
    
    // MARK: - Platform Scaling Tests
    
    func testRemovePlatformScaling_ScalesFonts() throws {
        // Given: Attributed string with specific font size (Mac-rendered size)
        let originalFontSize: CGFloat = 22.1  // Mac-rendered font (17pt × 1.3)
        let font = UIFont.systemFont(ofSize: originalFontSize)
        let attributedString = NSAttributedString(
            string: "Test content",
            attributes: [.font: font]
        )
        
        // When: Removing platform scaling
        let result = PrintFormatter.removePlatformScaling(from: attributedString)
        
        // Then: Font size should be scaled down by 1.3 on both platforms
        // (Database stores Mac-rendered fonts, both platforms scale for print)
        var range = NSRange(location: 0, length: 0)
        if let resultFont = result.attribute(.font, at: 0, effectiveRange: &range) as? UIFont {
            let expectedSize = originalFontSize / 1.3  // 22.1pt → 17pt
            XCTAssertEqual(resultFont.pointSize, expectedSize, accuracy: 0.01, "Font should be scaled to print size (÷1.3)")
        } else {
            XCTFail("Result should have font attribute")
        }
    }
    
    func testRemovePlatformScaling_PreservesOtherAttributes() throws {
        // Given: Attributed string with multiple attributes
        let font = UIFont.systemFont(ofSize: 20.0)
        let color = UIColor.red
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributedString = NSAttributedString(
            string: "Test content",
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        // When: Removing platform scaling
        let result = PrintFormatter.removePlatformScaling(from: attributedString)
        
        // Then: Other attributes should be preserved
        var range = NSRange(location: 0, length: 0)
        let resultColor = result.attribute(.foregroundColor, at: 0, effectiveRange: &range) as? UIColor
        let resultParagraph = result.attribute(.paragraphStyle, at: 0, effectiveRange: &range) as? NSParagraphStyle
        
        XCTAssertEqual(resultColor, color, "Color should be preserved")
        XCTAssertEqual(resultParagraph?.alignment, .center, "Paragraph style should be preserved")
    }
    
    // MARK: - Validation Tests
    
    func testIsValidForPrinting_WithValidContent_ReturnsTrue() throws {
        // Given: Valid attributed string
        let attributedString = NSAttributedString(string: "Valid content")
        
        // When: Checking validity
        let result = PrintFormatter.isValidForPrinting(attributedString)
        
        // Then: Should return true
        XCTAssertTrue(result, "Valid content should be printable")
    }
    
    func testIsValidForPrinting_WithEmptyContent_ReturnsFalse() throws {
        // Given: Empty attributed string
        let attributedString = NSAttributedString(string: "")
        
        // When: Checking validity
        let result = PrintFormatter.isValidForPrinting(attributedString)
        
        // Then: Should return false
        XCTAssertFalse(result, "Empty content should not be printable")
    }
    
    func testIsValidForPrinting_WithNil_ReturnsFalse() throws {
        // Given: Nil attributed string
        let attributedString: NSAttributedString? = nil
        
        // When: Checking validity
        let result = PrintFormatter.isValidForPrinting(attributedString)
        
        // Then: Should return false
        XCTAssertFalse(result, "Nil content should not be printable")
    }
    
    // MARK: - Page Count Estimation Tests
    
    func testEstimatedPageCount_WithShortContent_ReturnsOnePageEstimate() throws {
        // Given: Short content and standard page setup
        let content = NSAttributedString(string: "Short content")
        let pageSetup = PageSetup()
        
        // When: Estimating page count
        let result = PrintFormatter.estimatedPageCount(for: content, pageSetup: pageSetup)
        
        // Then: Should estimate at least 1 page
        XCTAssertGreaterThanOrEqual(result, 1, "Should estimate at least 1 page")
    }
    
    func testEstimatedPageCount_WithLongContent_ReturnsMultiplePages() throws {
        // Given: Long content (3000 characters) and standard page setup
        let longText = String(repeating: "A", count: 3000)
        let content = NSAttributedString(string: longText)
        let pageSetup = PageSetup()
        
        // When: Estimating page count
        let result = PrintFormatter.estimatedPageCount(for: content, pageSetup: pageSetup)
        
        // Then: Should estimate multiple pages
        XCTAssertGreaterThan(result, 1, "Long content should estimate multiple pages")
    }
    
    // MARK: - Integration Tests
    
    func testFormatFile_WithFormattedContent_PreservesFormatting() throws {
        // Given: A text file with formatted content
        let project = Project(name: "Test Project")
        modelContext.insert(project)
        
        let folder = Folder(name: "Test Folder", project: project)
        modelContext.insert(folder)
        
        let textFile = TextFile(name: "Formatted File", initialContent: "Test", parentFolder: folder)
        
        // Create formatted content with bold text
        let mutableString = NSMutableAttributedString(string: "Bold text")
        let boldFont = UIFont.boldSystemFont(ofSize: 17.0)
        mutableString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))
        
        textFile.currentVersion?.attributedContent = mutableString
        modelContext.insert(textFile)
        
        // When: Formatting the file
        let result = PrintFormatter.formatFile(textFile)
        
        // Then: Should preserve bold formatting (after scaling)
        XCTAssertNotNil(result, "Should return formatted content")
        var range = NSRange(location: 0, length: 0)
        if let font = result?.attribute(.font, at: 0, effectiveRange: &range) as? UIFont {
            // Font traits should be preserved even if size changes
            let traits = font.fontDescriptor.symbolicTraits
            XCTAssertTrue(traits.contains(.traitBold), "Bold formatting should be preserved")
        }
    }
}
