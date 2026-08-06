import Foundation
import UIKit

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
    weak var targetFile: TextFile?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Replace",
         startPosition: Int,
         endPosition: Int,
         oldText: String,
         newText: String,
         targetFile: TextFile?) {
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
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              startPosition >= 0,
              endPosition <= content.length,
              startPosition < endPosition else {
            return
        }

        let updatedContent = NSMutableAttributedString(attributedString: content)
        let replacementRange = NSRange(location: startPosition, length: endPosition - startPosition)
        let replacementAttributes: [NSAttributedString.Key: Any]
        if startPosition < updatedContent.length {
            replacementAttributes = updatedContent.attributes(at: startPosition, effectiveRange: nil)
        } else if startPosition > 0 {
            replacementAttributes = updatedContent.attributes(at: startPosition - 1, effectiveRange: nil)
        } else {
            replacementAttributes = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .textStyle: UIFont.TextStyle.body.attributeValue
            ]
        }
        updatedContent.replaceCharacters(in: replacementRange, with: NSAttributedString(string: newText, attributes: replacementAttributes))
        currentVersion.attributedContent = updatedContent
        file.modifiedDate = Date()

        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
    }
    
    func undo() {
        guard let file = targetFile,
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              startPosition >= 0,
              startPosition + (newText as NSString).length <= content.length else {
            return
        }

        let updatedContent = NSMutableAttributedString(attributedString: content)
        let replacementRange = NSRange(location: startPosition, length: (newText as NSString).length)
        let replacementAttributes: [NSAttributedString.Key: Any]
        if startPosition < updatedContent.length {
            replacementAttributes = updatedContent.attributes(at: startPosition, effectiveRange: nil)
        } else if startPosition > 0 {
            replacementAttributes = updatedContent.attributes(at: startPosition - 1, effectiveRange: nil)
        } else {
            replacementAttributes = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .textStyle: UIFont.TextStyle.body.attributeValue
            ]
        }
        updatedContent.replaceCharacters(in: replacementRange, with: NSAttributedString(string: oldText, attributes: replacementAttributes))
        currentVersion.attributedContent = updatedContent
        file.modifiedDate = Date()

        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
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
