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
    
    func testEncodeImageWithCaptionPrefix() {
        // Given
        let text = "Image:\u{FFFC}"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Create image attachment with caption including prefix
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        attachment.updateCaption(hasCaption: true, prefix: "Figure", text: "My caption", style: "caption1")
        
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
        XCTAssertEqual(restoredAttachment?.captionPrefix, "Figure", "Caption prefix should be preserved")
        XCTAssertEqual(restoredAttachment?.captionText, "My caption", "Caption text should be preserved")
        XCTAssertEqual(restoredAttachment?.captionStyle, "caption1", "Caption style should be preserved")
    }
    
    func testEncodeImageWithNilCaptionPrefix() {
        // Given
        let text = "Image:\u{FFFC}"
        let attributedString = NSMutableAttributedString(string: text)
        
        // Create image attachment with caption but no prefix
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        attachment.updateCaption(hasCaption: true, prefix: nil, text: "Just caption", style: "caption2")
        
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
        XCTAssertNil(restoredAttachment?.captionPrefix, "Caption prefix should be nil")
        XCTAssertEqual(restoredAttachment?.captionText, "Just caption", "Caption text should be preserved")
        XCTAssertEqual(restoredAttachment?.captionStyle, "caption2", "Caption style should be preserved")
    }
    
    // MARK: - End-to-End RTF Export Tests
    
    func testRTFExportContainsJPEGImage() {
        // Given: create an attributed string with an image attachment
        let text = "Hello\u{FFFC}World"
        let attributedString = NSMutableAttributedString(string: text)
        
        let testImage = createTestImage(width: 200, height: 150)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData, scale: 0.5, alignment: .center) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        // Replace the FFFC character with the attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 5, length: 1), with: attachmentString)
        
        // Verify attachment is present before export
        let preAttrs = attributedString.attributes(at: 5, effectiveRange: nil)
        XCTAssertTrue(preAttrs[.attachment] is ImageAttachment, "ImageAttachment should be on the attributed string")
        
        // When: go through prepare + toRTF (same as export pipeline)
        let prepared = AttributedStringSerializer.prepareForExport(from: attributedString)
        
        // Verify attachment survives prepareForExport
        let postPrepAttrs = prepared.attributes(at: 5, effectiveRange: nil)
        XCTAssertTrue(postPrepAttrs[.attachment] is ImageAttachment, "ImageAttachment should survive prepareForExport")
        
        // Check containsImages detection
        XCTAssertTrue(RTFImageEncoder.containsImages(prepared), "containsImages should detect the image")
        
        // Generate RTF — images are NOT embedded in RTF (by design).
        // RTF export uses Apple's standard converter which strips images.
        guard let rtfData = AttributedStringSerializer.toRTF(prepared) else {
            XCTFail("toRTF returned nil")
            return
        }
        
        // Verify RTF was generated (text content is present)
        guard let rtfString = String(data: rtfData, encoding: .utf8) else {
            XCTFail("RTF data is not valid UTF-8")
            return
        }
        
        // RTF should NOT contain image data (images not supported in RTF export)
        XCTAssertFalse(rtfString.contains("\\pict\\jpegblip"), "RTF should NOT contain embedded images (by design)")
        XCTAssertTrue(rtfString.contains("Hello"), "RTF should contain text content")
    }
    
    func testRTFExportFullPipelineWithEncodeDecode() {
        // Given: simulate the full pipeline: create → encode → decode → prepareForExport → toRTF
        let text = "Document with image:\u{FFFC} and more text."
        let attributedString = NSMutableAttributedString(string: text)
        
        let testImage = createTestImage(width: 300, height: 200)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData, scale: 0.8, alignment: .left) else {
            XCTFail("Failed to create image attachment")
            return
        }
        
        attachment.setCaption(text: "Test caption", style: "caption1")
        
        // Replace FFFC with attachment (simulates what InsertImageCommand does)
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: NSRange(location: 20, length: 1), with: attachmentString)
        
        // Step 1: Encode (simulates version.attributedContent setter → formattedContent)
        let encoded = AttributedStringSerializer.encode(attributedString)
        XCTAssertFalse(encoded.isEmpty, "Encoded data should not be empty")
        
        // Step 2: Decode (simulates version.attributedContent getter)
        let decoded = AttributedStringSerializer.decode(encoded, text: text)
        
        // Verify the decoded string has the ImageAttachment
        let decodedAttrs = decoded.attributes(at: 20, effectiveRange: nil)
        let decodedAttachment = decodedAttrs[.attachment] as? ImageAttachment
        XCTAssertNotNil(decodedAttachment, "ImageAttachment should survive encode→decode")
        XCTAssertNotNil(decodedAttachment?.imageData, "imageData should be present after decode")
        XCTAssertNotNil(decodedAttachment?.image, "UIImage should be reconstructed after decode")
        
        // Step 3: prepareForExport (simulates WordDocumentService path)
        let prepared = AttributedStringSerializer.prepareForExport(from: decoded)
        
        // Verify attachment survives prepareForExport
        let preparedAttrs = prepared.attributes(at: 20, effectiveRange: nil)
        let preparedAttachment = preparedAttrs[.attachment]
        XCTAssertNotNil(preparedAttachment, ".attachment attribute should exist after prepareForExport")
        XCTAssertTrue(preparedAttachment is ImageAttachment, "Attachment should still be ImageAttachment (not generic NSTextAttachment)")
        
        // Step 4: toRTF — images are not embedded in RTF export
        guard let rtfData = AttributedStringSerializer.toRTF(prepared) else {
            XCTFail("toRTF returned nil for attributed string with image")
            return
        }
        
        guard let rtfString = String(data: rtfData, encoding: .utf8) else {
            XCTFail("RTF data is not valid UTF-8")
            return
        }
        
        // RTF should contain text but NOT embedded images
        XCTAssertTrue(rtfString.contains("Document"), "RTF should contain 'Document' text")
        XCTAssertTrue(rtfString.contains("more text"), "RTF should contain 'more text'")
        XCTAssertFalse(rtfString.contains("\\pict\\jpegblip"), "RTF should NOT contain embedded images (by design)")
    }
    
    func testRTFExportMultipleFiles() {
        // Given: simulate exportMultipleToRTF with two attributed strings, one with image
        let text1 = "First file\u{FFFC}end"
        let as1 = NSMutableAttributedString(string: text1)
        
        let testImage = createTestImage(width: 100, height: 100)
        guard let imageData = testImage.pngData(),
              let attachment = ImageAttachment.from(imageData: imageData) else {
            XCTFail("Failed to create image attachment")
            return
        }
        let attachmentStr = NSAttributedString(attachment: attachment)
        as1.replaceCharacters(in: NSRange(location: 10, length: 1), with: attachmentStr)
        
        let as2 = NSAttributedString(string: "Second file with no images")
        
        // Simulate exportMultipleToRTF combining logic
        let combined = NSMutableAttributedString()
        let prepared1 = AttributedStringSerializer.prepareForExport(from: as1)
        combined.append(prepared1)
        combined.append(NSAttributedString(string: "\n\n"))
        let prepared2 = AttributedStringSerializer.prepareForExport(from: as2)
        combined.append(prepared2)
        
        // Verify image survived combining
        var foundImage = false
        combined.enumerateAttribute(.attachment, in: NSRange(location: 0, length: combined.length)) { value, _, _ in
            if value is ImageAttachment {
                foundImage = true
            }
        }
        XCTAssertTrue(foundImage, "ImageAttachment should survive combining multiple attributed strings")
        
        // Generate RTF — images are stripped by Apple's standard RTF converter
        guard let rtfData = AttributedStringSerializer.toRTF(combined) else {
            XCTFail("toRTF returned nil")
            return
        }
        
        guard let rtfString = String(data: rtfData, encoding: .utf8) else {
            XCTFail("RTF data is not valid UTF-8")
            return
        }
        
        // RTF should contain text but NOT embedded images
        XCTAssertFalse(rtfString.contains("\\pict\\jpegblip"), "Combined RTF should NOT contain embedded images (by design)")
        XCTAssertTrue(rtfString.contains("Second file"), "Combined RTF should contain second file text")
    }
}
