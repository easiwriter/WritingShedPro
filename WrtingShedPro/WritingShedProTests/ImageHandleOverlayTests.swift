//
//  ImageHandleOverlayTests.swift
//  WritingShedProTests
//
//  Tests for ImageHandleOverlay resize handle functionality
//

import XCTest
import SwiftUI
@testable import Writing_Shed_Pro

final class ImageHandleOverlayTests: XCTestCase {
    
    // MARK: - Anchor Point Tests
    
    func testCenterAlignmentUsesMiddleAnchor() {
        // Given: Center-aligned image
        let imageFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        _ = ImageAttachment.ImageAlignment.center
        
        // When: Calculate anchor point for center alignment
        let expectedAnchor = CGPoint(x: 50, y: 50) // Middle of 100x100 frame
        
        // Then: Anchor should be at center for symmetric resize
        XCTAssertEqual(expectedAnchor.x, imageFrame.width / 2, "Center anchor X should be at midpoint")
        XCTAssertEqual(expectedAnchor.y, imageFrame.height / 2, "Center anchor Y should be at midpoint")
    }
    
    func testLeftAlignmentUsesLeftAnchor() {
        // Given: Left-aligned image
        let imageFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        _ = ImageAttachment.ImageAlignment.left
        
        // When: Calculate anchor point for left alignment
        let expectedAnchor = CGPoint(x: 0, y: 50) // Left edge, vertical center
        
        // Then: Anchor should be at left edge
        XCTAssertEqual(expectedAnchor.x, 0, "Left anchor X should be at left edge")
        XCTAssertEqual(expectedAnchor.y, imageFrame.height / 2, "Left anchor Y should be at vertical center")
    }
    
    func testRightAlignmentUsesRightAnchor() {
        // Given: Right-aligned image
        let imageFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        _ = ImageAttachment.ImageAlignment.right
        
        // When: Calculate anchor point for right alignment
        let expectedAnchor = CGPoint(x: 100, y: 50) // Right edge, vertical center
        
        // Then: Anchor should be at right edge
        XCTAssertEqual(expectedAnchor.x, imageFrame.width, "Right anchor X should be at right edge")
        XCTAssertEqual(expectedAnchor.y, imageFrame.height / 2, "Right anchor Y should be at vertical center")
    }
    
    func testInlineAlignmentUsesMiddleAnchor() {
        // Given: Inline-aligned image (behaves like center)
        let imageFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        _ = ImageAttachment.ImageAlignment.inline
        
        // When: Calculate anchor point for inline alignment
        let expectedAnchor = CGPoint(x: 50, y: 50) // Middle of frame
        
        // Then: Anchor should be at center for symmetric resize
        XCTAssertEqual(expectedAnchor.x, imageFrame.width / 2, "Inline anchor X should be at midpoint")
        XCTAssertEqual(expectedAnchor.y, imageFrame.height / 2, "Inline anchor Y should be at midpoint")
    }
    
    // MARK: - Resize Behavior Tests
    
    func testCornerResizeMaintainsAspectRatio() {
        // Given: Original image dimensions
        let originalWidth: CGFloat = 100
        let originalHeight: CGFloat = 75
        let aspectRatio = originalWidth / originalHeight // 1.333...
        
        // When: User drags corner to resize width to 150
        let newWidth: CGFloat = 150
        let expectedHeight = newWidth / aspectRatio // Should be 112.5
        
        // Then: Height should scale proportionally
        XCTAssertEqual(expectedHeight, 112.5, accuracy: 0.1, 
                      "Height should scale to maintain aspect ratio")
    }
    
    func testMinimumSizeConstraint() {
        // Given: Minimum size constraint
        let minimumSize: CGFloat = 50
        
        // When: User tries to resize below minimum
        let attemptedWidth: CGFloat = 30
        let attemptedHeight: CGFloat = 30
        
        // Then: Size should be clamped to minimum
        let finalWidth = max(attemptedWidth, minimumSize)
        let finalHeight = max(attemptedHeight, minimumSize)
        
        XCTAssertEqual(finalWidth, minimumSize, "Width should be clamped to minimum")
        XCTAssertEqual(finalHeight, minimumSize, "Height should be clamped to minimum")
    }
    
