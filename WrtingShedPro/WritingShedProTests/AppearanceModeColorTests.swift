//
//  AppearanceModeColorTests.swift
//  WritingShedProTests
//
//  Tests for appearance mode color adaptation functionality
//  Verifies that adaptive colors (black/white/gray) are handled correctly
//  and that custom colors are preserved across light/dark modes.
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class AppearanceModeColorTests: XCTestCase {
    
    // MARK: - Color Detection Tests
    
    func testIsAdaptiveSystemColor_DetectsBlack() {
        // Given
        let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // When
        let result = AttributedStringSerializer.isAdaptiveSystemColor(black)
        
        // Then
        XCTAssertTrue(result, "Pure black should be detected as adaptive")
    }
    
    func testIsAdaptiveSystemColor_DetectsWhite() {
        // Given
        let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        // When
        let result = AttributedStringSerializer.isAdaptiveSystemColor(white)
        
        // Then
        XCTAssertTrue(result, "Pure white should be detected as adaptive")
    }
    
    func testIsAdaptiveSystemColor_DetectsGray() {
        // Given: Various shades of gray (R==G==B)
        let lightGray = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)
        let mediumGray = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let darkGray = UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        
        // When/Then
        XCTAssertTrue(AttributedStringSerializer.isAdaptiveSystemColor(lightGray), "Light gray should be adaptive")
        XCTAssertTrue(AttributedStringSerializer.isAdaptiveSystemColor(mediumGray), "Medium gray should be adaptive")
        XCTAssertTrue(AttributedStringSerializer.isAdaptiveSystemColor(darkGray), "Dark gray should be adaptive")
    }
    
    func testIsAdaptiveSystemColor_DoesNotDetectCustomColors() {
        // Given: Various custom colors
        let red = UIColor.red
        let blue = UIColor.blue
        let green = UIColor.green
        let cyan = UIColor(red: 0.00392157, green: 0.780392, blue: 0.988235, alpha: 1)
        
        // When/Then
        XCTAssertFalse(AttributedStringSerializer.isAdaptiveSystemColor(red), "Red should NOT be adaptive")
        XCTAssertFalse(AttributedStringSerializer.isAdaptiveSystemColor(blue), "Blue should NOT be adaptive")
        XCTAssertFalse(AttributedStringSerializer.isAdaptiveSystemColor(green), "Green should NOT be adaptive")
        XCTAssertFalse(AttributedStringSerializer.isAdaptiveSystemColor(cyan), "Cyan should NOT be adaptive")
    }
    
    func testIsFixedBlackOrWhite_DetectsBlack() {
        // Given
        let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // When
        let result = AttributedStringSerializer.isFixedBlackOrWhite(black)
        
        // Then
        XCTAssertTrue(result, "Pure black should be detected as fixed black/white")
    }
    
    func testIsFixedBlackOrWhite_DetectsWhite() {
        // Given
        let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        // When
        let result = AttributedStringSerializer.isFixedBlackOrWhite(white)
        
        // Then
        XCTAssertTrue(result, "Pure white should be detected as fixed black/white")
    }
    
    func testIsFixedBlackOrWhite_DoesNotDetectGray() {
        // Given
        let gray = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        
        // When
        let result = AttributedStringSerializer.isFixedBlackOrWhite(gray)
        
        // Then
        XCTAssertFalse(result, "Gray should NOT be detected as fixed black/white")
    }
    
    func testIsFixedBlackOrWhite_DoesNotDetectCustomColors() {
        // Given
        let red = UIColor.red
        let cyan = UIColor(red: 0.00392157, green: 0.780392, blue: 0.988235, alpha: 1)
        
        // When/Then
        XCTAssertFalse(AttributedStringSerializer.isFixedBlackOrWhite(red), "Red should NOT be fixed black/white")
        XCTAssertFalse(AttributedStringSerializer.isFixedBlackOrWhite(cyan), "Cyan should NOT be fixed black/white")
    }
    
    // MARK: - Strip Adaptive Colors Tests
    
    func testStripAdaptiveColors_RemovesBlackColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: black, range: NSRange(location: 0, length: text.count))
        
        // When
        let stripped = AttributedStringSerializer.stripAdaptiveColors(from: attributedString)
        
        // Then
        XCTAssertEqual(stripped.string, text, "Text should be preserved")
        let color = stripped.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "Black color should be replaced with .label for adaptive behavior")
    }
    
    func testStripAdaptiveColors_RemovesWhiteColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: white, range: NSRange(location: 0, length: text.count))
        
        // When
        let stripped = AttributedStringSerializer.stripAdaptiveColors(from: attributedString)
        
        // Then
        XCTAssertEqual(stripped.string, text, "Text should be preserved")
        let color = stripped.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "White color should be replaced with .label for adaptive behavior")
    }
    
    func testStripAdaptiveColors_RemovesGrayColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let gray = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: gray, range: NSRange(location: 0, length: text.count))
        
        // When
        let stripped = AttributedStringSerializer.stripAdaptiveColors(from: attributedString)
        
        // Then
        XCTAssertEqual(stripped.string, text, "Text should be preserved")
        let color = stripped.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "Gray color should be replaced with .label for adaptive behavior")
    }
    
    func testStripAdaptiveColors_PreservesCustomColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let cyan = UIColor(red: 0.00392157, green: 0.780392, blue: 0.988235, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: cyan, range: NSRange(location: 0, length: text.count))
        
        // When
        let stripped = AttributedStringSerializer.stripAdaptiveColors(from: attributedString)
        
        // Then
        XCTAssertEqual(stripped.string, text, "Text should be preserved")
        let color = stripped.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color, "Custom color should be preserved")
    }
    
    func testStripAdaptiveColors_HandlesMultipleRanges() {
        // Given: "Hello" in black, " " no color, "World" in cyan
        let text = "Hello World"
        let attributedString = NSMutableAttributedString(string: text)
        let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        let cyan = UIColor(red: 0.00392157, green: 0.780392, blue: 0.988235, alpha: 1)
        
        attributedString.addAttribute(.foregroundColor, value: black, range: NSRange(location: 0, length: 5)) // "Hello"
        attributedString.addAttribute(.foregroundColor, value: cyan, range: NSRange(location: 6, length: 5)) // "World"
        
        // When
        let stripped = AttributedStringSerializer.stripAdaptiveColors(from: attributedString)
        
        // Then
        XCTAssertEqual(stripped.string, text, "Text should be preserved")
        
        let helloColor = stripped.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(helloColor, UIColor.label, "Black color in 'Hello' should be replaced with .label")
        
        let worldColor = stripped.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(worldColor, "Cyan color in 'World' should be preserved")
    }
    
    // MARK: - Serialization Tests
    
    func testEncode_DoesNotSaveBlackColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: black, range: NSRange(location: 0, length: text.count))
        
        // When
        let data = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(data, text: text)
        
        // Then
        XCTAssertEqual(decoded.string, text, "Text should be preserved")
        let color = decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "Black color should not be saved but .label should be added for adaptive behavior")
    }
    
    func testEncode_DoesNotSaveWhiteColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: white, range: NSRange(location: 0, length: text.count))
        
        // When
        let data = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(data, text: text)
        
        // Then
        XCTAssertEqual(decoded.string, text, "Text should be preserved")
        let color = decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "White color should not be saved but .label should be added for adaptive behavior")
    }
    
    func testEncode_DoesNotSaveGrayColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let gray = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: gray, range: NSRange(location: 0, length: text.count))
        
        // When
        let data = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(data, text: text)
        
        // Then
        XCTAssertEqual(decoded.string, text, "Text should be preserved")
        let color = decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "Gray color should not be saved but .label should be added for adaptive behavior")
    }
    
    func testEncode_SavesCustomColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let cyan = UIColor(red: 0.00392157, green: 0.780392, blue: 0.988235, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: cyan, range: NSRange(location: 0, length: text.count))
        
        // When
        let data = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(data, text: text)
        
        // Then
        XCTAssertEqual(decoded.string, text, "Text should be preserved")
        let color = decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(color, "Custom color should be saved/restored")
    }
    
    func testEncode_PreservesBoldAndStripsBlackColor() {
        // Given
        let text = "Hello, World!"
        let attributedString = NSMutableAttributedString(string: text)
        let boldFont = UIFont.systemFont(ofSize: 17, weight: .bold)
        let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        attributedString.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: 5)) // "Hello"
        attributedString.addAttribute(.foregroundColor, value: black, range: NSRange(location: 0, length: text.count))
        
        // When
        let data = AttributedStringSerializer.encode(attributedString)
        let decoded = AttributedStringSerializer.decode(data, text: text)
        
        // Then
        XCTAssertEqual(decoded.string, text, "Text should be preserved")
        
        // Bold should be preserved
        let font = decoded.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false, "Bold should be preserved")
        
        // Black color should not be saved but .label should be added
        let color = decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "Black color should not be saved but .label should be added for adaptive behavior")
    }
    
    func testDecode_StripsAdaptiveColorsFromOldDocuments() {
        // This test simulates loading an old document that has black color baked in
        // The decode() method should strip it
        
        // Given: An attributed string with black color (simulating old document)
        let text = "Old document text"
        let attributedString = NSMutableAttributedString(string: text)
        let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        attributedString.addAttribute(.foregroundColor, value: black, range: NSRange(location: 0, length: text.count))
        
        // Convert to JSON data (simulating old saved format)
        let data = AttributedStringSerializer.encode(attributedString)
        
        // When: Decode (which should strip the black color)
        let decoded = AttributedStringSerializer.decode(data, text: text)
        
        // Then: Black color should be stripped and .label added for adaptive behavior
        let color = decoded.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor.label, "Black color from old document should be stripped and .label added for adaptive behavior")
    }
}
