//
//  PageBreakAttachment.swift
//  Writing Shed Pro
//
//  Visual representation of page break in editor (excluded from print)
//

import UIKit

/// Custom text attachment that displays a page break indicator in the editor
/// The actual page break is handled by the form feed character (\u{000C})
/// This attachment provides visual feedback without affecting print output
class PageBreakAttachment: NSTextAttachment {
    
    // MARK: - Properties
    
    private static let attachmentCharacter = "\u{FFFC}" // Object replacement character
    
    // MARK: - Initialization
    
    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    convenience init() {
        self.init(data: nil, ofType: nil)
    }
    
    private func setupAppearance() {
        // Create a visual representation of the page break
        self.image = createPageBreakImage()
    }
    
    // MARK: - Visual Representation
    
    /// Create an image showing a page break line with scissors icon
    private func createPageBreakImage() -> UIImage? {
        let width: CGFloat = 300
        let height: CGFloat = 20
        let size = CGSize(width: width, height: height)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Use a light gray color
            let color = UIColor.systemGray3
            color.setStroke()
            color.setFill()
            
            // Draw dashed line
            ctx.setLineWidth(1.0)
            ctx.setLineDash(phase: 0, lengths: [4, 4])
            
            let lineY = height / 2
            ctx.move(to: CGPoint(x: 0, y: lineY))
            ctx.addLine(to: CGPoint(x: width, y: lineY))
            ctx.strokePath()
            
            // Draw text in the center
            let text = "— Page Break —"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: color
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (width - textSize.width) / 2,
                y: (height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            // Draw white background behind text
            ctx.setFillColor(UIColor.systemBackground.cgColor)
            ctx.fill(textRect.insetBy(dx: -4, dy: -2))
            
            // Draw text
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image
    }
    
    // MARK: - Bounds
    
    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        // Return bounds that span most of the line width
        let width = lineFrag.width * 0.8
        let height: CGFloat = 20
        
        return CGRect(
            x: 0,
            y: -4, // Slight vertical offset for better alignment
            width: width,
            height: height
        )
    }
}

/// Helper to create page break attributed string with both visual indicator and actual page break
extension PageBreakAttachment {
    
    /// Custom attribute key to mark page break visual indicators
    /// These should be stripped out before printing
    static let visualMarkerAttribute = NSAttributedString.Key("PageBreakVisualMarker")
    
    /// Create an attributed string containing a page break
    /// Single form feed character with visual styling (deleted with one backspace)
    /// - Returns: Attributed string with page break
    static func createPageBreakString() -> NSAttributedString {
        // Just the form feed character with styling to make it visible
        // The form feed itself is a single character, so one backspace deletes it
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 1),  // Tiny so it doesn't take space
            .backgroundColor: UIColor.systemGray4,  // Light gray background to see it
            .foregroundColor: UIColor.systemGray2  // Slightly darker text
        ]
        
        return NSAttributedString(string: "\u{000C}", attributes: attributes)
    }
    
    /// Remove visual styling from form feed characters before printing
    /// The form feed remains but without background color or other styling
    /// - Parameter attributedString: The string that may contain styled form feeds
    /// - Returns: String with form feeds preserved but styling removed
    static func removeVisualMarkers(from attributedString: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: result.length)
        
        // Remove all attributes from form feed characters
        // This leaves the form feed itself (which the print system needs)
        // but removes the visual styling (background color, etc.)
        result.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            let substring = result.attributedSubstring(from: range).string
            if substring.contains("\u{000C}") {
                // Keep the character but remove all styling
                result.setAttributes([:], range: range)
            }
        }
        
        return result
    }
    
    /// Check if a character index contains a page break attachment
    /// - Parameters:
    ///   - attributedString: The attributed string to check
    ///   - index: The character index to check
    /// - Returns: True if the index contains a page break attachment
    static func isPageBreak(in attributedString: NSAttributedString, at index: Int) -> Bool {
        guard index < attributedString.length else { return false }
        
        let attributes = attributedString.attributes(at: index, effectiveRange: nil)
        if let attachment = attributes[.attachment] as? PageBreakAttachment {
            return true
        }
        
        return false
    }
}
