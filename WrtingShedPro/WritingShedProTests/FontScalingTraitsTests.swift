//
//  FontScalingTraitsTests.swift
//  Writing Shed Pro Tests
//
//  Tests that font scaling preserves bold/italic traits
//  Bug fix for legacy import losing formatting
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class FontScalingTraitsTests: XCTestCase {
    
    func testScaleFontsPreservesBoldTrait() {
        // Create attributed string with bold text
        let boldFont = UIFont.boldSystemFont(ofSize: 12)
        let text = NSAttributedString(string: "Bold Text", attributes: [.font: boldFont])
        
        // Scale the fonts
        let scaled = AttributedStringSerializer.scaleFonts(text, scaleFactor: 1.8)
        
        // Check that bold trait is preserved
        var foundBold = false
        scaled.enumerateAttribute(.font, in: NSRange(location: 0, length: scaled.length)) { value, _, _ in
            if let font = value as? UIFont {
                XCTAssertEqual(font.pointSize, 12 * 1.8, accuracy: 0.1, "Font should be scaled")
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    foundBold = true
                }
            }
        }
        
        XCTAssertTrue(foundBold, "Bold trait should be preserved after scaling")
    }
    
    func testScaleFontsPreservesItalicTrait() {
        // Create attributed string with italic text
        let italicFont = UIFont.italicSystemFont(ofSize: 13)
        let text = NSAttributedString(string: "Italic Text", attributes: [.font: italicFont])
        
        // Scale the fonts
        let scaled = AttributedStringSerializer.scaleFonts(text, scaleFactor: 1.8)
        
        // Check that italic trait is preserved
        var foundItalic = false
        scaled.enumerateAttribute(.font, in: NSRange(location: 0, length: scaled.length)) { value, _, _ in
            if let font = value as? UIFont {
                XCTAssertEqual(font.pointSize, 13 * 1.8, accuracy: 0.1, "Font should be scaled")
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    foundItalic = true
                }
            }
        }
        
        XCTAssertTrue(foundItalic, "Italic trait should be preserved after scaling")
    }
    
    func testScaleFontsPreservesBoldItalicTrait() {
        // Create attributed string with bold+italic text
        let baseFont = UIFont.systemFont(ofSize: 14)
        let descriptor = baseFont.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic])!
        let boldItalicFont = UIFont(descriptor: descriptor, size: 14)
        let text = NSAttributedString(string: "Bold Italic", attributes: [.font: boldItalicFont])
        
        // Scale the fonts
        let scaled = AttributedStringSerializer.scaleFonts(text, scaleFactor: 1.8)
        
        // Check that both traits are preserved
        var foundBold = false
        var foundItalic = false
        scaled.enumerateAttribute(.font, in: NSRange(location: 0, length: scaled.length)) { value, _, _ in
            if let font = value as? UIFont {
                XCTAssertEqual(font.pointSize, 14 * 1.8, accuracy: 0.1, "Font should be scaled")
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { foundBold = true }
                if traits.contains(.traitItalic) { foundItalic = true }
            }
        }
        
        XCTAssertTrue(foundBold, "Bold trait should be preserved after scaling")
        XCTAssertTrue(foundItalic, "Italic trait should be preserved after scaling")
    }
    
    func testScaleFontsMixedTraits() {
        // Create attributed string with mixed formatting
        let mutableString = NSMutableAttributedString()
        
        // Add normal text
        let normalFont = UIFont.systemFont(ofSize: 12)
        mutableString.append(NSAttributedString(string: "Normal ", attributes: [.font: normalFont]))
        
        // Add bold text
        let boldFont = UIFont.boldSystemFont(ofSize: 12)
        mutableString.append(NSAttributedString(string: "Bold ", attributes: [.font: boldFont]))
        
        // Add italic text
        let italicFont = UIFont.italicSystemFont(ofSize: 12)
        mutableString.append(NSAttributedString(string: "Italic", attributes: [.font: italicFont]))
        
        // Scale the fonts
        let scaled = AttributedStringSerializer.scaleFonts(mutableString, scaleFactor: 1.8)
        
        // Check each section
        var normalCount = 0
        var boldCount = 0
        var italicCount = 0
        
        scaled.enumerateAttribute(.font, in: NSRange(location: 0, length: scaled.length)) { value, range, _ in
            if let font = value as? UIFont {
                XCTAssertEqual(font.pointSize, 12 * 1.8, accuracy: 0.1, "Font should be scaled")
                
                let traits = font.fontDescriptor.symbolicTraits
                let text = (scaled.string as NSString).substring(with: range)
                
                if text.contains("Normal") {
                    XCTAssertFalse(traits.contains(.traitBold), "Normal text should not be bold")
                    XCTAssertFalse(traits.contains(.traitItalic), "Normal text should not be italic")
                    normalCount += 1
                } else if text.contains("Bold") {
                    XCTAssertTrue(traits.contains(.traitBold), "Bold text should be bold")
                    boldCount += 1
                } else if text.contains("Italic") {
                    XCTAssertTrue(traits.contains(.traitItalic), "Italic text should be italic")
                    italicCount += 1
                }
            }
        }
        
        XCTAssertGreaterThan(normalCount, 0, "Should have normal text")
        XCTAssertGreaterThan(boldCount, 0, "Should have bold text")
        XCTAssertGreaterThan(italicCount, 0, "Should have italic text")
    }
    
    func testRTFRoundTripPreservesTraits() {
        // Create attributed string with bold and italic
        let mutableString = NSMutableAttributedString()
        mutableString.append(NSAttributedString(string: "Title", attributes: [.font: UIFont.boldSystemFont(ofSize: 14)]))
        mutableString.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 12)]))
        mutableString.append(NSAttributedString(string: "Body text", attributes: [.font: UIFont.systemFont(ofSize: 12)]))
        
        // Convert to RTF
        guard let rtfData = AttributedStringSerializer.toRTF(mutableString) else {
            XCTFail("Failed to convert to RTF")
            return
        }
        
        // Read back from RTF with scaling
        guard let recovered = AttributedStringSerializer.fromLegacyRTF(rtfData) else {
            XCTFail("Failed to recover from RTF")
            return
        }
        
        // Check that "Title" is still bold after RTF round-trip and scaling
        var foundBoldTitle = false
        recovered.enumerateAttribute(.font, in: NSRange(location: 0, length: recovered.length)) { value, range, _ in
            if let font = value as? UIFont {
                let text = (recovered.string as NSString).substring(with: range)
                if text.contains("Title") {
                    if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                        foundBoldTitle = true
                    }
                }
            }
        }
        
        XCTAssertTrue(foundBoldTitle, "Bold title should survive RTF round-trip and scaling")
    }
}
