//
//  MarkdownImportServiceTests.swift
//  WritingShedProTests
//
//  Created on 20 February 2026.
//  Tests for Markdown import service and markdown-to-rich-text export round-trips
//

import XCTest
import UIKit
import SwiftData
@testable import Writing_Shed_Pro

final class MarkdownImportServiceTests: XCTestCase {
    
    // MARK: - Basic Import Tests
    
    func testImportPlainText() throws {
        let markdown = "Hello, world!"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertTrue(result.string.contains("Hello, world!"))
    }
    
    func testImportEmptyContentThrows() {
        XCTAssertThrowsError(try MarkdownImportService.importMarkdown(from: "")) { error in
            XCTAssertTrue(error is MarkdownImportError)
            if case MarkdownImportError.emptyContent = error {
                // Expected
            } else {
                XCTFail("Expected emptyContent error")
            }
        }
    }
    
    func testImportFromData() throws {
        let markdown = "Test content"
        let data = markdown.data(using: .utf8)!
        
        let result = try MarkdownImportService.importMarkdown(from: data)
        XCTAssertTrue(result.string.contains("Test content"))
    }
    
    // MARK: - Heading Import Tests
    
    func testImportHeading1() throws {
        let markdown = "# Main Title"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Should strip the # prefix
        XCTAssertFalse(result.string.contains("#"), "Heading marker should be stripped")
        XCTAssertTrue(result.string.contains("Main Title"))
        
        // Should have large title font
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        let largeTitleSize = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        XCTAssertEqual(font?.pointSize, largeTitleSize, accuracy: 1.0, "H1 should use largeTitle font size")
    }
    
    func testImportHeading2() throws {
        let markdown = "## Section Title"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertFalse(result.string.hasPrefix("##"))
        XCTAssertTrue(result.string.contains("Section Title"))
        
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        let title1Size = UIFont.preferredFont(forTextStyle: .title1).pointSize
        XCTAssertEqual(font?.pointSize, title1Size, accuracy: 1.0, "H2 should use title1 font size")
    }
    
    func testImportHeading3() throws {
        let markdown = "### Subsection"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertFalse(result.string.hasPrefix("###"))
        XCTAssertTrue(result.string.contains("Subsection"))
    }
    
    func testImportAllHeadingLevels() throws {
        let markdown = """
        # H1
        ## H2
        ### H3
        #### H4
        ##### H5
        ###### H6
        """
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // All heading markers should be stripped
        XCTAssertFalse(result.string.contains("#"), "All heading markers should be stripped")
        XCTAssertTrue(result.string.contains("H1"))
        XCTAssertTrue(result.string.contains("H2"))
        XCTAssertTrue(result.string.contains("H3"))
        XCTAssertTrue(result.string.contains("H4"))
        XCTAssertTrue(result.string.contains("H5"))
        XCTAssertTrue(result.string.contains("H6"))
    }
    
    // MARK: - Inline Formatting Tests
    
