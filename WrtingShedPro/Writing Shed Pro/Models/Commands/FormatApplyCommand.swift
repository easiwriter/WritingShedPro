import Foundation

/// Command for applying formatting attributes to a text range
/// Note: This is a placeholder for future rich text formatting support
/// Currently the File model uses plain String content
final class FormatApplyCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The start position of formatting
    let startPosition: Int
    
    /// The end position of formatting
    let endPosition: Int
    
    /// The formatting attributes to apply (stored as key-value pairs)
    let attributes: [String: String]
    
    /// The previous attributes (for undo)
    let previousAttributes: [String: String]?
    
    /// Reference to the target file (weak to prevent retain cycles)
    weak var targetFile: File?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Format",
         startPosition: Int,
         endPosition: Int,
         attributes: [String: String],
         previousAttributes: [String: String]? = nil,
         targetFile: File?) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.attributes = attributes
        self.previousAttributes = previousAttributes
        self.targetFile = targetFile
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        // Placeholder: Will be implemented when AttributedString support is added
        // For now, this is a no-op since File.content is plain String
        print("⚠️ FormatApplyCommand.execute() - Formatting not yet supported with plain String content")
    }
    
    func undo() {
        // Placeholder: Will be implemented when AttributedString support is added
        print("⚠️ FormatApplyCommand.undo() - Formatting not yet supported with plain String content")
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description, startPosition, endPosition, attributes, previousAttributes
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(startPosition, forKey: .startPosition)
        try container.encode(endPosition, forKey: .endPosition)
        try container.encode(attributes, forKey: .attributes)
        try container.encodeIfPresent(previousAttributes, forKey: .previousAttributes)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        startPosition = try container.decode(Int.self, forKey: .startPosition)
        endPosition = try container.decode(Int.self, forKey: .endPosition)
        attributes = try container.decode([String: String].self, forKey: .attributes)
        previousAttributes = try container.decodeIfPresent([String: String].self, forKey: .previousAttributes)
        targetFile = nil // Will be set when restored
    }
}
