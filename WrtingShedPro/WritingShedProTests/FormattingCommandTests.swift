import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class FormattingCommandTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testFile: File!
    var undoManager: TextFileUndoManager!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([Project.self, Folder.self, File.self, Version.self, TextFile.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
            
            // Create test file with attributed content
            testFile = File(name: "Test File", content: "Hello World")
            modelContext.insert(testFile)
            
            // Create undo manager
            undoManager = TextFileUndoManager(file: testFile)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    override func tearDown() {
        undoManager = nil
        testFile = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Create an attributed string with default font
    private func createAttributedString(_ text: String) -> NSAttributedString {
        return NSAttributedString(
            string: text,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
    }
    
    /// Check if text in range has bold trait
    private func isBold(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        guard range.location + range.length <= attributedString.length else { return false }
        let attributes = attributedString.attributes(at: range.location, effectiveRange: nil)
        guard let font = attributes[.font] as? UIFont else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    /// Check if text in range has italic trait
    private func isItalic(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        guard range.location + range.length <= attributedString.length else { return false }
        let attributes = attributedString.attributes(at: range.location, effectiveRange: nil)
        guard let font = attributes[.font] as? UIFont else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    /// Check if text in range is underlined
    private func isUnderlined(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        guard range.location + range.length <= attributedString.length else { return false }
        let attributes = attributedString.attributes(at: range.location, effectiveRange: nil)
        return (attributes[.underlineStyle] as? Int ?? 0) > 0
    }
    
    /// Check if text in range has strikethrough
    private func isStrikethrough(in attributedString: NSAttributedString, range: NSRange) -> Bool {
        guard range.location + range.length <= attributedString.length else { return false }
        let attributes = attributedString.attributes(at: range.location, effectiveRange: nil)
        return (attributes[.strikethroughStyle] as? Int ?? 0) > 0
    }
    
    // MARK: - FormatApplyCommand Execution Tests
    
    func testFormatApplyCommand_ExecuteAddsBoldFormatting() {
        // Given: "Hello World" with no formatting
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // Apply bold to "Hello"
        let range = NSRange(location: 0, length: 5)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        // When: Execute FormatApplyCommand
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then: "Hello" should be bold
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: NSRange(location: 0, length: 5)), "First word should be bold")
        XCTAssertFalse(isBold(in: result, range: NSRange(location: 6, length: 5)), "Second word should not be bold")
    }
    
    func testFormatApplyCommand_ExecuteAddsItalicFormatting() {
        // Given
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // Apply italic to "World"
        let range = NSRange(location: 6, length: 5)
        let formattedContent = TextFormatter.toggleItalic(in: originalContent, range: range)
        
        // When
        let command = FormatApplyCommand(
            description: "Italic",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isItalic(in: result, range: NSRange(location: 6, length: 5)), "Second word should be italic")
        XCTAssertFalse(isItalic(in: result, range: NSRange(location: 0, length: 5)), "First word should not be italic")
    }
    
    func testFormatApplyCommand_ExecuteAddsUnderline() {
        // Given
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // Apply underline to "Hello"
        let range = NSRange(location: 0, length: 5)
        let formattedContent = TextFormatter.toggleUnderline(in: originalContent, range: range)
        
        // When
        let command = FormatApplyCommand(
            description: "Underline",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isUnderlined(in: result, range: NSRange(location: 0, length: 5)), "First word should be underlined")
        XCTAssertFalse(isUnderlined(in: result, range: NSRange(location: 6, length: 5)), "Second word should not be underlined")
    }
    
    func testFormatApplyCommand_ExecuteAddsStrikethrough() {
        // Given
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // Apply strikethrough to "World"
        let range = NSRange(location: 6, length: 5)
        let formattedContent = TextFormatter.toggleStrikethrough(in: originalContent, range: range)
        
        // When
        let command = FormatApplyCommand(
            description: "Strikethrough",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isStrikethrough(in: result, range: NSRange(location: 6, length: 5)), "Second word should have strikethrough")
        XCTAssertFalse(isStrikethrough(in: result, range: NSRange(location: 0, length: 5)), "First word should not have strikethrough")
    }
    
    func testFormatApplyCommand_ToggleRemovesFormatting() {
        // Given: "Hello" already bold
        let originalContent = createAttributedString("Hello World")
        let boldContent = TextFormatter.toggleBold(in: originalContent, range: NSRange(location: 0, length: 5))
        testFile.currentVersion?.attributedContent = boldContent
        
        XCTAssertTrue(isBold(in: boldContent, range: NSRange(location: 0, length: 5)), "Should start bold")
        
        // When: Toggle bold off
        let range = NSRange(location: 0, length: 5)
        let unboldContent = TextFormatter.toggleBold(in: boldContent, range: range)
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: boldContent,
            afterContent: unboldContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then: "Hello" should not be bold anymore
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertFalse(isBold(in: result, range: NSRange(location: 0, length: 5)), "Bold should be removed")
    }
    
    // MARK: - Undo/Redo Tests
    
    func testFormatApplyCommand_UndoRestoresOriginal() {
        // Given: Apply bold formatting
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        let range = NSRange(location: 0, length: 5)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Verify bold was applied
        XCTAssertTrue(isBold(in: testFile.currentVersion?.attributedContent ?? NSAttributedString(), range: range))
        
        // When: Undo
        command.undo()
        
        // Then: Should restore to non-bold
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertFalse(isBold(in: result, range: range), "Undo should remove bold")
        XCTAssertEqual(result.string, "Hello World", "Text should be unchanged")
    }
    
    func testFormatApplyCommand_RedoReappliesFormatting() {
        // Given: Apply and undo bold
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        let range = NSRange(location: 0, length: 5)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        command.undo()
        
        // When: Redo
        command.execute()
        
        // Then: Bold should be reapplied
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: range), "Redo should reapply bold")
    }
    
    func testFormatApplyCommand_MultipleUndoRedoSequence() {
        // Simplified test: just verify the command's undo/redo works correctly
        // Given: Start with plain text
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // Step 1: Apply bold to "Hello"
        let boldRange = NSRange(location: 0, length: 5)
        let boldContent = TextFormatter.toggleBold(in: originalContent, range: boldRange)
        let boldCommand = FormatApplyCommand(
            description: "Bold",
            range: boldRange,
            beforeContent: originalContent,
            afterContent: boldContent,
            targetFile: testFile
        )
        boldCommand.execute()
        
        // Verify bold was applied
        var result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: boldRange), "Hello should be bold after execute")
        
        // Step 2: Apply italic to "World"
        let italicRange = NSRange(location: 6, length: 5)
        let stateBeforeItalic = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        let italicContent = TextFormatter.toggleItalic(in: stateBeforeItalic, range: italicRange)
        let italicCommand = FormatApplyCommand(
            description: "Italic",
            range: italicRange,
            beforeContent: stateBeforeItalic,
            afterContent: italicContent,
            targetFile: testFile
        )
        italicCommand.execute()
        
        // Verify both formats exist
        result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: boldRange), "Hello should be bold")
        XCTAssertTrue(isItalic(in: result, range: italicRange), "World should be italic")
        
        // Step 3: Undo italic - should restore to stateBeforeItalic
        italicCommand.undo()
        result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        
        XCTAssertTrue(isBold(in: result, range: boldRange), "Hello should still be bold after undo")
        XCTAssertFalse(isItalic(in: result, range: italicRange), "World should not be italic after undo")
        
        // Step 4: Undo bold
        boldCommand.undo()
        result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertFalse(isBold(in: result, range: boldRange), "Hello should not be bold after undo")
        
        // Step 5: Redo bold
        boldCommand.execute()
        result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: boldRange), "Hello should be bold after redo")
        
        // Step 6: Redo italic
        italicCommand.execute()
        result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isItalic(in: result, range: italicRange), "World should be italic after redo")
    }
    
    func testFormatApplyCommand_NotificationSentOnUndo() {
        // Given: Command that posts notification on undo
        let expectation = XCTestExpectation(description: "Notification should be posted")
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UndoRedoContentRestored"),
            object: nil,
            queue: .main
        ) { notification in
            if let content = notification.userInfo?["content"] as? NSAttributedString {
                XCTAssertEqual(content.string, "Hello World")
                expectation.fulfill()
            }
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        let range = NSRange(location: 0, length: 5)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // When: Undo
        command.undo()
        
        // Then: Notification should be posted
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Mixed Formatting Tests
    
    func testMixedFormatting_BoldAndItalic() {
        // Given: Text with no formatting
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply both bold and italic to same range
        let range = NSRange(location: 0, length: 5)
        let boldContent = TextFormatter.toggleBold(in: originalContent, range: range)
        let boldItalicContent = TextFormatter.toggleItalic(in: boldContent, range: range)
        
        let boldCommand = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: boldContent,
            targetFile: testFile
        )
        boldCommand.execute()
        
        let italicCommand = FormatApplyCommand(
            description: "Italic",
            range: range,
            beforeContent: boldContent,
            afterContent: boldItalicContent,
            targetFile: testFile
        )
        italicCommand.execute()
        
        // Then: Text should have both bold and italic
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: range), "Should be bold")
        XCTAssertTrue(isItalic(in: result, range: range), "Should be italic")
    }
    
    func testMixedFormatting_UnderlineAndStrikethrough() {
        // Given: Plain text
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply underline and strikethrough
        let range = NSRange(location: 6, length: 5)
        let underlineContent = TextFormatter.toggleUnderline(in: originalContent, range: range)
        let bothContent = TextFormatter.toggleStrikethrough(in: underlineContent, range: range)
        
        let underlineCommand = FormatApplyCommand(
            description: "Underline",
            range: range,
            beforeContent: originalContent,
            afterContent: underlineContent,
            targetFile: testFile
        )
        underlineCommand.execute()
        
        let strikeCommand = FormatApplyCommand(
            description: "Strikethrough",
            range: range,
            beforeContent: underlineContent,
            afterContent: bothContent,
            targetFile: testFile
        )
        strikeCommand.execute()
        
        // Then: Should have both
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isUnderlined(in: result, range: range), "Should be underlined")
        XCTAssertTrue(isStrikethrough(in: result, range: range), "Should have strikethrough")
    }
    
    func testMixedFormatting_AllFormatsAtOnce() {
        // Given: Plain text
        let originalContent = createAttributedString("Test")
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply all four formats
        let range = NSRange(location: 0, length: 4)
        var content = originalContent
        content = TextFormatter.toggleBold(in: content, range: range)
        content = TextFormatter.toggleItalic(in: content, range: range)
        content = TextFormatter.toggleUnderline(in: content, range: range)
        content = TextFormatter.toggleStrikethrough(in: content, range: range)
        
        testFile.currentVersion?.attributedContent = content
        
        // Then: All formats should be present
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: range), "Should be bold")
        XCTAssertTrue(isItalic(in: result, range: range), "Should be italic")
        XCTAssertTrue(isUnderlined(in: result, range: range), "Should be underlined")
        XCTAssertTrue(isStrikethrough(in: result, range: range), "Should have strikethrough")
    }
    
    // MARK: - Edge Case Tests
    
    func testFormatApplyCommand_AtDocumentStart() {
        // Given: Format at position 0
        let originalContent = createAttributedString("Hello")
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply bold to first character
        let range = NSRange(location: 0, length: 1)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then: Should work correctly
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: range), "First character should be bold")
    }
    
    func testFormatApplyCommand_AtDocumentEnd() {
        // Given: Format at end of document
        let originalContent = createAttributedString("Hello")
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply bold to last character
        let range = NSRange(location: 4, length: 1)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then: Should work correctly
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: range), "Last character should be bold")
    }
    
    func testFormatApplyCommand_EntireDocument() {
        // Given: Format entire document
        let originalContent = createAttributedString("Hello World")
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply bold to entire string
        let range = NSRange(location: 0, length: originalContent.length)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then: Entire document should be bold
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertTrue(isBold(in: result, range: NSRange(location: 0, length: 5)), "First word should be bold")
        XCTAssertTrue(isBold(in: result, range: NSRange(location: 6, length: 5)), "Second word should be bold")
    }
    
    func testFormatApplyCommand_PreservesTextContent() {
        // Given: Original text
        let originalText = "Hello World"
        let originalContent = createAttributedString(originalText)
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply formatting
        let range = NSRange(location: 0, length: 5)
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then: Text should be unchanged, only formatting changed
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertEqual(result.string, originalText, "Text content should be preserved")
    }
    
    func testFormatApplyCommand_WithEmojiAndUnicode() {
        // Given: Text with emoji
        let originalContent = createAttributedString("Hello 👋 World 🌍")
        testFile.currentVersion?.attributedContent = originalContent
        
        // When: Apply bold to emoji
        let range = NSRange(location: 6, length: 2)  // The 👋 emoji
        let formattedContent = TextFormatter.toggleBold(in: originalContent, range: range)
        
        let command = FormatApplyCommand(
            description: "Bold",
            range: range,
            beforeContent: originalContent,
            afterContent: formattedContent,
            targetFile: testFile
        )
        command.execute()
        
        // Then: Should handle unicode correctly
        let result = testFile.currentVersion?.attributedContent ?? NSAttributedString()
        XCTAssertEqual(result.string, "Hello 👋 World 🌍", "Should preserve emoji")
        XCTAssertTrue(isBold(in: result, range: range), "Emoji should be bold")
    }
}
