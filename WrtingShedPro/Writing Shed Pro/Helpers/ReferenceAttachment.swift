//
//  ReferenceAttachment.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Custom NSTextAttachment for displaying reference markers in text
//  Supports notes, endnotes, citations, glossary, index, figures, and tables
//

import UIKit

/// Custom NSTextAttachment that displays a reference marker in the text
/// Used for inline references to notes, citations, glossary terms, index entries, etc.
final class ReferenceAttachment: NSTextAttachment {
    
    // MARK: - Properties
    
    /// The type of reference
    let referenceType: ReferenceType
    
    /// UUID of the referenced entry (NoteEntry, CitationEntry, etc.)
    let entryID: UUID
    
    /// Display text for the marker (e.g., "[1]", "[Smith, 2024]", "protagonist")
    var displayText: String {
        didSet {
            if displayText != oldValue {
                // Clear cached image when display text changes
                self.image = nil
                self.contents = nil
                #if DEBUG
                print("🔄 ReferenceAttachment: displayText changed, clearing cached image")
                #endif
            }
        }
    }
    
    /// For notes/endnotes: the display number
    var displayNumber: Int = 0 {
        didSet {
            if displayNumber != oldValue && (referenceType == .note || referenceType == .endnote) {
                updateDisplayText()
            }
        }
    }
    
    /// Font size for the marker
    private static let markerFontSize: CGFloat = 13
    
    /// Superscript font size (for endnotes)
    private static let superscriptFontSize: CGFloat = 11
    
    // MARK: - Initialization
    
    /// Initialize a new reference attachment
    /// - Parameters:
    ///   - referenceType: The type of reference
    ///   - entryID: UUID of the referenced entry
    ///   - displayText: Text to display in the marker
    init(referenceType: ReferenceType, entryID: UUID, displayText: String) {
        self.referenceType = referenceType
        self.entryID = entryID
        self.displayText = displayText
        super.init(data: nil, ofType: nil)
    }
    
    /// Convenience initializer for numbered references (notes, endnotes, figures, tables)
    /// - Parameters:
    ///   - referenceType: The type of reference
    ///   - entryID: UUID of the referenced entry
    ///   - number: The display number
    convenience init(referenceType: ReferenceType, entryID: UUID, number: Int) {
        let text: String
        switch referenceType {
        case .endnote:
            text = "[\(number)]"
        case .note:
            text = "[Note \(number)]"
        case .figure:
            text = "[Fig \(number)]"
        case .table:
            text = "[Table \(number)]"
        default:
            text = "[\(number)]"
        }
        self.init(referenceType: referenceType, entryID: entryID, displayText: text)
        self.displayNumber = number
    }
    
    /// Convenience initializer for citation references
    /// - Parameters:
    ///   - entryID: UUID of the CitationEntry
    ///   - authorLastName: Primary author's last name
    ///   - year: Publication year
    convenience init(citationEntryID: UUID, authorLastName: String, year: Int?) {
        let text: String
        if let year = year {
            text = "[\(authorLastName), \(year)]"
        } else {
            text = "[\(authorLastName)]"
        }
        self.init(referenceType: .citation, entryID: citationEntryID, displayText: text)
    }
    
    /// Convenience initializer for glossary terms
    /// - Parameters:
    ///   - entryID: UUID of the GlossaryEntry
    ///   - term: The glossary term
    convenience init(glossaryEntryID: UUID, term: String) {
        self.init(referenceType: .glossary, entryID: glossaryEntryID, displayText: term)
    }
    
    /// Convenience initializer for index markers (invisible)
    /// - Parameter entryID: UUID of the IndexEntry
    convenience init(indexEntryID: UUID) {
        // Index markers use a zero-width space for invisibility
        self.init(referenceType: .index, entryID: indexEntryID, displayText: "\u{200B}")
    }
    
    required init?(coder: NSCoder) {
        // Decode reference type
        guard let typeString = coder.decodeObject(forKey: "referenceType") as? String,
              let type = ReferenceType(rawValue: typeString) else {
            #if DEBUG
            print("❌ ReferenceAttachment: Failed to decode referenceType")
            #endif
            return nil
        }
        
        // Decode entry ID
        guard let entryIDString = coder.decodeObject(forKey: "entryID") as? String,
              let entryID = UUID(uuidString: entryIDString) else {
            #if DEBUG
            print("❌ ReferenceAttachment: Failed to decode entryID")
            #endif
            return nil
        }
        
        // Decode display text
        guard let displayText = coder.decodeObject(forKey: "displayText") as? String else {
            #if DEBUG
            print("❌ ReferenceAttachment: Failed to decode displayText")
            #endif
            return nil
        }
        
        self.referenceType = type
        self.entryID = entryID
        self.displayText = displayText
        self.displayNumber = coder.decodeInteger(forKey: "displayNumber")
        
        #if DEBUG
        print("✅ ReferenceAttachment decoded: type=\(type), entryID=\(entryID), displayText=\(displayText)")
        #endif
        
        super.init(data: nil, ofType: nil)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(referenceType.rawValue, forKey: "referenceType")
        coder.encode(entryID.uuidString, forKey: "entryID")
        coder.encode(displayText, forKey: "displayText")
        coder.encode(displayNumber, forKey: "displayNumber")
        
        #if DEBUG
        print("💾 ReferenceAttachment encoding: type=\(referenceType), entryID=\(entryID)")
        #endif
    }
    
