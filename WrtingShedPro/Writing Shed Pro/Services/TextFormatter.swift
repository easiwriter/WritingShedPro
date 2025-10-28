import Foundation
import UIKit

/// Service for applying and removing text formatting to NSAttributedString
struct TextFormatter {
    
    // MARK: - Helper Methods
    
    /// Remove paragraph styles with invalid line heights (0/0) that cause NaN errors
    /// UITextView adds default paragraph styles with maximumLineHeight=0 and minimumLineHeight=0
    /// to all text. When we copy attributed strings, these invalid values cause CoreGraphics errors.
    /// - Parameter attributedText: The attributed string to clean
    /// - Returns: A new attributed string without invalid paragraph styles
    private static func cleanParagraphStyles(in attributedText: NSAttributedString) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        let fullRange = NSRange(location: 0, length: mutableText.length)
        
        mutableText.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            if let paragraphStyle = value as? NSParagraphStyle {
                // Check if this paragraph style has invalid line heights (both 0)
                // These cause NaN errors when CoreGraphics tries to divide by line height
                if paragraphStyle.maximumLineHeight == 0 && paragraphStyle.minimumLineHeight == 0 {
                    // Remove the paragraph style to avoid NaN errors
                    mutableText.removeAttribute(.paragraphStyle, range: range)
                }
            }
        }
        
        return mutableText
    }
    
    // MARK: - Character Formatting
    
    /// Toggle bold formatting for the given range
    /// - Parameters:
    ///   - attributedText: The attributed string to modify
    ///   - range: The range to toggle bold in
    /// - Returns: A new attributed string with bold toggled
    static func toggleBold(in attributedText: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length else {
            return attributedText
        }
        
        // First, clean any invalid paragraph styles that would cause NaN errors
        let cleanedText = cleanParagraphStyles(in: attributedText)
        let mutableText = NSMutableAttributedString(attributedString: cleanedText)
        
        // Check if the range already has bold
        let hasBold = checkForBold(in: cleanedText, range: range)
        
        // Apply or remove bold using font traits
        mutableText.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
            let currentFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            
            // Get current traits
            let currentTraits = currentFont.fontDescriptor.symbolicTraits
            let hasItalic = currentTraits.contains(.traitItalic)
            
            // Use the font descriptor to create a new font with traits
            var newTraits = currentTraits
            if !hasBold {
                newTraits.insert(.traitBold)
            } else {
                newTraits.remove(.traitBold)
            }
            
            if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
                mutableText.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        
        return mutableText
    }
    
    /// Toggle italic formatting for the given range
    static func toggleItalic(in attributedText: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length else {
            return attributedText
        }
        
        let cleanedText = cleanParagraphStyles(in: attributedText)
        let mutableText = NSMutableAttributedString(attributedString: cleanedText)
        let hasItalic = checkForItalic(in: cleanedText, range: range)
        
        mutableText.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
            let currentFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            
            // Get current traits
            let currentTraits = currentFont.fontDescriptor.symbolicTraits
            
            // Use the font descriptor to create a new font with traits
            var newTraits = currentTraits
            if !hasItalic {
                newTraits.insert(.traitItalic)
            } else {
                newTraits.remove(.traitItalic)
            }
            
            if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(newTraits) {
                let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
                mutableText.addAttribute(.font, value: newFont, range: subrange)
            }
        }
        
        return mutableText
    }
    
    /// Toggle underline formatting for the given range
    static func toggleUnderline(in attributedText: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length else {
            return attributedText
        }
        
        let cleanedText = cleanParagraphStyles(in: attributedText)
        let mutableText = NSMutableAttributedString(attributedString: cleanedText)
        let hasUnderline = checkForUnderline(in: cleanedText, range: range)
        
        if hasUnderline {
            mutableText.removeAttribute(.underlineStyle, range: range)
        } else {
            mutableText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        return mutableText
    }
    
    /// Toggle strikethrough formatting for the given range
    static func toggleStrikethrough(in attributedText: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length else {
            return attributedText
        }
        
        let cleanedText = cleanParagraphStyles(in: attributedText)
        let mutableText = NSMutableAttributedString(attributedString: cleanedText)
        let hasStrikethrough = checkForStrikethrough(in: cleanedText, range: range)
        
        if hasStrikethrough {
            mutableText.removeAttribute(.strikethroughStyle, range: range)
        } else {
            mutableText.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        return mutableText
    }
    
    // MARK: - Format Detection
    
    static func checkForBold(in attributedText: NSAttributedString, range: NSRange) -> Bool {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length,
              range.length > 0 else {
            return false
        }
        
        var hasBold = false
        attributedText.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    hasBold = true
                    stop.pointee = true
                }
            }
        }
        return hasBold
    }
    
    static func checkForItalic(in attributedText: NSAttributedString, range: NSRange) -> Bool {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length,
              range.length > 0 else {
            return false
        }
        
        var hasItalic = false
        attributedText.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    hasItalic = true
                    stop.pointee = true
                }
            }
        }
        return hasItalic
    }
    
    static func checkForUnderline(in attributedText: NSAttributedString, range: NSRange) -> Bool {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length,
              range.length > 0 else {
            return false
        }
        
        var hasUnderline = false
        attributedText.enumerateAttribute(.underlineStyle, in: range, options: []) { value, subrange, stop in
            if let style = value as? Int, style != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }
        return hasUnderline
    }
    
    static func checkForStrikethrough(in attributedText: NSAttributedString, range: NSRange) -> Bool {
        guard range.location != NSNotFound,
              range.location + range.length <= attributedText.length,
              range.length > 0 else {
            return false
        }
        
        var hasStrikethrough = false
        attributedText.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, subrange, stop in
            if let style = value as? Int, style != 0 {
                hasStrikethrough = true
                stop.pointee = true
            }
        }
        return hasStrikethrough
    }
    
    static func getFormattingState(in attributedText: NSAttributedString, range: NSRange) -> (isBold: Bool, isItalic: Bool, hasUnderline: Bool, hasStrikethrough: Bool) {
        let isBold = checkForBold(in: attributedText, range: range)
        let isItalic = checkForItalic(in: attributedText, range: range)
        let hasUnderline = checkForUnderline(in: attributedText, range: range)
        let hasStrikethrough = checkForStrikethrough(in: attributedText, range: range)
        return (isBold, isItalic, hasUnderline, hasStrikethrough)
    }
}
