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
        let xml = helper.createDocumentXML()
        XCTAssertTrue(xml.contains("<?xml version=\"1.0\""))
        XCTAssertTrue(xml.contains("<w:document"))
        XCTAssertTrue(xml.contains("<w:body>"))
    }
    
    func testEscapeXML_Ampersand() {
        let escaped = helper.escapeXML("Tom & Jerry")
        XCTAssertEqual(escaped, "Tom &amp; Jerry")
    }
    
    func testEscapeXML_LessThan() {
        let escaped = helper.escapeXML("x < y")
        XCTAssertEqual(escaped, "x &lt; y")
    }
    
    func testAddContent_SingleParagraph() {
        let baseXML = helper.createDocumentXML()
        let xml = helper.addContent(to: baseXML, content: "Hello, World!")
        XCTAssertTrue(xml.contains("<w:p>"))
        XCTAssertTrue(xml.contains("Hello, World!"))
    }
}
