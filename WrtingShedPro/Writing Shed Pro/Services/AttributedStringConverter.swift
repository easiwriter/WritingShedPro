//
//  AttributedStringConverter.swift
//  Writing Shed Pro
//
//  Created on 12 November 2025.
//  Feature 009: Database Import
//

import Foundation
import UIKit

/// Converts NSAttributedString from legacy database to new SwiftData format
/// Handles RTF encoding for formatting preservation with fallback to plain text
class AttributedStringConverter {
    
    // MARK: - Main Conversion Method
    
    /// Convert NSAttributedString to new format
    /// - Parameters:
    ///   - attributedString: The NSAttributedString to convert
    ///   - preserveFormatting: Whether to preserve formatting (default: true)
    /// - Returns: Tuple of (plainText: String, rtfData: Data?)
    static func convert(
        _ attributedString: NSAttributedString,
        preserveFormatting: Bool = true
    ) -> (plainText: String, rtfData: Data?) {
        // CRITICAL: Strip adaptive colors from imported documents
        // This fixes dark mode issues where legacy documents have fixed black/white colors
        // that don't adapt to appearance changes
        let cleanedString = AttributedStringSerializer.stripAdaptiveColors(from: attributedString)
        
        let plainText = cleanedString.string
        
        guard preserveFormatting && hasFormatting(cleanedString) else {
            // No formatting to preserve, just return plain text
            return (plainText, nil)
        }
        
        // Try to convert to RTF
        let rtfData = convertToRTF(cleanedString)
        return (plainText, rtfData)
    }
    
    // MARK: - RTF Conversion
    
