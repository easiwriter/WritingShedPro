//
//  ImageSerializationTests.swift
//  WritingShedProTests
//
//  Tests for image attachment serialization and deserialization
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class ImageSerializationTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func createTestImage(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        
        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
        #else
        UIGraphicsBeginImageContext(size)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
        #endif
    }
    
    // MARK: - Basic Image Serialization Tests
    
    func testEncodeDecodeImageAttachment() {
        // Given
        let text = "Here is an image: \u{FFFC}" // Object replacement character
        let attributedString = NSMutableAttributedString(string: text)
        
        // Create image attachment
        let testImage = createTestImage(width: 400, height: 300)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData, scale: 0.8, alignment: .center) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        // Insert attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 18, length: 1), with: attachmentString)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        XCTAssertEqual(decoded.string, text, "Text should be preserved")
        
        // Check if attachment was restored
        let attrs = decoded.attributes(at: 18, effectiveRange: nil)
        let restoredAttachment = attrs[.attachment] as? ImageAttachment
        
        XCTAssertNotNil(restoredAttachment, "Image attachment should be restored")
        XCTAssertEqual(restoredAttachment?.scale ?? 0, 0.8, accuracy: 0.01, "Scale should be preserved")
        XCTAssertEqual(restoredAttachment?.alignment, .center, "Alignment should be preserved")
        XCTAssertNotNil(restoredAttachment?.imageData, "Image data should be preserved")
        XCTAssertNotNil(restoredAttachment?.image, "Image should be reconstructed")
    }
    
    func testEncodeImageWithCaption() {
        // Given
        let text = "Image:\u{FFFC}"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Create image attachment with caption
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        attachment.setCaption(text: "My caption", style: "caption1")
        
        // Insert attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 6, length: 1), with: attachmentString)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        let attrs = decoded.attributes(at: 6, effectiveRange: nil)
        let restoredAttachment = attrs[.attachment] as? ImageAttachment
        
        XCTAssertTrue(restoredAttachment?.hasCaption ?? false, "Caption should be enabled")
        XCTAssertEqual(restoredAttachment?.captionText, "My caption")
        XCTAssertEqual(restoredAttachment?.captionStyle, "caption1")
    }
    
    func testEncodeImageWithoutCaption() {
        // Given
        let text = "Image:\u{FFFC}"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Create image attachment without caption
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        // Insert attachment (no caption)
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 6, length: 1), with: attachmentString)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        let attrs = decoded.attributes(at: 6, effectiveRange: nil)
        let restoredAttachment = attrs[.attachment] as? ImageAttachment
        
        XCTAssertFalse(restoredAttachment?.hasCaption ?? true, "Caption should be disabled")
        XCTAssertNil(restoredAttachment?.captionText)
    }
    
    func testMultipleImagesInDocument() {
        // Given
        let text = "First:\u{FFFC} Second:\u{FFFC}"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Create two image attachments with different properties
        let testImage1 = createTestImage(width: 300, height: 200)
        guard let imageData1 = testImage1.pngData(),
              let attachment1 = ImageAttachment.from(imageData: imageData1, scale: 0.5, alignment: .left) else {
            XCTFail("Failed to create first image attachment")
            return
        }
        
        let testImage2 = createTestImage(width: 400, height: 300)
        guard let imageData2 = testImage2.pngData(),
              let attachment2 = ImageAttachment.from(imageData: imageData2, scale: 1.5, alignment: .right) else {
            XCTFail("Failed to create second image attachment")
            return
        }
        
        // Insert attachments
        let attachmentString1 = NSAttributedString(attachment: attachment1)
        attributedString.replaceCharacters(in: NSRange(location: 6, length: 1), with: attachmentString1)
        
        let attachmentString2 = NSAttributedString(attachment: attachment2)
        attributedString.replaceCharacters(in: NSRange(location: 15, length: 1), with: attachmentString2)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        // Check first image
        let attrs1 = decoded.attributes(at: 6, effectiveRange: nil)
        let restoredAttachment1 = attrs1[.attachment] as? ImageAttachment
        
        XCTAssertNotNil(restoredAttachment1, "First image should be restored")
        XCTAssertEqual(restoredAttachment1?.scale ?? 0, 0.5, accuracy: 0.01)
        XCTAssertEqual(restoredAttachment1?.alignment, .left)
        
        // Check second image
        let attrs2 = decoded.attributes(at: 15, effectiveRange: nil)
        let restoredAttachment2 = attrs2[.attachment] as? ImageAttachment
        
        XCTAssertNotNil(restoredAttachment2, "Second image should be restored")
        XCTAssertEqual(restoredAttachment2?.scale ?? 0, 1.5, accuracy: 0.01)
        XCTAssertEqual(restoredAttachment2?.alignment, .right)
    }
    
    func testImageWithTextFormatting() {
        // Given: Text with bold formatting and an image
        let text = "Bold text\u{FFFC}normal"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Add bold to "Bold text"
        let boldFont = UIFont.systemFont(ofSize: 17, weight: .bold)
        attributedString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 9))
        
        // Create and insert image
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 9, length: 1), with: attachmentString)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        // Check bold formatting preserved
        let boldAttrs = decoded.attributes(at: 0, effectiveRange: nil)
        let font = boldAttrs[.font] as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false, "Bold should be preserved")
        
        // Check image preserved
        let imageAttrs = decoded.attributes(at: 9, effectiveRange: nil)
        let restoredAttachment = imageAttrs[.attachment] as? ImageAttachment
        XCTAssertNotNil(restoredAttachment, "Image should be preserved alongside formatting")
    }
    
    func testImageIDPreserved() {
        // Given
        let text = "Image:\u{FFFC}"
        let attributedString = NSMutableAttributedString(string: text)
        
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        let originalID = attachment.imageID
        
        // Insert attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 6, length: 1), with: attachmentString)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        let attrs = decoded.attributes(at: 6, effectiveRange: nil)
        let restoredAttachment = attrs[.attachment] as? ImageAttachment
        
        XCTAssertEqual(restoredAttachment?.imageID, originalID, "Image ID should be preserved")
    }
    
    func testImageScaleRange() {
        // Test that extreme scale values are preserved
        let scales: [CGFloat] = [0.1, 0.5, 1.0, 1.5, 2.0]
        
        for scale in scales {
            // Given
            let text = "\u{FFFC}"
            let attributedString = NSMutableAttributedString(string: text)
            
            let testImage = createTestImage(width: 200, height: 150)
            guard let imageData = testImage.pngData(),
                  let attachment = ImageAttachment.from(imageData: imageData, scale: scale) else {
                XCTFail("Failed to create image attachment with scale \(scale)")
                continue
            }
            
            let attachmentString = NSAttributedString(attachment: attachment)
            attributedString.replaceCharacters(in: NSRange(location: 0, length: 1), with: attachmentString)
            
            // When
            let encoded = AttributedStringSerializer.encode(attributedString)
            let decoded = AttributedStringSerializer.decode(encoded, text: text)
            
            // Then
            let attrs = decoded.attributes(at: 0, effectiveRange: nil)
            let restoredAttachment = attrs[.attachment] as? ImageAttachment
            
            XCTAssertEqual(restoredAttachment?.scale ?? 0, scale, accuracy: 0.01, "Scale \(scale) should be preserved")
        }
    }
    
    func testEmptyDocument() {
        // Given
        let text = ""
        let attributedString = NSAttributedString(string: text)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        XCTAssertEqual(decoded.string, "", "Empty document should be preserved")
    }
    
    func testFileIDSerialization() {
        // Given
        let text = "Image:\u{FFFC}"
        let attributedString = NSMutableAttributedString(string: text)
        let testFileID = UUID()
        
        // Create image attachment with fileID
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        attachment.fileID = testFileID
        
        // Insert attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 6, length: 1), with: attachmentString)
        
        // When
        let encoded = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Then
        let attrs = decoded.attributes(at: 6, effectiveRange: nil)
        let restoredAttachment = attrs[.attachment] as? ImageAttachment
        
        XCTAssertEqual(restoredAttachment?.fileID, testFileID, "File ID should be preserved through serialization")
    }
}
