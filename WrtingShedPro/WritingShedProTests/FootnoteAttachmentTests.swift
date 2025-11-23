//
//  FootnoteAttachmentTests.swift
//  Writing Shed Pro Tests
//
//  Feature 015: Footnotes - Unit tests for FootnoteAttachment
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class FootnoteAttachmentTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testFootnoteAttachmentInitialization() {
        let footnoteID = UUID()
        let attachment = FootnoteAttachment(footnoteID: footnoteID, number: 1)
        
        XCTAssertEqual(attachment.footnoteID, footnoteID)
        XCTAssertEqual(attachment.number, 1)
    }
    
    func testMultipleFootnoteAttachments() {
        let id1 = UUID()
        let id2 = UUID()
        
        let attachment1 = FootnoteAttachment(footnoteID: id1, number: 1)
        let attachment2 = FootnoteAttachment(footnoteID: id2, number: 2)
        
        XCTAssertNotEqual(attachment1.footnoteID, attachment2.footnoteID)
        XCTAssertNotEqual(attachment1.number, attachment2.number)
    }
    
    func testFootnoteAttachmentWithZeroNumber() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 0)
        
        XCTAssertEqual(attachment.number, 0)
    }
    
    func testFootnoteAttachmentWithLargeNumber() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 999)
        
        XCTAssertEqual(attachment.number, 999)
    }
    
    // MARK: - Image Generation Tests
    
    func testFootnoteImageGeneration() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let image = attachment.image(
            forBounds: CGRect(x: 0, y: 0, width: 16, height: 16),
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image, "Footnote should generate an image")
    }
    
    func testFootnoteImageSize() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let image = attachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image)
        
        if let image = image {
            // Image should be small (superscript size)
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
            XCTAssertLessThan(image.size.width, 50) // Reasonable max width
            XCTAssertLessThan(image.size.height, 50) // Reasonable max height
        }
    }
    
    func testFootnoteImageConsistencyForSameNumber() {
        let attachment1 = FootnoteAttachment(footnoteID: UUID(), number: 5)
        let attachment2 = FootnoteAttachment(footnoteID: UUID(), number: 5)
        
        let image1 = attachment1.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        let image2 = attachment2.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        
        // Images for the same number should have the same size
        if let img1 = image1, let img2 = image2 {
            XCTAssertEqual(img1.size.width, img2.size.width, accuracy: 0.1)
            XCTAssertEqual(img1.size.height, img2.size.height, accuracy: 0.1)
        }
    }
    
    func testSingleDigitVsDoubleDigitImageSize() {
        let singleDigit = FootnoteAttachment(footnoteID: UUID(), number: 5)
        let doubleDigit = FootnoteAttachment(footnoteID: UUID(), number: 15)
        
        let singleImage = singleDigit.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        let doubleImage = doubleDigit.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(singleImage)
        XCTAssertNotNil(doubleImage)
        
        // Double digit should be wider
        if let single = singleImage, let double = doubleImage {
            XCTAssertGreaterThan(double.size.width, single.size.width)
            // Height should be similar
            XCTAssertEqual(single.size.height, double.size.height, accuracy: 2.0)
        }
    }
    
    func testTripleDigitImageSize() {
        let tripleDigit = FootnoteAttachment(footnoteID: UUID(), number: 123)
        
        let image = tripleDigit.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image)
        
        if let image = image {
            // Should still be reasonable size
            XCTAssertLessThan(image.size.width, 100)
            XCTAssertGreaterThan(image.size.width, 0)
        }
    }
    
    // MARK: - Bounds Tests
    
    func testAttachmentBounds() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let bounds = attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 100, height: 20),
            glyphPosition: CGPoint(x: 0, y: 0),
            characterIndex: 0
        )
        
        XCTAssertGreaterThan(bounds.size.width, 0)
        XCTAssertGreaterThan(bounds.size.height, 0)
    }
    
    func testBoundsOriginX() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let bounds = attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect.zero,
            glyphPosition: CGPoint.zero,
            characterIndex: 0
        )
        
        // X origin should be 0
        XCTAssertEqual(bounds.origin.x, 0)
    }
    
    func testBoundsOriginYOffset() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let bounds = attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect.zero,
            glyphPosition: CGPoint.zero,
            characterIndex: 0
        )
        
        // Y origin should be negative (superscript offset)
        XCTAssertLessThan(bounds.origin.y, 0)
    }
    
    func testBoundsConsistencyForSameNumber() {
        let attachment1 = FootnoteAttachment(footnoteID: UUID(), number: 7)
        let attachment2 = FootnoteAttachment(footnoteID: UUID(), number: 7)
        
        let bounds1 = attachment1.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect.zero,
            glyphPosition: CGPoint.zero,
            characterIndex: 0
        )
        
        let bounds2 = attachment2.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect.zero,
            glyphPosition: CGPoint.zero,
            characterIndex: 0
        )
        
        // Same number should produce same bounds
        XCTAssertEqual(bounds1.size.width, bounds2.size.width, accuracy: 0.1)
        XCTAssertEqual(bounds1.size.height, bounds2.size.height, accuracy: 0.1)
        XCTAssertEqual(bounds1.origin.y, bounds2.origin.y, accuracy: 0.1)
    }
    
    // MARK: - NSCoding Tests
    
    func testEncodeAndDecode() throws {
        let footnoteID = UUID()
        let originalAttachment = FootnoteAttachment(footnoteID: footnoteID, number: 42)
        
        // Encode
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: originalAttachment,
            requiringSecureCoding: true
        )
        
        XCTAssertGreaterThan(data.count, 0)
        
        // Decode
        let decodedAttachment = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: FootnoteAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decodedAttachment)
        XCTAssertEqual(decodedAttachment?.footnoteID, footnoteID)
        XCTAssertEqual(decodedAttachment?.number, 42)
    }
    
    func testSecureCoding() {
        XCTAssertTrue(FootnoteAttachment.supportsSecureCoding)
    }
    
    func testEncodeDecodeMultipleAttachments() throws {
        let attachments = [
            FootnoteAttachment(footnoteID: UUID(), number: 1),
            FootnoteAttachment(footnoteID: UUID(), number: 2),
            FootnoteAttachment(footnoteID: UUID(), number: 3)
        ]
        
        for attachment in attachments {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: attachment,
                requiringSecureCoding: true
            )
            
            let decoded = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: FootnoteAttachment.self,
                from: data
            )
            
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.footnoteID, attachment.footnoteID)
            XCTAssertEqual(decoded?.number, attachment.number)
        }
    }
    
    func testDecodePreservesNumber() throws {
        let originalAttachment = FootnoteAttachment(footnoteID: UUID(), number: 99)
        
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: originalAttachment,
            requiringSecureCoding: true
        )
        
        let decodedAttachment = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: FootnoteAttachment.self,
            from: data
        )
        
        XCTAssertEqual(decodedAttachment?.number, 99)
    }
    
    // MARK: - Number Update Tests
    
    func testNumberUpdate() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        XCTAssertEqual(attachment.number, 1)
        
        attachment.number = 5
        
        XCTAssertEqual(attachment.number, 5)
    }
    
    func testNumberUpdatePreservesID() {
        let footnoteID = UUID()
        let attachment = FootnoteAttachment(footnoteID: footnoteID, number: 1)
        
        attachment.number = 10
        
        XCTAssertEqual(attachment.footnoteID, footnoteID)
        XCTAssertEqual(attachment.number, 10)
    }
    
    func testNumberUpdateAffectsImageSize() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let image1 = attachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        attachment.number = 99
        
        let image2 = attachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image1)
        XCTAssertNotNil(image2)
        
        // Different numbers should produce different width images
        if let img1 = image1, let img2 = image2 {
            XCTAssertNotEqual(img1.size.width, img2.size.width, accuracy: 0.1)
        }
    }
    
    // MARK: - Unique ID Tests
    
    func testUniqueFootnoteIDs() {
        let id1 = UUID()
        let id2 = UUID()
        
        let attachment1 = FootnoteAttachment(footnoteID: id1, number: 1)
        let attachment2 = FootnoteAttachment(footnoteID: id2, number: 1)
        
        XCTAssertNotEqual(attachment1.footnoteID, attachment2.footnoteID)
    }
    
    func testFootnoteIDPersistence() {
        let footnoteID = UUID()
        let attachment = FootnoteAttachment(footnoteID: footnoteID, number: 1)
        
        // ID should remain constant
        XCTAssertEqual(attachment.footnoteID, footnoteID)
        
        // Even after number changes
        attachment.number = 5
        XCTAssertEqual(attachment.footnoteID, footnoteID)
    }
    
    // MARK: - Integration with NSAttributedString Tests
    
    func testAttachmentInAttributedString() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        let attachmentString = NSAttributedString(attachment: attachment)
        
        XCTAssertEqual(attachmentString.length, 1)
        
        // Verify attachment is preserved
        attachmentString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: 1),
            options: []
        ) { value, range, stop in
            XCTAssertNotNil(value as? FootnoteAttachment)
            XCTAssertEqual((value as? FootnoteAttachment)?.number, 1)
        }
    }
    
    func testMultipleAttachmentsInString() {
        let attachment1 = FootnoteAttachment(footnoteID: UUID(), number: 1)
        let attachment2 = FootnoteAttachment(footnoteID: UUID(), number: 2)
        
        let mutableString = NSMutableAttributedString()
        mutableString.append(NSAttributedString(string: "Text "))
        mutableString.append(NSAttributedString(attachment: attachment1))
        mutableString.append(NSAttributedString(string: " more text "))
        mutableString.append(NSAttributedString(attachment: attachment2))
        
        XCTAssertEqual(mutableString.length, 18) // "Text " (5) + attachment (1) + " more text " (11) + attachment (1) = 18
        
        var attachmentCount = 0
        mutableString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutableString.length),
            options: []
        ) { value, range, stop in
            if value is FootnoteAttachment {
                attachmentCount += 1
            }
        }
        
        XCTAssertEqual(attachmentCount, 2)
    }
    
    // MARK: - Edge Cases
    
    func testNegativeNumber() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: -1)
        
        XCTAssertEqual(attachment.number, -1)
        
        let image = attachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        // Should still generate an image
        XCTAssertNotNil(image)
    }
    
    func testVeryLargeNumber() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 999999)
        
        let image = attachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image)
        
        if let image = image {
            // Should still produce reasonable size (with truncation or wrapping)
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }
    
    func testImageGenerationWithNilTextContainer() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let image = attachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        // Should handle nil text container gracefully
        XCTAssertNotNil(image)
    }
    
    func testImageGenerationWithVariousBounds() {
        let attachment = FootnoteAttachment(footnoteID: UUID(), number: 1)
        
        let bounds = [
            CGRect.zero,
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 0, y: 0, width: 50, height: 50),
            CGRect(x: 100, y: 100, width: 20, height: 20)
        ]
        
        for bound in bounds {
            let image = attachment.image(
                forBounds: bound,
                textContainer: nil,
                characterIndex: 0
            )
            
            XCTAssertNotNil(image, "Should generate image for bounds: \(bound)")
        }
    }
    
    // MARK: - Memory Tests
    
    func testMultipleAttachmentsMemory() {
        var attachments: [FootnoteAttachment] = []
        
        for i in 1...100 {
            let attachment = FootnoteAttachment(footnoteID: UUID(), number: i)
            attachments.append(attachment)
        }
        
        XCTAssertEqual(attachments.count, 100)
        
        // Generate images for all
        for attachment in attachments {
            let image = attachment.image(
                forBounds: CGRect.zero,
                textContainer: nil,
                characterIndex: 0
            )
            XCTAssertNotNil(image)
        }
    }
}
