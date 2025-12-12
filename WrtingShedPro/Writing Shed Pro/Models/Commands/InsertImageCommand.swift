import Foundation
import UIKit

/// Command for inserting an image at a specific position
final class InsertImageCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The position where the image should be inserted
    let position: Int
    
    /// The image data (JPEG/PNG)
    let imageData: Data
    
    /// Image scale (0.1 to 2.0)
    let scale: CGFloat
    
    /// Image alignment
    let alignment: ImageAttachment.ImageAlignment
    
    /// Whether image has a caption
    let hasCaption: Bool
    
    /// Caption text (if hasCaption is true)
    let captionText: String
    
    /// Caption style name (if hasCaption is true)
    let captionStyle: String
    
    /// Original filename (if available)
    let originalFilename: String?
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: TextFile?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        description: String = "Insert Image",
        position: Int,
        imageData: Data,
        scale: CGFloat,
        alignment: ImageAttachment.ImageAlignment,
        hasCaption: Bool,
        captionText: String,
        captionStyle: String,
        originalFilename: String? = nil,
        targetFile: TextFile?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.position = position
        self.imageData = imageData
        self.scale = scale
        self.alignment = alignment
        self.hasCaption = hasCaption
        self.captionText = captionText
        self.captionStyle = captionStyle
        self.originalFilename = originalFilename
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        print("🖼️💾 InsertImageCommand.execute() called")
        guard let file = targetFile,
              let currentVersion = file.currentVersion else {
            print("❌ No file or current version")
            return
        }
        
        let content = currentVersion.attributedContent ?? NSAttributedString()
        print("🖼️💾 Current content length: \(content.length)")
        print("🖼️💾 Insert position: \(position)")
        
        guard position >= 0, position <= content.length else {
            print("❌ Invalid position: \(position), content length: \(content.length)")
            return
        }
        
        // Create the ImageAttachment
        guard let attachment = ImageAttachment.from(imageData: imageData) else {
            print("❌ Failed to create ImageAttachment from data")
            return
        }
        
        print("🖼️💾 Created ImageAttachment: \(attachment)")
        
        // Set properties
        attachment.scale = scale
        attachment.alignment = alignment
        attachment.fileID = file.id // Set file ID for stylesheet access
        attachment.originalFilename = originalFilename // Set the original filename
        print("🖼️💾 Set originalFilename on attachment: \(originalFilename ?? "nil")")
        if hasCaption {
            attachment.setCaption(text: captionText, style: captionStyle)
        }
        
        // Create attributed string with the attachment
        let attachmentString = NSMutableAttributedString(attachment: attachment)
        print("🖼️💾 Created attachment string, length: \(attachmentString.length)")
        
        // Apply paragraph alignment based on image alignment
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        case .inline:
            paragraphStyle.alignment = .natural
        }
        
        attachmentString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attachmentString.length))
        
        // Create mutable copy and insert
        let mutableContent = NSMutableAttributedString(attributedString: content)
        print("🖼️💾 Before insert - mutableContent length: \(mutableContent.length)")
        
        // For center/right aligned images, wrap in newlines to isolate the paragraph
        if alignment == .center || alignment == .right {
            // Check if we need newline before
            let needsNewlineBefore = position > 0 && 
                                    mutableContent.string[mutableContent.string.index(mutableContent.string.startIndex, offsetBy: position - 1)] != "\n"
            
            // Check if we need newline after
            let needsNewlineAfter = position < mutableContent.length &&
                                   mutableContent.string[mutableContent.string.index(mutableContent.string.startIndex, offsetBy: position)] != "\n"
            
            var insertPosition = position
            
            // Get the attributes from the surrounding text to preserve font, color, etc.
            var surroundingAttributes: [NSAttributedString.Key: Any] = [:]
            if insertPosition > 0 && insertPosition < mutableContent.length {
                // Get attributes from character before insertion point
                surroundingAttributes = mutableContent.attributes(at: insertPosition - 1, effectiveRange: nil)
            } else if mutableContent.length > 0 {
                // Get attributes from first/last character
                let refPosition = insertPosition == 0 ? 0 : mutableContent.length - 1
                surroundingAttributes = mutableContent.attributes(at: refPosition, effectiveRange: nil)
            }
            
            // Create a text paragraph style to prevent image line height from bleeding
            let textParagraphStyle = NSMutableParagraphStyle()
            textParagraphStyle.alignment = .left
            textParagraphStyle.lineHeightMultiple = 1.0
            
            // Insert newline before if needed
            if needsNewlineBefore {
                let newline = NSMutableAttributedString(string: "\n", attributes: surroundingAttributes)
                newline.addAttribute(.paragraphStyle, value: textParagraphStyle, range: NSRange(location: 0, length: 1))
                mutableContent.insert(newline, at: insertPosition)
                insertPosition += 1
            }
            
            // Insert the attachment
            mutableContent.insert(attachmentString, at: insertPosition)
            insertPosition += 1
            
            // Insert newline after if needed
            if needsNewlineAfter {
                let newline = NSMutableAttributedString(string: "\n", attributes: surroundingAttributes)
                newline.addAttribute(.paragraphStyle, value: textParagraphStyle, range: NSRange(location: 0, length: 1))
                mutableContent.insert(newline, at: insertPosition)
            }
        } else {
            // For left/inline aligned images, just insert directly
            mutableContent.insert(attachmentString, at: position)
        }
        
        print("🖼️💾 After insert - mutableContent length: \(mutableContent.length)")
        
        // Verify the attachment is there
        if mutableContent.length > position {
            var effectiveRange = NSRange(location: 0, length: 0)
            let attrs = mutableContent.attributes(at: position, effectiveRange: &effectiveRange)
            if let att = attrs[NSAttributedString.Key.attachment] {
                print("🖼️💾 ✅ Attachment verified at position \(position): \(type(of: att))")
            } else {
                print("❌ NO attachment at position \(position) after insert!")
            }
        }
        
        // Update the version's content
        currentVersion.attributedContent = mutableContent
        print("🖼️💾 Set currentVersion.attributedContent")
        
        // DEBUG: Check if font size is preserved
        if mutableContent.length > 0 {
            let attrs = mutableContent.attributes(at: 0, effectiveRange: nil)
            if let font = attrs[.font] as? UIFont {
                print("🖼️💾 Font at position 0: \(font.fontName) \(font.pointSize)pt")
            }
            if let textStyle = attrs[.textStyle] {
                print("🖼️💾 TextStyle at position 0: \(textStyle)")
            }
        }
        
        file.modifiedDate = Date()
    }
    
    func undo() {
        guard let file = targetFile,
              let currentVersion = file.currentVersion else {
            return
        }
        
        let content = currentVersion.attributedContent ?? NSAttributedString()
        guard position >= 0, position + 1 <= content.length else {
            return
        }
        
        // Remove the image (attachments take up 1 character position)
        let mutableContent = NSMutableAttributedString(attributedString: content)
        mutableContent.deleteCharacters(in: NSRange(location: position, length: 1))
        
        // Update the version's content
        currentVersion.attributedContent = mutableContent
        file.modifiedDate = Date()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, position, imageData, scale, alignment
        case hasCaption, captionText, captionStyle, originalFilename
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(position, forKey: .position)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(scale, forKey: .scale)
        try container.encode(alignment.rawValue, forKey: .alignment)
        try container.encode(hasCaption, forKey: .hasCaption)
        try container.encode(captionText, forKey: .captionText)
        try container.encode(captionStyle, forKey: .captionStyle)
        try container.encodeIfPresent(originalFilename, forKey: .originalFilename)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        position = try container.decode(Int.self, forKey: .position)
        imageData = try container.decode(Data.self, forKey: .imageData)
        scale = try container.decode(CGFloat.self, forKey: .scale)
        let alignmentRaw = try container.decode(String.self, forKey: .alignment)
        alignment = ImageAttachment.ImageAlignment(rawValue: alignmentRaw) ?? .inline
        hasCaption = try container.decode(Bool.self, forKey: .hasCaption)
        captionText = try container.decode(String.self, forKey: .captionText)
        captionStyle = try container.decode(String.self, forKey: .captionStyle)
        originalFilename = try container.decodeIfPresent(String.self, forKey: .originalFilename)
        // Note: targetFile will be set when command is deserialized
    }
}
