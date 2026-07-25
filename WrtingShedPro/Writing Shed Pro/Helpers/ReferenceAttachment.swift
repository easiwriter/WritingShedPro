//
//  ReferenceAttachment.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Custom NSTextAttachment for displaying reference markers in text
//  Supports notes, endnotes, references, glossary, index, figures, and tables
//

import UIKit

/// Custom NSTextAttachment that displays a reference marker in the text
/// Used for inline references to notes, references, glossary terms, index entries, etc.
final class ReferenceAttachment: NSTextAttachment {
    
    // MARK: - Properties
    
    /// The type of reference
    let referenceType: ReferenceType
    
    /// UUID of the referenced entry (NoteEntry, ReferenceEntry, etc.)
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
    
    /// For index markers: whether this is a primary reference (shown bold in index)
    var isPrimaryReference: Bool = false
    
    /// Whether this attachment is being rendered for the page/print view (as opposed to edit view)
    /// When true: render in black. When false: render in blue
    var isForPageView: Bool = false {
        didSet {
            if isForPageView != oldValue {
                // Clear cached image when context changes
                self.image = nil
                self.contents = nil
            }
        }
    }
    
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
    
    /// Convenience initializer for tag-based note/endnote references
    /// - Parameters:
    ///   - referenceType: The type of reference (.note or .endnote)
    ///   - entryID: UUID of the referenced entry
    ///   - tag: The user-supplied tag (e.g., "timeline-1")
    convenience init(referenceType: ReferenceType, entryID: UUID, tag: String) {
        let text: String
        switch referenceType {
        case .endnote:
            text = "[\(tag)]"
        case .note:
            text = "[Note: \(tag)]"
        default:
            text = "[\(tag)]"
        }
        self.init(referenceType: referenceType, entryID: entryID, displayText: text)
    }
    
    /// Convenience initializer for citation references
    /// - Parameters:
    ///   - entryID: UUID of the CitationEntry
    ///   - authorLastName: Primary author's last name
    
    /// Convenience initializer for glossary terms
    /// - Parameters:
    ///   - entryID: UUID of the GlossaryEntry
    ///   - term: The glossary term
    convenience init(glossaryEntryID: UUID, term: String) {
        let displayText = "[see \(term)]"
        self.init(referenceType: .glossary, entryID: glossaryEntryID, displayText: displayText)
    }
    
    /// Convenience initializer for references (author, date)
    /// - Parameters:
    ///   - entryID: UUID of the ReferenceEntry
    ///   - author: Author or organisation name
    ///   - date: Publication date
    convenience init(referenceEntryID: UUID, author: String, date: String) {
        let displayText = "[\(author), \(date)]"
        self.init(referenceType: .reference, entryID: referenceEntryID, displayText: displayText)
    }
    
    /// Convenience initializer for index markers (invisible)
    /// - Parameters:
    ///   - entryID: UUID of the IndexEntry
    ///   - isPrimary: Whether this is a primary reference (shown bold in generated index)
    convenience init(indexEntryID: UUID, isPrimary: Bool = false) {
        // Index markers use a zero-width space for invisibility
        self.init(referenceType: .index, entryID: indexEntryID, displayText: "\u{200B}")
        self.isPrimaryReference = isPrimary
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
        self.isPrimaryReference = coder.decodeBool(forKey: "isPrimaryReference")
        
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
        coder.encode(isPrimaryReference, forKey: "isPrimaryReference")
        
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
        print("🔖🎨 ReferenceAttachment.image() - type: \(referenceType), displayText: \(displayText), isForPageView: \(isForPageView)")
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
        
        // Get the font from the surrounding text for proper sizing and baseline alignment
        guard let textContainer = textContainer,
              let layoutManager = textContainer.layoutManager,
              let textStorage = layoutManager.textStorage else {
            return createFallbackImage(at: charIndex)
        }
        
        let surroundingFont = resolvedFont(in: textStorage, at: charIndex)
        
        let textColor = isForPageView ? UIColor.black : resolvedForegroundColor(in: textStorage, at: charIndex)
        
        // Create attributed string using the surrounding text's font
        let attributes: [NSAttributedString.Key: Any] = [
            .font: surroundingFont,
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)
        
        // Calculate size needed for the text
        let textSize = attributedString.size()
        
        guard textSize.width > 0 && textSize.height > 0 else {
            return nil
        }
        
        // Create image - no padding, just the text itself for inline display
        let imageSize = CGSize(
            width: ceil(textSize.width),
            height: ceil(textSize.height)
        )
        
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { context in
            // Draw text directly without background or border
            let textRect = CGRect(origin: .zero, size: imageSize)
            attributedString.draw(in: textRect)
        }
        
        return image
    }
    
