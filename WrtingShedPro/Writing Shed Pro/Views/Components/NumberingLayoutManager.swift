//
//  NumberingLayoutManager.swift
//  Writing Shed Pro
//
//  Feature 016: Custom NSLayoutManager that renders paragraph numbers dynamically
//  Numbers are NEVER stored in the document - they're drawn at render time
//  Supports hierarchical numbering (e.g., 1.1, 1.2) for follow-on styles
//  For poetry projects, also draws line numbers on the right margin
//

import UIKit
import SwiftData

/// Custom layout manager that draws paragraph numbers in the left margin
/// For poetry projects, also draws line numbers on the right margin (paginated view only)
/// Similar to line numbers in a code editor - purely visual, not part of document
class NumberingLayoutManager: NSLayoutManager {
    
    /// Reference to project for accessing style sheet (set by FormattedTextEditor)
    weak var project: Project?
    
    /// Whether this is a paginated view (enables poetry line numbers on right margin)
    /// Set to true by VirtualPageScrollView, false by FormattedTextEditor
    var isPaginatedView: Bool = false
    
    /// Starting line number for poetry projects (for paginated view where each page
    /// has a separate text view). Set by VirtualPageScrollView based on preceding pages.
    var poetryStartingLineNumber: Int = 1
    
    /// Width reserved for right-margin line numbers in poetry mode
    private let poetryLineNumberWidth: CGFloat = 40
    
    /// Font size for poetry line numbers
    private let poetryLineNumberFontSize: CGFloat = 11
    
    /// Build a map of child style → parent style from parentStyleName relationships
    /// If Title2.parentStyleName == "Title1", then Title2's numbers are prefixed with Title1's
    private func buildParentStyleMap(from styleSheet: StyleSheet) -> [String: String] {
        var parentMap: [String: String] = [:]
        
        guard let styles = styleSheet.textStyles else { return parentMap }
        
        for style in styles {
            if let parentName = style.parentStyleName, !parentName.isEmpty {
                // This style is a child of the parent style for numbering
                parentMap[style.name] = parentName
            }
        }
        
        return parentMap
    }
    
    /// Calculate and draw paragraph numbers for numbered styles
    /// For poetry projects, also draws line numbers on the right margin
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        guard let textStorage = textStorage,
              let project = project else {
            return
        }
        
        // MARK: - Poetry Line Numbers (Right Margin)
        // For poetry projects in paginated view, draw line numbers on the right side
        // Only shown in paginated view, not in edit mode
        if project.type == .poetry && isPaginatedView {
            drawPoetryLineNumbers(forGlyphRange: glyphsToShow, at: origin)
        }
        
        // Paragraph numbering requires a stylesheet
        guard let styleSheet = project.styleSheet else {
            return
        }
        
        // Get the visible character range
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        // Build parent-child style map for hierarchical numbering
        let parentStyleMap = buildParentStyleMap(from: styleSheet)
        
        // Track paragraph counters for each style
        var styleCounters: [String: Int] = [:]
        
        // Track the last number used for each style (for parent number prefixes)
        var lastNumberForStyle: [String: Int] = [:]
        
