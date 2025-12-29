import Foundation

/// Command for removing formatting attributes from a text range
/// Note: This is a placeholder for future rich text formatting support
/// Currently the File model uses plain String content
final class FormatRemoveCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The start position where formatting should be removed
    let startPosition: Int
    
    /// The end position where formatting should be removed
    let endPosition: Int
    
    /// The attribute keys to remove
    let attributeKeys: [String]
    
    /// The previous attributes (for undo)
    let previousAttributes: [String: String]
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: TextFile?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Remove Format",
         startPosition: Int,
         endPosition: Int,
         attributeKeys: [String],
         previousAttributes: [String: String],
         targetFile: TextFile?) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.attributeKeys = attributeKeys
        self.previousAttributes = previousAttributes
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        // Placeholder: Will be implemented when AttributedString support is added
        // For now, this is a no-op since File.content is plain String
        #if DEBUG
        print("⚠️ FormatRemoveCommand.execute() - Formatting not yet supported with plain String content")
        #endif
    }
    
    func undo() {
        // Placeholder: Will be implemented when AttributedString support is added
        #if DEBUG
        print("⚠️ FormatRemoveCommand.undo() - Formatting not yet supported with plain String content")
        #endif
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, startPosition, endPosition, attributeKeys, previousAttributes
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(startPosition, forKey: .startPosition)
        try container.encode(endPosition, forKey: .endPosition)
        try container.encode(attributeKeys, forKey: .attributeKeys)
        try container.encode(previousAttributes, forKey: .previousAttributes)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        startPosition = try container.decode(Int.self, forKey: .startPosition)
        endPosition = try container.decode(Int.self, forKey: .endPosition)
        attributeKeys = try container.decode([String].self, forKey: .attributeKeys)
        previousAttributes = try container.decode([String: String].self, forKey: .previousAttributes)
        targetFile = nil // Will be set when restored
    }
}
