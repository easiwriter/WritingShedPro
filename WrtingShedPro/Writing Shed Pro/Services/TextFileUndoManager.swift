import Foundation
import Combine

/// Manages undo/redo operations for a text file
/// Implements the Command pattern with support for typing coalescing and persistence
final class TextFileUndoManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether undo is available
    @Published private(set) var canUndo: Bool = false
    
    /// Whether redo is available
    @Published private(set) var canRedo: Bool = false
    
    /// Description of the action that would be undone
    @Published private(set) var undoActionName: String?
    
    /// Description of the action that would be redone
    @Published private(set) var redoActionName: String?
    
    // MARK: - Private Properties
    
    /// Stack of undoable commands
    private(set) var undoStack: [UndoableCommand] = []
    
    /// Stack of redoable commands
    private(set) var redoStack: [UndoableCommand] = []
    
    /// Maximum number of commands to keep in stack
    private let maxStackSize: Int
    
    /// Reference to the file being edited
    private weak var file: File?
    
    /// Buffer for typing coalescing
    private var typingBuffer: TextInsertCommand?
    
    /// Timer for typing coalescing
    private var typingTimer: Timer?
    
    /// Time interval for grouping typing (default 0.5 seconds)
    private let typingGroupInterval: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    /// Initialize the undo manager for a specific file
    /// - Parameters:
    ///   - file: The file to manage undo/redo for
    ///   - maxStackSize: Maximum number of commands to keep (default 100)
    init(file: File, maxStackSize: Int = 100) {
        self.file = file
        self.maxStackSize = maxStackSize
    }
    
    deinit {
        typingTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Execute a command and add it to the undo stack
    /// - Parameter command: The command to execute
    func execute(_ command: UndoableCommand) {
        // Flush any typing buffer if this isn't another insert command
        if typingBuffer != nil && !(command is TextInsertCommand) {
            flushTypingBuffer()
        }
        
        // For insert commands, try to coalesce with typing buffer
        if let insertCommand = command as? TextInsertCommand {
            handleInsertCommand(insertCommand)
            return
        }
        
        // Execute the command
        command.execute()
        
        // Clear redo stack when new action performed
        redoStack.removeAll()
        
        // Add to undo stack
        undoStack.append(command)
        
        // Trim if exceeds max size
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        updateState()
    }
    
    /// Undo the last command
    func undo() {
        // Flush typing buffer before undoing
        flushTypingBuffer()
        
        guard let command = undoStack.popLast() else { return }
        
        command.undo()
        redoStack.append(command)
        
        updateState()
    }
    
    /// Redo the last undone command
    func redo() {
        guard let command = redoStack.popLast() else { return }
        
        command.execute()
        undoStack.append(command)
        
        updateState()
    }
    
    /// Clear all undo/redo history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        typingBuffer = nil
        typingTimer?.invalidate()
        updateState()
    }
    
    /// Flush typing buffer (force group current typing)
    func flushTypingBuffer() {
        guard let buffer = typingBuffer else { return }
        
        // Execute and add to undo stack
        buffer.execute()
        undoStack.append(buffer)
        
        // Trim if exceeds max size
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        typingBuffer = nil
        typingTimer?.invalidate()
        updateState()
    }
    
    // MARK: - Private Methods
    
    private func handleInsertCommand(_ command: TextInsertCommand) {
        // Check if we can coalesce with existing buffer
        if let buffer = typingBuffer,
           buffer.position + buffer.text.count == command.position,
           buffer.targetFile === command.targetFile {
            // Coalesce: append to existing buffer
            let newText = buffer.text + command.text
            typingBuffer = TextInsertCommand(
                id: buffer.id,
                timestamp: buffer.timestamp,
                description: buffer.description,
                position: buffer.position,
                text: newText,
                targetFile: buffer.targetFile
            )
            
            // Execute the command immediately
            command.execute()
            
            // Reset timer
            startTypingTimer()
        } else {
            // Flush old buffer if exists
            if typingBuffer != nil {
                flushTypingBuffer()
            }
            
            // Start new buffer
            command.execute()
            typingBuffer = command
            
            // Clear redo stack
            redoStack.removeAll()
            
            // Start timer
            startTypingTimer()
        }
        
        updateState()
    }
    
    private func updateState() {
        canUndo = !undoStack.isEmpty || typingBuffer != nil
        canRedo = !redoStack.isEmpty
        undoActionName = typingBuffer?.description ?? undoStack.last?.description
        redoActionName = redoStack.last?.description
    }
    
    private func startTypingTimer() {
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(
            withTimeInterval: typingGroupInterval,
            repeats: false
        ) { [weak self] _ in
            self?.flushTypingBuffer()
        }
    }
}