    // MARK: - Secure Coding
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    // MARK: - Display Text Updates
    
    private func updateDisplayText() {
        switch referenceType {
        case .endnote:
            displayText = "[\(displayNumber)]"
        case .note:
            displayText = "[Note \(displayNumber)]"
        case .figure:
            displayText = "[Fig \(displayNumber)]"
        case .table:
            displayText = "[Table \(displayNumber)]"
        default:
            break
        }
    }
    
    // MARK: - Image Generation
    
    /// Generate the reference marker as a styled image
    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        
        #if DEBUG
        print("🔖🎨 ReferenceAttachment.image() - type: \(referenceType), displayText: \(displayText)")
        #endif
        
        // Index markers are invisible
        if referenceType == .index {
            // Return a tiny transparent image
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            return renderer.image { context in
                UIColor.clear.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            }
        }
        
        // Determine styling based on reference type
        let (textColor, backgroundColor, borderColor, font) = stylingForType()
        
        // Create attributed string for the marker
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)
        
        // Calculate size needed for the text
        let textSize = attributedString.size()
        
        // Add padding
        let horizontalPadding: CGFloat = referenceType == .glossary ? 2 : 4
        let verticalPadding: CGFloat = 2
        let imageSize = CGSize(
            width: ceil(textSize.width) + (horizontalPadding * 2),
            height: ceil(textSize.height) + (verticalPadding * 2)
        )
        
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return nil
        }
        
        // Create image with styling
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: imageSize)
            
            // Draw background (rounded rect for most types)
            if referenceType != .glossary {
                let backgroundPath = UIBezierPath(roundedRect: rect, cornerRadius: 3)
                backgroundColor.setFill()
                backgroundPath.fill()
                
                // Draw border
                borderColor.setStroke()
                backgroundPath.lineWidth = 0.5
                backgroundPath.stroke()
            }
            
            // Draw text centered
            let textRect = CGRect(
                x: horizontalPadding,
                y: verticalPadding,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
            
            // For glossary, add underline
            if referenceType == .glossary {
                let underlineY = rect.maxY - 1
                let underlinePath = UIBezierPath()
                underlinePath.move(to: CGPoint(x: 0, y: underlineY))
                underlinePath.addLine(to: CGPoint(x: rect.width, y: underlineY))
                textColor.setStroke()
                underlinePath.lineWidth = 1
                underlinePath.stroke()
            }
        }
        
        return image
    }
    
    /// Calculate the bounds for the attachment
    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        // Index markers are invisible - minimal size
        if referenceType == .index {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        // Get the font from the text container's layout manager for alignment
        guard let textContainer = textContainer,
              let layoutManager = textContainer.layoutManager,
              let textStorage = layoutManager.textStorage else {
            // Fallback
            return calculateBoundsForDefaultFont()
        }
        
        // Get the font at this character position
        let font: UIFont
        if charIndex < textStorage.length {
            font = textStorage.attribute(.font, at: charIndex, effectiveRange: nil) as? UIFont
                ?? UIFont.systemFont(ofSize: 17)
        } else {
            font = UIFont.systemFont(ofSize: 17)
        }
        
        return calculateBounds(for: font)
    }
    
    // MARK: - Private Helpers
    
    private func stylingForType() -> (textColor: UIColor, backgroundColor: UIColor, borderColor: UIColor, font: UIFont) {
        switch referenceType {
        case .endnote:
            // Superscript blue
            return (
                textColor: UIColor.systemBlue,
                backgroundColor: UIColor.systemBlue.withAlphaComponent(0.1),
                borderColor: UIColor.systemBlue.withAlphaComponent(0.3),
                font: UIFont.systemFont(ofSize: Self.superscriptFontSize, weight: .semibold)
            )
            
        case .note:
            // Blue badge
            return (
                textColor: UIColor.systemBlue,
                backgroundColor: UIColor.systemBlue.withAlphaComponent(0.1),
                borderColor: UIColor.systemBlue.withAlphaComponent(0.3),
                font: UIFont.systemFont(ofSize: Self.markerFontSize, weight: .medium)
            )
            
        case .citation:
            // Purple/indigo for academic feel
            return (
                textColor: UIColor.systemIndigo,
                backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.1),
                borderColor: UIColor.systemIndigo.withAlphaComponent(0.3),
                font: UIFont.systemFont(ofSize: Self.markerFontSize, weight: .medium)
            )
            
        case .glossary:
            // Teal with underline (no background)
            return (
                textColor: UIColor.systemTeal,
                backgroundColor: UIColor.clear,
                borderColor: UIColor.clear,
                font: UIFont.systemFont(ofSize: Self.markerFontSize, weight: .regular)
            )
            
        case .figure, .table:
            // Green for figures/tables
            return (
                textColor: UIColor.systemGreen.darker(by: 0.1) ?? .systemGreen,
                backgroundColor: UIColor.systemGreen.withAlphaComponent(0.1),
                borderColor: UIColor.systemGreen.withAlphaComponent(0.3),
                font: UIFont.systemFont(ofSize: Self.markerFontSize, weight: .medium)
            )
            
        case .index:
            // Invisible
            return (
                textColor: .clear,
                backgroundColor: .clear,
                borderColor: .clear,
                font: UIFont.systemFont(ofSize: 1)
            )
        }
    }
    
    private func calculateBoundsForDefaultFont() -> CGRect {
        let (_, _, _, font) = stylingForType()
        let size = (displayText as NSString).size(withAttributes: [.font: font])
        let horizontalPadding: CGFloat = referenceType == .glossary ? 2 : 4
        let verticalPadding: CGFloat = 2
        
        return CGRect(
            x: 0,
            y: -verticalPadding,
            width: ceil(size.width) + (horizontalPadding * 2),
            height: ceil(size.height) + (verticalPadding * 2)
        )
    }
    
    private func calculateBounds(for contextFont: UIFont) -> CGRect {
        let (_, _, _, markerFont) = stylingForType()
        let size = (displayText as NSString).size(withAttributes: [.font: markerFont])
        let horizontalPadding: CGFloat = referenceType == .glossary ? 2 : 4
        let verticalPadding: CGFloat = 2
        
        // Calculate vertical offset to align with text baseline
        let descent = contextFont.descender
        let yOffset: CGFloat
        
        switch referenceType {
        case .endnote:
            // Superscript - raised position
            yOffset = descent + (contextFont.pointSize * 0.3)
        case .glossary:
            // Inline with text
            yOffset = descent
        default:
            // Slight raise for badge-style markers
            yOffset = descent - 1
        }
        
        return CGRect(
            x: 0,
            y: yOffset,
            width: ceil(size.width) + (horizontalPadding * 2),
            height: ceil(size.height) + (verticalPadding * 2)
        )
    }
}

