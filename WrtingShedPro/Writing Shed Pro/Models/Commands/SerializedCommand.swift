import Foundation

/// Serializable wrapper for persisting commands
struct SerializedCommand: Codable {
    let id: UUID
    let type: CommandType
    let timestamp: Date
    let description: String
    let data: CommandData
    
    enum CommandType: String, Codable {
        case textInsert
        case textDelete
        case textReplace
        case formatApply
        case formatRemove
    }
    
    enum CommandData: Codable {
        case textInsert(position: Int, text: String)
        case textDelete(startPosition: Int, endPosition: Int, deletedText: String)
        case textReplace(startPosition: Int, endPosition: Int, oldText: String, newText: String)
        case formatApply(startPosition: Int, endPosition: Int, attributes: [String: String], previousAttributes: [String: String]?)
        case formatRemove(startPosition: Int, endPosition: Int, attributeKeys: [String], previousAttributes: [String: String])
    }
    
    /// Convert from an UndoableCommand
    static func from(_ command: UndoableCommand) throws -> SerializedCommand {
        let id = command.id
        let timestamp = command.timestamp
        let description = command.description
        
        switch command {
        case let cmd as TextInsertCommand:
            return SerializedCommand(
                id: id,
                type: .textInsert,
                timestamp: timestamp,
                description: description,
                data: .textInsert(position: cmd.position, text: cmd.text)
            )
            
        case let cmd as TextDeleteCommand:
            return SerializedCommand(
                id: id,
                type: .textDelete,
                timestamp: timestamp,
                description: description,
                data: .textDelete(startPosition: cmd.startPosition, endPosition: cmd.endPosition, deletedText: cmd.deletedText)
            )
            
        case let cmd as TextReplaceCommand:
            return SerializedCommand(
                id: id,
                type: .textReplace,
                timestamp: timestamp,
                description: description,
                data: .textReplace(startPosition: cmd.startPosition, endPosition: cmd.endPosition, oldText: cmd.oldText, newText: cmd.newText)
            )
            
        case let cmd as FormatApplyCommand:
            return SerializedCommand(
                id: id,
                type: .formatApply,
                timestamp: timestamp,
                description: description,
                data: .formatApply(startPosition: cmd.startPosition, endPosition: cmd.endPosition, attributes: cmd.attributes, previousAttributes: cmd.previousAttributes)
            )
            
        case let cmd as FormatRemoveCommand:
            return SerializedCommand(
                id: id,
                type: .formatRemove,
                timestamp: timestamp,
                description: description,
                data: .formatRemove(startPosition: cmd.startPosition, endPosition: cmd.endPosition, attributeKeys: cmd.attributeKeys, previousAttributes: cmd.previousAttributes)
            )
            
        default:
            throw SerializationError.unsupportedCommandType
        }
    }
    
    /// Convert to an UndoableCommand
    func toCommand(file: File) -> UndoableCommand? {
        switch data {
        case .textInsert(let position, let text):
            return TextInsertCommand(
                id: id,
                timestamp: timestamp,
                description: description,
                position: position,
                text: text,
                targetFile: file
            )
            
        case .textDelete(let startPosition, let endPosition, let deletedText):
            return TextDeleteCommand(
                id: id,
                timestamp: timestamp,
                description: description,
                startPosition: startPosition,
                endPosition: endPosition,
                deletedText: deletedText,
                targetFile: file
            )
            
        case .textReplace(let startPosition, let endPosition, let oldText, let newText):
            return TextReplaceCommand(
                id: id,
                timestamp: timestamp,
                description: description,
                startPosition: startPosition,
                endPosition: endPosition,
                oldText: oldText,
                newText: newText,
                targetFile: file
            )
            
        case .formatApply(let startPosition, let endPosition, let attributes, let previousAttributes):
            return FormatApplyCommand(
                id: id,
                timestamp: timestamp,
                description: description,
                startPosition: startPosition,
                endPosition: endPosition,
                attributes: attributes,
                previousAttributes: previousAttributes,
                targetFile: file
            )
            
        case .formatRemove(let startPosition, let endPosition, let attributeKeys, let previousAttributes):
            return FormatRemoveCommand(
                id: id,
                timestamp: timestamp,
                description: description,
                startPosition: startPosition,
                endPosition: endPosition,
                attributeKeys: attributeKeys,
                previousAttributes: previousAttributes,
                targetFile: file
            )
        }
    }
    
    enum SerializationError: Error {
        case unsupportedCommandType
    }
}
