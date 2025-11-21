//
//  CommentAttachment.swift
//  Writing Shed Pro
//
//  Feature 014: Comments
//  Created by GitHub Copilot on 20/11/2025.
//

import UIKit

/// Custom NSTextAttachment that displays a comment indicator icon in the text
final class CommentAttachment: NSTextAttachment {
    
    // MARK: - Properties
    
    /// Unique identifier linking this attachment to a CommentModel
    let commentID: UUID
    
    /// Whether the associated comment is resolved
    var isResolved: Bool
    
    /// Size of the comment icon - made larger for better visibility and tappability
    private static let iconSize: CGFloat = 22
    
    // MARK: - Initialization
    
    /// Initialize a new comment attachment
    /// - Parameters:
    ///   - commentID: ID of the associated comment
    ///   - isResolved: Whether the comment is resolved
    init(commentID: UUID, isResolved: Bool = false) {
        self.commentID = commentID
        self.isResolved = isResolved
        super.init(data: nil, ofType: nil)
    }
    
    required init?(coder: NSCoder) {
        // Decode commentID
        guard let commentIDString = coder.decodeObject(forKey: "commentID") as? String,
              let commentID = UUID(uuidString: commentIDString) else {
            return nil
        }
        
        self.commentID = commentID
        self.isResolved = coder.decodeBool(forKey: "isResolved")
        super.init(data: nil, ofType: nil)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(commentID.uuidString, forKey: "commentID")
        coder.encode(isResolved, forKey: "isResolved")
    }
    
    // MARK: - Secure Coding
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    // MARK: - Image Generation
    
    /// Generate the comment icon image
    /// - Parameters:
    ///   - imageBounds: The bounds for the image
    ///   - textContainer: The text container
    ///   - charIndex: The character index
    /// - Returns: The comment icon as a UIImage
    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        // Choose icon based on resolved state
        let symbolName = "bubble.left.fill"
        let color: UIColor = isResolved ? .systemGray : .systemBlue
        
        #if DEBUG
        print("💬🎨 CommentAttachment.image() called - commentID: \(commentID), isResolved: \(isResolved), color: \(isResolved ? "gray" : "blue")")
        #endif
        
        // Create configuration for the SF Symbol
        let config = UIImage.SymbolConfiguration(pointSize: Self.iconSize, weight: .regular)
        
        // Generate and tint the image
        return UIImage(systemName: symbolName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    /// Calculate the bounds for the attachment
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
            return CGRect(x: 0, y: -2, width: Self.iconSize, height: Self.iconSize)
        }
        
        // Get the font at this character position
        let font: UIFont
        if charIndex < textStorage.length {
            font = textStorage.attribute(.font, at: charIndex, effectiveRange: nil) as? UIFont
                ?? UIFont.systemFont(ofSize: 17)
        } else {
            font = UIFont.systemFont(ofSize: 17)
        }
        
        // Calculate vertical offset to align with text baseline
        let descent = font.descender
        let yOffset = descent - 2 // Slight adjustment for better visual alignment
        
        return CGRect(
            x: 0,
            y: yOffset,
            width: Self.iconSize,
            height: Self.iconSize
        )
    }
}

// MARK: - NSAttributedString Extension

extension NSAttributedString {
    
    /// Find all comment attachments in the attributed string
    /// - Returns: Array of tuples containing (attachment, range)
    func commentAttachments() -> [(CommentAttachment, NSRange)] {
        var attachments: [(CommentAttachment, NSRange)] = []
        
        enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: length),
            options: []
        ) { value, range, _ in
            if let attachment = value as? CommentAttachment {
                attachments.append((attachment, range))
            }
        }
        
        return attachments
    }
    
    /// Find a comment attachment by comment ID
    /// - Parameter commentID: The comment ID to search for
    /// - Returns: Tuple of (attachment, range) if found
    func commentAttachment(withID commentID: UUID) -> (CommentAttachment, NSRange)? {
        return commentAttachments().first { attachment, _ in
            attachment.commentID == commentID
        }
    }
}
