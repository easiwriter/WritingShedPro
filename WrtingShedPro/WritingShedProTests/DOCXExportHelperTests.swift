import XCTest
@testable import Writing_Shed_Pro

final class DOCXExportHelperTests: XCTestCase {
    var helper: DOCXExportHelper!
    
    override func setUp() {
        helper = DOCXExportHelper()
    }
    
    override func tearDown() {
        helper = nil
    }
    
    func testCreateDocumentXML_ReturnsValidXML() {
        let testString = NSAttributedString(string: "Test content")
        let xml = helper.createDocumentXML(withAttributedString: testString)
        XCTAssertTrue(xml.contains("<?xml version=\"1.0\""))
        XCTAssertTrue(xml.contains("<w:document"))
        XCTAssertTrue(xml.contains("<w:body>"))
        XCTAssertTrue(xml.contains("Test content"))
    }
    
    func testEscapeXML_Ampersand() {
        let escaped = helper.escapeXML("Tom & Jerry")
        XCTAssertEqual(escaped, "Tom &amp; Jerry")
    }
    
    func testEscapeXML_LessThan() {
        let escaped = helper.escapeXML("x < y")
        XCTAssertEqual(escaped, "x &lt; y")
    }
    
    func testCreateDocumentXML_MultipleParagraphs() {
        let testString = NSAttributedString(string: "Hello\nWorld")
        let xml = helper.createDocumentXML(withAttributedString: testString)
        XCTAssertTrue(xml.contains("<w:p>"))
        XCTAssertTrue(xml.contains("Hello"))
        XCTAssertTrue(xml.contains("World"))
    }
    
    func testCreateDocumentXML_WithImage_IncludesDrawingNamespaces() {
        let text = "Hello\u{FFFC}World"
        let mutableAttr = NSMutableAttributedString(string: text)
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        let testImage = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create attachment")
            return
        }
        
        let attachmentStr = NSAttributedString(attachment: attachment)
        mutableAttr.replaceCharacters(in: NSRange(location: 5, length: 1), with: attachmentStr)
        
        let xml = helper.createDocumentXML(withAttributedString: mutableAttr)
        
        // Document should include DrawingML namespaces when images are present
        XCTAssertTrue(xml.contains("xmlns:wp="), "Should include wp namespace for images")
        XCTAssertTrue(xml.contains("xmlns:pic="), "Should include pic namespace for images")
        XCTAssertTrue(xml.contains("xmlns:a="), "Should include a namespace for images")
        XCTAssertTrue(xml.contains("xmlns:r="), "Should include r namespace for images")
    }
    
    func testCreateDOCXPackage_WithImages_IncludesMediaFiles() throws {
        let imageData = Data(repeating: 0xFF, count: 100)
        let images = [
            DOCXImageEntry(relationshipID: "rId2", filename: "image1.jpeg", data: imageData, pixelWidth: 100, pixelHeight: 80)
        ]
        
        let simpleXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body><w:p><w:r><w:t>Test</w:t></w:r></w:p></w:body>
        </w:document>
        """
        
        let data = try helper.createDOCXPackage(documentXML: simpleXML, images: images)
        
        // Should be a valid ZIP
        let zipHeader = data.prefix(4)
        XCTAssertEqual(zipHeader, Data([0x50, 0x4B, 0x03, 0x04]))
        
        // Convert to string to check for file paths in the ZIP
        // The ZIP central directory contains the file paths as ASCII
        let dataString = String(data: data, encoding: .isoLatin1) ?? ""
        XCTAssertTrue(dataString.contains("word/media/image1.jpeg"), "ZIP should contain image file path")
        XCTAssertTrue(dataString.contains("word/_rels/document.xml.rels"), "ZIP should contain document rels")
    }
    
    func testCreateDocumentXML_NoImage_NoDrawingNamespaces() {
        let testString = NSAttributedString(string: "Just plain text")
        let xml = helper.createDocumentXML(withAttributedString: testString)
        
        // Should NOT include DrawingML namespaces when no images present
        XCTAssertFalse(xml.contains("xmlns:wp="), "Should not include wp namespace without images")
        XCTAssertTrue(helper.collectedImages.isEmpty, "Should have no collected images")
    }
}
