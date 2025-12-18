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
        
        guard let textStorage = textStorage,
//              let textContainer = textContainers.first,
              let project = project,
              let styleSheet = project.styleSheet else {
            return
        }
        
        // Get the visible character range
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        
        // Track paragraph counters for each style
        var styleCounters: [String: Int] = [:]
        
        // Enumerate paragraphs in visible range
        let text = textStorage.string as NSString
        text.enumerateSubstrings(in: charRange, options: .byParagraphs) { [weak self] _, paragraphRange, _, _ in
            guard let self = self,
                  paragraphRange.length > 0,
                  paragraphRange.location < textStorage.length else {
                return
            }
            
            // Get style at paragraph start
            let attrs = textStorage.attributes(at: paragraphRange.location, effectiveRange: nil)
            guard let styleName = attrs[.textStyle] as? String,
                  let style = styleSheet.style(named: styleName),
                  style.numberFormat != .none else {
                return
            }
            
            // Increment counter for this style
            let counter = (styleCounters[styleName] ?? 0) + 1
            styleCounters[styleName] = counter
            
            // Format the number using the existing NumberFormat
            let formattedNumber = style.numberFormat.symbol(for: counter - 1) // symbol() is 0-based
            
            // Get the line fragment for this paragraph
            let glyphRange = self.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }
            
            let lineFragmentRect = self.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            
            // Calculate position for the number (in left margin)
            let numberX = origin.x - 60 // 60pt left of text container
            let numberY = origin.y + lineFragmentRect.origin.y
            
            // Get font and color from paragraph attributes
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
                y: numberY + (lineFragmentRect.height - numberSize.height) / 2,
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
}
