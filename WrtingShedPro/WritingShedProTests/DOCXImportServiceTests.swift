import XCTest
@testable import Writing_Shed_Pro

final class DOCXImportServiceTests: XCTestCase {
    
    func testImportSimpleDOCX() throws {
        // Create a simple DOCX with plain text
        let helper = DOCXExportHelper()
        let plainAttrString = NSAttributedString(string: "Hello, World!\nThis is a test.")
        let docXML = helper.createDocumentXML(withAttributedString: plainAttrString)
        let docxData = try helper.createDOCXPackage(documentXML: docXML)
        
        // Import it back
        let imported = try DOCXImportService.importDOCX(from: docxData)
        
        // Verify content
        XCTAssertTrue(imported.string.contains("Hello, World!"))
        XCTAssertTrue(imported.string.contains("This is a test."))
    }
    
    func testImportDOCXWithFormatting() throws {
        // Create DOCX with bold and italic text
        let attrString = NSMutableAttributedString()
        
        #if canImport(UIKit)
        let boldFont = UIFont.boldSystemFont(ofSize: 17)
        let italicFont = UIFont.italicSystemFont(ofSize: 17)
        #elseif canImport(AppKit)
        let boldFont = NSFont.boldSystemFont(ofSize: 13)
        let italicFont = NSFont.systemFont(ofSize: 13)
        #endif
        
        attrString.append(NSAttributedString(string: "Bold text", attributes: [.font: boldFont]))
        attrString.append(NSAttributedString(string: " and "))
        attrString.append(NSAttributedString(string: "italic text", attributes: [.font: italicFont]))
        
        let helper = DOCXExportHelper()
        let docXML = helper.createDocumentXML(withAttributedString: attrString)
        let docxData = try helper.createDOCXPackage(documentXML: docXML)
        
        // Import it back
        let imported = try DOCXImportService.importDOCX(from: docxData)
        
        // Verify content
        XCTAssertTrue(imported.string.contains("Bold text"))
        XCTAssertTrue(imported.string.contains("italic text"))
        
        // Verify formatting is preserved (check for font attributes)
        var foundBold = false
        var foundItalic = false
        
        imported.enumerateAttributes(in: NSRange(location: 0, length: imported.length), options: []) { attributes, range, _ in
            #if canImport(UIKit)
            if let font = attributes[.font] as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    foundBold = true
                }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    foundItalic = true
                }
            }
            #elseif canImport(AppKit)
            if let font = attributes[.font] as? NSFont {
                if font.fontDescriptor.symbolicTraits.contains(.bold) {
                    foundBold = true
                }
                if font.fontDescriptor.symbolicTraits.contains(.italic) {
                    foundItalic = true
                }
            }
            #endif
        }
        
        XCTAssertTrue(foundBold, "Bold formatting should be preserved")
        XCTAssertTrue(foundItalic, "Italic formatting should be preserved")
    }
    
    func testImportDOCXWithMultipleParagraphs() throws {
        // Create DOCX with multiple paragraphs
        let attrString = NSAttributedString(string: "Paragraph 1\nParagraph 2\nParagraph 3")
        
        let helper = DOCXExportHelper()
        let docXML = helper.createDocumentXML(withAttributedString: attrString)
        let docxData = try helper.createDOCXPackage(documentXML: docXML)
        
        // Import it back
        let imported = try DOCXImportService.importDOCX(from: docxData)
        
        // Verify paragraphs are preserved
        XCTAssertTrue(imported.string.contains("Paragraph 1"))
        XCTAssertTrue(imported.string.contains("Paragraph 2"))
        XCTAssertTrue(imported.string.contains("Paragraph 3"))
    }
    
    func testImportInvalidDOCX() {
        // Try to import invalid data
        let invalidData = "Not a DOCX file".data(using: .utf8)!
        
        XCTAssertThrowsError(try DOCXImportService.importDOCX(from: invalidData))
    }
}
