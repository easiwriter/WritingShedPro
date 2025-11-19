//
//  FormattingUndoRedoTests.swift
//  WritingShedProTests
//
//  Tests for formatting operations with undo/redo using TextFileUndoManager
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class FormattingUndoRedoTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testFile: TextFile!
    var version: Version!
    var undoManager: TextFileUndoManager!
    
    override func setUp() async throws {
        // Create in-memory model container for testing
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Create test file with version
        testFile = TextFile(name: "Test File", initialContent: "")
        version = Version(content: "", versionNumber: 1)
        version.textFile = testFile
        testFile.versions = [version]
        
        modelContext.insert(testFile)
        modelContext.insert(version)
        
        // Create undo manager
        undoManager = TextFileUndoManager(file: testFile)
        
        try modelContext.save()
    }
    
    override func tearDown() {
        undoManager = nil
        version = nil
        testFile = nil
        modelContext = nil
        modelContainer = nil
    }
    
    // MARK: - Bold Formatting Undo/Redo
    
    func testBoldFormatUndoRedo() {
        // Given - Initial attributed content
        let normalFont = UIFont.systemFont(ofSize: 17)
        let initialText = NSMutableAttributedString(string: "Hello", attributes: [.font: normalFont])
        version.attributedContent = initialText
        
        // When - Apply bold formatting
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let boldText = NSMutableAttributedString(attributedString: initialText)
        boldText.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5))
        
        // Apply the formatting to the version FIRST (simulating UI change)
        version.attributedContent = boldText
        
        // Then create and register the command
        let command = FormatApplyCommand(
            description: "Apply Bold",
            range: NSRange(location: 0, length: 5),
            beforeContent: initialText,
            afterContent: boldText,
            targetFile: testFile
        )
        undoManager.execute(command)
        
        // Then - Should be bold
        let boldContent = version.attributedContent
        let boldAttribute = boldContent?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(boldAttribute?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        
        // When - Undo
        undoManager.undo()
        
        // Then - Should return to normal
        let normalContent = version.attributedContent
        let normalAttribute = normalContent?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertFalse(normalAttribute?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        
        // When - Redo
        undoManager.redo()
        
        // Then - Should be bold again
        let redoContent = version.attributedContent
        let redoAttribute = redoContent?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(redoAttribute?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }
    
    // MARK: - Multiple Formatting Changes
    
    func testMultipleFormattingChangesUndo() {
        // Given
        let normalFont = UIFont.systemFont(ofSize: 17)
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        
        let text1 = NSMutableAttributedString(string: "Text", attributes: [.font: normalFont])
        version.attributedContent = text1
        
        // Apply bold
        let text2 = NSMutableAttributedString(attributedString: text1)
        text2.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))
        version.attributedContent = text2  // Apply to version first
        let command1 = FormatApplyCommand(
            description: "Apply Bold",
            range: NSRange(location: 0, length: 4),
            beforeContent: text1,
            afterContent: text2,
            targetFile: testFile
        )
        undoManager.execute(command1)
        
        // Apply italic (overriding bold)
        let text3 = NSMutableAttributedString(attributedString: text2)
        text3.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: 4))
        version.attributedContent = text3  // Apply to version first
        let command2 = FormatApplyCommand(
            description: "Apply Italic",
            range: NSRange(location: 0, length: 4),
            beforeContent: text2,
            afterContent: text3,
            targetFile: testFile
        )
        undoManager.execute(command2)
        
        // When - Undo twice
        undoManager.undo()
        undoManager.undo()
        
        // Then - Should be back to normal
        let finalContent = version.attributedContent
        let finalFont = finalContent?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertFalse(finalFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertFalse(finalFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? true)
    }
    
    // MARK: - Partial Format Removal
    
    func testPartialFormatRemoval() {
        // Given - All text bold
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let normalFont = UIFont.systemFont(ofSize: 17)
        
        let text1 = NSMutableAttributedString(string: "Hello World", attributes: [.font: boldFont])
        version.attributedContent = text1
        
        // When - Remove bold from "World"
        let text2 = NSMutableAttributedString(attributedString: text1)
        text2.addAttribute(.font, value: normalFont, range: NSRange(location: 6, length: 5))
        version.attributedContent = text2  // Apply to version first
        
        let command = FormatApplyCommand(
            description: "Remove Bold",
            range: NSRange(location: 6, length: 5),
            beforeContent: text1,
            afterContent: text2,
            targetFile: testFile
        )
        undoManager.execute(command)
        
        // Verify mixed formatting
        var content = version.attributedContent
        var helloFont = content?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        var worldFont = content?.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        XCTAssertTrue(helloFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertFalse(worldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        
        // When - Undo
        undoManager.undo()
        
        // Then - All should be bold again
        content = version.attributedContent
        helloFont = content?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        worldFont = content?.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        XCTAssertTrue(helloFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        XCTAssertTrue(worldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }
    
    // MARK: - Color Change Undo/Redo
    
    func testColorChangeUndoRedo() {
        // Given - Use a custom color and red (adaptive colors like black are now stripped)
        let cyanColor = UIColor(red: 0.00392157, green: 0.780392, blue: 0.988235, alpha: 1) // Custom color
        let redColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        let font = UIFont.systemFont(ofSize: 17)
        
        let text1 = NSMutableAttributedString(string: "Text", attributes: [
            .font: font,
            .foregroundColor: cyanColor
        ])
        version.attributedContent = text1
        
        // When - Change to red
        let text2 = NSMutableAttributedString(attributedString: text1)
        text2.addAttribute(.foregroundColor, value: redColor, range: NSRange(location: 0, length: 4))
        version.attributedContent = text2  // Apply to version first
        
        let command = FormatApplyCommand(
            description: "Change Color",
            range: NSRange(location: 0, length: 4),
            beforeContent: text1,
            afterContent: text2,
            targetFile: testFile
        )
        undoManager.execute(command)
        
        var content = version.attributedContent
        var color = content?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, redColor)
        
        // When - Undo
        undoManager.undo()
        
        // Then - Should be cyan (the original custom color)
        content = version.attributedContent
        color = content?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color, "Color should be restored")
        // Compare RGB components (both colors are in extended sRGB color space)
        XCTAssertEqual(color?.cgColor.components?[0] ?? 0, 0.00392157, accuracy: 0.01, "Red component should match cyan")
        XCTAssertEqual(color?.cgColor.components?[1] ?? 0, 0.780392, accuracy: 0.01, "Green component should match cyan")
        XCTAssertEqual(color?.cgColor.components?[2] ?? 0, 0.988235, accuracy: 0.01, "Blue component should match cyan")
        
        // When - Redo
        undoManager.redo()
        
        // Then - Should be red again
        content = version.attributedContent
        color = content?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, redColor)
    }
    
    // MARK: - Paragraph Style Undo/Redo
    
    func testParagraphStyleUndoRedo() {
        // Given
        let leftStyle = NSMutableParagraphStyle()
        leftStyle.alignment = .left
        
        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center
        
        let font = UIFont.systemFont(ofSize: 17)
        let text1 = NSMutableAttributedString(string: "Paragraph", attributes: [
            .font: font,
            .paragraphStyle: leftStyle
        ])
        version.attributedContent = text1
        
        // When - Change to center
        let text2 = NSMutableAttributedString(attributedString: text1)
        text2.addAttribute(.paragraphStyle, value: centerStyle, range: NSRange(location: 0, length: 9))
        version.attributedContent = text2  // Apply to version first
        
        let command = FormatApplyCommand(
            description: "Change Alignment",
            range: NSRange(location: 0, length: 9),
            beforeContent: text1,
            afterContent: text2,
            targetFile: testFile
        )
        undoManager.execute(command)
        
        var content = version.attributedContent
        var style = content?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .center)
        
        // When - Undo
        undoManager.undo()
        
        // Then - Should be left aligned
        content = version.attributedContent
        style = content?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .left)
        
        // When - Redo
        undoManager.redo()
        
        // Then - Should be centered again
        content = version.attributedContent
        style = content?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.alignment, .center)
    }
    
    // MARK: - Underline/Strikethrough Undo
    
    func testUnderlineStrikethroughUndo() {
        // Given
        let font = UIFont.systemFont(ofSize: 17)
        let text1 = NSMutableAttributedString(string: "Text", attributes: [.font: font])
        version.attributedContent = text1
        
        // Apply underline
        let text2 = NSMutableAttributedString(attributedString: text1)
        text2.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: 4))
        version.attributedContent = text2  // Apply to version first
        let command1 = FormatApplyCommand(
            description: "Apply Underline",
            range: NSRange(location: 0, length: 4),
            beforeContent: text1,
            afterContent: text2,
            targetFile: testFile
        )
        undoManager.execute(command1)
        
        // Apply strikethrough
        let text3 = NSMutableAttributedString(attributedString: text2)
        text3.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: 4))
        version.attributedContent = text3  // Apply to version first
        let command2 = FormatApplyCommand(
            description: "Apply Strikethrough",
            range: NSRange(location: 0, length: 4),
            beforeContent: text2,
            afterContent: text3,
            targetFile: testFile
        )
        undoManager.execute(command2)
        
        var content = version.attributedContent
        var underline = content?.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        var strike = content?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
        
        // When - Undo strikethrough
        undoManager.undo()
        
        content = version.attributedContent
        underline = content?.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        strike = content?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
        XCTAssertNil(strike)
        
        // When - Undo underline
        undoManager.undo()
        
        content = version.attributedContent
        underline = content?.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertNil(underline)
    }
    
    // MARK: - Mixed Text and Formatting
    
    func testMixedTextAndFormattingUndo() {
        // Given - Start with text
        let normalFont = UIFont.systemFont(ofSize: 17)
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        
        let text1 = NSMutableAttributedString(string: "Hello", attributes: [.font: normalFont])
        version.attributedContent = text1
        
        // Make it bold
        let text2 = NSMutableAttributedString(attributedString: text1)
        text2.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5))
        version.attributedContent = text2  // Apply to version first
        let command1 = FormatApplyCommand(
            description: "Apply Bold",
            range: NSRange(location: 0, length: 5),
            beforeContent: text1,
            afterContent: text2,
            targetFile: testFile
        )
        undoManager.execute(command1)
        
        // Add more text (using text insertion command)
        let text3 = NSMutableAttributedString(attributedString: text2)
        text3.append(NSAttributedString(string: " World", attributes: [.font: boldFont]))
        version.attributedContent = text3  // Apply to version first
        let command2 = FormatApplyCommand(
            description: "Add Text",
            range: NSRange(location: 0, length: 11),
            beforeContent: text2,
            afterContent: text3,
            targetFile: testFile
        )
        undoManager.execute(command2)
        
        XCTAssertEqual(version.attributedContent?.string, "Hello World")
        
        // When - Undo text addition
        undoManager.undo()
        XCTAssertEqual(version.attributedContent?.string, "Hello")
        
        // When - Undo formatting
        undoManager.undo()
        
        // Then - Should be normal text
        let content = version.attributedContent
        let font = content?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertFalse(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertEqual(content?.string, "Hello")
    }
    
    // MARK: - Undo/Redo Stack Management
    
    func testFormattingClearsRedoStack() {
        // Given
        let normalFont = UIFont.systemFont(ofSize: 17)
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        
        let text1 = NSMutableAttributedString(string: "Text", attributes: [.font: normalFont])
        version.attributedContent = text1
        
        // Apply bold
        let text2 = NSMutableAttributedString(attributedString: text1)
        text2.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 4))
        version.attributedContent = text2  // Apply to version first
        let command1 = FormatApplyCommand(
            description: "Apply Bold",
            range: NSRange(location: 0, length: 4),
            beforeContent: text1,
            afterContent: text2,
            targetFile: testFile
        )
        undoManager.execute(command1)
        
        // Undo
        undoManager.undo()
        XCTAssertTrue(undoManager.canRedo)
        
        // When - Apply new formatting (italic)
        let text3 = NSMutableAttributedString(attributedString: text1)
        text3.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: 4))
        version.attributedContent = text3  // Apply to version first
        let command2 = FormatApplyCommand(
            description: "Apply Italic",
            range: NSRange(location: 0, length: 4),
            beforeContent: text1,
            afterContent: text3,
            targetFile: testFile
        )
        undoManager.execute(command2)
        
        // Then - Redo stack should be cleared
        XCTAssertFalse(undoManager.canRedo)
    }
}
