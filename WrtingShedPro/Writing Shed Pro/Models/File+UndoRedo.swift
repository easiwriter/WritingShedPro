import Foundation

/// Extension to File model for undo/redo persistence
extension File {
    
    /// Save the current undo manager state to the file
    /// - Parameter undoManager: The undo manager to save
    func saveUndoState(_ undoManager: TextFileUndoManager) {
        do {
            // Flush typing buffer before saving
            undoManager.flushTypingBuffer()
            
            // Convert undo stack to serialized commands
            let undoCommands = try undoManager.undoStack.map { command -> SerializedCommand in
                try SerializedCommand.from(command)
            }
            
            let redoCommands = try undoManager.redoStack.map { command -> SerializedCommand in
                try SerializedCommand.from(command)
            }
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            undoStackData = try encoder.encode(undoCommands)
            redoStackData = try encoder.encode(redoCommands)
            lastUndoSaveDate = Date()
            
            print("✅ Saved undo state: \(undoCommands.count) undo, \(redoCommands.count) redo commands")
        } catch {
            print("❌ Failed to save undo state: \(error)")
        }
    }
    
    /// Restore undo manager from saved state
    /// - Returns: A new undo manager with restored state, or nil if no saved state
    func restoreUndoState() -> TextFileUndoManager? {
        guard let undoData = undoStackData else {
            print("ℹ️ No undo state to restore")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Decode commands
            let undoCommands = try decoder.decode([SerializedCommand].self, from: undoData)
            
            var redoCommands: [SerializedCommand] = []
            if let redoData = redoStackData {
                redoCommands = try decoder.decode([SerializedCommand].self, from: redoData)
            }
            
            // Create undo manager
            let undoManager = TextFileUndoManager(file: self, maxStackSize: undoStackMaxSize)
            
            // Convert serialized commands to actual commands
            let restoredUndoCommands = undoCommands.compactMap { $0.toCommand(file: self) }
            let restoredRedoCommands = redoCommands.compactMap { $0.toCommand(file: self) }
            
            // Restore the stacks
            undoManager.restoreStacks(undoCommands: restoredUndoCommands, redoCommands: restoredRedoCommands)
            
            print("✅ Restored undo state: \(restoredUndoCommands.count) undo, \(restoredRedoCommands.count) redo commands")
            return undoManager
        } catch {
            print("❌ Failed to restore undo state: \(error)")
            // Return fresh undo manager on error
            return nil
        }
    }
    
    /// Clear undo history
    func clearUndoHistory() {
        undoStackData = nil
        redoStackData = nil
        lastUndoSaveDate = nil
        print("✅ Cleared undo history")
    }
}