    /// Convert NSAttributedString to RTF data
    /// - Parameter attributedString: The NSAttributedString to convert
    /// - Returns: RTF data or nil if conversion fails
    private static func convertToRTF(_ attributedString: NSAttributedString) -> Data? {
        // DEBUG: Log traits BEFORE conversion
        var boldCount = 0
        var italicCount = 0
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length)) { value, range, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    boldCount += 1
                }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    italicCount += 1
                }
            }
        }
        print("[AttributedStringConverter] BEFORE RTF conversion: \(boldCount) bold ranges, \(italicCount) italic ranges")
        
        // CRITICAL: Preserve multiple consecutive spaces for poetry formatting
        // RTF automatically collapses multiple spaces during encoding/decoding
        // Replace consecutive spaces with non-breaking spaces to preserve them
        let preservedString = preserveMultipleSpaces(attributedString)
        
        do {
            let range = NSRange(location: 0, length: preservedString.length)
            let rtfData = try preservedString.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            print("[AttributedStringConverter] RTF conversion successful: \(rtfData.count) bytes")
            return rtfData
        } catch {
            // RTF conversion failed, return nil
            // Caller will use plain text fallback
            print("[AttributedStringConverter] RTF conversion failed: \(error)")
            return nil
        }
    }
    
    /// Preserve multiple consecutive spaces by replacing with non-breaking spaces
    /// RTF format collapses multiple spaces, so we need to use U+00A0 (non-breaking space)
    /// - Parameter attributedString: The attributed string to process
    /// - Returns: New attributed string with preserved spaces
    private static func preserveMultipleSpaces(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let pattern = "  +" // Two or more consecutive spaces
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attributedString
        }
        
        let range = NSRange(location: 0, length: mutableString.length)
        let matches = regex.matches(in: mutableString.string, options: [], range: range)
        
        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            let matchRange = match.range
            let spaces = (mutableString.string as NSString).substring(with: matchRange)
            
            // Replace regular spaces with non-breaking spaces (U+00A0)
            let nonBreakingSpaces = String(repeating: "\u{00A0}", count: spaces.count)
            
            // Get attributes from the first character of the match
            let attrs = mutableString.attributes(at: matchRange.location, effectiveRange: nil)
            let replacement = NSAttributedString(string: nonBreakingSpaces, attributes: attrs)
            
            mutableString.replaceCharacters(in: matchRange, with: replacement)
        }
        
        return mutableString
    }
    
    // MARK: - Formatting Detection
    
    /// Check if NSAttributedString has any formatting beyond plain text
    /// - Parameter attributedString: The string to check
    /// - Returns: True if formatting is present
    private static func hasFormatting(_ attributedString: NSAttributedString) -> Bool {
        guard attributedString.length > 0 else {
            return false
        }
        
        var hasAnyFormatting = false
        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { attributes, _, _ in
            // Check for any formatting attributes
            if !attributes.isEmpty {
                // Filter out trivial attributes (if any)
                for (key, _) in attributes {
                    // Common formatting attributes
                    if key == .font || key == .foregroundColor || key == .backgroundColor ||
                       key == .underlineStyle || key == .strikethroughStyle ||
                       key == .link || key == .paragraphStyle {
                        hasAnyFormatting = true
                        return
                    }
                }
            }
        }
        
        return hasAnyFormatting
    }
    
    // MARK: - Recovery Methods
    
    /// Recover as much text as possible from NSAttributedString
    /// - Parameter attributedString: The string to recover text from
    /// - Returns: Plain text string, with best effort recovery
    static func recoverPlainText(_ attributedString: NSAttributedString?) -> String {
        guard let attributedString = attributedString else {
            return ""
        }
        
        // Try to get plain string
        let plainString = attributedString.string
        
        // If empty, try to extract any content
        if plainString.isEmpty {
            return ""
        }
        
        return plainString
    }
    
    /// Verify RTF data can be read back as NSAttributedString
    /// - Parameter rtfData: The RTF data to verify
    /// - Returns: True if data can be successfully decoded
    static func verifyRTFData(_ rtfData: Data) -> Bool {
        do {
            _ = try NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Statistics
    
    /// Get statistics about formatting in NSAttributedString
    /// - Parameter attributedString: The string to analyze
    /// - Returns: Dictionary with formatting statistics
    static func getFormattingStats(_ attributedString: NSAttributedString) -> [String: Int] {
        var stats: [String: Int] = [
            "totalLength": attributedString.length,
            "boldRanges": 0,
            "italicRanges": 0,
            "underlineRanges": 0,
            "coloredRanges": 0,
            "linkRanges": 0
        ]
        
        guard attributedString.length > 0 else {
            return stats
        }
        
        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { attributes, _, _ in
            for (key, value) in attributes {
                switch key {
                case .font:
                    if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                        stats["boldRanges"] = (stats["boldRanges"] ?? 0) + 1
                    }
                    if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                        stats["italicRanges"] = (stats["italicRanges"] ?? 0) + 1
                    }
                case .underlineStyle:
                    stats["underlineRanges"] = (stats["underlineRanges"] ?? 0) + 1
                case .foregroundColor:
                    stats["coloredRanges"] = (stats["coloredRanges"] ?? 0) + 1
                case .link:
                    stats["linkRanges"] = (stats["linkRanges"] ?? 0) + 1
                default:
                    break
                }
            }
        }
        
        return stats
    }
}

// MARK: - Testing Utilities

extension AttributedStringConverter {
    
    /// Create test NSAttributedString with formatting for testing
    /// - Returns: NSAttributedString with various formatting
    static func createTestAttributedString() -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        
        // Bold text
        let boldText = NSAttributedString(
            string: "Bold ",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 16)]
        )
        attributed.append(boldText)
        
        // Regular text
        let regularText = NSAttributedString(
            string: "Regular ",
            attributes: [.font: UIFont.systemFont(ofSize: 16)]
        )
        attributed.append(regularText)
        
        // Italic text
        let italicText = NSAttributedString(
            string: "Italic",
            attributes: [.font: UIFont.italicSystemFont(ofSize: 16)]
        )
        attributed.append(italicText)
        
        return attributed
    }
}
