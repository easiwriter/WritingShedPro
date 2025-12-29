import Foundation

/// Extension to TextFile model for undo/redo persistence
extension TextFile {
    
    /// Save the current undo manager state to the file
    /// - Parameter undoManager: The undo manager to save
    func saveUndoState(_ undoManager: TextFileUndoManager) {
        do {
            // Flush typing buffer before saving
            undoManager.flushTypingBuffer()
            
            // PERFORMANCE FIX: Filter out "Typing" commands before saving
            // FormatApplyCommand for typing stores the ENTIRE document twice per keystroke,
            // which can create massive undo stacks (100 commands × 2 full documents).
            // Deserializing this on load causes beachball/hang.
            // Only persist meaningful formatting commands, not per-keystroke snapshots.
            let commandsToSave = undoManager.undoStack.filter { command in
                // Skip FormatApplyCommand with "Typing" description
                if let formatCmd = command as? FormatApplyCommand,
                   formatCmd.description == "Typing" {
                    return false
                }
                // Skip TextInsertCommand (these are lightweight but typing-related)
                if command is TextInsertCommand {
                    return false
                }
                return true
            }
            
            // Convert filtered commands to serialized format
            let undoCommands = try commandsToSave.map { command -> SerializedCommand in
                try SerializedCommand.from(command)
            }
            
            // Note: We intentionally do NOT save the redo stack
            // Redo commands are only valid during an active editing session
            // When reopening a file, we start fresh with no redo history
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            undoStackData = try encoder.encode(undoCommands)
            redoStackData = nil // Clear redo stack on save
            lastUndoSaveDate = Date()
            
            // print("✅ Saved undo state: \(undoCommands.count) undo commands (redo stack not saved)")
        } catch {
            // print("❌ Failed to save undo state: \(error)")
        }
    }
    
    /// Restore undo manager from saved state
    /// - Returns: A new undo manager with restored state, or nil if no saved state
    func restoreUndoState() -> TextFileUndoManager? {
        guard let undoData = undoStackData else {
            // print("ℹ️ No undo state to restore")
            return nil
        }
        
        // PERFORMANCE FIX: If undo data is too large (likely old format with full document snapshots),
        // skip loading it to prevent beachball/hang. Clear the problematic data.
        // 1MB is a reasonable limit - normal undo commands should be much smaller
        let maxUndoDataSize = 1024 * 1024 // 1MB
        if undoData.count > maxUndoDataSize {
            #if DEBUG
            print("⚠️ Undo data too large (\(undoData.count) bytes) - clearing to prevent hang")
            #endif
            clearUndoHistory()
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Decode undo commands only (redo stack is never saved/restored)
            let undoCommands = try decoder.decode([SerializedCommand].self, from: undoData)
            
            // Create undo manager
            let undoManager = TextFileUndoManager(file: self, maxStackSize: undoStackMaxSize)
            
            // Convert serialized commands to actual commands
            let restoredUndoCommands = undoCommands.compactMap { $0.toCommand(file: self) }
            
            // Restore only the undo stack (redo stack starts empty)
            undoManager.restoreStacks(undoCommands: restoredUndoCommands, redoCommands: [])
            
            // print("✅ Restored undo state: \(restoredUndoCommands.count) undo commands, 0 redo commands")
            return undoManager
        } catch {
            // print("❌ Failed to restore undo state: \(error)")
            // Return nil on error so a fresh manager is created
            return nil
        }
    }
    
    /// Clear undo history
    func clearUndoHistory() {
        undoStackData = nil
        redoStackData = nil
        lastUndoSaveDate = nil
        // print("✅ Cleared undo history")
    }
}
