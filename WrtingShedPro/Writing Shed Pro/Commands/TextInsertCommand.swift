import Foundation
import UIKit

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
    weak var targetFile: TextFile?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(), 
         timestamp: Date = Date(), 
         description: String = "Typing",
         position: Int, 
         text: String, 
         targetFile: TextFile?) {
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
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              position >= 0,
              position <= content.length else {
            return
        }

        let updatedContent = NSMutableAttributedString(attributedString: content)
        let insertionAttributes: [NSAttributedString.Key: Any]
        if position > 0 {
            insertionAttributes = updatedContent.attributes(at: position - 1, effectiveRange: nil)
        } else if updatedContent.length > 0 {
            insertionAttributes = updatedContent.attributes(at: 0, effectiveRange: nil)
        } else {
            insertionAttributes = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .textStyle: UIFont.TextStyle.body.attributeValue
            ]
        }
        updatedContent.insert(NSAttributedString(string: text, attributes: insertionAttributes), at: position)

        currentVersion.attributedContent = updatedContent
        currentVersion.updateContent(updatedContent.string)
        file.modifiedDate = Date()

        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
        NotificationCenter.default.post(
            name: NSNotification.Name("UndoRedoContentRestored"),
            object: file,
            userInfo: ["content": updatedContent]
        )
    }
    
    func undo() {
        guard let file = targetFile,
              let currentVersion = file.currentVersion,
              let content = currentVersion.attributedContent,
              position >= 0,
              position + (text as NSString).length <= content.length else {
            return
        }

        let updatedContent = NSMutableAttributedString(attributedString: content)
        updatedContent.deleteCharacters(in: NSRange(location: position, length: (text as NSString).length))

        currentVersion.attributedContent = updatedContent
        currentVersion.updateContent(updatedContent.string)
        file.modifiedDate = Date()

        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
        NotificationCenter.default.post(
            name: NSNotification.Name("UndoRedoContentRestored"),
            object: file,
            userInfo: ["content": updatedContent]
        )
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