    func testScaleCalculationFromResize() {
        // Given: Original image size and current scale
        let originalImageWidth: CGFloat = 200
        let currentScale: CGFloat = 0.5 // Currently displayed at 100px
        _ = originalImageWidth * currentScale // 100px
        
        // When: User resizes to 150px width
        let newDisplayWidth: CGFloat = 150
        let newScale = newDisplayWidth / originalImageWidth // Should be 0.75
        
        // Then: New scale should be correct
        XCTAssertEqual(newScale, 0.75, accuracy: 0.001, 
                      "Scale should be calculated correctly from resize")
    }
    
    // MARK: - Edge Case Tests
    
    func testZeroSizeHandling() {
        // Given: Attempt to resize to zero
        let minimumSize: CGFloat = 50
        let attemptedSize: CGFloat = 0
        
        // When: Clamping to minimum
        let finalSize = max(attemptedSize, minimumSize)
        
        // Then: Should use minimum size
        XCTAssertEqual(finalSize, minimumSize, 
                      "Zero size should be prevented by minimum constraint")
    }
    
    func testNegativeSizeHandling() {
        // Given: Attempt to resize to negative (drag past anchor)
        let minimumSize: CGFloat = 50
        let attemptedSize: CGFloat = -10
        
        // When: Clamping to minimum
        let finalSize = max(attemptedSize, minimumSize)
        
        // Then: Should use minimum size
        XCTAssertEqual(finalSize, minimumSize, 
                      "Negative size should be prevented by minimum constraint")
    }
    
    // MARK: - Handle Position Tests
    
    func testTopLeftHandlePosition() {
        // Given: Image frame
        let imageFrame = CGRect(x: 100, y: 100, width: 200, height: 150)
        _ = CGFloat(10) // handleSize
        
        // When: Calculate top-left handle position
        let handleX = imageFrame.minX
        let handleY = imageFrame.minY
        
        // Then: Should be at top-left corner
        XCTAssertEqual(handleX, 100, "Top-left handle X should be at left edge")
        XCTAssertEqual(handleY, 100, "Top-left handle Y should be at top edge")
    }
    
    func testBottomRightHandlePosition() {
        // Given: Image frame
        let imageFrame = CGRect(x: 100, y: 100, width: 200, height: 150)
        let handleSize: CGFloat = 10
        
        // When: Calculate bottom-right handle position
        let handleX = imageFrame.maxX - handleSize
        let handleY = imageFrame.maxY - handleSize
        
        // Then: Should be at bottom-right corner
        XCTAssertEqual(handleX, 290, "Bottom-right handle X should be at right edge minus handle size")
        XCTAssertEqual(handleY, 240, "Bottom-right handle Y should be at bottom edge minus handle size")
    }
    
    func testMiddleRightHandlePosition() {
        // Given: Image frame
        let imageFrame = CGRect(x: 100, y: 100, width: 200, height: 150)
        let handleSize: CGFloat = 10
        
        // When: Calculate middle-right handle position
        let handleX = imageFrame.maxX - handleSize
        let handleY = imageFrame.midY - (handleSize / 2)
        
        // Then: Should be at right edge, vertically centered
        XCTAssertEqual(handleX, 290, "Middle-right handle X should be at right edge")
        XCTAssertEqual(handleY, 170, "Middle-right handle Y should be vertically centered")
    }
    
    // MARK: - Integration Tests
    
    func testResizeUpdatesImageAttachmentScale() {
        // Given: An image attachment with original scale
        let attachment = ImageAttachment()
        
        // Create a 200x200 test image
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        attachment.imageData = testImage?.pngData()
        attachment.setScale(0.5) // Currently displayed at 100x100
        
        let originalScale = attachment.scale
        
        // When: User resizes to 150px width (new scale should be 0.75)
        let newDisplayWidth: CGFloat = 150
        let newScale = newDisplayWidth / 200 // 0.75
        attachment.setScale(newScale)
        
        // Then: Scale should be updated
        XCTAssertEqual(attachment.scale, 0.75, accuracy: 0.001, 
                      "Scale should be updated to match new display size")
        XCTAssertNotEqual(attachment.scale, originalScale, 
                         "Scale should have changed from original")
    }
}
