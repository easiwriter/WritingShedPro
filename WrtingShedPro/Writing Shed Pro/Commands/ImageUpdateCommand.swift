import Foundation

/// Command for updating image properties (scale, alignment, caption, etc.)
/// Supports undo/redo for image modifications
final class ImageUpdateCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The attributed string before the image was updated
    let beforeContent: NSAttributedString
    
    /// The attributed string after the image was updated
    let afterContent: NSAttributedString
    
    /// Reference to the image attachment being updated
    weak var attachment: ImageAttachment?
    
    /// Old image properties (for undo)
    let oldScale: CGFloat
    let oldAlignment: ImageAttachment.ImageAlignment
    let oldHasCaption: Bool
    let oldCaptionPrefix: String?
    let oldCaptionText: String?
    let oldCaptionStyle: String?
    let oldImageStyleName: String
    let oldSpacingAbove: CGFloat
    let oldSpacingBelow: CGFloat
    let oldBorderStyle: ImageAttachment.BorderStyle
    let oldBorderPadding: CGFloat
    
    /// New image properties (for redo)
    let newScale: CGFloat
    let newAlignment: ImageAttachment.ImageAlignment
    let newHasCaption: Bool
    let newCaptionPrefix: String
    let newCaptionText: String
    let newCaptionStyle: String
    let newImageStyleName: String
    let newSpacingAbove: CGFloat
    let newSpacingBelow: CGFloat
    let newBorderStyle: ImageAttachment.BorderStyle
    let newBorderPadding: CGFloat
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: TextFile?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String,
         beforeContent: NSAttributedString,
         afterContent: NSAttributedString,
         attachment: ImageAttachment?,
         oldScale: CGFloat,
         oldAlignment: ImageAttachment.ImageAlignment,
         oldHasCaption: Bool,
         oldCaptionPrefix: String?,
         oldCaptionText: String?,
         oldCaptionStyle: String?,
         oldImageStyleName: String,
         oldSpacingAbove: CGFloat,
         oldSpacingBelow: CGFloat,
         oldBorderStyle: ImageAttachment.BorderStyle,
         oldBorderPadding: CGFloat,
         newScale: CGFloat,
         newAlignment: ImageAttachment.ImageAlignment,
         newHasCaption: Bool,
         newCaptionPrefix: String,
         newCaptionText: String,
         newCaptionStyle: String,
         newImageStyleName: String,
         newSpacingAbove: CGFloat,
         newSpacingBelow: CGFloat,
         newBorderStyle: ImageAttachment.BorderStyle,
         newBorderPadding: CGFloat,
         targetFile: TextFile?) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.beforeContent = beforeContent
        self.afterContent = afterContent
        self.attachment = attachment
        self.oldScale = oldScale
        self.oldAlignment = oldAlignment
        self.oldHasCaption = oldHasCaption
        self.oldCaptionPrefix = oldCaptionPrefix
        self.oldCaptionText = oldCaptionText
        self.oldCaptionStyle = oldCaptionStyle
        self.oldImageStyleName = oldImageStyleName
        self.oldSpacingAbove = oldSpacingAbove
        self.oldSpacingBelow = oldSpacingBelow
        self.oldBorderStyle = oldBorderStyle
        self.oldBorderPadding = oldBorderPadding
        self.newScale = newScale
        self.newAlignment = newAlignment
        self.newHasCaption = newHasCaption
        self.newCaptionPrefix = newCaptionPrefix
        self.newCaptionText = newCaptionText
        self.newCaptionStyle = newCaptionStyle
        self.newImageStyleName = newImageStyleName
        self.newSpacingAbove = newSpacingAbove
        self.newSpacingBelow = newSpacingBelow
        self.newBorderStyle = newBorderStyle
        self.newBorderPadding = newBorderPadding
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        // The image update has already been applied in the UI
        // This is called when the command is first executed
        // Update the file's attributed content
        guard let file = targetFile else {
            #if DEBUG
            print("⚠️ ImageUpdateCommand.execute() - targetFile is nil")
            #endif
            return
        }
        
        file.currentVersion?.attributedContent = afterContent
        
        // Update attachment properties to new state
        attachment?.scale = newScale
        attachment?.alignment = newAlignment
        attachment?.imageStyleName = newImageStyleName
        attachment?.spacingAbove = newSpacingAbove
        attachment?.spacingBelow = newSpacingBelow
        attachment?.borderStyle = newBorderStyle
        attachment?.borderPadding = newBorderPadding
        attachment?.updateCaption(hasCaption: newHasCaption, prefix: newCaptionPrefix, text: newCaptionText, style: newCaptionStyle)
        
        #if DEBUG
        print("✅ ImageUpdateCommand.execute() - Applied image update: \(description)")
        #endif
        
        // Post notification that content was restored (FileEditView will listen)
        NotificationCenter.default.post(
            name: NSNotification.Name("UndoRedoContentRestored"),
            object: file,
            userInfo: ["content": afterContent]
        )
    }
    
    func undo() {
        // Restore the previous attributed content and image properties
        guard let file = targetFile else {
            #if DEBUG
            print("⚠️ ImageUpdateCommand.undo() - targetFile is nil")
            #endif
            return
        }
        
        file.currentVersion?.attributedContent = beforeContent
        
        // Restore old attachment properties
        attachment?.scale = oldScale
        attachment?.alignment = oldAlignment
        attachment?.imageStyleName = oldImageStyleName
        attachment?.spacingAbove = oldSpacingAbove
        attachment?.spacingBelow = oldSpacingBelow
        attachment?.borderStyle = oldBorderStyle
        attachment?.borderPadding = oldBorderPadding
        attachment?.updateCaption(hasCaption: oldHasCaption, prefix: oldCaptionPrefix, text: oldCaptionText, style: oldCaptionStyle)
        
        #if DEBUG
        print("↩️ ImageUpdateCommand.undo() - Reverted image update: \(description)")
        #endif
        
        // Post notification that content was restored (FileEditView will listen)
        NotificationCenter.default.post(
            name: NSNotification.Name("UndoRedoContentRestored"),
            object: file,
            userInfo: ["content": beforeContent]
        )
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description
        case beforeContentData, beforeContentText
        case afterContentData, afterContentText
        case oldScale, oldAlignment, oldHasCaption, oldCaptionPrefix, oldCaptionText, oldCaptionStyle, oldImageStyleName, oldSpacingAbove, oldSpacingBelow, oldBorderStyle, oldBorderPadding
        case newScale, newAlignment, newHasCaption, newCaptionPrefix, newCaptionText, newCaptionStyle, newImageStyleName, newSpacingAbove, newSpacingBelow, newBorderStyle, newBorderPadding
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.description = try container.decode(String.self, forKey: .description)
        
        // Decode attributed strings
        let beforeText = try container.decode(String.self, forKey: .beforeContentText)
        self.beforeContent = NSAttributedString(string: beforeText)
        
        let afterText = try container.decode(String.self, forKey: .afterContentText)
        self.afterContent = NSAttributedString(string: afterText)
        
        // Decode old properties
        self.oldScale = try container.decode(CGFloat.self, forKey: .oldScale)
        let oldAlignmentRaw = try container.decode(String.self, forKey: .oldAlignment)
        self.oldAlignment = ImageAttachment.ImageAlignment(rawValue: oldAlignmentRaw) ?? .center
        self.oldHasCaption = try container.decode(Bool.self, forKey: .oldHasCaption)
        self.oldCaptionPrefix = try container.decodeIfPresent(String.self, forKey: .oldCaptionPrefix)
        self.oldCaptionText = try container.decodeIfPresent(String.self, forKey: .oldCaptionText)
        self.oldCaptionStyle = try container.decodeIfPresent(String.self, forKey: .oldCaptionStyle)
        self.oldImageStyleName = try container.decodeIfPresent(String.self, forKey: .oldImageStyleName) ?? "default"
        self.oldSpacingAbove = try container.decodeIfPresent(CGFloat.self, forKey: .oldSpacingAbove) ?? 0
        self.oldSpacingBelow = try container.decodeIfPresent(CGFloat.self, forKey: .oldSpacingBelow) ?? 0
        let oldBorderStyleRaw = try container.decodeIfPresent(String.self, forKey: .oldBorderStyle) ?? "none"
        self.oldBorderStyle = ImageAttachment.BorderStyle(rawValue: oldBorderStyleRaw) ?? .none
        self.oldBorderPadding = max(0, try container.decodeIfPresent(CGFloat.self, forKey: .oldBorderPadding) ?? 0)
        
        // Decode new properties
        self.newScale = try container.decode(CGFloat.self, forKey: .newScale)
        let newAlignmentRaw = try container.decode(String.self, forKey: .newAlignment)
        self.newAlignment = ImageAttachment.ImageAlignment(rawValue: newAlignmentRaw) ?? .center
        self.newHasCaption = try container.decode(Bool.self, forKey: .newHasCaption)
        self.newCaptionPrefix = try container.decodeIfPresent(String.self, forKey: .newCaptionPrefix) ?? "Figure"
        self.newCaptionText = try container.decode(String.self, forKey: .newCaptionText)
        self.newCaptionStyle = try container.decode(String.self, forKey: .newCaptionStyle)
        self.newImageStyleName = try container.decodeIfPresent(String.self, forKey: .newImageStyleName) ?? "default"
        self.newSpacingAbove = try container.decodeIfPresent(CGFloat.self, forKey: .newSpacingAbove) ?? 0
        self.newSpacingBelow = try container.decodeIfPresent(CGFloat.self, forKey: .newSpacingBelow) ?? 0
        let newBorderStyleRaw = try container.decodeIfPresent(String.self, forKey: .newBorderStyle) ?? "none"
        self.newBorderStyle = ImageAttachment.BorderStyle(rawValue: newBorderStyleRaw) ?? .none
        self.newBorderPadding = max(0, try container.decodeIfPresent(CGFloat.self, forKey: .newBorderPadding) ?? 0)
        
        self.attachment = nil
        self.targetFile = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(beforeContent.string, forKey: .beforeContentText)
        try container.encode(afterContent.string, forKey: .afterContentText)
        try container.encode(oldScale, forKey: .oldScale)
        try container.encode(oldAlignment.rawValue, forKey: .oldAlignment)
        try container.encode(oldHasCaption, forKey: .oldHasCaption)
        try container.encodeIfPresent(oldCaptionPrefix, forKey: .oldCaptionPrefix)
        try container.encodeIfPresent(oldCaptionText, forKey: .oldCaptionText)
        try container.encodeIfPresent(oldCaptionStyle, forKey: .oldCaptionStyle)
        try container.encode(oldImageStyleName, forKey: .oldImageStyleName)
        try container.encode(oldSpacingAbove, forKey: .oldSpacingAbove)
        try container.encode(oldSpacingBelow, forKey: .oldSpacingBelow)
        try container.encode(oldBorderStyle.rawValue, forKey: .oldBorderStyle)
        try container.encode(oldBorderPadding, forKey: .oldBorderPadding)
        try container.encode(newScale, forKey: .newScale)
        try container.encode(newAlignment.rawValue, forKey: .newAlignment)
        try container.encode(newHasCaption, forKey: .newHasCaption)
        try container.encode(newCaptionPrefix, forKey: .newCaptionPrefix)
        try container.encode(newCaptionText, forKey: .newCaptionText)
        try container.encode(newCaptionStyle, forKey: .newCaptionStyle)
        try container.encode(newImageStyleName, forKey: .newImageStyleName)
        try container.encode(newSpacingAbove, forKey: .newSpacingAbove)
        try container.encode(newSpacingBelow, forKey: .newSpacingBelow)
        try container.encode(newBorderStyle.rawValue, forKey: .newBorderStyle)
        try container.encode(newBorderPadding, forKey: .newBorderPadding)
    }
}
