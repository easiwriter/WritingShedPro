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

    let captionPrefix: String?

    let imageStyleName: String

    let spacingAbove: CGFloat
    let spacingBelow: CGFloat
    
    /// Original filename (if available)
    let originalFilename: String?
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: TextFile?

    /// The actual attachment position after any newline wrapping has been applied.
    private(set) var insertedImagePosition: Int?

    /// The image and only the wrapper newlines introduced by this command.
    private var insertedContentRange: NSRange?
    
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
        captionPrefix: String? = nil,
        imageStyleName: String = "default",
        spacingAbove: CGFloat = 0,
        spacingBelow: CGFloat = 0,
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
        self.captionPrefix = captionPrefix
        self.imageStyleName = imageStyleName
        self.spacingAbove = spacingAbove
        self.spacingBelow = spacingBelow
        self.originalFilename = originalFilename
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        #if DEBUG
        print("🖼️💾 InsertImageCommand.execute() called")
        #endif
        insertedImagePosition = nil
        insertedContentRange = nil
        guard let file = targetFile,
              let currentVersion = file.currentVersion else {
            #if DEBUG
            print("❌ No file or current version")
            #endif
            return
        }
        
        let content = currentVersion.attributedContent ?? NSAttributedString()
        #if DEBUG
        print("🖼️💾 Current content length: \(content.length)")
        #endif
        #if DEBUG
        print("🖼️💾 Insert position: \(position)")
        #endif
        
        guard position >= 0, position <= content.length else {
            #if DEBUG
            print("❌ Invalid position: \(position), content length: \(content.length)")
            #endif
            return
        }
        
        // Create the ImageAttachment
        guard let attachment = ImageAttachment.from(imageData: imageData) else {
            #if DEBUG
            print("❌ Failed to create ImageAttachment from data")
            #endif
            return
        }
        
        #if DEBUG
        print("🖼️💾 Created ImageAttachment: \(attachment)")
        #endif
        
        // Set properties
        attachment.scale = scale
        attachment.alignment = alignment
        attachment.imageStyleName = imageStyleName
        attachment.fileID = file.id // Set file ID for stylesheet access
        attachment.originalFilename = originalFilename // Set the original filename
        attachment.spacingAbove = spacingAbove
        attachment.spacingBelow = spacingBelow
        #if DEBUG
        print("🖼️💾 Set originalFilename on attachment: \(originalFilename ?? "nil")")
        #endif
        if hasCaption {
            attachment.setCaption(text: captionText, style: captionStyle)
            attachment.captionPrefix = captionPrefix
        }
        
        // Create attributed string with the attachment
        let attachmentString = NSMutableAttributedString(attachment: attachment)
        #if DEBUG
        print("🖼️💾 Created attachment string, length: \(attachmentString.length)")
        #endif
        
        attachmentString.addAttribute(
            .paragraphStyle,
            value: attachment.paragraphStyle(),
            range: NSRange(location: 0, length: attachmentString.length)
        )
        
        // Create mutable copy and insert
        let mutableContent = NSMutableAttributedString(attributedString: content)
        #if DEBUG
        print("🖼️💾 Before insert - mutableContent length: \(mutableContent.length)")
        #endif
        
        // For center/right aligned images, wrap in newlines to isolate the paragraph
        if alignment == .center || alignment == .right {
            let nsString = mutableContent.string as NSString

            // Check if we need newline before
            let needsNewlineBefore = position > 0 && 
                                    nsString.character(at: position - 1) != 0x0A
            
            // Check if we need newline after
            let needsNewlineAfter = position < mutableContent.length &&
                                   nsString.character(at: position) != 0x0A
            
            var insertPosition = position
            let insertedRangeStart = position
            
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
            insertedImagePosition = insertPosition
            mutableContent.insert(attachmentString, at: insertPosition)
            insertPosition += 1
            
            // Insert newline after if needed
            if needsNewlineAfter {
                let newline = NSMutableAttributedString(string: "\n", attributes: surroundingAttributes)
                newline.addAttribute(.paragraphStyle, value: textParagraphStyle, range: NSRange(location: 0, length: 1))
                mutableContent.insert(newline, at: insertPosition)
                insertPosition += 1
            }
            insertedContentRange = NSRange(
                location: insertedRangeStart,
                length: insertPosition - insertedRangeStart
            )
        } else {
            // For left/inline aligned images, just insert directly
            insertedImagePosition = position
            mutableContent.insert(attachmentString, at: position)
            insertedContentRange = NSRange(location: position, length: 1)
        }
        
        #if DEBUG
        print("🖼️💾 After insert - mutableContent length: \(mutableContent.length)")
        #endif
        
        // Verify the attachment is there
        let verificationPosition = insertedImagePosition ?? position
        if mutableContent.length > verificationPosition {
            var effectiveRange = NSRange(location: 0, length: 0)
            let attrs = mutableContent.attributes(at: verificationPosition, effectiveRange: &effectiveRange)
            if let att = attrs[NSAttributedString.Key.attachment] {
                #if DEBUG
                print("🖼️💾 ✅ Attachment verified at position \(verificationPosition): \(type(of: att))")
                #endif
            } else {
                #if DEBUG
                print("❌ NO attachment at position \(verificationPosition) after insert!")
                #endif
            }
        }
        
        // Update the version's content
        currentVersion.attributedContent = mutableContent
        notifyContentRestored(mutableContent)
        #if DEBUG
        print("🖼️💾 Set currentVersion.attributedContent")
        #endif
        
        // DEBUG: Check if font size is preserved
        if mutableContent.length > 0 {
            let attrs = mutableContent.attributes(at: 0, effectiveRange: nil)
            if let font = attrs[.font] as? UIFont {
                #if DEBUG
                print("🖼️💾 Font at position 0: \(font.fontName) \(font.pointSize)pt")
                #endif
            }
            if let textStyle = attrs[.textStyle] {
                #if DEBUG
                print("🖼️💾 TextStyle at position 0: \(textStyle)")
                #endif
            }
        }
        
        file.modifiedDate = Date()
        Task { @MainActor in
            try? WriteCoalescer.shared?.requestSaveAndFlush(reason: "insert-image-command")
        }
    }
    
    func undo() {
        guard let file = targetFile,
              let currentVersion = file.currentVersion else {
            return
        }
        
        let content = currentVersion.attributedContent ?? NSAttributedString()
        let removalRange = insertedContentRange
            ?? NSRange(location: insertedImagePosition ?? position, length: 1)
        guard removalRange.location >= 0,
              NSMaxRange(removalRange) <= content.length else {
            return
        }
        
        let mutableContent = NSMutableAttributedString(attributedString: content)
        mutableContent.deleteCharacters(in: removalRange)
        
        // Update the version's content
        currentVersion.attributedContent = mutableContent
        notifyContentRestored(mutableContent)
        file.modifiedDate = Date()
        Task { @MainActor in
            try? WriteCoalescer.shared?.requestSaveAndFlush(reason: "insert-image-command-undo")
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, position, imageData, scale, alignment
        case hasCaption, captionText, captionStyle, captionPrefix, imageStyleName, spacingAbove, spacingBelow, originalFilename
        case insertedImagePosition, insertedRangeLocation, insertedRangeLength
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
        try container.encodeIfPresent(captionPrefix, forKey: .captionPrefix)
        try container.encode(imageStyleName, forKey: .imageStyleName)
        try container.encode(spacingAbove, forKey: .spacingAbove)
        try container.encode(spacingBelow, forKey: .spacingBelow)
        try container.encodeIfPresent(originalFilename, forKey: .originalFilename)
        try container.encodeIfPresent(insertedImagePosition, forKey: .insertedImagePosition)
        try container.encodeIfPresent(insertedContentRange?.location, forKey: .insertedRangeLocation)
        try container.encodeIfPresent(insertedContentRange?.length, forKey: .insertedRangeLength)
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
        captionPrefix = try container.decodeIfPresent(String.self, forKey: .captionPrefix)
        imageStyleName = try container.decodeIfPresent(String.self, forKey: .imageStyleName) ?? "default"
        spacingAbove = try container.decodeIfPresent(CGFloat.self, forKey: .spacingAbove) ?? 0
        spacingBelow = try container.decodeIfPresent(CGFloat.self, forKey: .spacingBelow) ?? 0
        originalFilename = try container.decodeIfPresent(String.self, forKey: .originalFilename)
        insertedImagePosition = try container.decodeIfPresent(Int.self, forKey: .insertedImagePosition)
        if let rangeLocation = try container.decodeIfPresent(Int.self, forKey: .insertedRangeLocation),
           let rangeLength = try container.decodeIfPresent(Int.self, forKey: .insertedRangeLength) {
            insertedContentRange = NSRange(location: rangeLocation, length: rangeLength)
        }
        // Note: targetFile will be set when command is deserialized
    }

    private func notifyContentRestored(_ content: NSAttributedString) {
        NotificationCenter.default.post(
            name: NSNotification.Name("UndoRedoContentRestored"),
            object: targetFile,
            userInfo: [
                "content": content,
                "updateEditorInPlace": true
            ]
        )
    }
}

