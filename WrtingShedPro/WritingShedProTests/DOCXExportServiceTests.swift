import XCTest
import SwiftData
import UniformTypeIdentifiers
@testable import Writing_Shed_Pro

final class DOCXExportServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var exportService: DOCXExportService!
    
    override func setUp() async throws {
        let schema = Schema([TextFile.self, Project.self, Version.self, Folder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        exportService = DOCXExportService(modelContext: modelContext)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        exportService = nil
    }
    
    func testExportToDOCX_WithValidContent() throws {
        let attributedString = NSAttributedString(string: "Hello, World!\nThis is a test.")
        
        let data = try exportService.exportToDOCX(attributedString, filename: "Test.docx")
        XCTAssertFalse(data.isEmpty)
        
        // Verify it's a valid ZIP file by checking the first bytes (PK header)
        let zipHeader = data.prefix(4)
        let expectedHeader = Data([0x50, 0x4B, 0x03, 0x04]) // "PK\x03\x04"
        XCTAssertEqual(zipHeader, expectedHeader, "Data should be a valid ZIP file")
    }
    
    func testExportToDOCX_WithNoContent_ThrowsError() {
        let attributedString = NSAttributedString(string: "")
        
        XCTAssertThrowsError(try exportService.exportToDOCX(attributedString, filename: "Empty.docx")) { error in
            XCTAssertEqual(error as? DOCXExportError, .noContent)
        }
    }
    
    func testExportMultipleToDOCX_WithValidFiles() throws {
        let attr1 = NSAttributedString(string: "Content 1")
        let attr2 = NSAttributedString(string: "Content 2")
        
        let data = try exportService.exportMultipleToDOCX([attr1, attr2], filename: "Combined.docx")
        
        XCTAssertFalse(data.isEmpty)
        
        // Verify it's a valid ZIP file
        let zipHeader = data.prefix(4)
        let expectedHeader = Data([0x50, 0x4B, 0x03, 0x04])
        XCTAssertEqual(zipHeader, expectedHeader, "Data should be a valid ZIP file")
    }
    
    func testExportToDOCX_WithImage() throws {
        // Create an attributed string with an ImageAttachment
        let text = "Before image\u{FFFC}After image"
        let mutableAttr = NSMutableAttributedString(string: text)
        
        // Create a small test image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 80))
        let testImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 80))
        }
        
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData, scale: 0.5, alignment: .center) else {
            XCTFail("Failed to create ImageAttachment")
            return
        }
        
        // Replace U+FFFC with the attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        mutableAttr.replaceCharacters(in: NSRange(location: 12, length: 1), with: attachmentString)
        
        let data = try exportService.exportToDOCX(mutableAttr, filename: "ImageTest.docx")
        XCTAssertFalse(data.isEmpty)
        
        // Verify it's a valid ZIP file
        let zipHeader = data.prefix(4)
        let expectedHeader = Data([0x50, 0x4B, 0x03, 0x04])
        XCTAssertEqual(zipHeader, expectedHeader, "Data should be a valid ZIP file")
        
        // The ZIP should contain the image file (word/media/image1.jpeg)
        // and relationship file (word/_rels/document.xml.rels)
        // Verify by checking file size is substantially larger than text-only
        let textOnlyData = try exportService.exportToDOCX(
            NSAttributedString(string: "Before imageAfter image"),
            filename: "NoImage.docx"
        )
        XCTAssertGreaterThan(data.count, textOnlyData.count + 100,
                             "DOCX with image should be significantly larger than text-only")
    }
    
    func testExportToDOCX_ImageDrawingXML() {
        // Test that the XML generator produces <w:drawing> elements for images
        let text = "Text\u{FFFC}More"
        let mutableAttr = NSMutableAttributedString(string: text)
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        let testImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }
        
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create ImageAttachment")
            return
        }
        
        let attachmentString = NSAttributedString(attachment: attachment)
        mutableAttr.replaceCharacters(in: NSRange(location: 4, length: 1), with: attachmentString)
        
        let helper = DOCXExportHelper()
        let xml = helper.createDocumentXML(withAttributedString: mutableAttr)
        
        XCTAssertTrue(xml.contains("<w:drawing>"), "XML should contain <w:drawing> element")
        XCTAssertTrue(xml.contains("wp:inline"), "XML should contain wp:inline element")
        XCTAssertTrue(xml.contains("pic:pic"), "XML should contain pic:pic element")
        XCTAssertTrue(xml.contains("a:blip"), "XML should contain a:blip element with image reference")
        XCTAssertTrue(xml.contains("r:embed=\"rId2\""), "XML should reference rId2 for the first image")
        XCTAssertEqual(helper.collectedImages.count, 1, "Should have collected 1 image")
        XCTAssertEqual(helper.collectedImages.first?.filename, "image1.jpeg")
    }
}