    /// Fallback image generation when we can't get surrounding font
    private func createFallbackImage(at charIndex: Int) -> UIImage? {
        let font = UIFont.systemFont(ofSize: 16)
        let textColor = isForPageView ? UIColor.black : UIColor.label
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: displayText, attributes: attributes)
        let textSize = attributedString.size()
        
        guard textSize.width > 0 && textSize.height > 0 else {
            return nil
        }
        
        let imageSize = CGSize(
            width: ceil(textSize.width),
            height: ceil(textSize.height)
        )
        
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            let textRect = CGRect(origin: .zero, size: imageSize)
            attributedString.draw(in: textRect)
        }
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
            // Fallback: use standard 16pt font
            let font = UIFont.systemFont(ofSize: 16)
            let size = (displayText as NSString).size(withAttributes: [.font: font])
            // Use descender to align numbers with baseline (brackets can extend above/below)
            return CGRect(x: 0, y: font.descender, width: ceil(size.width), height: ceil(size.height))
        }
        
        let font = resolvedFont(in: textStorage, at: charIndex)
        
        // Calculate bounds that match the surrounding text's baseline
        let size = (displayText as NSString).size(withAttributes: [.font: font])
        
        // Position attachment so the *number inside* aligns with baseline, not the brackets
        // The brackets are typically full line height, but numbers are smaller
        // Move the attachment down (negative y) so descenders align, which positions numbers correctly
        // Use the font's descender value (negative number) to align with text baseline
        return CGRect(
            x: 0,
            y: font.descender,
            width: ceil(size.width),
            height: ceil(size.height)
        )
    }
    
    // MARK: - Private Helpers

    private func resolvedFont(in textStorage: NSTextStorage, at charIndex: Int) -> UIFont {
        let candidateLocations = [charIndex - 1, charIndex + 1]
        for location in candidateLocations where location >= 0 && location < textStorage.length {
            if textStorage.attribute(.attachment, at: location, effectiveRange: nil) != nil {
                continue
            }
            if let font = textStorage.attribute(.font, at: location, effectiveRange: nil) as? UIFont {
                return font
            }
        }

        if charIndex >= 0 && charIndex < textStorage.length,
           let font = textStorage.attribute(.font, at: charIndex, effectiveRange: nil) as? UIFont {
            return font
        }

        return UIFont.systemFont(ofSize: 16)
    }

    private func resolvedForegroundColor(in textStorage: NSTextStorage, at charIndex: Int) -> UIColor {
        let candidateLocations = [charIndex - 1, charIndex + 1]
        for location in candidateLocations where location >= 0 && location < textStorage.length {
            if textStorage.attribute(.attachment, at: location, effectiveRange: nil) != nil {
                continue
            }
            if let color = textStorage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor {
                return color
            }
        }

        if charIndex >= 0 && charIndex < textStorage.length,
           let color = textStorage.attribute(.foregroundColor, at: charIndex, effectiveRange: nil) as? UIColor {
            return color
        }

        return UIColor.label
    }
    
    private func stylingForType() -> (textColor: UIColor, backgroundColor: UIColor, borderColor: UIColor, font: UIFont) {
        switch referenceType {
        case .endnote:
            // Superscript style matching paragraph text color
            return (
                textColor: UIColor.label,
                backgroundColor: UIColor.label.withAlphaComponent(0.05),
                borderColor: UIColor.label.withAlphaComponent(0.15),
                font: UIFont.systemFont(ofSize: 11, weight: .semibold)
            )
            
        case .note:
            // Use paragraph font (body) size with label color
            let bodyFont = UIFont.preferredFont(forTextStyle: .body)
            return (
                textColor: UIColor.label,
                backgroundColor: UIColor.label.withAlphaComponent(0.05),
                borderColor: UIColor.label.withAlphaComponent(0.15),
                font: UIFont.systemFont(ofSize: bodyFont.pointSize, weight: .regular)
            )
            
        case .glossary:
            // Match paragraph text color
            return (
                textColor: UIColor.label,
                backgroundColor: UIColor.clear,
                borderColor: UIColor.clear,
                font: UIFont.systemFont(ofSize: 13, weight: .regular)
            )
            
        case .reference:
            // Match paragraph text color
            return (
                textColor: UIColor.label,
                backgroundColor: UIColor.label.withAlphaComponent(0.05),
                borderColor: UIColor.label.withAlphaComponent(0.15),
                font: UIFont.systemFont(ofSize: 13, weight: .regular)
            )
            
        case .figure, .table:
            // Match paragraph text color
            return (
                textColor: UIColor.label,
                backgroundColor: UIColor.label.withAlphaComponent(0.05),
                borderColor: UIColor.label.withAlphaComponent(0.15),
                font: UIFont.systemFont(ofSize: 13, weight: .medium)
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
