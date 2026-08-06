import Foundation
import UIKit

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
    weak var targetFile: TextFile?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Deletion",
         startPosition: Int,
         endPosition: Int,
         deletedText: String,
         targetFile: TextFile?) {
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
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              startPosition >= 0,
              endPosition <= content.length,
              startPosition < endPosition else {
            return
        }

        let updatedContent = NSMutableAttributedString(attributedString: content)
        updatedContent.deleteCharacters(in: NSRange(location: startPosition, length: endPosition - startPosition))
        currentVersion.attributedContent = updatedContent
        file.modifiedDate = Date()

        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
    }
    
    func undo() {
        guard let file = targetFile,
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              startPosition >= 0,
              startPosition <= content.length else {
            return
        }

        let updatedContent = NSMutableAttributedString(attributedString: content)
        let insertionAttributes: [NSAttributedString.Key: Any]
        if startPosition > 0, startPosition <= updatedContent.length {
            insertionAttributes = updatedContent.attributes(at: startPosition - 1, effectiveRange: nil)
        } else if updatedContent.length > 0 {
            insertionAttributes = updatedContent.attributes(at: 0, effectiveRange: nil)
        } else {
            insertionAttributes = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .textStyle: UIFont.TextStyle.body.attributeValue
            ]
        }
        updatedContent.insert(NSAttributedString(string: deletedText, attributes: insertionAttributes), at: startPosition)
        currentVersion.attributedContent = updatedContent
        file.modifiedDate = Date()

        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
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