    func testImportBoldText() throws {
        let markdown = "This is **bold** text"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Should strip ** markers
        XCTAssertFalse(result.string.contains("**"), "Bold markers should be stripped")
        XCTAssertTrue(result.string.contains("bold"))
        
        // Find "bold" range and check font trait
        let boldRange = (result.string as NSString).range(of: "bold")
        let font = result.attribute(.font, at: boldRange.location, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold), "Text should be bold")
    }
    
    func testImportItalicText() throws {
        let markdown = "This is *italic* text"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertFalse(result.string.contains("*"), "Italic markers should be stripped")
        XCTAssertTrue(result.string.contains("italic"))
        
        let italicRange = (result.string as NSString).range(of: "italic")
        let font = result.attribute(.font, at: italicRange.location, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic), "Text should be italic")
    }
    
    func testImportBoldItalicText() throws {
        let markdown = "This is ***bold italic*** text"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertTrue(result.string.contains("bold italic"))
        
        let range = (result.string as NSString).range(of: "bold italic")
        let font = result.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold), "Text should be bold")
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic), "Text should be italic")
    }
    
    func testImportStrikethrough() throws {
        let markdown = "This is ~~deleted~~ text"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertFalse(result.string.contains("~~"), "Strikethrough markers should be stripped")
        XCTAssertTrue(result.string.contains("deleted"))
        
        let range = (result.string as NSString).range(of: "deleted")
        let strike = result.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int
        XCTAssertNotNil(strike)
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }
    
    // MARK: - Link Import Tests
    
    func testImportLink() throws {
        let markdown = "Visit [Example](https://example.com) for more"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Should show link text without markdown syntax
        XCTAssertFalse(result.string.contains("["), "Link brackets should be stripped")
        XCTAssertFalse(result.string.contains("]("), "Link syntax should be stripped")
        XCTAssertTrue(result.string.contains("Example"))
        
        let linkRange = (result.string as NSString).range(of: "Example")
        let link = result.attribute(.link, at: linkRange.location, effectiveRange: nil)
        XCTAssertNotNil(link, "Link attribute should be present")
    }
    
    // MARK: - List Import Tests
    
    func testImportUnorderedList() throws {
        let markdown = "- Item one\n- Item two\n- Item three"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Should convert - to bullet character
        XCTAssertTrue(result.string.contains("•"), "Should use bullet character")
        XCTAssertTrue(result.string.contains("Item one"))
        XCTAssertTrue(result.string.contains("Item two"))
        XCTAssertTrue(result.string.contains("Item three"))
    }
    
    func testImportOrderedList() throws {
        let markdown = "1. First\n2. Second\n3. Third"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertTrue(result.string.contains("First"))
        XCTAssertTrue(result.string.contains("Second"))
        XCTAssertTrue(result.string.contains("Third"))
    }
    
    // MARK: - Blockquote Import Tests
    
    func testImportBlockquote() throws {
        let markdown = "> This is a quote"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Should strip > marker
        XCTAssertFalse(result.string.hasPrefix(">"), "Blockquote marker should be stripped")
        XCTAssertTrue(result.string.contains("This is a quote"))
    }
    
    // MARK: - Code Import Tests
    
    func testImportInlineCode() throws {
        let markdown = "Use the `print()` function"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Should strip backticks
        XCTAssertTrue(result.string.contains("print()"))
        // The raw backtick should not appear in the content text itself
        // (it may not be possible to verify this reliably since ` might be used in code)
        
        let codeRange = (result.string as NSString).range(of: "print()")
        let font = result.attribute(.font, at: codeRange.location, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        // Monospaced font check
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitMonoSpace),
                      "Inline code should use monospaced font")
    }
    
    func testImportCodeBlock() throws {
        let markdown = "```swift\nlet x = 42\nprint(x)\n```"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Should not contain the fence markers
        XCTAssertFalse(result.string.contains("```"), "Code fence markers should be stripped")
        XCTAssertTrue(result.string.contains("let x = 42"))
        XCTAssertTrue(result.string.contains("print(x)"))
    }
    
    // MARK: - Horizontal Rule Import Tests
    
    func testImportHorizontalRule() throws {
        let markdown = "Above\n\n---\n\nBelow"
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        XCTAssertTrue(result.string.contains("Above"))
        XCTAssertTrue(result.string.contains("Below"))
        // Should contain visual rule character (box drawing horizontal)
        XCTAssertTrue(result.string.contains("─"), "Should contain visual horizontal rule")
    }
    
    // MARK: - Complex Document Import Tests
    
    func testImportComplexDocument() throws {
        let markdown = """
        # Privacy Policy
        
        **Writing Shed Pro** does not collect any data.
        
        ## Your Data
        
        All content is stored *on your device*.
        
        - No tracking
        - No analytics
        - No third-party SDKs
        
        Visit [our site](https://example.com) for more info.
        """
        
        let result = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Markdown syntax should be converted to formatting, not appear as raw text
        XCTAssertFalse(result.string.contains("# "), "Heading markers should be stripped")
        XCTAssertFalse(result.string.contains("## "), "Heading markers should be stripped")
        XCTAssertFalse(result.string.contains("**"), "Bold markers should be stripped")
        XCTAssertFalse(result.string.contains("- No"), "List markers should be converted to bullets")
        XCTAssertFalse(result.string.contains("]("), "Link syntax should be stripped")
        
        // Content should be preserved
        XCTAssertTrue(result.string.contains("Privacy Policy"))
        XCTAssertTrue(result.string.contains("Writing Shed Pro"))
        XCTAssertTrue(result.string.contains("Your Data"))
        XCTAssertTrue(result.string.contains("on your device"))
        
        // Should have bold formatting on "Writing Shed Pro"
        let boldRange = (result.string as NSString).range(of: "Writing Shed Pro")
        let font = result.attribute(.font, at: boldRange.location, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true,
                      "Writing Shed Pro should be bold")
    }
    
    // MARK: - Markdown → DOCX Round-Trip Tests
    
    /// Tests the exact scenario that caused the bug: markdown content exported to DOCX
    /// should contain rendered rich text, not raw markdown syntax
    func testMarkdownToDOCXRoundTrip_BoldPreserved() throws {
        let markdown = "This has **bold** and *italic* words"
        
        // Step 1: Import markdown → rich text (this is what the fix does before export)
        let richText = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Verify the rich text has no markdown syntax
        XCTAssertFalse(richText.string.contains("**"), "Rich text should not contain ** markers")
        XCTAssertFalse(richText.string.contains("*italic*"), "Rich text should not contain *italic* markers")
        
        // Verify bold trait is present
        let boldRange = (richText.string as NSString).range(of: "bold")
        let boldFont = richText.attribute(.font, at: boldRange.location, effectiveRange: nil) as? UIFont
        XCTAssertTrue(boldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        
        // Verify italic trait is present
        let italicRange = (richText.string as NSString).range(of: "italic")
        let italicFont = richText.attribute(.font, at: italicRange.location, effectiveRange: nil) as? UIFont
        XCTAssertTrue(italicFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
        
        // Step 2: Export to DOCX — should succeed with formatted content
        let schema = Schema([TextFile.self, Project.self, Version.self, Folder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let docxService = DOCXExportService(modelContext: context)
        
        let docxData = try docxService.exportToDOCX(richText, filename: "test")
        XCTAssertFalse(docxData.isEmpty, "DOCX export should produce data")
        
        // Verify valid ZIP (DOCX is a ZIP archive)
        let zipHeader = docxData.prefix(4)
        XCTAssertEqual(zipHeader, Data([0x50, 0x4B, 0x03, 0x04]), "Should be a valid DOCX/ZIP file")
    }
    
    /// Tests markdown with headings exported to DOCX preserves heading formatting
    func testMarkdownToDOCXRoundTrip_HeadingsPreserved() throws {
        let markdown = "# Chapter One\n\nSome body text here.\n\n## Section A\n\nMore content."
        
        let richText = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Heading syntax stripped
        XCTAssertFalse(richText.string.contains("# "))
        XCTAssertFalse(richText.string.contains("## "))
        XCTAssertTrue(richText.string.contains("Chapter One"))
        XCTAssertTrue(richText.string.contains("Section A"))
        
        // H1 should have larger font than body
        let h1Range = (richText.string as NSString).range(of: "Chapter One")
        let bodyRange = (richText.string as NSString).range(of: "Some body text here.")
        
        let h1Font = richText.attribute(.font, at: h1Range.location, effectiveRange: nil) as? UIFont
        let bodyFont = richText.attribute(.font, at: bodyRange.location, effectiveRange: nil) as? UIFont
        
        XCTAssertNotNil(h1Font)
        XCTAssertNotNil(bodyFont)
        XCTAssertGreaterThan(h1Font!.pointSize, bodyFont!.pointSize,
                            "H1 font should be larger than body font")
        
        // Export to DOCX
        let schema = Schema([TextFile.self, Project.self, Version.self, Folder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let docxService = DOCXExportService(modelContext: context)
        
        let docxData = try docxService.exportToDOCX(richText, filename: "test")
        XCTAssertFalse(docxData.isEmpty)
    }
    
    // MARK: - Markdown → RTF Round-Trip Tests
    
    /// Tests markdown exported to RTF preserves formatting
    func testMarkdownToRTFRoundTrip_FormattingPreserved() throws {
        let markdown = "# Title\n\nA paragraph with **bold** and *italic* text."
        
        let richText = try MarkdownImportService.importMarkdown(from: markdown)
        
        // Verify markdown syntax is gone
        XCTAssertFalse(richText.string.contains("# "))
        XCTAssertFalse(richText.string.contains("**"))
        
        // Export to RTF
        let rtfData = try WordDocumentService.exportToRTF(richText, filename: "test")
        XCTAssertFalse(rtfData.isEmpty, "RTF export should produce data")
        
        // Verify valid RTF header
        let rtfString = String(data: rtfData, encoding: .ascii)
        XCTAssertTrue(rtfString?.hasPrefix("{\\rtf1") == true, "Should be valid RTF")
        
        // RTF should contain the text content
        XCTAssertTrue(rtfString?.contains("Title") == true)
        XCTAssertTrue(rtfString?.contains("bold") == true)
        XCTAssertTrue(rtfString?.contains("italic") == true)
        
        // RTF should have bold formatting (\\b marker in RTF)
        XCTAssertTrue(rtfString?.contains("\\b ") == true || rtfString?.contains("\\b\\") == true,
                      "RTF should contain bold formatting")
    }
    
    /// Tests that raw markdown text (without import conversion) would not have formatting —
    /// demonstrating why the fix was necessary
    func testRawMarkdownExportHasNoFormatting() throws {
        // This simulates what happened BEFORE the fix:
        // raw markdown text treated as plain NSAttributedString
        let rawMarkdown = "# Title\n\nThis has **bold** text"
        let rawAttrString = NSAttributedString(string: rawMarkdown)
        
        // The raw string still contains markdown syntax
        XCTAssertTrue(rawAttrString.string.contains("# "), "Raw string has heading markers")
        XCTAssertTrue(rawAttrString.string.contains("**"), "Raw string has bold markers")
        
        // No bold trait anywhere
        var hasBold = false
        rawAttrString.enumerateAttribute(.font, in: NSRange(location: 0, length: rawAttrString.length)) { value, _, _ in
            if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                hasBold = true
            }
        }
        XCTAssertFalse(hasBold, "Raw markdown string should have no bold formatting")
        
        // After conversion, markdown syntax is rendered
        let richText = try MarkdownImportService.importMarkdown(from: rawMarkdown)
        XCTAssertFalse(richText.string.contains("**"), "Converted text should not have ** markers")
        
        var hasConvertedBold = false
        richText.enumerateAttribute(.font, in: NSRange(location: 0, length: richText.length)) { value, _, _ in
            if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                hasConvertedBold = true
            }
        }
        XCTAssertTrue(hasConvertedBold, "Converted text should have bold formatting")
    }
}
