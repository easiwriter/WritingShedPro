import Foundation

/// Command for deleting text in a specific range
final class TextDeleteCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The start position of deletion
    let startPosition: Int
    
    /// The end position of deletion
    let endPosition: Int
    
    /// The text that was deleted (stored for undo)
    let deletedText: String
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: File?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Deletion",
         startPosition: Int,
         endPosition: Int,
         deletedText: String,
         targetFile: File?) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.deletedText = deletedText
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        guard let file = targetFile,
              let content = file.content,
              startPosition >= 0,
              endPosition <= content.count,
              startPosition < endPosition else {
            return
        }
        
        let startIndex = content.index(content.startIndex, offsetBy: startPosition)
        let endIndex = content.index(content.startIndex, offsetBy: endPosition)
        var newContent = content
        newContent.removeSubrange(startIndex..<endIndex)
        file.content = newContent
        file.modifiedDate = Date()
    }
    
    func undo() {
        guard let file = targetFile,
              let content = file.content,
              startPosition >= 0,
              startPosition <= content.count else {
            return
        }
        
        let index = content.index(content.startIndex, offsetBy: startPosition)
        var newContent = content
        newContent.insert(contentsOf: deletedText, at: index)
        file.content = newContent
        file.modifiedDate = Date()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, startPosition, endPosition, deletedText
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(startPosition, forKey: .startPosition)
        try container.encode(endPosition, forKey: .endPosition)
        try container.encode(deletedText, forKey: .deletedText)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        startPosition = try container.decode(Int.self, forKey: .startPosition)
        endPosition = try container.decode(Int.self, forKey: .endPosition)
        deletedText = try container.decode(String.self, forKey: .deletedText)
        targetFile = nil // Will be set when restored
    }
}