/// Removes one image attachment while retaining enough data to restore it exactly on undo.
final class DeleteImageCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    let position: Int
    let attachmentData: Data
    weak var targetFile: TextFile?
    private var originalAttachment: ImageAttachment?

    init?(position: Int, attachment: ImageAttachment, targetFile: TextFile?) {
        guard let attachmentData = try? NSKeyedArchiver.archivedData(
            withRootObject: attachment,
            requiringSecureCoding: true
        ) else {
            return nil
        }

        self.id = UUID()
        self.timestamp = Date()
        self.description = "Cut Image"
        self.position = position
        self.attachmentData = attachmentData
        self.targetFile = targetFile
        self.originalAttachment = attachment
    }

    func execute() {
        guard let file = targetFile,
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              position >= 0,
              position < content.length,
              content.attribute(.attachment, at: position, effectiveRange: nil) is ImageAttachment else {
            return
        }

        let updatedContent = NSMutableAttributedString(attributedString: content)
          updatedContent.deleteCharacters(in: NSRange(location: position, length: 1))
        apply(updatedContent, to: file, version: currentVersion)
    }

    func undo() {
        guard let file = targetFile,
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              position >= 0,
              position <= content.length else {
            return
        }

        let attachment: ImageAttachment
        if let originalAttachment {
            attachment = originalAttachment
        } else if let decodedAttachment = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: ImageAttachment.self,
            from: attachmentData
        ) {
            attachment = decodedAttachment
            originalAttachment = decodedAttachment
        } else {
            return
        }

        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.addAttribute(
            .paragraphStyle,
            value: attachment.paragraphStyle(),
            range: NSRange(location: 0, length: attachmentString.length)
        )
        let updatedContent = NSMutableAttributedString(attributedString: content)
        updatedContent.insert(attachmentString, at: position)
        apply(updatedContent, to: file, version: currentVersion)
    }

    private func apply(_ content: NSAttributedString, to file: TextFile, version: Version) {
        version.attributedContent = content
        file.modifiedDate = Date()
        NotificationCenter.default.post(
            name: NSNotification.Name("UndoRedoContentRestored"),
            object: file,
            userInfo: [
                "content": content,
                "updateEditorInPlace": true,
                "caretPosition": position
            ]
        )
        Task { @MainActor in
            WriteCoalescer.shared?.requestSave(reason: "delete-image-command")
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, position, attachmentData
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(position, forKey: .position)
        try container.encode(attachmentData, forKey: .attachmentData)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        position = try container.decode(Int.self, forKey: .position)
        attachmentData = try container.decode(Data.self, forKey: .attachmentData)
        originalAttachment = nil
        targetFile = nil
    }
}
