//
//  CommentAttachmentTests.swift
//  Writing Shed Pro Tests
//
//  Feature 014: Comments - Unit tests for CommentAttachment
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class CommentAttachmentTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testCommentAttachmentInitialization() {
        let commentID = UUID()
        let attachment = CommentAttachment(commentID: commentID, isResolved: false)
        
        XCTAssertEqual(attachment.commentID, commentID)
        XCTAssertFalse(attachment.isResolved)
    }
    
    func testResolvedCommentAttachment() {
        let commentID = UUID()
        let attachment = CommentAttachment(commentID: commentID, isResolved: true)
        
        XCTAssertEqual(attachment.commentID, commentID)
        XCTAssertTrue(attachment.isResolved)
    }
    
    // MARK: - Image Generation Tests
    
    func testActiveCommentImage() {
        let attachment = CommentAttachment(commentID: UUID(), isResolved: false)
        
        let image = attachment.image(
            forBounds: CGRect(x: 0, y: 0, width: 16, height: 16),
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image, "Active comment should have an image")
        
        // Verify it's using the correct system image (icon size is 22)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let expectedImage = UIImage(systemName: "bubble.left.fill", withConfiguration: config)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        
        XCTAssertNotNil(expectedImage)
        // System symbol sizes can vary by OS version, use wider tolerance
        XCTAssertEqual(image?.size.width ?? 0, expectedImage?.size.width ?? 0, accuracy: 5.0)
        XCTAssertEqual(image?.size.height ?? 0, expectedImage?.size.height ?? 0, accuracy: 5.0)
    }
    
    func testResolvedCommentImage() {
        let attachment = CommentAttachment(commentID: UUID(), isResolved: true)
        
        let image = attachment.image(
            forBounds: CGRect(x: 0, y: 0, width: 16, height: 16),
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(image, "Resolved comment should have an image")
        
        // Verify it's using gray color (icon size is 22)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let expectedImage = UIImage(systemName: "bubble.left.fill", withConfiguration: config)?
            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        
        XCTAssertNotNil(expectedImage)
        // System symbol sizes can vary by OS version, use wider tolerance
        XCTAssertEqual(image?.size.width ?? 0, expectedImage?.size.width ?? 0, accuracy: 5.0)
        XCTAssertEqual(image?.size.height ?? 0, expectedImage?.size.height ?? 0, accuracy: 5.0)
    }
    
    func testImageSizeConsistency() {
        let activeAttachment = CommentAttachment(commentID: UUID(), isResolved: false)
        let resolvedAttachment = CommentAttachment(commentID: UUID(), isResolved: true)
        
        let activeImage = activeAttachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        let resolvedImage = resolvedAttachment.image(
            forBounds: CGRect.zero,
            textContainer: nil,
            characterIndex: 0
        )
        
        XCTAssertNotNil(activeImage)
        XCTAssertNotNil(resolvedImage)
        
        // Active and resolved images should have the same size
        if let active = activeImage, let resolved = resolvedImage {
            XCTAssertEqual(active.size.width, resolved.size.width, accuracy: 0.1)
            XCTAssertEqual(active.size.height, resolved.size.height, accuracy: 0.1)
        }
    }
    
    // MARK: - Bounds Tests
    
    func testAttachmentBounds() {
        let attachment = CommentAttachment(commentID: UUID(), isResolved: false)
        
        let bounds = attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 100, height: 20),
            glyphPosition: CGPoint(x: 0, y: 0),
            characterIndex: 0
        )
        
        XCTAssertEqual(bounds.origin.x, 0)
        XCTAssertEqual(bounds.origin.y, -2) // Fallback value when no text container
        XCTAssertEqual(bounds.size.width, 22)
        XCTAssertEqual(bounds.size.height, 22)
    }
    
    func testBoundsConsistency() {
        let attachment1 = CommentAttachment(commentID: UUID(), isResolved: false)
        let attachment2 = CommentAttachment(commentID: UUID(), isResolved: true)
        
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
        
        // Both active and resolved attachments should have the same bounds
        XCTAssertEqual(bounds1, bounds2)
    }
    
    // MARK: - Unique ID Tests
    
    func testUniqueCommentIDs() {
        let id1 = UUID()
        let id2 = UUID()
        
        let attachment1 = CommentAttachment(commentID: id1, isResolved: false)
        let attachment2 = CommentAttachment(commentID: id2, isResolved: false)
        
        XCTAssertNotEqual(attachment1.commentID, attachment2.commentID)
    }
    
    func testSameIDDifferentStates() {
        let commentID = UUID()
        
        let activeAttachment = CommentAttachment(commentID: commentID, isResolved: false)
        let resolvedAttachment = CommentAttachment(commentID: commentID, isResolved: true)
        
        XCTAssertEqual(activeAttachment.commentID, resolvedAttachment.commentID)
        XCTAssertNotEqual(activeAttachment.isResolved, resolvedAttachment.isResolved)
    }
    
    // MARK: - NSTextAttachment Integration Tests
    
    func testAttachmentInAttributedString() {
        let attachment = CommentAttachment(commentID: UUID(), isResolved: false)
        let attachmentString = NSAttributedString(attachment: attachment)
        
        XCTAssertEqual(attachmentString.length, 1)
        
        let retrievedAttachment = attachmentString.attribute(
            .attachment,
            at: 0,
            effectiveRange: nil
        ) as? CommentAttachment
        
        XCTAssertNotNil(retrievedAttachment)
        XCTAssertEqual(retrievedAttachment?.commentID, attachment.commentID)
        XCTAssertEqual(retrievedAttachment?.isResolved, attachment.isResolved)
    }
    
    func testMultipleAttachmentsInString() {
        let attachment1 = CommentAttachment(commentID: UUID(), isResolved: false)
        let attachment2 = CommentAttachment(commentID: UUID(), isResolved: true)
        
        let mutableString = NSMutableAttributedString()
        mutableString.append(NSAttributedString(string: "Text before "))
        mutableString.append(NSAttributedString(attachment: attachment1))
        mutableString.append(NSAttributedString(string: " middle "))
        mutableString.append(NSAttributedString(attachment: attachment2))
        mutableString.append(NSAttributedString(string: " after"))
        
        // Find attachments
        var foundAttachments: [CommentAttachment] = []
        mutableString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: mutableString.length),
            options: []
        ) { value, range, stop in
            if let attachment = value as? CommentAttachment {
                foundAttachments.append(attachment)
            }
        }
        
        XCTAssertEqual(foundAttachments.count, 2)
        XCTAssertTrue(foundAttachments.contains { $0.commentID == attachment1.commentID })
        XCTAssertTrue(foundAttachments.contains { $0.commentID == attachment2.commentID })
    }
    
    // MARK: - Visual Consistency Tests
    
    func testImageNotNil() {
        let activeAttachment = CommentAttachment(commentID: UUID(), isResolved: false)
        let resolvedAttachment = CommentAttachment(commentID: UUID(), isResolved: true)
        
        let activeImage = activeAttachment.image(forBounds: .zero, textContainer: nil, characterIndex: 0)
        let resolvedImage = resolvedAttachment.image(forBounds: .zero, textContainer: nil, characterIndex: 0)
        
        XCTAssertNotNil(activeImage, "Active comment should always have an image")
        XCTAssertNotNil(resolvedImage, "Resolved comment should always have an image")
    }
    
    func testImageRenderingMode() {
        let attachment = CommentAttachment(commentID: UUID(), isResolved: false)
        
        let image = attachment.image(forBounds: .zero, textContainer: nil, characterIndex: 0)
        
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.renderingMode, .alwaysOriginal, "Image should use alwaysOriginal rendering mode")
    }
    
    // MARK: - Edge Cases
    
    func testAttachmentWithDifferentBoundsInputs() {
        let attachment = CommentAttachment(commentID: UUID(), isResolved: false)
        
        // Test with various proposed line fragments
        let bounds1 = attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: 100, height: 20),
            glyphPosition: CGPoint.zero,
            characterIndex: 0
        )
        
        let bounds2 = attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 50, y: 100, width: 200, height: 40),
            glyphPosition: CGPoint(x: 10, y: 10),
            characterIndex: 50
        )
        
        // Bounds should be consistent regardless of input
        XCTAssertEqual(bounds1, bounds2)
    }
    
    func testAttachmentSerializationInAttributedString() {
        let commentID = UUID()
        let attachment = CommentAttachment(commentID: commentID, isResolved: false)
        let attributedString = NSAttributedString(attachment: attachment)
        
        // Archive and unarchive
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: attributedString,
                requiringSecureCoding: false
            )
            
            let unarchived = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSAttributedString
            
            XCTAssertNotNil(unarchived)
            XCTAssertEqual(unarchived?.length, 1)
            
            // Note: Custom properties may not survive serialization
            // This tests that the attachment itself survives
            let retrievedAttachment = unarchived?.attribute(.attachment, at: 0, effectiveRange: nil)
            XCTAssertNotNil(retrievedAttachment)
        } catch {
            XCTFail("Serialization failed: \(error)")
        }
    }
}