        // For empty files with numbering enabled, show the first number
        if textStorage.length == 0 {
            #if DEBUG
            print("   📄 Empty document detected")
            #endif
            // Check if the default style has numbering enabled
            if let defaultStyle = styleSheet.style(named: "UICTFontTextStyleBody"),
               defaultStyle.numberFormat != .none {
                #if DEBUG
                print("   ✅ Body style has numbering - drawing '1' at \(origin)")
                #endif
                let font = defaultStyle.generateFont(applyPlatformScaling: true)
                let defaultLineRect = CGRect(x: 0, y: 0, width: 100, height: font.lineHeight)
                let defaultAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: defaultStyle.textColor ?? UIColor.label
                ]
                drawNumber("1", at: origin, lineFragmentRect: defaultLineRect, paragraphAttributes: defaultAttrs, with: defaultStyle)
            } else {
                #if DEBUG
                print("   ❌ Body style has no numbering or not found")
                #endif
            }
            return
        }
        
        // Enumerate ALL paragraphs from the beginning to get correct counts
        // but only DRAW numbers for paragraphs in the visible charRange
        let text = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        text.enumerateSubstrings(in: fullRange, options: .byParagraphs) { [weak self] _, paragraphRange, _, _ in
            guard let self = self,
                  paragraphRange.location < textStorage.length else {
                return
            }
            
            // Get style at paragraph start (or end of text for empty last paragraph)
            let attrLocation = min(paragraphRange.location, textStorage.length - 1)
            guard attrLocation >= 0 else { return }
            
            let attrs = textStorage.attributes(at: attrLocation, effectiveRange: nil)
            
            guard let styleName = attrs[.textStyle] as? String,
                  let style = styleSheet.style(named: styleName),
                  style.numberFormat != .none else {
                return
            }
            
            // Check if this style has a parent (for hierarchical numbering)
            let parentStyleName = parentStyleMap[styleName]
            
            // If this is a child style and the parent number changed, reset child counter
            if let parentName = parentStyleName {
                let currentParentNumber = lastNumberForStyle[parentName] ?? 0
                let trackedParentNumber = lastNumberForStyle["\(styleName)_parentNum"] ?? 0
                
                #if DEBUG
                print("   🔢 Child style '\(styleName)': currentParentNumber=\(currentParentNumber), trackedParentNumber=\(trackedParentNumber)")
                #endif
                
                if currentParentNumber != trackedParentNumber {
                    // Parent number changed - reset this child's counter
                    #if DEBUG
                    print("   🔄 Parent changed! Resetting '\(styleName)' counter from \(styleCounters[styleName] ?? 0) to 0")
                    #endif
                    styleCounters[styleName] = 0
                    lastNumberForStyle["\(styleName)_parentNum"] = currentParentNumber
                }
            }
            
            // Increment counter for this style (always count, even if not visible)
            let counter = (styleCounters[styleName] ?? 0) + 1
            styleCounters[styleName] = counter
            
            // Track this style's last number for any children
            lastNumberForStyle[styleName] = counter
            
            // Only DRAW if this paragraph is within the visible range
            // Check if paragraph overlaps with visible charRange
            let paragraphEnd = paragraphRange.location + paragraphRange.length
            let charRangeEnd = charRange.location + charRange.length
            let isVisible = (paragraphRange.location < charRangeEnd) && (paragraphEnd > charRange.location)
            
            guard isVisible else {
                return
            }
            
            // Build the formatted number, with parent prefix for hierarchical numbering
            let formattedNumber: String
            if let parentName = parentStyleName,
               let parentStyle = styleSheet.style(named: parentName),
               parentStyle.numberFormat != .none,
               let parentNumber = lastNumberForStyle[parentName] {
                // Hierarchical: format as "parentNumber.childNumber" (e.g., "1.1", "1.2")
                let parentSymbol = parentStyle.numberFormat.symbol(for: parentNumber - 1, adornment: .plain)
                let childSymbol = style.numberFormat.symbol(for: counter - 1, adornment: .plain)
                // Apply adornment to the final combined number
                formattedNumber = style.numberAdornment.apply(to: "\(parentSymbol).\(childSymbol)")
            } else {
                // No parent or parent has no numbering - use standard format
                formattedNumber = style.numberFormat.symbol(for: counter - 1, adornment: style.numberAdornment)
            }
            
            // Get the line fragment for this paragraph
            let glyphRange = self.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            
            // For empty paragraphs or when no glyphs, still draw at the paragraph location
            let lineFragmentRect: CGRect
            if glyphRange.length > 0 {
                lineFragmentRect = self.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            } else {
                // For empty paragraph, use a default line height
                let font = style.generateFont(applyPlatformScaling: true)
                lineFragmentRect = CGRect(x: 0, y: CGFloat(styleCounters[styleName]! - 1) * font.lineHeight, width: 100, height: font.lineHeight)
            }
            
            // Draw the number at the paragraph position with matching attributes
            self.drawNumber(formattedNumber, at: CGPoint(x: origin.x, y: origin.y + lineFragmentRect.origin.y), lineFragmentRect: lineFragmentRect, paragraphAttributes: attrs, with: style)
        }
        
        // Check for empty trailing paragraph (e.g., after pressing Enter)
        // enumerateSubstrings doesn't include empty paragraphs at the end
        if text.hasSuffix("\n") {
            // Get attributes for the empty paragraph (use last character's attributes)
            if textStorage.length > 0 {
                let attrs = textStorage.attributes(at: textStorage.length - 1, effectiveRange: nil)
                
                if let styleName = attrs[.textStyle] as? String,
                   let style = styleSheet.style(named: styleName),
                   style.numberFormat != .none {
                    
                    // Check if this style has a parent (for hierarchical numbering)
                    let parentStyleName = parentStyleMap[styleName]
                    
                    // If this is a child style and the parent number changed, reset child counter
                    if let parentName = parentStyleName {
                        let currentParentNumber = lastNumberForStyle[parentName] ?? 0
                        let trackedParentNumber = lastNumberForStyle["\(styleName)_parentNum"] ?? 0
                        
                        if currentParentNumber != trackedParentNumber {
                            styleCounters[styleName] = 0
                            lastNumberForStyle["\(styleName)_parentNum"] = currentParentNumber
                        }
                    }
                    
                    // Increment counter for this style
                    let counter = (styleCounters[styleName] ?? 0) + 1
                    styleCounters[styleName] = counter
                    lastNumberForStyle[styleName] = counter
                    
                    // Build the formatted number, with parent prefix for hierarchical numbering
                    let formattedNumber: String
                    if let parentName = parentStyleName,
                       let parentStyle = styleSheet.style(named: parentName),
                       parentStyle.numberFormat != .none,
                       let parentNumber = lastNumberForStyle[parentName] {
                        let parentSymbol = parentStyle.numberFormat.symbol(for: parentNumber - 1, adornment: .plain)
                        let childSymbol = style.numberFormat.symbol(for: counter - 1, adornment: .plain)
                        formattedNumber = style.numberAdornment.apply(to: "\(parentSymbol).\(childSymbol)")
                    } else {
                        formattedNumber = style.numberFormat.symbol(for: counter - 1, adornment: style.numberAdornment)
                    }
                    
                    // Calculate Y position for empty paragraph (after last line)
                    let font = style.generateFont(applyPlatformScaling: true)
                    let lastLineY: CGFloat
                    let lastLineRect: CGRect
                    if textStorage.length > 1 {
                        let lastGlyphRange = self.glyphRange(forCharacterRange: NSRange(location: textStorage.length - 2, length: 1), actualCharacterRange: nil)
                        if lastGlyphRange.length > 0 {
                            lastLineRect = self.lineFragmentRect(forGlyphAt: lastGlyphRange.location, effectiveRange: nil)
                            lastLineY = lastLineRect.origin.y + lastLineRect.height
                        } else {
                            lastLineY = font.lineHeight
                            lastLineRect = CGRect(x: 0, y: 0, width: 100, height: font.lineHeight)
                        }
                    } else {
                        lastLineY = 0
                        lastLineRect = CGRect(x: 0, y: 0, width: 100, height: font.lineHeight)
                    }
                    
                    // Draw the number for empty paragraph with matching attributes
                    self.drawNumber(formattedNumber, at: CGPoint(x: origin.x, y: origin.y + lastLineY), lineFragmentRect: lastLineRect, paragraphAttributes: attrs, with: style)
                }
            }
        }
    }
    
    /// Draw line numbers on the right margin for poetry projects
    /// Numbers are consecutive, skip blank lines, respect marked sections
    /// Uses poetryStartingLineNumber for correct numbering across pages
    private func drawPoetryLineNumbers(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let textStorage = textStorage,
              let textContainer = textContainers.first else {
            return
        }
        
        // Get character range for visible glyphs
        let visibleCharRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        // Count lines in THIS page's text storage
        let text = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // Build a map of paragraph start position to line number (only non-blank, non-excluded lines)
        // Start from poetryStartingLineNumber to continue from previous pages
        var paragraphLineNumbers: [Int: Int] = [:] // paragraph start location -> line number
        var lineNumber = poetryStartingLineNumber - 1 // Will be incremented to starting number
        
        text.enumerateSubstrings(in: fullRange, options: .byParagraphs) { substring, paragraphRange, _, _ in
            // Skip blank lines
            let lineText = substring ?? ""
            if lineText.trimmingCharacters(in: .whitespaces).isEmpty {
                return
            }
            
            // Check if this line is marked as excluded (poemSectionType != .poem and != nil)
            if paragraphRange.location < textStorage.length {
                if let sectionType = textStorage.attribute(.poemSectionType, at: paragraphRange.location, effectiveRange: nil) as? String,
                   sectionType != PoemSectionType.poem.rawValue {
                    // This line is excluded - don't number it
                    return
                }
            }
            
            // This is a numbered line
            lineNumber += 1
            paragraphLineNumbers[paragraphRange.location] = lineNumber
        }
        
        // Second pass: draw line numbers for visible paragraphs
        text.enumerateSubstrings(in: fullRange, options: .byParagraphs) { [weak self] substring, paragraphRange, _, _ in
            guard let self = self else { return }
            
            // Check if this paragraph is visible
            let paragraphEnd = paragraphRange.location + paragraphRange.length
            let visibleEnd = visibleCharRange.location + visibleCharRange.length
            let isVisible = (paragraphRange.location < visibleEnd) && (paragraphEnd > visibleCharRange.location)
            
            guard isVisible,
                  let lineNum = paragraphLineNumbers[paragraphRange.location] else {
                return
            }
            
            // Get line fragment rect for this paragraph
            let glyphRange = self.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }
            
            let lineFragmentRect = self.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            
            // Draw the line number on the right
            self.drawPoetryLineNumber(lineNum, at: origin, lineFragmentRect: lineFragmentRect, containerWidth: textContainer.size.width)
        }
    }
    
    /// Draw a single poetry line number on the right margin
    private func drawPoetryLineNumber(_ lineNumber: Int, at origin: CGPoint, lineFragmentRect: CGRect, containerWidth: CGFloat) {
        let numberString = "\(lineNumber)" as NSString
        
        // Use a subtle, secondary color for line numbers
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: poetryLineNumberFontSize, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let numberSize = numberString.size(withAttributes: numberAttributes)
        
        // Position on the right side, just inside the right margin
        // The containerWidth is the text container width, so we position at the far right
        let numberX = origin.x + containerWidth - poetryLineNumberWidth + 5
        
        // Vertically center in the line fragment
        let baselineY = origin.y + lineFragmentRect.origin.y + (lineFragmentRect.height - numberSize.height) / 2
        
        let numberRect = CGRect(
            x: numberX,
            y: baselineY,
            width: poetryLineNumberWidth - 10,
            height: numberSize.height
        )
        
        numberString.draw(in: numberRect, withAttributes: numberAttributes)
    }
    
    /// Helper method to draw a number at the start of a paragraph's first line
    /// The number is drawn just before the text starts. For list styles, the text
    /// starts at the style's headIndent, so the number is drawn at headIndent - numberWidth.
    /// - Parameters:
    ///   - formattedNumber: The number string to draw
    ///   - origin: The origin point for drawing (includes text container inset)
    ///   - lineFragmentRect: The line fragment rect for baseline calculation
    ///   - paragraphAttributes: The actual attributes from the paragraph text
    ///   - style: The TextStyleModel for fallback values
    private func drawNumber(_ formattedNumber: String, at origin: CGPoint, lineFragmentRect: CGRect, paragraphAttributes: [NSAttributedString.Key: Any], with style: TextStyleModel) {
        // Get font from paragraph attributes (preserves bold/italic traits)
        let paragraphFont = paragraphAttributes[.font] as? UIFont ?? style.generateFont(applyPlatformScaling: true)
        
        // Get color from paragraph attributes (or fall back to style color)
        let paragraphColor: UIColor
        if let attrColor = paragraphAttributes[.foregroundColor] as? UIColor {
            paragraphColor = attrColor
        } else {
            paragraphColor = style.textColor ?? UIColor.label
        }
        
        // Build number attributes matching the paragraph
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: paragraphFont,
            .foregroundColor: paragraphColor
        ]
        
        let numberString = formattedNumber as NSString
        let numberSize = numberString.size(withAttributes: numberAttributes)
        
        // For list styles, draw the number just before where the text starts (at headIndent)
        // For other numbered styles, draw at the start of the line
        let numberX: CGFloat
        if style.styleCategory == .list {
            // List items: number goes just before headIndent position
            // Add a small gap between number and text
            let gap: CGFloat = 4.0
            numberX = origin.x + style.headIndent - numberSize.width - gap
        } else {
            // Non-list numbered paragraphs: number at the start of the line
            numberX = origin.x + lineFragmentRect.origin.x
        }
        
        // Calculate baseline-aligned Y position
        let baselineY = origin.y + lineFragmentRect.height - paragraphFont.descender - numberSize.height + paragraphFont.descender
        
        // Draw number left-aligned at the calculated position
        let numberRect = CGRect(
            x: numberX,
            y: baselineY,
            width: numberSize.width,
            height: numberSize.height
        )
        
        numberString.draw(in: numberRect, withAttributes: numberAttributes)
    }
}
