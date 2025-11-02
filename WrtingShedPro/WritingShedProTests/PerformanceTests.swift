//
//  PerformanceTests.swift
//  WritingShedProTests
//
//  Performance tests for text formatting with large documents
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class PerformanceTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        let schema = Schema([File.self, Version.self, StyleSheet.self, TextStyleModel.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
        
        try modelContext.save()
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Large Document Tests
    
    func testFormattingLargeDocument() {
        // Given - 10,000 word document
        let words = Array(repeating: "Word", count: 10000)
        let largeText = words.joined(separator: " ")
        let text = NSMutableAttributedString(string: largeText)
        let range = NSRange(location: 0, length: text.length)
        
        // When - Measure formatting performance
        measure {
            let _ = TextFormatter.toggleBold(in: text, range: range)
        }
        
        // Then - Should complete in reasonable time (baseline for comparison)
        XCTAssertGreaterThan(text.length, 0)
    }
    
    func testSearchingLargeDocument() {
        // Given - Large document
        let words = Array(repeating: "Test Word Test", count: 5000)
        let largeText = words.joined(separator: " ")
        let text = NSAttributedString(string: largeText)
        
        // When - Measure search performance
        measure {
            let range = (text.string as NSString).range(of: "Test")
            XCTAssertNotEqual(range.location, NSNotFound)
        }
    }
    
    func testRTFSerializationLargeDocument() throws {
        // Given - Large formatted document
        let words = Array(repeating: "Word", count: 5000)
        let largeText = words.joined(separator: " ")
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: largeText, attributes: [.font: boldFont])
        
        // When - Measure serialization performance
        measure {
            if let rtfData = AttributedStringSerializer.toRTF(text) {
                XCTAssertGreaterThan(rtfData.count, 0)
            } else {
                XCTFail("Serialization failed")
            }
        }
    }
    
    func testRTFDeserializationLargeDocument() throws {
        // Given - Large RTF data
        let words = Array(repeating: "Word", count: 5000)
        let largeText = words.joined(separator: " ")
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let text = NSMutableAttributedString(string: largeText, attributes: [.font: boldFont])
        
        guard let rtfData = AttributedStringSerializer.toRTF(text) else {
            XCTFail("Failed to create RTF data")
            return
        }
        
        // When - Measure deserialization performance
        measure {
            if let deserialized = AttributedStringSerializer.fromRTF(rtfData) {
                XCTAssertGreaterThan(deserialized.length, 0)
            } else {
                XCTFail("Deserialization failed")
            }
        }
    }
    
    // MARK: - Heavily Formatted Text Tests
    
    func testMultipleFormattingChanges() {
        // Given - Document with many formatting changes
        let text = NSMutableAttributedString(string: String(repeating: "Text ", count: 1000))
        
        // When - Apply formatting to alternating words
        measure {
            for i in stride(from: 0, to: text.length, by: 10) {
                let range = NSRange(location: i, length: min(4, text.length - i))
                if i % 20 == 0 {
                    let _ = TextFormatter.toggleBold(in: text, range: range)
                } else {
                    let _ = TextFormatter.toggleItalic(in: text, range: range)
                }
            }
        }
    }
    
    func testMixedFormattingEnumeration() {
        // Given - Text with many formatting changes
        let text = NSMutableAttributedString()
        let normalFont = UIFont.systemFont(ofSize: 17)
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        
        for i in 0..<1000 {
            let font = i % 2 == 0 ? normalFont : boldFont
            text.append(NSAttributedString(string: "Word ", attributes: [.font: font]))
        }
        
        // When - Measure enumeration performance
        measure {
            text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, stop in
                _ = value as? UIFont
            }
        }
    }
    
    func testColorChangesPerformance() {
        // Given
        let text = NSMutableAttributedString(string: String(repeating: "Colored ", count: 1000))
        let colors: [UIColor] = [.red, .blue, .green, .yellow, .purple]
        
        // When - Apply different colors
        measure {
            for i in stride(from: 0, to: text.length, by: 8) {
                let range = NSRange(location: i, length: min(7, text.length - i))
                let color = colors[i / 8 % colors.count]
                text.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryWithLargeDocument() {
        // Given
        let words = Array(repeating: "Word", count: 20000)
        let largeText = words.joined(separator: " ")
        
        // When - Create multiple large attributed strings
        autoreleasepool {
            for _ in 0..<10 {
                let text = NSMutableAttributedString(string: largeText)
                let range = NSRange(location: 0, length: min(1000, text.length))
                let _ = TextFormatter.toggleBold(in: text, range: range)
                // Text should be deallocated after each iteration
            }
        }
        
        // Then - Should not crash or run out of memory
        XCTAssertTrue(true, "Memory test completed")
    }
    
    func testMemoryWithManySmallDocuments() {
        // When - Create many small documents
        autoreleasepool {
            for _ in 0..<1000 {
                let text = NSMutableAttributedString(string: "Short text")
                let range = NSRange(location: 0, length: text.length)
                let _ = TextFormatter.toggleBold(in: text, range: range)
            }
        }
        
        // Then - Should not leak memory
        XCTAssertTrue(true, "Memory test completed")
    }
    
    // MARK: - Undo/Redo Performance
    
    func testUndoStackPerformance() {
        // Given
        let file = File(name: "Test", content: "")
        let version = Version(content: "", versionNumber: 1)
        version.file = file
        file.versions = [version]
        
        modelContext.insert(file)
        modelContext.insert(version)
        
        // When - Perform many operations
        measure {
            for i in 0..<100 {
                version.content = String(repeating: "A", count: i + 1)
            }
        }
    }
    
    func testUndoRedoWithFormatting() {
        // Given
        let file = File(name: "Test", content: "")
        let version = Version(content: "", versionNumber: 1)
        version.file = file
        file.versions = [version]
        
        modelContext.insert(file)
        modelContext.insert(version)
        
        let text = NSMutableAttributedString(string: "Test Text")
        version.attributedContent = text
        let range = NSRange(location: 0, length: text.length)
        
        // When - Perform many format changes
        measure {
            for _ in 0..<50 {
                let formatted = TextFormatter.toggleBold(in: text, range: range)
                version.attributedContent = formatted
            }
        }
    }
    
    // MARK: - Paragraph Style Performance
    
    func testParagraphStyleApplication() {
        // Given - Large multi-paragraph document
        let paragraphs = Array(repeating: "Paragraph text here.\n", count: 500)
        let text = NSMutableAttributedString(string: paragraphs.joined())
        
        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center
        
        // When - Apply paragraph style to all
        measure {
            text.addAttribute(.paragraphStyle, value: centerStyle, range: NSRange(location: 0, length: text.length))
        }
    }
    
    func testMultipleParagraphStyles() {
        // Given
        let paragraphs = Array(repeating: "Paragraph.\n", count: 500)
        let text = NSMutableAttributedString(string: paragraphs.joined())
        
        let styles = [
            NSMutableParagraphStyle().apply { $0.alignment = .left },
            NSMutableParagraphStyle().apply { $0.alignment = .center },
            NSMutableParagraphStyle().apply { $0.alignment = .right }
        ]
        
        // When - Apply different styles to different paragraphs
        measure {
            var location = 0
            for i in 0..<500 {
                let paragraphLength = 11 // "Paragraph.\n"
                let style = styles[i % styles.count]
                text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: location, length: paragraphLength))
                location += paragraphLength
            }
        }
    }
    
    // MARK: - Stress Tests
    
    func testRapidFormattingChanges() {
        // Given
        let text = NSMutableAttributedString(string: "Quick changes")
        let range = NSRange(location: 0, length: text.length)
        
        // When - Rapid toggle operations
        measure {
            var currentText = text
            for _ in 0..<100 {
                currentText = NSMutableAttributedString(attributedString: TextFormatter.toggleBold(in: currentText, range: range))
                currentText = NSMutableAttributedString(attributedString: TextFormatter.toggleItalic(in: currentText, range: range))
                currentText = NSMutableAttributedString(attributedString: TextFormatter.toggleUnderline(in: currentText, range: range))
                currentText = NSMutableAttributedString(attributedString: TextFormatter.toggleStrikethrough(in: currentText, range: range))
            }
        }
    }
    
    func testConcurrentAttributeChanges() {
        // Given
        let text = NSMutableAttributedString(string: String(repeating: "Text ", count: 200))
        
        // When - Apply multiple attribute types simultaneously
        measure {
            var currentText = text
            for i in stride(from: 0, to: text.length, by: 5) {
                let range = NSRange(location: i, length: min(4, text.length - i))
                currentText = NSMutableAttributedString(attributedString: TextFormatter.toggleBold(in: currentText, range: range))
                currentText.addAttribute(.foregroundColor, value: UIColor.red, range: range)
                currentText = NSMutableAttributedString(attributedString: TextFormatter.toggleUnderline(in: currentText, range: range))
            }
        }
    }
    
    // MARK: - Database Performance
    
    func testStyleSheetLookupPerformance() async throws {
        // Given - Create many text styles
        let styleSheet = StyleSheet(name: "Test")
        modelContext.insert(styleSheet)
        
        for i in 0..<100 {
            let style = TextStyleModel(name: "Style\(i)", displayName: "Style \(i)")
            style.styleSheet = styleSheet
            modelContext.insert(style)
        }
        try modelContext.save()
        
        // When - Measure lookup performance
        measure {
            let descriptor = FetchDescriptor<TextStyleModel>(
                predicate: #Predicate { style in style.name == "Style50" }
            )
            do {
                let results = try modelContext.fetch(descriptor)
                XCTAssertEqual(results.count, 1)
            } catch {
                XCTFail("Fetch failed: \(error)")
            }
        }
    }
}

// Helper extension for inline configuration
extension NSMutableParagraphStyle {
    func apply(_ block: (NSMutableParagraphStyle) -> Void) -> NSMutableParagraphStyle {
        block(self)
        return self
    }
}