// MARK: - NSAttributedString Extension

extension NSAttributedString {
    
    /// Find all reference attachments in the attributed string
    /// - Returns: Array of tuples containing (attachment, range)
    func referenceAttachments() -> [(ReferenceAttachment, NSRange)] {
        var attachments: [(ReferenceAttachment, NSRange)] = []
        
        enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: length),
            options: []
        ) { value, range, _ in
            if let attachment = value as? ReferenceAttachment {
                attachments.append((attachment, range))
            }
        }
        
        return attachments.sorted { $0.1.location < $1.1.location }
    }
    
    /// Find reference attachments of a specific type
    /// - Parameter type: The reference type to filter by
    /// - Returns: Array of tuples containing (attachment, range)
    func referenceAttachments(ofType type: ReferenceType) -> [(ReferenceAttachment, NSRange)] {
        referenceAttachments().filter { $0.0.referenceType == type }
    }
    
    /// Find a reference attachment by entry ID
    /// - Parameter entryID: The UUID of the entry
    /// - Returns: Tuple of (attachment, range) if found
    func referenceAttachment(forEntryID entryID: UUID) -> (ReferenceAttachment, NSRange)? {
        referenceAttachments().first { $0.0.entryID == entryID }
    }
}

// MARK: - NSMutableAttributedString Extension

extension NSMutableAttributedString {
    
    /// Insert a reference attachment at the specified location
    /// - Parameters:
    ///   - attachment: The reference attachment to insert
    ///   - location: The character index to insert at
    func insertReferenceAttachment(_ attachment: ReferenceAttachment, at location: Int) {
        guard location >= 0 && location <= length else { return }
        
        // Create attachment string with the attachment character
        let attachmentString = NSAttributedString(attachment: attachment)
        
        // Also add reference type and ID as custom attributes for serialization
        let mutableAttachment = NSMutableAttributedString(attributedString: attachmentString)
        let range = NSRange(location: 0, length: mutableAttachment.length)
        mutableAttachment.addAttribute(.referenceType, value: attachment.referenceType.rawValue, range: range)
        mutableAttachment.addAttribute(.referenceID, value: attachment.entryID.uuidString, range: range)
        
        insert(mutableAttachment, at: location)
    }
    
    /// Update display numbers for all reference attachments of a given type
    /// Renumbers based on order of appearance in the document
    /// - Parameter type: The reference type to renumber
    func renumberReferenceAttachments(ofType type: ReferenceType) {
        let attachments = referenceAttachments(ofType: type)
        
        for (index, (attachment, _)) in attachments.enumerated() {
            let newNumber = index + 1
            if attachment.displayNumber != newNumber {
                attachment.displayNumber = newNumber
            }
        }
    }
    
    /// Remove all reference attachments for a specific entry
    /// - Parameter entryID: The UUID of the entry to remove references for
    func removeReferenceAttachments(forEntryID entryID: UUID) {
        let attachments = referenceAttachments().filter { $0.0.entryID == entryID }
        
        // Remove in reverse order to maintain valid indices
        for (_, range) in attachments.reversed() {
            deleteCharacters(in: range)
        }
    }
}
