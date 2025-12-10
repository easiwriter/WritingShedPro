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
    let oldCaptionText: String?
    let oldCaptionStyle: String?
    
    /// New image properties (for redo)
    let newScale: CGFloat
    let newAlignment: ImageAttachment.ImageAlignment
    let newHasCaption: Bool
    let newCaptionText: String
    let newCaptionStyle: String
    
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
         oldCaptionText: String?,
         oldCaptionStyle: String?,
         newScale: CGFloat,
         newAlignment: ImageAttachment.ImageAlignment,
         newHasCaption: Bool,
         newCaptionText: String,
         newCaptionStyle: String,
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
        self.oldCaptionText = oldCaptionText
        self.oldCaptionStyle = oldCaptionStyle
        self.newScale = newScale
        self.newAlignment = newAlignment
        self.newHasCaption = newHasCaption
        self.newCaptionText = newCaptionText
        self.newCaptionStyle = newCaptionStyle
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        // The image update has already been applied in the UI
        // This is called when the command is first executed
        // Update the file's attributed content
        guard let file = targetFile else {
            print("⚠️ ImageUpdateCommand.execute() - targetFile is nil")
            return
        }
        
        file.currentVersion?.attributedContent = afterContent
        
        // Update attachment properties to new state
        attachment?.scale = newScale
        attachment?.alignment = newAlignment
        attachment?.updateCaption(hasCaption: newHasCaption, text: newCaptionText, style: newCaptionStyle)
        
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
            print("⚠️ ImageUpdateCommand.undo() - targetFile is nil")
            return
        }
        
        file.currentVersion?.attributedContent = beforeContent
        
        // Restore old attachment properties
        attachment?.scale = oldScale
        attachment?.alignment = oldAlignment
        attachment?.updateCaption(hasCaption: oldHasCaption, text: oldCaptionText, style: oldCaptionStyle)
        
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
        case oldScale, oldAlignment, oldHasCaption, oldCaptionText, oldCaptionStyle
        case newScale, newAlignment, newHasCaption, newCaptionText, newCaptionStyle
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
        self.oldCaptionText = try container.decodeIfPresent(String.self, forKey: .oldCaptionText)
        self.oldCaptionStyle = try container.decodeIfPresent(String.self, forKey: .oldCaptionStyle)
        
        // Decode new properties
        self.newScale = try container.decode(CGFloat.self, forKey: .newScale)
        let newAlignmentRaw = try container.decode(String.self, forKey: .newAlignment)
        self.newAlignment = ImageAttachment.ImageAlignment(rawValue: newAlignmentRaw) ?? .center
        self.newHasCaption = try container.decode(Bool.self, forKey: .newHasCaption)
        self.newCaptionText = try container.decode(String.self, forKey: .newCaptionText)
        self.newCaptionStyle = try container.decode(String.self, forKey: .newCaptionStyle)
        
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
        try container.encodeIfPresent(oldCaptionText, forKey: .oldCaptionText)
        try container.encodeIfPresent(oldCaptionStyle, forKey: .oldCaptionStyle)
        try container.encode(newScale, forKey: .newScale)
        try container.encode(newAlignment.rawValue, forKey: .newAlignment)
        try container.encode(newHasCaption, forKey: .newHasCaption)
        try container.encode(newCaptionText, forKey: .newCaptionText)
        try container.encode(newCaptionStyle, forKey: .newCaptionStyle)
    }
}
