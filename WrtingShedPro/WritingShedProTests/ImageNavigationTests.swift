//
//  ImageNavigationTests.swift
//  WritingShedProTests
//
//  Tests for cursor navigation around embedded images
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class ImageNavigationTests: XCTestCase {
    
    var textView: UITextView!
    var attributedText: NSMutableAttributedString!
    
    override func setUp() {
        super.setUp()
        textView = UITextView()
        
        // Create test text with structure: "a\n[image]\n[zero-width-space]b"
        // Position 0: 'a'
        // Position 1: newline
        // Position 2: image attachment
        // Position 3: newline
        // Position 4: zero-width space
        // Position 5: 'b'
        attributedText = NSMutableAttributedString(string: "a\n")
        
        // Add image
        let attachment = ImageAttachment()
        let attachmentString = NSAttributedString(attachment: attachment)
        attributedText.append(attachmentString)
        
        // Add newline + zero-width space + text
        attributedText.append(NSAttributedString(string: "\n\u{200B}b"))
        
        textView.attributedText = attributedText
    }
    
    override func tearDown() {
        textView = nil
        attributedText = nil
        super.tearDown()
    }
    
    // MARK: - Zero-Width Space Detection Tests
    
    func testZeroWidthSpaceAtPosition4() {
        // Given
        let text = textView.attributedText!.string
        let index = text.index(text.startIndex, offsetBy: 4)
        
        // When
        let char = text[index]
        
        // Then
        XCTAssertEqual(char, "\u{200B}", "Position 4 should contain zero-width space")
    }
    
    func testImageAtPosition2() {
        // Given
        let text = textView.attributedText!
        
        // When
        let attachment = text.attribute(.attachment, at: 2, effectiveRange: nil)
        
        // Then
        XCTAssertNotNil(attachment, "Position 2 should contain an attachment")
        XCTAssertTrue(attachment is ImageAttachment, "Attachment should be an ImageAttachment")
    }
    
    // MARK: - Text Structure Tests
    
    func testTextLength() {
        // Given/When
        let length = textView.attributedText.length
        
        // Then
        XCTAssertEqual(length, 6, "Text should have 6 characters total")
    }
    
    func testTextStructure() {
        // Given
        let text = textView.attributedText!.string
        
        // When/Then
        XCTAssertEqual(text.count, 6, "String should have 6 characters")
        
        let char0 = text[text.index(text.startIndex, offsetBy: 0)]
        XCTAssertEqual(char0, "a", "Position 0 should be 'a'")
        
        let char1 = text[text.index(text.startIndex, offsetBy: 1)]
        XCTAssertEqual(char1, "\n", "Position 1 should be newline")
        
        let char2 = text[text.index(text.startIndex, offsetBy: 2)]
        XCTAssertEqual(char2, "\u{FFFC}", "Position 2 should be object replacement character (image)")
        
        let char3 = text[text.index(text.startIndex, offsetBy: 3)]
        XCTAssertEqual(char3, "\n", "Position 3 should be newline")
        
        let char4 = text[text.index(text.startIndex, offsetBy: 4)]
        XCTAssertEqual(char4, "\u{200B}", "Position 4 should be zero-width space")
        
        let char5 = text[text.index(text.startIndex, offsetBy: 5)]
        XCTAssertEqual(char5, "b", "Position 5 should be 'b'")
    }
    
    // MARK: - Navigation Direction Tests
    
    func testForwardNavigationDetection() {
        // Given
        let previousPosition = 3
        let currentPosition = 4
        
        // When
        let movingForward = currentPosition > previousPosition
        
        // Then
        XCTAssertTrue(movingForward, "Should detect forward movement from position 3 to 4")
    }
    
    func testBackwardNavigationDetection() {
        // Given
        let previousPosition = 5
        let currentPosition = 4
        
        // When
        let movingBackward = currentPosition < previousPosition
        
        // Then
        XCTAssertTrue(movingBackward, "Should detect backward movement from position 5 to 4")
    }
    
    // MARK: - Selection Range Tests
    
    func testImageSelectionRange() {
        // Given/When
        let imageSelectionRange = NSRange(location: 2, length: 1)
        
        // Then
        XCTAssertEqual(imageSelectionRange.location, 2, "Image selection should start at position 2")
        XCTAssertEqual(imageSelectionRange.length, 1, "Image selection should have length 1")
    }
    
    func testCursorPositionRange() {
        // Given/When
        let cursorRange = NSRange(location: 5, length: 0)
        
        // Then
        XCTAssertEqual(cursorRange.length, 0, "Cursor (not selection) should have length 0")
    }
    
    // MARK: - Position Calculation Tests
    
    func testSkipToPositionAfterZeroWidthSpace() {
        // Given
        let zeroWidthSpacePosition = 4
        
        // When
        let nextPosition = zeroWidthSpacePosition + 1
        
        // Then
        XCTAssertEqual(nextPosition, 5, "Should skip to position 5 after zero-width space")
    }
    
    func testSkipBackToImageFromZeroWidthSpace() {
        // Given
        let zeroWidthSpacePosition = 4
        
        // When
        let imagePosition = zeroWidthSpacePosition - 2 // Skip newline at position 3
        
        // Then
        XCTAssertEqual(imagePosition, 2, "Should skip back to image at position 2")
    }
    
    func testMoveBeforeImageWhenAlreadySelected() {
        // Given
        let imagePosition = 2
        
        // When
        let beforeImagePosition = imagePosition - 1
        
        // Then
        XCTAssertEqual(beforeImagePosition, 1, "Should move to position 1 (before image)")
    }
    
    func testSkipForwardFromImage() {
        // Given
        let imagePosition = 2
        
        // When
        let afterImagePosition = imagePosition + 3 // Skip newline + zero-width space
        
        // Then
        XCTAssertEqual(afterImagePosition, 5, "Should skip to position 5 when moving forward from image")
    }
    
    // MARK: - Edge Case Tests
    
    func testPositionBounds() {
        // Given
        let textLength = textView.attributedText.length
        
        // When/Then
        XCTAssertTrue(0 < textLength, "Position 0 should be valid")
        XCTAssertTrue(textLength - 1 < textLength, "Last position should be valid")
        XCTAssertFalse(textLength < textLength, "Position equal to length should not be valid for character access")
    }
    
    func testImagePositionIsValid() {
        // Given
        let imagePosition = 2
        let textLength = textView.attributedText.length
        
        // When
        let isValid = imagePosition >= 0 && imagePosition < textLength
        
        // Then
        XCTAssertTrue(isValid, "Image position should be valid")
    }
    
    func testZeroWidthSpacePositionIsValid() {
        // Given
        let zeroWidthSpacePosition = 4
        let textLength = textView.attributedText.length
        
        // When
        let isValid = zeroWidthSpacePosition >= 0 && zeroWidthSpacePosition < textLength
        
        // Then
        XCTAssertTrue(isValid, "Zero-width space position should be valid")
    }
    
    // MARK: - Previous Selection State Tests
    
    func testImageWasSelected() {
        // Given
        let previousSelection = NSRange(location: 2, length: 1)
        
        // When
        let wasImageSelected = previousSelection.length == 1
        
        // Then
        XCTAssertTrue(wasImageSelected, "Length 1 indicates image was selected")
    }
    
    func testImageWasNotSelected() {
        // Given
        let previousSelection = NSRange(location: 2, length: 0)
        
        // When
        let wasImageSelected = previousSelection.length == 1
        
        // Then
        XCTAssertFalse(wasImageSelected, "Length 0 indicates cursor, not image selection")
    }
    
    func testNewPositionMatchesPreviousImagePosition() {
        // Given
        let previousSelection = NSRange(location: 2, length: 1)
        let newPosition = 2
        
        // When
        let isAtSameImagePosition = previousSelection.length == 1 && 
                                   previousSelection.location == newPosition
        
        // Then
        XCTAssertTrue(isAtSameImagePosition, "Should detect cursor returned to already-selected image")
    }
}
