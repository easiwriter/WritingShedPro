import Foundation

/// Protocol for all undoable commands in the text editing system
/// Commands encapsulate actions that can be executed and reversed
protocol UndoableCommand: AnyObject, Codable {
    /// Unique identifier for the command
    var id: UUID { get }
    
    /// When the command was created
    var timestamp: Date { get }
    
    /// Human-readable description of the action (e.g., "Typing", "Delete")
    var description: String { get }
    
    /// Execute the command (perform the action)
    func execute()
    
    /// Reverse the command (undo the action)
    func undo()
}

// MARK: - Coding Keys

/// Common coding keys for all commands
enum UndoableCommandCodingKeys: String, CodingKey {
    case id
    case timestamp
    case description
    case commandType
}
