import Foundation

/// Command for applying/toggling formatting attributes to a text range
/// Supports bold, italic, underline, and strikethrough formatting with undo/redo
final class FormatApplyCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The range where formatting was applied
    let range: NSRange
    
    /// The attributed string before formatting was applied
    let beforeContent: NSAttributedString
    
    /// The attributed string after formatting was applied
    let afterContent: NSAttributedString
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: TextFile?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String,
         range: NSRange,
         beforeContent: NSAttributedString,
         afterContent: NSAttributedString,
         targetFile: TextFile?) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.range = range
        self.beforeContent = beforeContent
        self.afterContent = afterContent
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        // The formatting has already been applied in the UI
        // This is called when the command is first executed
        // Update the file's attributed content
        targetFile?.currentVersion?.attributedContent = afterContent
        
        #if DEBUG
        print("✅ FormatApplyCommand.execute() - Applied formatting: \(description)")
        #endif
    }
    
    func undo() {
        // Restore the previous attributed content
        guard let file = targetFile else {
            print("⚠️ FormatApplyCommand.undo() - targetFile is nil")
            return
        }
        
        file.currentVersion?.attributedContent = beforeContent
        
        #if DEBUG
        print("↩️ FormatApplyCommand.undo() - Reverted formatting: \(description)")
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
        case id, timestamp, description, range
        case beforeContentData, beforeContentText
        case afterContentData, afterContentText
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        
        // Encode range as location and length
        let rangeDict = ["location": range.location, "length": range.length]
        try container.encode(rangeDict, forKey: .range)
        
        // Encode attributed strings with both data and text
        let beforeData = AttributedStringSerializer.encode(beforeContent)
        try container.encode(beforeData, forKey: .beforeContentData)
        try container.encode(beforeContent.string, forKey: .beforeContentText)
        
        let afterData = AttributedStringSerializer.encode(afterContent)
        try container.encode(afterData, forKey: .afterContentData)
        try container.encode(afterContent.string, forKey: .afterContentText)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        
        // Decode range
        let rangeDict = try container.decode([String: Int].self, forKey: .range)
        let location = rangeDict["location"] ?? 0
        let length = rangeDict["length"] ?? 0
        range = NSRange(location: location, length: length)
        
        // Decode attributed strings
        let beforeData = try container.decode(Data.self, forKey: .beforeContentData)
        let beforeText = try container.decode(String.self, forKey: .beforeContentText)
        beforeContent = AttributedStringSerializer.decode(beforeData, text: beforeText)
        
        let afterData = try container.decode(Data.self, forKey: .afterContentData)
        let afterText = try container.decode(String.self, forKey: .afterContentText)
        afterContent = AttributedStringSerializer.decode(afterData, text: afterText)
        
        targetFile = nil // Will be set when restored
    }
}
