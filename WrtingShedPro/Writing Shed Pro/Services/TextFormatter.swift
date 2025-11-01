import Foundation
import UIKit
import SwiftData

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
        mutableText.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            // Every paragraph MUST have a font attribute (text style)
            // If missing, it's a bug - but we handle it gracefully with .body default
            guard let currentFont = value as? UIFont else {
                #if DEBUG
                print("⚠️ TextFormatter.toggleBold: Missing font attribute at range \(subrange) - using .body as fallback")
                #endif
                // Apply body style with trait as fallback
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                if let descriptor = bodyFont.fontDescriptor.withSymbolicTraits(hasBold ? [] : .traitBold) {
                    let newFont = UIFont(descriptor: descriptor, size: bodyFont.pointSize)
                    mutableText.addAttribute(.font, value: newFont, range: subrange)
                }
                return
            }
            
            // Get current traits and preserve them (except bold which we're toggling)
            let currentTraits = currentFont.fontDescriptor.symbolicTraits
            
            // Create new traits by toggling bold while preserving font family and size
            var newTraits = currentTraits
            if !hasBold {
                newTraits.insert(.traitBold)
            } else {
                newTraits.remove(.traitBold)
            }
            
            // Apply new traits - this preserves the font family and size
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
        
        mutableText.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            // Every paragraph MUST have a font attribute (text style)
            // If missing, it's a bug - but we handle it gracefully with .body default
            guard let currentFont = value as? UIFont else {
                #if DEBUG
                print("⚠️ TextFormatter.toggleItalic: Missing font attribute at range \(subrange) - using .body as fallback")
                #endif
                // Apply body style with trait as fallback
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                if let descriptor = bodyFont.fontDescriptor.withSymbolicTraits(hasItalic ? [] : .traitItalic) {
                    let newFont = UIFont(descriptor: descriptor, size: bodyFont.pointSize)
                    mutableText.addAttribute(.font, value: newFont, range: subrange)
                }
                return
            }
            
            // Get current traits and preserve them (except italic which we're toggling)
            let currentTraits = currentFont.fontDescriptor.symbolicTraits
            
            // Create new traits by toggling italic while preserving font family and size
            var newTraits = currentTraits
            if !hasItalic {
                newTraits.insert(.traitItalic)
            } else {
                newTraits.remove(.traitItalic)
            }
            
            // Apply new traits - this preserves the font family and size
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
    
    // MARK: - Paragraph Formatting
    
    /// Get typing attributes for a given text style
    /// Use this to set UITextView.typingAttributes when applying styles to empty text
    /// - Parameter style: The UIFont.TextStyle to get attributes for
    /// - Returns: Dictionary of attributes suitable for typing
    static func getTypingAttributes(for style: UIFont.TextStyle) -> [NSAttributedString.Key: Any] {
        let font = UIFont.preferredFont(forTextStyle: style)
        return [
            .font: font,
            .textStyle: style.attributeValue
        ]
    }
    
    /// Apply a paragraph style (UIFont.TextStyle) to the given range
    /// This preserves existing character formatting (bold, italic, etc.)
    /// - Parameters:
    ///   - attributedText: The attributed string to modify
    ///   - style: The UIFont.TextStyle to apply
    ///   - range: The range to apply the style to (will be expanded to paragraph boundaries)
    /// - Returns: A new attributed string with the style applied
    static func applyStyle(_ style: UIFont.TextStyle, to attributedText: NSAttributedString, range: NSRange) -> NSAttributedString {
        guard range.location != NSNotFound,
              range.location <= attributedText.length else {
            return attributedText
        }
        
        // Special case: empty text
        // Return an attributed string with the default style set
        // The calling code should use this to set typing attributes
        if attributedText.length == 0 {
            let baseFont = UIFont.preferredFont(forTextStyle: style)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .textStyle: style.attributeValue
            ]
            return NSAttributedString(string: "", attributes: attrs)
        }
        
        // Clean invalid paragraph styles first
        let cleanedText = cleanParagraphStyles(in: attributedText)
        let mutableText = NSMutableAttributedString(attributedString: cleanedText)
        
        // Expand range to paragraph boundaries
        let paragraphRange = getParagraphRange(for: range, in: mutableText.string)
        
        // Get the preferred font for the style
        let baseFont = UIFont.preferredFont(forTextStyle: style)
        
        // Apply the style to each character in the paragraph range
        // while preserving character-level formatting (bold, italic, etc.)
        mutableText.enumerateAttributes(in: paragraphRange, options: []) { attributes, subrange, _ in
            var newAttributes = attributes
            
            // Get existing font or use base font
            let existingFont = attributes[.font] as? UIFont ?? baseFont
            let existingTraits = existingFont.fontDescriptor.symbolicTraits
            
            // Create new font with the style's size but preserve traits
            let newFont = UIFont.preferredFont(forTextStyle: style)
            
            // If there were existing traits (bold, italic), preserve them
            if !existingTraits.isEmpty {
                if let descriptor = newFont.fontDescriptor.withSymbolicTraits(existingTraits) {
                    newAttributes[.font] = UIFont(descriptor: descriptor, size: 0) // 0 means use descriptor's size
                } else {
                    newAttributes[.font] = newFont
                }
            } else {
                newAttributes[.font] = newFont
            }
            
            // Store the text style name as a custom attribute
            newAttributes[.textStyle] = style.attributeValue
            
            mutableText.setAttributes(newAttributes, range: subrange)
        }
        
        return mutableText
    }
    
    /// Get the current paragraph style at the given range
    /// - Parameters:
    ///   - attributedText: The attributed string to check
    ///   - range: The range to check (typically the cursor position or selection)
    /// - Returns: The UIFont.TextStyle if one is detected, nil otherwise
    static func getCurrentStyle(in attributedText: NSAttributedString, at range: NSRange) -> UIFont.TextStyle? {
        guard range.location != NSNotFound else {
            return nil
        }
        
        // If text is empty, return body as default
        guard attributedText.length > 0 else {
            return .body
        }
        
        // For cursor at end of document, check the last character
        // For cursor in middle, check character at or before cursor
        let checkLocation: Int
        if range.location >= attributedText.length {
            checkLocation = attributedText.length - 1
        } else if range.location > 0 && range.length == 0 {
            // Cursor position (no selection) - check character before cursor
            // This gives us the style of text we're "in"
            checkLocation = range.location - 1
        } else {
            // Selection or at start - check at current location
            checkLocation = range.location
        }
        
        // First, try to get the stored text style attribute
        if let styleValue = attributedText.attribute(.textStyle, at: checkLocation, effectiveRange: nil),
           let style = UIFont.TextStyle.from(attributeValue: styleValue) {
            return style
        }
        
        // Fallback: try to match font to style (for legacy or untagged text)
        if let font = attributedText.attribute(.font, at: checkLocation, effectiveRange: nil) as? UIFont {
            return matchFontToStyle(font)
        }
        
        return .body
    }
    
    /// Find paragraph boundaries for a given range
    /// - Parameters:
    ///   - range: The range to expand
    ///   - string: The string to search in
    /// - Returns: A range expanded to include full paragraphs
    private static func getParagraphRange(for range: NSRange, in string: String) -> NSRange {
        let nsString = string as NSString
        var paragraphRange = NSRange(location: 0, length: 0)
        
        // Get the paragraph range that contains our selection
        nsString.getParagraphStart(nil,
                                  end: nil,
                                  contentsEnd: nil,
                                  for: range)
        
        // Use NSString's paragraph detection
        var start = range.location
        var end = range.location + range.length
        
        // Find start of paragraph
        while start > 0 {
            let char = nsString.character(at: start - 1)
            if char == 0x0A || char == 0x0D { // \n or \r
                break
            }
            start -= 1
        }
        
        // Find end of paragraph
        while end < nsString.length {
            let char = nsString.character(at: end)
            if char == 0x0A || char == 0x0D { // \n or \r
                end += 1 // Include the newline
                break
            }
            end += 1
        }
        
        paragraphRange = NSRange(location: start, length: end - start)
        return paragraphRange
    }
    
    /// Match a UIFont to its corresponding UIFont.TextStyle
    /// This is a best-effort match based on font size and weight characteristics
    private static func matchFontToStyle(_ font: UIFont) -> UIFont.TextStyle {
        let fontSize = font.pointSize
        let traits = font.fontDescriptor.symbolicTraits
        let isBold = traits.contains(.traitBold)
        
        // Get sizes of known styles for comparison
        let largeTitleSize = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        let title1Size = UIFont.preferredFont(forTextStyle: .title1).pointSize
        let title2Size = UIFont.preferredFont(forTextStyle: .title2).pointSize
        let title3Size = UIFont.preferredFont(forTextStyle: .title3).pointSize
        let headlineSize = UIFont.preferredFont(forTextStyle: .headline).pointSize
        let bodySize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let calloutSize = UIFont.preferredFont(forTextStyle: .callout).pointSize
        let subheadlineSize = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        let footnoteSize = UIFont.preferredFont(forTextStyle: .footnote).pointSize
        let caption1Size = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        let caption2Size = UIFont.preferredFont(forTextStyle: .caption2).pointSize
        
        // Find closest match (with some tolerance)
        let tolerance: CGFloat = 2.0
        
        if abs(fontSize - largeTitleSize) < tolerance { return .largeTitle }
        if abs(fontSize - title1Size) < tolerance { return .title1 }
        if abs(fontSize - title2Size) < tolerance { return .title2 }
        if abs(fontSize - title3Size) < tolerance { return .title3 }
        
        // Headline and body are both ~17pt, but headline is semibold/bold
        // Check headline ONLY if the font is bold
        if abs(fontSize - headlineSize) < tolerance {
            if isBold || font.fontDescriptor.object(forKey: .face) as? String == "Semibold" {
                return .headline
            }
        }
        
        // Body is regular weight at ~17pt
        if abs(fontSize - bodySize) < tolerance { return .body }
        if abs(fontSize - calloutSize) < tolerance { return .callout }
        if abs(fontSize - subheadlineSize) < tolerance { return .subheadline }
        if abs(fontSize - footnoteSize) < tolerance { return .footnote }
        if abs(fontSize - caption1Size) < tolerance { return .caption1 }
        if abs(fontSize - caption2Size) < tolerance { return .caption2 }
        
        // Default to body if no close match
        return .body
    }
    
    // MARK: - Model-Based Paragraph Formatting (Phase 5)
    
    /// Get typing attributes for a style from the database
    /// - Parameters:
    ///   - styleName: Name of the style (e.g., "body", "title1")
    ///   - project: The project to resolve styles from
    ///   - context: ModelContext for database access
    /// - Returns: Dictionary of attributes suitable for typing
    static func getTypingAttributes(
        forStyleNamed styleName: String,
        project: Project,
        context: ModelContext
    ) -> [NSAttributedString.Key: Any] {
        // Resolve style from database
        guard let textStyle = StyleSheetService.resolveStyle(named: styleName, for: project, context: context) else {
            // Fallback to body style
            return getTypingAttributes(for: .body)
        }
        
        return textStyle.generateAttributes()
    }
    
    /// Apply a style from the database to the given range
    /// - Parameters:
    ///   - styleName: Name of the style to apply
    ///   - attributedText: The attributed string to modify
    ///   - range: The range to apply the style to
    ///   - project: The project to resolve styles from
    ///   - context: ModelContext for database access
    /// - Returns: A new attributed string with the style applied
    static func applyStyle(
        named styleName: String,
        to attributedText: NSAttributedString,
        range: NSRange,
        project: Project,
        context: ModelContext
    ) -> NSAttributedString {
        guard range.location != NSNotFound,
              range.location <= attributedText.length else {
            return attributedText
        }
        
        // Resolve style from database
        guard let textStyle = StyleSheetService.resolveStyle(named: styleName, for: project, context: context) else {
            print("⚠️ Could not resolve style '\(styleName)' - using body as fallback")
            return applyStyle(.body, to: attributedText, range: range)
        }
        
        // Special case: empty text
        if attributedText.length == 0 {
            var attrs = textStyle.generateAttributes()
            attrs[.textStyle] = styleName  // Add TextStyle attribute
            return NSAttributedString(string: "", attributes: attrs)
        }
        
        // Clean invalid paragraph styles first
        let cleanedText = cleanParagraphStyles(in: attributedText)
        let mutableText = NSMutableAttributedString(attributedString: cleanedText)
        
        // Expand range to paragraph boundaries
        let paragraphRange = getParagraphRange(for: range, in: mutableText.string)
        
        // Get base attributes from the style model
        let baseAttributes = textStyle.generateAttributes()
        guard let baseFont = baseAttributes[NSAttributedString.Key.font] as? UIFont else {
            print("⚠️ Style '\(styleName)' has no font - using existing method")
            return applyStyle(.body, to: attributedText, range: range)
        }
        
        // Apply the style to each character in the paragraph range
        // while preserving character-level formatting (bold, italic, etc.)
        mutableText.enumerateAttributes(in: paragraphRange, options: []) { attributes, subrange, _ in
            var newAttributes = baseAttributes
            
            // CRITICAL: Add the TextStyle attribute so reapplyAllStyles() can find it
            newAttributes[.textStyle] = styleName
            
            // Get existing font to check for traits
            let existingFont = attributes[.font] as? UIFont ?? baseFont
            let existingTraits = existingFont.fontDescriptor.symbolicTraits
            
            // If there were existing traits (bold, italic), preserve them
            if !existingTraits.isEmpty {
                if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(existingTraits) {
                    newAttributes[.font] = UIFont(descriptor: descriptor, size: 0) // 0 means use descriptor's size
                } else {
                    newAttributes[.font] = baseFont
                }
            }
            
            // NOTE: We intentionally DO NOT preserve existing foreground color
            // When applying a paragraph style, we want the style's color to be applied
            // This ensures the style definition is fully respected
            
            mutableText.setAttributes(newAttributes, range: subrange)
        }
        
        return mutableText
    }
    
    /// Get the current style name at the given range
    /// - Parameters:
    ///   - attributedText: The attributed string to check
    ///   - range: The range to check
    ///   - project: The project to resolve styles from
    ///   - context: ModelContext for database access
    /// - Returns: The style name if detected, nil otherwise
    static func getCurrentStyleName(
        in attributedText: NSAttributedString,
        at range: NSRange,
        project: Project,
        context: ModelContext
    ) -> String? {
        guard range.location != NSNotFound else {
            return nil
        }
        
        // If text is empty, return body as default
        guard attributedText.length > 0 else {
            return UIFont.TextStyle.body.rawValue
        }
        
        // Determine which character to check
        let checkLocation: Int
        if range.location >= attributedText.length {
            checkLocation = attributedText.length - 1
        } else if range.location > 0 && range.length == 0 {
            checkLocation = range.location - 1
        } else {
            checkLocation = range.location
        }
        
        // First, try to get the stored text style attribute
        if let styleValue = attributedText.attribute(.textStyle, at: checkLocation, effectiveRange: nil),
           let style = UIFont.TextStyle.from(attributeValue: styleValue) {
            return style.rawValue
        }
        
        // Fallback: try to match font to style
        if let font = attributedText.attribute(.font, at: checkLocation, effectiveRange: nil) as? UIFont {
            let matchedStyle = matchFontToStyle(font)
            return matchedStyle.rawValue
        }
        
        return UIFont.TextStyle.body.rawValue
    }
}

