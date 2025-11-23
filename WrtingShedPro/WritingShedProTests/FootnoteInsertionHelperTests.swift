//
//  FootnoteInsertionHelperTests.swift
//  Writing Shed Pro Tests
//
//  Feature 015: Footnotes - Unit tests for FootnoteInsertionHelper
//

import XCTest
import SwiftData
import UIKit
@testable import Writing_Shed_Pro

@MainActor
final class FootnoteInsertionHelperTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testVersion: Version!
    
    override func setUpWithError() throws {
        // Create in-memory model container
        let schema = Schema([
            FootnoteModel.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        
        testVersion = Version(content: "Test content")
        modelContext.insert(testVersion)
    }
    
    override func tearDownWithError() throws {
        // Clean up all footnotes
        let fetchDescriptor = FetchDescriptor<FootnoteModel>()
        let footnotes = try? modelContext.fetch(fetchDescriptor)
        footnotes?.forEach { modelContext.delete($0) }
        try? modelContext.save()
        
        modelContext = nil
        testVersion = nil
    }
    
    // MARK: - Insert Footnote Tests
    
    func testInsertFootnoteInAttributedString() throws {
        let originalText = NSAttributedString(string: "Hello World")
        let position = 5 // After "Hello"
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: position,
            footnoteText: "Test footnote",
            version: testVersion,
            context: modelContext
        )
        
        // Check that footnote was created
        XCTAssertEqual(footnote.text, "Test footnote")
        XCTAssertEqual(footnote.version?.id, testVersion.id)
        XCTAssertEqual(footnote.characterPosition, position)
        XCTAssertEqual(footnote.number, 1)
        
        // Check that attachment was inserted
        XCTAssertEqual(resultString.length, originalText.length + 1) // +1 for attachment
        
        // Verify attachment exists at correct position
        let attachment = resultString.attribute(
            .attachment,
            at: position,
            effectiveRange: nil
        ) as? FootnoteAttachment
        
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.footnoteID, footnote.attachmentID)
        XCTAssertEqual(attachment?.number, 1)
    }
    
    func testInsertFootnoteAtStart() throws {
        let originalText = NSAttributedString(string: "Hello")
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 0,
            footnoteText: "Start footnote",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.characterPosition, 0)
        XCTAssertEqual(footnote.number, 1)
        XCTAssertEqual(resultString.length, 6) // 5 chars + 1 attachment
        
        // Attachment should be at position 0
        let attachment = resultString.attribute(.attachment, at: 0, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.number, 1)
    }
    
    func testInsertFootnoteAtEnd() throws {
        let originalText = NSAttributedString(string: "Hello")
        let position = originalText.length
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: position,
            footnoteText: "End footnote",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.characterPosition, position)
        XCTAssertEqual(footnote.number, 1)
        XCTAssertEqual(resultString.length, 6)
        
        // Attachment should be at the end
        let attachment = resultString.attribute(.attachment, at: 5, effectiveRange: nil) as? FootnoteAttachment
        XCTAssertNotNil(attachment)
    }
    
    func testInsertMultipleFootnotes() throws {
        let originalText = NSAttributedString(string: "Hello World")
        
        // Insert first footnote
        let (afterFirst, footnote1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 5,
            footnoteText: "First",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote1.number, 1)
        
        // Insert second footnote (adjust position for first attachment)
        let (final, footnote2) = FootnoteInsertionHelper.insertFootnote(
            in: afterFirst,
            at: 7, // After " W" including first attachment
            footnoteText: "Second",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote2.number, 2)
        XCTAssertEqual(final.length, 13) // 11 chars + 2 attachments
        
        // Verify both attachments exist
        let attachment1 = final.attribute(.attachment, at: 5, effectiveRange: nil) as? FootnoteAttachment
        let attachment2 = final.attribute(.attachment, at: 7, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertNotNil(attachment1)
        XCTAssertNotNil(attachment2)
        XCTAssertEqual(attachment1?.footnoteID, footnote1.attachmentID)
        XCTAssertEqual(attachment2?.footnoteID, footnote2.attachmentID)
        XCTAssertEqual(attachment1?.number, 1)
        XCTAssertEqual(attachment2?.number, 2)
    }
    
    func testInsertFootnotesOutOfOrder() throws {
        let originalText = NSAttributedString(string: "A B C D E")
        
        // Insert at position 6 (after "C ")
        let (afterFirst, footnote1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 6,
            footnoteText: "Second by position",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote1.number, 1)
        
        // Insert at position 2 (after "A ") - before the first footnote
        let (final, footnote2) = FootnoteInsertionHelper.insertFootnote(
            in: afterFirst,
            at: 2,
            footnoteText: "First by position",
            version: testVersion,
            context: modelContext
        )
        
        // Should be renumbered: footnote2 at position 2 becomes #1, footnote1 at position 6 becomes #2
        XCTAssertEqual(footnote2.number, 1)
        XCTAssertEqual(footnote1.number, 2)
    }
    
    // MARK: - Insert at Cursor Tests
    
    func testInsertFootnoteAtCursor() throws {
        let textView = UITextView()
        textView.text = "Hello World"
        textView.selectedRange = NSRange(location: 5, length: 0)
        
        let footnote = FootnoteInsertionHelper.insertFootnoteAtCursor(
            in: textView,
            footnoteText: "Cursor footnote",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertNotNil(footnote)
        XCTAssertEqual(footnote?.characterPosition, 5)
        XCTAssertEqual(footnote?.text, "Cursor footnote")
        XCTAssertEqual(footnote?.number, 1)
        
        // Verify attachment was inserted
        XCTAssertEqual(textView.textStorage.length, 12) // 11 chars + 1 attachment
        
        // Verify cursor moved after attachment
        XCTAssertEqual(textView.selectedRange.location, 6)
        XCTAssertEqual(textView.selectedRange.length, 0)
    }
    
    func testInsertFootnoteAtCursorStart() throws {
        let textView = UITextView()
        textView.text = "Hello"
        textView.selectedRange = NSRange(location: 0, length: 0)
        
        let footnote = FootnoteInsertionHelper.insertFootnoteAtCursor(
            in: textView,
            footnoteText: "Start",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertNotNil(footnote)
        XCTAssertEqual(footnote?.characterPosition, 0)
        
        // Cursor should move to position 1
        XCTAssertEqual(textView.selectedRange.location, 1)
    }
    
    func testInsertFootnoteAtCursorEnd() throws {
        let textView = UITextView()
        textView.text = "Hello"
        textView.selectedRange = NSRange(location: 5, length: 0)
        
        let footnote = FootnoteInsertionHelper.insertFootnoteAtCursor(
            in: textView,
            footnoteText: "End",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertNotNil(footnote)
        XCTAssertEqual(footnote?.characterPosition, 5)
        
        // Cursor should move to position 6
        XCTAssertEqual(textView.selectedRange.location, 6)
    }
    
    func testInsertMultipleFootnotesAtCursor() throws {
        let textView = UITextView()
        textView.text = "Hello World"
        
        // Insert first
        textView.selectedRange = NSRange(location: 5, length: 0)
        let footnote1 = FootnoteInsertionHelper.insertFootnoteAtCursor(
            in: textView,
            footnoteText: "First",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote1?.number, 1)
        XCTAssertEqual(textView.selectedRange.location, 6)
        
        // Insert second
        textView.selectedRange = NSRange(location: 8, length: 0)
        let footnote2 = FootnoteInsertionHelper.insertFootnoteAtCursor(
            in: textView,
            footnoteText: "Second",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote2?.number, 2)
        XCTAssertEqual(textView.textStorage.length, 13) // 11 + 2 attachments
    }
    
    // MARK: - Footnote Numbering Tests
    
    func testFootnoteNumberingSequential() throws {
        let originalText = NSAttributedString(string: "A B C D E")
        
        let (after1, fn1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 2,
            footnoteText: "One",
            version: testVersion,
            context: modelContext
        )
        
        let (after2, fn2) = FootnoteInsertionHelper.insertFootnote(
            in: after1,
            at: 5,
            footnoteText: "Two",
            version: testVersion,
            context: modelContext
        )
        
        let (_, fn3) = FootnoteInsertionHelper.insertFootnote(
            in: after2,
            at: 8,
            footnoteText: "Three",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(fn1.number, 1)
        XCTAssertEqual(fn2.number, 2)
        XCTAssertEqual(fn3.number, 3)
    }
    
    func testFootnoteNumberingWithInsertionInMiddle() throws {
        let originalText = NSAttributedString(string: "A B C D E")
        
        // Create footnotes at positions 2 and 8
        let (after1, fn1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 2,
            footnoteText: "First",
            version: testVersion,
            context: modelContext
        )
        
        let (after2, fn3) = FootnoteInsertionHelper.insertFootnote(
            in: after1,
            at: 9, // Adjusted for first attachment
            footnoteText: "Third",
            version: testVersion,
            context: modelContext
        )
        
        // Insert in the middle at position 5
        let (_, fn2) = FootnoteInsertionHelper.insertFootnote(
            in: after2,
            at: 5,
            footnoteText: "Second",
            version: testVersion,
            context: modelContext
        )
        
        // Should be renumbered by position
        XCTAssertEqual(fn1.number, 1) // Position 2
        XCTAssertEqual(fn2.number, 2) // Position 5
        XCTAssertEqual(fn3.number, 3) // Position 9
    }
    
    // MARK: - Bounds Checking Tests
    
    func testInsertFootnoteAtNegativePosition() throws {
        let originalText = NSAttributedString(string: "Hello")
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: -5,
            footnoteText: "Negative",
            version: testVersion,
            context: modelContext
        )
        
        // Should clamp to 0
        XCTAssertEqual(footnote.characterPosition, 0)
        XCTAssertEqual(resultString.length, 6)
    }
    
    func testInsertFootnoteBeyondLength() throws {
        let originalText = NSAttributedString(string: "Hello")
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 100,
            footnoteText: "Beyond",
            version: testVersion,
            context: modelContext
        )
        
        // Should clamp to length
        XCTAssertEqual(footnote.characterPosition, 5)
        XCTAssertEqual(resultString.length, 6)
    }
    
    // MARK: - Empty String Tests
    
    func testInsertFootnoteInEmptyString() throws {
        let originalText = NSAttributedString(string: "")
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 0,
            footnoteText: "Empty",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.characterPosition, 0)
        XCTAssertEqual(footnote.number, 1)
        XCTAssertEqual(resultString.length, 1) // Just the attachment
    }
    
    func testInsertFootnoteInEmptyTextView() throws {
        let textView = UITextView()
        textView.text = ""
        textView.selectedRange = NSRange(location: 0, length: 0)
        
        let footnote = FootnoteInsertionHelper.insertFootnoteAtCursor(
            in: textView,
            footnoteText: "Empty",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertNotNil(footnote)
        XCTAssertEqual(footnote?.characterPosition, 0)
        XCTAssertEqual(textView.textStorage.length, 1)
        XCTAssertEqual(textView.selectedRange.location, 1)
    }
    
    // MARK: - Long Text Tests
    
    func testInsertFootnoteWithLongText() throws {
        let longText = String(repeating: "This is a long footnote. ", count: 50)
        let originalText = NSAttributedString(string: "Hello World")
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 5,
            footnoteText: longText,
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.text, longText)
        XCTAssertEqual(resultString.length, 12)
    }
    
    // MARK: - Multiple Files Tests
    
    func testFootnoteNumberingIndependentAcrossFiles() throws {
        let text = NSAttributedString(string: "Hello")
        
        // Create a second version for testing
        let testVersion2 = Version(content: "Test content 2")
        modelContext.insert(testVersion2)
        
        // Insert in first file
        let (_, fn1) = FootnoteInsertionHelper.insertFootnote(
            in: text,
            at: 2,
            footnoteText: "File 1",
            version: testVersion,
            context: modelContext
        )
        
        // Insert in second file
        let (_, fn2) = FootnoteInsertionHelper.insertFootnote(
            in: text,
            at: 2,
            footnoteText: "File 2",
            version: testVersion2,
            context: modelContext
        )
        
        // Both should be numbered independently
        XCTAssertEqual(fn1.number, 1)
        XCTAssertEqual(fn2.number, 1)
        XCTAssertEqual(fn1.version?.id, testVersion.id)
        XCTAssertEqual(fn2.version?.id, testVersion2.id)
    }
    
    // MARK: - Attributed Text Preservation Tests
    
    func testInsertFootnotePreservesFormatting() throws {
        let mutableText = NSMutableAttributedString(string: "Hello World")
        
        // Add some formatting
        mutableText.addAttribute(
            .font,
            value: UIFont.boldSystemFont(ofSize: 20),
            range: NSRange(location: 0, length: 5)
        )
        mutableText.addAttribute(
            .foregroundColor,
            value: UIColor.red,
            range: NSRange(location: 6, length: 5)
        )
        
        let (resultString, _) = FootnoteInsertionHelper.insertFootnote(
            in: mutableText,
            at: 5,
            footnoteText: "Test",
            version: testVersion,
            context: modelContext
        )
        
        // Check that formatting is preserved
        let boldFont = resultString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(boldFont)
        
        // Red color should still be at position 7 (adjusted for attachment)
        let redColor = resultString.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(redColor)
    }
    
    // MARK: - Attachment Verification Tests
    
    func testFootnoteAttachmentHasCorrectID() throws {
        let originalText = NSAttributedString(string: "Hello")
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 3,
            footnoteText: "Test",
            version: testVersion,
            context: modelContext
        )
        
        let attachment = resultString.attribute(.attachment, at: 3, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertNotNil(attachment)
        XCTAssertEqual(attachment?.footnoteID, footnote.attachmentID)
    }
    
    func testFootnoteAttachmentHasCorrectNumber() throws {
        let originalText = NSAttributedString(string: "Hello")
        
        // Create first footnote
        let (after1, fn1) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 2,
            footnoteText: "First",
            version: testVersion,
            context: modelContext
        )
        
        // Create second footnote
        let (after2, fn2) = FootnoteInsertionHelper.insertFootnote(
            in: after1,
            at: 4,
            footnoteText: "Second",
            version: testVersion,
            context: modelContext
        )
        
        let attachment1 = after2.attribute(.attachment, at: 2, effectiveRange: nil) as? FootnoteAttachment
        let attachment2 = after2.attribute(.attachment, at: 4, effectiveRange: nil) as? FootnoteAttachment
        
        XCTAssertEqual(attachment1?.number, fn1.number)
        XCTAssertEqual(attachment2?.number, fn2.number)
    }
    
    // MARK: - Edge Cases
    
    func testInsertFootnoteWithEmptyFootnoteText() throws {
        let originalText = NSAttributedString(string: "Hello")
        
        let (resultString, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 3,
            footnoteText: "",
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.text, "")
        XCTAssertEqual(resultString.length, 6)
    }
    
    func testInsertFootnoteWithSpecialCharacters() throws {
        let originalText = NSAttributedString(string: "Hello")
        let specialText = "Test with émojis 😀 and spëcial çharacters"
        
        let (_, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 3,
            footnoteText: specialText,
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.text, specialText)
    }
    
    func testInsertFootnoteWithNewlines() throws {
        let originalText = NSAttributedString(string: "Hello")
        let multilineText = "Line 1\nLine 2\nLine 3"
        
        let (_, footnote) = FootnoteInsertionHelper.insertFootnote(
            in: originalText,
            at: 3,
            footnoteText: multilineText,
            version: testVersion,
            context: modelContext
        )
        
        XCTAssertEqual(footnote.text, multilineText)
    }
}
