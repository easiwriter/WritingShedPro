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
    
    /// Whether to draw invisible characters (spaces, tabs, paragraph marks, page breaks)
    var showInvisibles: Bool = false
    
    /// Width reserved for right-margin line numbers in poetry mode
    private let poetryLineNumberWidth: CGFloat = 40
    
    /// Font size for poetry line numbers
    private let poetryLineNumberFontSize: CGFloat = 11
    
    /// Determine the bullet level from a style name
    /// Returns 0 for base level, 1 for level-2, 2 for level-3, etc.
    func bulletLevel(from styleName: String) -> Int {
        if styleName.contains("level-3") { return 2 }
        if styleName.contains("level-2") { return 1 }
        return 0
    }
    
    /// Build a map of child style → parent style from parentStyleName relationships
    /// If Title2.parentStyleName == "Title1", then Title2's numbers are prefixed with Title1's
    
    /// Build the full hierarchical number string by walking the ancestor chain.
    /// For a style with parent chain: Title2 → Title3 → Headline
    /// Returns "1.1.1" (Title2=1, Title3=1, Headline=1)
    func buildHierarchicalNumber(
        for styleName: String,
        counter: Int,
        parentStyleMap: [String: String],
        lastNumberForStyle: [String: Int],
        styleSheet: StyleSheet
    ) -> String {
        // Walk up the ancestor chain to collect segments: [grandparent, parent, self]
        var segments: [(styleName: String, number: Int)] = []
        var current: String? = styleName
        
        // First, collect from self up to root
        while let name = current {
            let num: Int
            if name == styleName {
                num = counter
            } else {
                num = lastNumberForStyle[name] ?? 0
            }
            segments.append((name, num))
            current = parentStyleMap[name]
        }
        
        // Reverse so root is first: [root, ..., self]
        segments.reverse()
        
        // If only one segment (no parent), format normally
        guard segments.count > 1 else {
            let style = styleSheet.style(named: styleName)
            let level = bulletLevel(from: styleName)
            let numberFormat = style?.numberFormat ?? .decimal
            let adornment = style?.numberAdornment ?? .period
            return numberFormat.symbol(for: counter - 1, adornment: adornment, level: level)
        }
        
        // Build "1.1.1" from segments, each formatted with its own style's numberFormat
        let parts: [String] = segments.map { seg in
            let level = bulletLevel(from: seg.styleName)
            if let style = styleSheet.style(named: seg.styleName),
               style.numberFormat != .none {
                return style.numberFormat.symbol(for: max(seg.number - 1, 0), adornment: .plain, level: level)
            }
            return "\(seg.number)"
        }
        
        // Apply the final style's adornment to the combined string
        let combined = parts.joined(separator: ".")
        let style = styleSheet.style(named: styleName)
        let adornment = style?.numberAdornment ?? .period
        return adornment.apply(to: combined)
    }
    func buildParentStyleMap(from styleSheet: StyleSheet) -> [String: String] {
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
            
            // Build the formatted number using the full ancestor chain
            let formattedNumber = self.buildHierarchicalNumber(
                for: styleName,
                counter: counter,
                parentStyleMap: parentStyleMap,
                lastNumberForStyle: lastNumberForStyle,
                styleSheet: styleSheet
            )
            
            // Get the line fragment for this paragraph
            let glyphRange = self.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            
            // For empty paragraphs or when no glyphs, still draw at the paragraph location
            let lineFragmentRect: CGRect
            if glyphRange.length > 0 {
                lineFragmentRect = self.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            } else if paragraphRange.location > 0 {
                // Empty paragraph mid-document: find position from the preceding character's
                // line fragment, then offset by its height so the number draws on the next line
                let prevCharGlyphRange = self.glyphRange(forCharacterRange: NSRange(location: paragraphRange.location - 1, length: 1), actualCharacterRange: nil)
                if prevCharGlyphRange.length > 0 {
                    let prevRect = self.lineFragmentRect(forGlyphAt: prevCharGlyphRange.location, effectiveRange: nil)
                    let font = style.generateFont(applyPlatformScaling: true)
                    lineFragmentRect = CGRect(x: 0, y: prevRect.origin.y + prevRect.height, width: 100, height: font.lineHeight)
                } else {
                    let font = style.generateFont(applyPlatformScaling: true)
                    lineFragmentRect = CGRect(x: 0, y: 0, width: 100, height: font.lineHeight)
                }
            } else {
                // Empty first paragraph
                let font = style.generateFont(applyPlatformScaling: true)
                lineFragmentRect = CGRect(x: 0, y: 0, width: 100, height: font.lineHeight)
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
                    
                    // Build the formatted number using the full ancestor chain
                    let formattedNumber = self.buildHierarchicalNumber(
                        for: styleName,
                        counter: counter,
                        parentStyleMap: parentStyleMap,
                        lastNumberForStyle: lastNumberForStyle,
                        styleSheet: styleSheet
                    )
                    
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
    
    // MARK: - Page Break Lines
    
    /// Draw a horizontal line with "Page Break" label for form feed characters.
    /// Always drawn regardless of showInvisibles setting since page breaks are structural.
    private func drawPageBreakLines(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let textStorage = textStorage else { return }
        
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let text = textStorage.string as NSString
        
        text.enumerateSubstrings(in: charRange, options: .byComposedCharacterSequences) { [weak self] substring, substringRange, _, _ in
            guard let self = self,
                  substring == "\u{000C}",
                  substringRange.length == 1 else { return }
            
            let glyphIndex = self.glyphIndexForCharacter(at: substringRange.location)
            let lineFragmentRect = self.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            
            // Get the text container width for line span
            let containerWidth = self.textContainers.first?.size.width ?? lineFragmentRect.width
            
            let lineColor = UIColor.systemGray2
            let lineY = origin.y + lineFragmentRect.origin.y + lineFragmentRect.height / 2
            
            // Horizontal extent: inset slightly from container edges
            let inset: CGFloat = 20
            let leftX = origin.x + inset
            let rightX = origin.x + containerWidth - inset
            
            // Draw the label text
            let label = "Page Break" as NSString
            let labelFont = UIFont.systemFont(ofSize: 12, weight: .medium)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: lineColor
            ]
            let labelSize = label.size(withAttributes: labelAttrs)
            let labelX = origin.x + (containerWidth - labelSize.width) / 2
            let labelRect = CGRect(
                x: labelX,
                y: lineY - labelSize.height / 2,
                width: labelSize.width,
                height: labelSize.height
            )
            
            // Draw background behind label to clear the line
            let bgRect = labelRect.insetBy(dx: -6, dy: -1)
            UIColor.systemBackground.setFill()
            UIBezierPath(rect: bgRect).fill()
            
            // Draw dashed line on either side of the label
            let path = UIBezierPath()
            path.lineWidth = 1.0
            lineColor.setStroke()
            let dashPattern: [CGFloat] = [4, 4]
            path.setLineDash(dashPattern, count: 2, phase: 0)
            
            // Left segment
            path.move(to: CGPoint(x: leftX, y: lineY))
            path.addLine(to: CGPoint(x: bgRect.minX, y: lineY))
            
            // Right segment
            path.move(to: CGPoint(x: bgRect.maxX, y: lineY))
            path.addLine(to: CGPoint(x: rightX, y: lineY))
            
            path.stroke()
            
            // Draw label text
            label.draw(in: labelRect, withAttributes: labelAttrs)
        }
    }
    
    // MARK: - Show Invisibles
    
    /// Draw invisible characters (spaces, tabs, paragraph marks) over glyph positions
    /// Page breaks are drawn separately by drawPageBreakLines (always visible)
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        
        // Always draw page break lines regardless of showInvisibles
        drawPageBreakLines(forGlyphRange: glyphsToShow, at: origin)
        
        guard showInvisibles, let textStorage = textStorage else { return }
        
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let text = textStorage.string as NSString
        
        // Invisible character symbols
        let spaceSymbol: NSString = "·"       // Middle dot for spaces
        let tabSymbol: NSString = "→"         // Arrow for tabs
        let returnSymbol: NSString = "¶"      // Pilcrow for newlines
        
        // Use a visible blue so invisible characters stand out clearly
        let invisibleColor = UIColor.systemBlue.withAlphaComponent(0.5)
        
        text.enumerateSubstrings(in: charRange, options: .byComposedCharacterSequences) { [weak self] substring, substringRange, _, _ in
            guard let self = self,
                  let char = substring,
                  substringRange.length == 1 else { return }
            
            let symbol: NSString?
            let useSmallFont: Bool
            
            switch char {
            case " ":
                symbol = spaceSymbol
                useSmallFont = true
            case "\t":
                symbol = tabSymbol
                useSmallFont = false
            case "\n":
                symbol = returnSymbol
                useSmallFont = false
            default:
                symbol = nil
                useSmallFont = false
            }
            
            guard let drawSymbol = symbol else { return }
            
            let glyphIndex = self.glyphIndexForCharacter(at: substringRange.location)
            
            // Get the line fragment for positioning
            let lineFragmentRect = self.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let locationInLine = self.location(forGlyphAt: glyphIndex)
            
            // Get font from text at this position for size matching
            let charFont: UIFont
            if substringRange.location < textStorage.length {
                charFont = textStorage.attribute(.font, at: substringRange.location, effectiveRange: nil) as? UIFont
                    ?? UIFont.systemFont(ofSize: 14)
            } else {
                charFont = UIFont.systemFont(ofSize: 14)
            }
            
            let symbolFontSize: CGFloat = useSmallFont ? charFont.pointSize * 0.8 : charFont.pointSize * 0.9
            let symbolFont = UIFont.systemFont(ofSize: symbolFontSize)
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: symbolFont,
                .foregroundColor: invisibleColor
            ]
            
            let symbolSize = drawSymbol.size(withAttributes: attrs)
            
            // Position the symbol at the glyph location
            let x = origin.x + lineFragmentRect.origin.x + locationInLine.x
            let y: CGFloat
            
            if char == "\n" {
                // For newline, position at the end of the line, vertically centered
                y = origin.y + lineFragmentRect.origin.y + (lineFragmentRect.height - symbolSize.height) / 2
            } else {
                // For spaces/tabs, baseline-align with the text
                y = origin.y + lineFragmentRect.origin.y + locationInLine.y - symbolSize.height + symbolFont.descender - charFont.descender
            }
            
            drawSymbol.draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        }
    }
}
