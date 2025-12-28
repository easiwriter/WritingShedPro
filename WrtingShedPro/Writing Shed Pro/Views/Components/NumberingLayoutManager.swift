//
//  NumberingLayoutManager.swift
//  Writing Shed Pro
//
//  Feature 016: Custom NSLayoutManager that renders paragraph numbers dynamically
//  Numbers are NEVER stored in the document - they're drawn at render time
//

import UIKit
import SwiftData

/// Custom layout manager that draws paragraph numbers in the left margin
/// Similar to line numbers in a code editor - purely visual, not part of document
class NumberingLayoutManager: NSLayoutManager {
    
    /// Reference to project for accessing style sheet (set by FormattedTextEditor)
    weak var project: Project?
    
    /// Calculate and draw paragraph numbers for numbered styles
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        // Disable debug logging - too verbose
        /*
        #if DEBUG
        print("🎨 NumberingLayoutManager.drawBackground called")
        print("   glyphsToShow: \(glyphsToShow)")
        print("   origin: \(origin)")
        print("   textStorage.length: \(textStorage?.length ?? -1)")
        print("   project: \(project != nil ? "✓" : "✗")")
        print("   styleSheet: \(project?.styleSheet != nil ? "✓" : "✗")")
        #endif
        */
        
        guard let textStorage = textStorage,
//              let textContainer = textContainers.first,
              let project = project,
              let styleSheet = project.styleSheet else {
            // Silent return - project may not have stylesheet yet
            return
        }
        
        // Get the visible character range
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        // Track paragraph counters for each style
        var styleCounters: [String: Int] = [:]
        
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
                drawNumber("1", at: origin, with: defaultStyle)
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
        
        #if DEBUG
        print("   🔍 Enumerating paragraphs in range \(charRange)")
        #endif
        
        text.enumerateSubstrings(in: fullRange, options: .byParagraphs) { [weak self] _, paragraphRange, _, _ in
            guard let self = self,
                  paragraphRange.location < textStorage.length else {
                #if DEBUG
                print("   ⏭️ Skipping paragraph (out of range)")
                #endif
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
            
            // Increment counter for this style (always count, even if not visible)
            let counter = (styleCounters[styleName] ?? 0) + 1
            styleCounters[styleName] = counter
            
            // Only DRAW if this paragraph is within the visible range
            // Check if paragraph overlaps with visible charRange
            let paragraphEnd = paragraphRange.location + paragraphRange.length
            let charRangeEnd = charRange.location + charRange.length
            let isVisible = (paragraphRange.location < charRangeEnd) && (paragraphEnd > charRange.location)
            
            guard isVisible else {
                return
            }
            
            #if DEBUG
            print("   📝 Found paragraph at range \(paragraphRange)")
            print("   🔍 Attributes at position \(attrLocation):")
            print("      textStyle: \(styleName)")
            print("      ✅ Style '\(styleName)' has numbering: \(style.numberFormat)")
            #endif
            
            // Format the number using the existing NumberFormat with adornment
            let formattedNumber = style.numberFormat.symbol(for: counter - 1, adornment: style.numberAdornment)
            
            #if DEBUG
            print("      🎯 Drawing number '\(formattedNumber)' for paragraph \(counter)")
            #endif
            
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
            
            // Draw the number at the paragraph position
            self.drawNumber(formattedNumber, at: CGPoint(x: origin.x, y: origin.y + lineFragmentRect.origin.y), with: style)
        }
        
        // Check for empty trailing paragraph (e.g., after pressing Enter)
        // enumerateSubstrings doesn't include empty paragraphs at the end
        if text.hasSuffix("\n") {
            let lastParaStart = textStorage.length
            
            #if DEBUG
            print("   📝 Found empty trailing paragraph at position \(lastParaStart)")
            #endif
            
            // Get attributes for the empty paragraph (use last character's attributes)
            if textStorage.length > 0 {
                let attrs = textStorage.attributes(at: textStorage.length - 1, effectiveRange: nil)
                
                #if DEBUG
                if let styleName = attrs[.textStyle] as? String {
                    print("      textStyle: \(styleName)")
                } else {
                    print("      textStyle: NONE")
                }
                #endif
                
                if let styleName = attrs[.textStyle] as? String,
                   let style = styleSheet.style(named: styleName),
                   style.numberFormat != .none {
                    
                    // Increment counter for this style
                    let counter = (styleCounters[styleName] ?? 0) + 1
                    styleCounters[styleName] = counter
                    
                    // Format the number
                    let formattedNumber = style.numberFormat.symbol(for: counter - 1, adornment: style.numberAdornment)
                    
                    #if DEBUG
                    print("      ✅ Style '\(styleName)' has numbering")
                    print("      🎯 Drawing number '\(formattedNumber)' for empty paragraph \(counter)")
                    #endif
                    
                    // Calculate Y position for empty paragraph (after last line)
                    let font = style.generateFont(applyPlatformScaling: true)
                    let lastLineY: CGFloat
                    if textStorage.length > 1 {
                        let lastGlyphRange = self.glyphRange(forCharacterRange: NSRange(location: textStorage.length - 2, length: 1), actualCharacterRange: nil)
                        if lastGlyphRange.length > 0 {
                            let lastLineRect = self.lineFragmentRect(forGlyphAt: lastGlyphRange.location, effectiveRange: nil)
                            lastLineY = lastLineRect.origin.y + lastLineRect.height
                        } else {
                            lastLineY = font.lineHeight
                        }
                    } else {
                        lastLineY = 0
                    }
                    
                    // Draw the number for empty paragraph
                    self.drawNumber(formattedNumber, at: CGPoint(x: origin.x, y: origin.y + lastLineY), with: style)
                }
            }
        }
    }
    
    /// Helper method to draw a number in the left margin
    private func drawNumber(_ formattedNumber: String, at origin: CGPoint, with style: TextStyleModel) {
        // Calculate position for the number (in left margin)
        let numberX = origin.x - 60 // 60pt left of text container
        let numberY = origin.y
        
        // Get font and color from style
        let font = style.generateFont(applyPlatformScaling: true)
        let color = style.textColor ?? UIColor.label
        
        // Draw the number
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.withAlphaComponent(0.5) // Dimmed
        ]
        
        let numberString = formattedNumber as NSString
        let numberSize = numberString.size(withAttributes: numberAttributes)
        let numberRect = CGRect(
            x: numberX,
            y: numberY,
            width: 55,
            height: numberSize.height
        )
        
        // Right-align the number
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        var drawAttributes = numberAttributes
        drawAttributes[.paragraphStyle] = paragraphStyle
        
        numberString.draw(in: numberRect, withAttributes: drawAttributes)
    }
}
