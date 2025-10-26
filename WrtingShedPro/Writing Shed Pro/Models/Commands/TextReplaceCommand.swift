import Foundation

/// Command for replacing text in a specific range with new text
final class TextReplaceCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The start position of replacement
    let startPosition: Int
    
    /// The end position of replacement
    let endPosition: Int
    
    /// The original text that was replaced
    let oldText: String
    
    /// The new text that replaces the old
    let newText: String
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: File?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Replace",
         startPosition: Int,
         endPosition: Int,
         oldText: String,
         newText: String,
         targetFile: File?) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.oldText = oldText
        self.newText = newText
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        guard let file = targetFile,
              let content = file.currentVersion?.content,
              startPosition >= 0,
              endPosition <= content.count,
              startPosition < endPosition else {
            return
        }
        
        let startIndex = content.index(content.startIndex, offsetBy: startPosition)
        let endIndex = content.index(content.startIndex, offsetBy: endPosition)
        var newContent = content
        newContent.replaceSubrange(startIndex..<endIndex, with: newText)
        file.currentVersion?.updateContent(newContent)
        file.modifiedDate = Date()
    }
    
    func undo() {
        guard let file = targetFile,
              let content = file.currentVersion?.content,
              startPosition >= 0,
              startPosition + newText.count <= content.count else {
            return
        }
        
        let startIndex = content.index(content.startIndex, offsetBy: startPosition)
        let endIndex = content.index(startIndex, offsetBy: newText.count)
        var newContent = content
        newContent.replaceSubrange(startIndex..<endIndex, with: oldText)
        file.currentVersion?.updateContent(newContent)
        file.modifiedDate = Date()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, startPosition, endPosition, oldText, newText
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(startPosition, forKey: .startPosition)
        try container.encode(endPosition, forKey: .endPosition)
        try container.encode(oldText, forKey: .oldText)
        try container.encode(newText, forKey: .newText)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        startPosition = try container.decode(Int.self, forKey: .startPosition)
        endPosition = try container.decode(Int.self, forKey: .endPosition)
        oldText = try container.decode(String.self, forKey: .oldText)
        newText = try container.decode(String.self, forKey: .newText)
        targetFile = nil // Will be set when restored
    }
}
