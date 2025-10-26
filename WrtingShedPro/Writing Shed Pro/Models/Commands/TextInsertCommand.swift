import Foundation

/// Command for inserting text at a specific position
final class TextInsertCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The position where text should be inserted
    let position: Int
    
    /// The text to insert
    let text: String
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: File?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(), 
         timestamp: Date = Date(), 
         description: String = "Typing",
         position: Int, 
         text: String, 
         targetFile: File?) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.position = position
        self.text = text
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        guard let file = targetFile,
              let content = file.content,
              position >= 0,
              position <= content.count else {
            return
        }
        
        let index = content.index(content.startIndex, offsetBy: position)
        var newContent = content
        newContent.insert(contentsOf: text, at: index)
        file.content = newContent
        file.modifiedDate = Date()
    }
    
    func undo() {
        guard let file = targetFile,
              let content = file.content,
              position >= 0,
              position + text.count <= content.count else {
            return
        }
        
        let startIndex = content.index(content.startIndex, offsetBy: position)
        let endIndex = content.index(startIndex, offsetBy: text.count)
        var newContent = content
        newContent.removeSubrange(startIndex..<endIndex)
        file.content = newContent
        file.modifiedDate = Date()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, position, text
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(position, forKey: .position)
        try container.encode(text, forKey: .text)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        position = try container.decode(Int.self, forKey: .position)
        text = try container.decode(String.self, forKey: .text)
        targetFile = nil // Will be set when restored
    }
}
