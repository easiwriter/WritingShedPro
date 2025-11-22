//
//  FootnoteAttachment.swift
//  Writing Shed Pro
//
//  Feature 017: Footnotes
//  Created by GitHub Copilot on 21/11/2025.
//

import UIKit

/// Custom NSTextAttachment that displays a footnote number as a superscript in the text
final class FootnoteAttachment: NSTextAttachment {
    
    // MARK: - Properties
    
    /// Unique identifier linking this attachment to a FootnoteModel
    let footnoteID: UUID
    
    /// The footnote number to display
    var number: Int
    
    /// Base font size for calculating superscript size
    private static let baseFontSize: CGFloat = 17
    
    /// Superscript font size (smaller than base text)
    private static let superscriptFontSize: CGFloat = 12
    
    /// Vertical offset for superscript positioning (positive moves up)
    private static let superscriptOffset: CGFloat = 6
    
    // MARK: - Initialization
    
    /// Initialize a new footnote attachment
    /// - Parameters:
    ///   - footnoteID: ID of the associated footnote
    ///   - number: The footnote number to display
    init(footnoteID: UUID, number: Int) {
        self.footnoteID = footnoteID
        self.number = number
        super.init(data: nil, ofType: nil)
    }
    
    required init?(coder: NSCoder) {
        // Decode footnoteID
        guard let footnoteIDString = coder.decodeObject(forKey: "footnoteID") as? String,
              let footnoteID = UUID(uuidString: footnoteIDString) else {
            return nil
        }
        
        self.footnoteID = footnoteID
        self.number = coder.decodeInteger(forKey: "number")
        super.init(data: nil, ofType: nil)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(footnoteID.uuidString, forKey: "footnoteID")
        coder.encode(number, forKey: "number")
    }
    
    // MARK: - Secure Coding
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    // MARK: - Image Generation
    
    /// Generate the footnote number as a styled image with button appearance
    /// - Parameters:
    ///   - imageBounds: The bounds for the image
    ///   - textContainer: The text container
    ///   - charIndex: The character index
    /// - Returns: The footnote number as a UIImage
    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        
        #if DEBUG
        print("📝🎨 FootnoteAttachment.image() called - footnoteID: \(footnoteID), number: \(number)")
        #endif
        
        // Create attributed string for the number
        let numberString = "\(number)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Self.superscriptFontSize, weight: .medium),
            .foregroundColor: UIColor.systemBlue,
            .baselineOffset: 0 // Baseline handled by attachmentBounds
        ]
        
        let attributedString = NSAttributedString(string: numberString, attributes: attributes)
        
        // Calculate size needed for the text
        let textSize = attributedString.size()
        
        // Add padding for button-like appearance
        let padding: CGFloat = 4
        let imageSize = CGSize(
            width: textSize.width + (padding * 2),
            height: textSize.height + (padding * 2)
        )
        
        // Create image with button styling
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: imageSize)
            
            // Draw button background (light blue tint)
            let backgroundPath = UIBezierPath(roundedRect: rect, cornerRadius: 4)
            UIColor.systemBlue.withAlphaComponent(0.1).setFill()
            backgroundPath.fill()
            
            // Draw border
            UIColor.systemBlue.withAlphaComponent(0.3).setStroke()
            backgroundPath.lineWidth = 0.5
            backgroundPath.stroke()
            
            // Draw the number text centered
            let textRect = CGRect(
                x: padding,
                y: padding,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
        }
        
        return image
    }
    
    /// Calculate the bounds for the attachment with superscript positioning
    /// - Parameters:
    ///   - textContainer: The text container
    ///   - proposedLineFragment: The proposed line fragment rect
    ///   - glyphPosition: The glyph position
    ///   - characterIndex: The character index
    /// - Returns: The bounds for the attachment
    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        // Get the font from the text container's layout manager
        guard let textContainer = textContainer,
              let layoutManager = textContainer.layoutManager,
              let textStorage = layoutManager.textStorage else {
            // Fallback to default size
            return defaultBounds()
        }
        
        // Get the font at this character position
        let font: UIFont
        if charIndex < textStorage.length {
            font = textStorage.attribute(.font, at: charIndex, effectiveRange: nil) as? UIFont
                ?? UIFont.systemFont(ofSize: Self.baseFontSize)
        } else {
            font = UIFont.systemFont(ofSize: Self.baseFontSize)
        }
        
        // Calculate size for the number
        let numberString = "\(number)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Self.superscriptFontSize, weight: .medium)
        ]
        let textSize = (numberString as NSString).size(withAttributes: attributes)
        
        // Add padding
        let padding: CGFloat = 4
        let width = textSize.width + (padding * 2)
        let height = textSize.height + (padding * 2)
        
        // Calculate vertical offset for superscript position
        // Use font descender for baseline alignment like CommentAttachment
        // Then apply superscript offset to raise it above baseline
        let descent = font.descender
        let yOffset = descent - Self.superscriptOffset
        
        return CGRect(
            x: 0,
            y: yOffset,
            width: width,
            height: height
        )
    }
    
    /// Default bounds when text container information is unavailable
    private func defaultBounds() -> CGRect {
        let numberString = "\(number)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: Self.superscriptFontSize, weight: .medium)
        ]
        let textSize = (numberString as NSString).size(withAttributes: attributes)
        
        let padding: CGFloat = 4
        let width = textSize.width + (padding * 2)
        let height = textSize.height + (padding * 2)
        
        // Use font descender approximation for baseline alignment
        let font = UIFont.systemFont(ofSize: Self.baseFontSize)
        let descent = font.descender
        let yOffset = descent - Self.superscriptOffset
        
        return CGRect(
            x: 0,
            y: yOffset,
            width: width,
            height: height
        )
    }
}

// MARK: - NSAttributedString Extension

extension NSAttributedString {
    
    /// Find all footnote attachments in the attributed string
    /// - Returns: Array of tuples containing (attachment, range)
    func footnoteAttachments() -> [(FootnoteAttachment, NSRange)] {
        var attachments: [(FootnoteAttachment, NSRange)] = []
        
        enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: length),
            options: []
        ) { value, range, _ in
            if let attachment = value as? FootnoteAttachment {
                attachments.append((attachment, range))
            }
        }
        
        return attachments
    }
    
    /// Find a footnote attachment by footnote ID
    /// - Parameter footnoteID: The footnote ID to search for
    /// - Returns: Tuple of (attachment, range) if found
    func footnoteAttachment(withID footnoteID: UUID) -> (FootnoteAttachment, NSRange)? {
        return footnoteAttachments().first { attachment, _ in
            attachment.footnoteID == footnoteID
        }
    }
    
    /// Find all footnotes sorted by their position in the text
    /// - Returns: Array of footnote attachments sorted by range location
    func sortedFootnoteAttachments() -> [(FootnoteAttachment, NSRange)] {
        return footnoteAttachments().sorted { $0.1.location < $1.1.location }
    }
}
