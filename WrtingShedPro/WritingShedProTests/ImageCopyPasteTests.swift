//
//  ImageCopyPasteTests.swift
//  WritingShedProTests
//
//  Created on November 3, 2025.
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

class ImageCopyPasteTests: XCTestCase {
    
    var testImage: UIImage!
    var testImageData: Data!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a simple test image (1x1 red pixel)
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        testImageData = testImage.pngData()!
    }
    
    override func tearDownWithError() throws {
        testImage = nil
        testImageData = nil
        try super.tearDownWithError()
    }
    
    // MARK: - NSSecureCoding Tests
    
    func testImageAttachmentSupportsSecureCoding() {
        // Test that ImageAttachment declares secure coding support
        XCTAssertTrue(ImageAttachment.supportsSecureCoding, 
                     "ImageAttachment must support NSSecureCoding")
    }
    
    func testEncodeDecodeBasicProperties() throws {
        // Create an image attachment with specific properties
        let original = ImageAttachment()
        original.imageData = testImageData
        original.scale = 0.5
        original.alignment = .left
        original.imageStyleName = "Custom Style"
        
        // Encode
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        
        // Decode
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decoded, "Decoded attachment should not be nil")
        XCTAssertEqual(Double(decoded?.scale ?? 0), 0.5, accuracy: 0.001)
        XCTAssertEqual(decoded?.alignment, .left)
        XCTAssertEqual(decoded?.imageStyleName, "Custom Style")
        XCTAssertEqual(decoded?.imageData, testImageData)
    }
    
    func testEncodeDecodeCaptionProperties() throws {
        // Create an image attachment with caption
        let original = ImageAttachment()
        original.imageData = testImageData
        original.hasCaption = true
        original.captionText = "Test Caption"
        original.captionStyle = "Caption Style"
        
        // Encode
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        
        // Decode
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded?.hasCaption ?? false)
        XCTAssertEqual(decoded?.captionText, "Test Caption")
        XCTAssertEqual(decoded?.captionStyle, "Caption Style")
    }
    
    func testEncodeDecodeAllProperties() throws {
        // Create an image attachment with all properties set
        let original = ImageAttachment()
        original.imageData = testImageData
        original.scale = 0.75
        original.alignment = .right
        original.imageStyleName = "Full Test Style"
        original.hasCaption = true
        original.captionText = "Complete Caption"
        original.captionStyle = "Caption Style Name"
        
        // Encode
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        
        // Decode
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(Double(decoded?.scale ?? 0), 0.75, accuracy: 0.001)
        XCTAssertEqual(decoded?.alignment, .right)
        XCTAssertEqual(decoded?.imageStyleName, "Full Test Style")
        XCTAssertTrue(decoded?.hasCaption ?? false)
        XCTAssertEqual(decoded?.captionText, "Complete Caption")
        XCTAssertEqual(decoded?.captionStyle, "Caption Style Name")
        XCTAssertEqual(decoded?.imageData, testImageData)
    }
    
    func testEncodeDecodeImageID() throws {
        // Create an image attachment
        let original = ImageAttachment()
        original.imageData = testImageData
        let originalID = original.imageID
        
        // Encode
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        
        // Decode
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.imageID, originalID, 
                      "ImageID should be preserved through encode/decode")
    }
    
    func testEncodeDecodeWithDefaultValues() throws {
        // Create an image attachment with minimal properties
        let original = ImageAttachment()
        original.imageData = testImageData
        // Don't set other properties - use defaults
        
        // Encode
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        
        // Decode
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(Double(decoded?.scale ?? 0), 1.0, accuracy: 0.001, "Default scale should be 1.0")
        XCTAssertEqual(decoded?.alignment, .left, "Default alignment should be left")
        XCTAssertEqual(decoded?.imageStyleName, "default", "Default style name should be 'default'")
        XCTAssertFalse(decoded?.hasCaption ?? true, "Default hasCaption should be false")
    }
    
    func testEncodeDecodeWithNilImageData() throws {
        // Create an image attachment without image data
        let original = ImageAttachment()
        original.scale = 0.5
        original.alignment = .left
        // imageData is nil
        
        // Encode
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        
        // Decode
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decoded)
        XCTAssertNil(decoded?.imageData, "Nil imageData should remain nil after encode/decode")
        XCTAssertEqual(Double(decoded?.scale ?? 0), 0.5, accuracy: 0.001)
        XCTAssertEqual(decoded?.alignment, .left)
    }
    
    func testMultipleEncodeDecodeRoundtrips() throws {
        // Create original
        let original = ImageAttachment()
        original.imageData = testImageData
        original.scale = 0.33
        original.alignment = .right
        original.hasCaption = true
        original.captionText = "Round Trip Test"
        
        // First roundtrip
        var data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        var decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        // Second roundtrip
        data = try NSKeyedArchiver.archivedData(
            withRootObject: decoded!,
            requiringSecureCoding: true
        )
        decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        // Third roundtrip
        data = try NSKeyedArchiver.archivedData(
            withRootObject: decoded!,
            requiringSecureCoding: true
        )
        decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        // Verify properties survived multiple roundtrips
        XCTAssertEqual(Double(decoded?.scale ?? 0), 0.33, accuracy: 0.001)
        XCTAssertEqual(decoded?.alignment, .right)
        XCTAssertTrue(decoded?.hasCaption ?? false)
        XCTAssertEqual(decoded?.captionText, "Round Trip Test")
        XCTAssertEqual(decoded?.imageData, testImageData)
    }
    
    // MARK: - Attributed String Copy/Paste Simulation
    // Note: FileWrapper-based tests are not included because ImageAttachment doesn't override
    // the fileWrapper property. The FormattedTextEditor.paste() method handles image property
    // preservation manually using NSSecureCoding when pasting RTFD data.
    
    func testAttributedStringWithImageAttachment() throws {
        // Create attributed string with image
        let attachment = ImageAttachment()
        attachment.imageData = testImageData
        attachment.scale = 0.7
        attachment.alignment = .right
        
        let attributedString = NSMutableAttributedString(string: "Before")
        attributedString.append(NSAttributedString(attachment: attachment))
        attributedString.append(NSAttributedString(string: "After"))
        
        // Verify attachment is in the string
        var foundAttachment: ImageAttachment?
        attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, range, stop in
            if let attachment = value as? ImageAttachment {
                foundAttachment = attachment
                stop.pointee = true
            }
        }
        
        XCTAssertNotNil(foundAttachment)
        XCTAssertEqual(Double(foundAttachment?.scale ?? 0), 0.7, accuracy: 0.001)
        XCTAssertEqual(foundAttachment?.alignment, .right)
    }

    func testClipboardCodecPreservesImagePropertiesAndCreatesNewIdentity() throws {
        let original = ImageAttachment()
        original.imageData = testImageData
        original.scale = 0.65
        original.alignment = .center
        original.hasCaption = true
        original.captionText = "Clipboard caption"
        let originalID = original.imageID

        let data = try XCTUnwrap(FormattedTextEditorImageClipboard.encode(original))
        let pasted = try XCTUnwrap(FormattedTextEditorImageClipboard.decode(data))

        XCTAssertNotEqual(pasted.imageID, originalID)
        XCTAssertEqual(pasted.imageData, testImageData)
        XCTAssertEqual(Double(pasted.scale), 0.65, accuracy: 0.001)
        XCTAssertEqual(pasted.alignment, .center)
        XCTAssertTrue(pasted.hasCaption)
        XCTAssertEqual(pasted.captionText, "Clipboard caption")
    }

    func testClipboardSelectionFindsOnlyExactlySelectedImage() {
        let attachment = ImageAttachment()
        attachment.imageData = testImageData
        let content = NSMutableAttributedString(string: "A")
        content.append(NSAttributedString(attachment: attachment))
        content.append(NSAttributedString(string: "B"))

        XCTAssertTrue(
            FormattedTextEditorImageClipboard.selectedAttachment(
                in: content,
                range: NSRange(location: 1, length: 1)
            ) === attachment
        )
        XCTAssertNil(
            FormattedTextEditorImageClipboard.selectedAttachment(
                in: content,
                range: NSRange(location: 0, length: 2)
            )
        )
    }

    @MainActor
    func testCutImageCommandSupportsUndoAndRedo() throws {
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let file = TextFile(name: "Clipboard Test", initialContent: "")
        context.insert(file)

        let attachment = ImageAttachment()
        attachment.imageData = testImageData
        attachment.scale = 0.6
        attachment.alignment = .right
        attachment.captionText = "Restored caption"
        attachment.hasCaption = true

        let content = NSMutableAttributedString(string: "A")
        content.append(NSAttributedString(attachment: attachment))
        content.append(NSAttributedString(string: "B"))
        file.currentVersion?.attributedContent = content

        let manager = TextFileUndoManager(file: file)
        let command = try XCTUnwrap(DeleteImageCommand(position: 1, attachment: attachment, targetFile: file))
        let restorationExpectation = expectation(description: "Image command restores content in place")
        restorationExpectation.expectedFulfillmentCount = 3
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UndoRedoContentRestored"),
            object: file,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["updateEditorInPlace"] as? Bool, true)
            XCTAssertEqual(notification.userInfo?["caretPosition"] as? Int, 1)
            restorationExpectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.execute(command)

        XCTAssertTrue(manager.canUndo)
        XCTAssertEqual(file.currentVersion?.attributedContent?.string, "AB")

        manager.undo()

        XCTAssertTrue(manager.canRedo)
        let restoredContent = try XCTUnwrap(file.currentVersion?.attributedContent)
        let restoredAttachment = try XCTUnwrap(
            restoredContent.attribute(.attachment, at: 1, effectiveRange: nil) as? ImageAttachment
        )
        XCTAssertTrue(restoredAttachment === attachment)
        XCTAssertEqual(restoredAttachment.imageData, testImageData)
        XCTAssertEqual(Double(restoredAttachment.scale), 0.6, accuracy: 0.001)
        XCTAssertEqual(restoredAttachment.alignment, .right)
        XCTAssertEqual(restoredAttachment.captionText, "Restored caption")

        manager.redo()

        XCTAssertTrue(manager.canUndo)
        XCTAssertEqual(file.currentVersion?.attributedContent?.string, "AB")
        wait(for: [restorationExpectation], timeout: 1)
    }

    // Note: RTFD copy/paste tests are not included because:
    // 1. RTFD encoding/decoding behavior is complex and platform-specific
    // 2. NSAttributedString RTFD serialization may not preserve custom attachment subclasses
    // 3. The actual FormattedTextEditor.paste() method uses UIPasteboard directly, not RTFD
    //    to detect and convert pasted images, preserving ImageAttachment properties
    
    // MARK: - Edge Cases
    
    func testEncodeDecodeEmptyCaption() throws {
        // Create attachment with empty caption
        let original = ImageAttachment()
        original.imageData = testImageData
        original.hasCaption = true
        original.captionText = "" // Empty string
        
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: true
        )
        
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertNotNil(decoded)
        XCTAssertTrue(decoded?.hasCaption ?? false)
        XCTAssertEqual(decoded?.captionText, "")
    }
    
    func testEncodeDecodeExtremeLScaleValues() throws {
        // Test minimum scale
        let minScale = ImageAttachment()
        minScale.imageData = testImageData
        minScale.scale = 0.1
        
        var data = try NSKeyedArchiver.archivedData(
            withRootObject: minScale,
            requiringSecureCoding: true
        )
        var decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertEqual(Double(decoded?.scale ?? 0), 0.1, accuracy: 0.001)
        
        // Test maximum scale
        let maxScale = ImageAttachment()
        maxScale.imageData = testImageData
        maxScale.scale = 1.0
        
        data = try NSKeyedArchiver.archivedData(
            withRootObject: maxScale,
            requiringSecureCoding: true
        )
        decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertEqual(Double(decoded?.scale ?? 0), 1.0, accuracy: 0.001)
    }
    
    func testEncodeDecodeAllAlignments() throws {
        let alignments: [ImageAttachment.ImageAlignment] = [.left, .center, .right, .inline]
        
        for alignment in alignments {
            let attachment = ImageAttachment()
            attachment.imageData = testImageData
            attachment.alignment = alignment
            
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: attachment,
                requiringSecureCoding: true
            )
            
            let decoded = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ImageAttachment.self,
                from: data
            )
            
            XCTAssertEqual(decoded?.alignment, alignment, 
                          "Alignment \(alignment) should be preserved")
        }
    }
    
    func testEncodeDecodeLongStrings() throws {
        // Test with very long style names and captions
        let longString = String(repeating: "A", count: 1000)
        
        let attachment = ImageAttachment()
        attachment.imageData = testImageData
        attachment.imageStyleName = longString
        attachment.hasCaption = true
        attachment.captionText = longString
        attachment.captionStyle = longString
        
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: attachment,
            requiringSecureCoding: true
        )
        
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertEqual(decoded?.imageStyleName, longString)
        XCTAssertEqual(decoded?.captionText, longString)
        XCTAssertEqual(decoded?.captionStyle, longString)
    }
    
    func testEncodeDecodeSpecialCharacters() throws {
        // Test with special characters in strings
        let specialString = "Test™ <>&\"' 中文 🎨📝✨"
        
        let attachment = ImageAttachment()
        attachment.imageData = testImageData
        attachment.imageStyleName = specialString
        attachment.hasCaption = true
        attachment.captionText = specialString
        
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: attachment,
            requiringSecureCoding: true
        )
        
        let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: data
        )
        
        XCTAssertEqual(decoded?.imageStyleName, specialString)
        XCTAssertEqual(decoded?.captionText, specialString)
    }
}
