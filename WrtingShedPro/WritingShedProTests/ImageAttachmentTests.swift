//
//  ImageAttachmentTests.swift
//  WritingShedProTests
//
//  Tests for ImageAttachment model
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class ImageAttachmentTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testImageAttachmentCreation() {
        // Given/When
        let attachment = ImageAttachment()
        
        // Then
        XCTAssertNotNil(attachment.imageID, "Image ID should be generated")
        XCTAssertEqual(attachment.scale, 1.0, "Default scale should be 1.0 (100%)")
        XCTAssertEqual(attachment.alignment, .left, "Default alignment should be left")
        XCTAssertFalse(attachment.hasCaption, "Caption should be disabled by default")
        XCTAssertNil(attachment.captionText, "Caption text should be nil by default")
        XCTAssertNil(attachment.captionStyle, "Caption style should be nil by default")
        XCTAssertNil(attachment.fileID, "File ID should be nil by default")
    }
    
    func testFileIDProperty() {
        // Given
        let attachment = ImageAttachment()
        let testFileID = UUID()
        
        // When
        attachment.fileID = testFileID
        
        // Then
        XCTAssertEqual(attachment.fileID, testFileID, "File ID should be set correctly")
    }
    
    // MARK: - Scale Tests
    
    func testSetScale() {
        // Given
        let attachment = ImageAttachment()
        
        // When
        attachment.setScale(0.5)
        
        // Then
        XCTAssertEqual(attachment.scale, 0.5, "Scale should be set to 0.5 (50%)")
    }
    
    func testScaleClampsToMinimum() {
        // Given
        let attachment = ImageAttachment()
        
        // When
        attachment.setScale(0.05) // Below minimum
        
        // Then
        XCTAssertEqual(attachment.scale, 0.1, "Scale should be clamped to minimum 0.1 (10%)")
    }
    
    func testScaleClampsToMaximum() {
        // Given
        let attachment = ImageAttachment()
        
        // When
        attachment.setScale(2.5) // Above maximum
        
        // Then
        XCTAssertEqual(attachment.scale, 2.0, "Scale should be clamped to maximum 2.0 (200%)")
    }
    
    func testIncrementScale() {
        // Given
        let attachment = ImageAttachment()
        attachment.setScale(0.5)
        
        // When
        attachment.incrementScale()
        
        // Then
        XCTAssertEqual(attachment.scale, 0.55, accuracy: 0.001, "Scale should increment by 0.05")
    }
    
    func testDecrementScale() {
        // Given
        let attachment = ImageAttachment()
        attachment.setScale(0.5)
        
        // When
        attachment.decrementScale()
        
        // Then
        XCTAssertEqual(attachment.scale, 0.45, accuracy: 0.001, "Scale should decrement by 0.05")
    }
    
    func testScalePercentageString() {
        // Given
        let attachment = ImageAttachment()
        attachment.setScale(0.95)
        
        // When
        let percentage = attachment.scalePercentage()
        
        // Then
        XCTAssertEqual(percentage, "95.00 %", "Scale percentage should be formatted correctly")
    }
    
    // MARK: - Alignment Tests
    
    func testSetAlignment() {
        // Given
        let attachment = ImageAttachment()
        
        // When
        attachment.setAlignment(.center)
        
        // Then
        XCTAssertEqual(attachment.alignment, .center, "Alignment should be set to center")
    }
    
    func testAlignmentRawValues() {
        // Test that alignment enum has correct raw values
        XCTAssertEqual(ImageAttachment.ImageAlignment.left.rawValue, "left")
        XCTAssertEqual(ImageAttachment.ImageAlignment.center.rawValue, "center")
        XCTAssertEqual(ImageAttachment.ImageAlignment.right.rawValue, "right")
        XCTAssertEqual(ImageAttachment.ImageAlignment.inline.rawValue, "inline")
    }
    
    // MARK: - Caption Tests
    
    func testSetCaption() {
        // Given
        let attachment = ImageAttachment()
        
        // When
        attachment.setCaption(text: "My caption", style: "caption1")
        
        // Then
        XCTAssertTrue(attachment.hasCaption, "hasCaption should be true")
        XCTAssertEqual(attachment.captionText, "My caption")
        XCTAssertEqual(attachment.captionStyle, "caption1")
    }
    
    func testSetCaptionWithEmptyText() {
        // Given
        let attachment = ImageAttachment()
        attachment.setCaption(text: "Some text", style: "caption1")
        
        // When
        attachment.setCaption(text: "", style: "caption1")
        
        // Then
        XCTAssertFalse(attachment.hasCaption, "hasCaption should be false for empty text")
    }
    
    func testSetCaptionWithNilText() {
        // Given
        let attachment = ImageAttachment()
        attachment.setCaption(text: "Some text", style: "caption1")
        
        // When
        attachment.setCaption(text: nil, style: "caption1")
        
        // Then
        XCTAssertFalse(attachment.hasCaption, "hasCaption should be false for nil text")
    }
    
    func testSetCaptionEnabled() {
        // Given
        let attachment = ImageAttachment()
        
        // When
        attachment.setCaptionEnabled(true)
        
        // Then
        XCTAssertTrue(attachment.hasCaption, "Caption should be enabled")
        
        // When
        attachment.setCaptionEnabled(false)
        
        // Then
        XCTAssertFalse(attachment.hasCaption, "Caption should be disabled")
    }
    
    func testUpdateCaption() {
        // Given
        let attachment = ImageAttachment()
        
        // When
        attachment.updateCaption(hasCaption: true, text: "Test caption", style: "caption2")
        
        // Then
        XCTAssertTrue(attachment.hasCaption, "hasCaption should be true")
        XCTAssertEqual(attachment.captionText, "Test caption")
        XCTAssertEqual(attachment.captionStyle, "caption2")
    }
    
    func testUpdateCaptionDisabled() {
        // Given
        let attachment = ImageAttachment()
        attachment.updateCaption(hasCaption: true, text: "Initial", style: "caption1")
        
        // When - disable caption but keep text
        attachment.updateCaption(hasCaption: false, text: "Initial", style: "caption1")
        
        // Then
        XCTAssertFalse(attachment.hasCaption, "hasCaption should be false")
        XCTAssertEqual(attachment.captionText, "Initial", "Caption text should be preserved")
        XCTAssertEqual(attachment.captionStyle, "caption1", "Caption style should be preserved")
    }
    
    func testCaptionNotificationIsSent() {
        // Given
        let attachment = ImageAttachment()
        let expectation = XCTestExpectation(description: "Notification should be posted")
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ImageAttachmentPropertiesChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let imageID = notification.userInfo?["imageID"] as? UUID,
               imageID == attachment.imageID {
                expectation.fulfill()
            }
        }
        
        // When
        attachment.updateCaption(hasCaption: true, text: "Test", style: "caption1")
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Display Size Tests
    
    func testDisplaySizeWithImage() {
        // Given
        let attachment = ImageAttachment()
        let testImage = createTestImage(width: 400, height: 200)
        attachment.image = testImage
        attachment.setScale(0.5)
        
        // When
        let displaySize = attachment.displaySize
        
        // Then
        XCTAssertEqual(displaySize.width, 200, accuracy: 0.1, "Display width should be 400 * 0.5 = 200")
        XCTAssertEqual(displaySize.height, 100, accuracy: 0.1, "Display height should be 200 * 0.5 = 100")
    }
    
    func testDisplaySizeWithoutImage() {
        // Given
        let attachment = ImageAttachment()
        // No image set
        
        // When
        let displaySize = attachment.displaySize
        
        // Then
        XCTAssertEqual(displaySize.width, 300, "Default width should be 300")
        XCTAssertEqual(displaySize.height, 200, "Default height should be 200")
    }
    
    // MARK: - Static Methods Tests
    
    func testCalculateDisplaySize() {
        // Given
        let image = createTestImage(width: 800, height: 600)
        
        // When
        let displaySize = ImageAttachment.calculateDisplaySize(for: image, maxWidth: 600)
        
        // Then
        XCTAssertEqual(displaySize.width, 600, "Width should be clamped to maxWidth")
        XCTAssertEqual(displaySize.height, 450, accuracy: 0.1, "Height should maintain aspect ratio")
    }
    
    func testCalculateDisplaySizeForSmallImage() {
        // Given
        let image = createTestImage(width: 400, height: 300)
        
        // When
        let displaySize = ImageAttachment.calculateDisplaySize(for: image, maxWidth: 600)
        
        // Then
        XCTAssertEqual(displaySize.width, 400, "Width should not exceed original")
        XCTAssertEqual(displaySize.height, 300, "Height should not exceed original")
    }
    
    func testCompressImage() {
        // Given
        let largeImage = createTestImage(width: 3000, height: 2000)
        
        // When
        let compressedData = ImageAttachment.compressImage(largeImage)
        
        // Then
        XCTAssertNotNil(compressedData, "Compressed data should not be nil")
        if let data = compressedData {
            XCTAssertLessThan(data.count, 3_000_000, "Compressed data should be smaller than 3MB")
        }
    }
    
    func testFromImageData() {
        // Given
        let testImage = createTestImage(width: 400, height: 300)
        guard let imageData = testImage.pngData() else {
            XCTFail("Failed to create image data")
            return
        }
        
        // When
        let attachment = ImageAttachment.from(imageData: imageData, scale: 0.75, alignment: .center)
        
        // Then
        XCTAssertNotNil(attachment, "Attachment should be created")
        XCTAssertEqual(attachment?.scale, 0.75, "Scale should be set")
        XCTAssertEqual(attachment?.alignment, .center, "Alignment should be set")
        XCTAssertNotNil(attachment?.image, "Image should be loaded")
        XCTAssertNotNil(attachment?.imageData, "Image data should be stored")
    }
    
    func testFromInvalidImageData() {
        // Given
        let invalidData = Data([0x00, 0x01, 0x02]) // Not valid image data
        
        // When
        let attachment = ImageAttachment.from(imageData: invalidData)
        
        // Then
        XCTAssertNil(attachment, "Attachment should be nil for invalid data")
    }
    
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
}
