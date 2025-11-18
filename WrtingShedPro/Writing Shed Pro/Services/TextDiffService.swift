import Foundation

/// Service for computing differences between two strings
/// Uses a simplified diff algorithm to detect insertions, deletions, and replacements
struct TextDiffService {
    
    /// Represents a change between two strings
    enum Change {
        case insert(position: Int, text: String)
        case delete(startPosition: Int, endPosition: Int, deletedText: String)
        case replace(startPosition: Int, endPosition: Int, oldText: String, newText: String)
    }
    
    /// Compute the difference between two strings
    /// - Parameters:
    ///   - old: The original string
    ///   - new: The modified string
    /// - Returns: The type of change that occurred
    static func diff(from old: String, to new: String) -> Change? {
        // Handle empty strings
        if old.isEmpty && new.isEmpty {
            return nil
        }
        
        if old.isEmpty {
            return .insert(position: 0, text: new)
        }
        
        if new.isEmpty {
            return .delete(startPosition: 0, endPosition: old.count, deletedText: old)
        }
        
        // Find common prefix
        let commonPrefixLength = findCommonPrefixLength(old, new)
        
        // Find common suffix (after the prefix)
        let oldSuffix = String(old.dropFirst(commonPrefixLength))
        let newSuffix = String(new.dropFirst(commonPrefixLength))
        let commonSuffixLength = findCommonSuffixLength(oldSuffix, newSuffix)
        
        // Extract the differing parts
        let oldDiffStart = commonPrefixLength
        let oldDiffEnd = old.count - commonSuffixLength
        let newDiffStart = commonPrefixLength
        let newDiffEnd = new.count - commonSuffixLength
        
        let oldDiff = String(old[old.index(old.startIndex, offsetBy: oldDiffStart)..<old.index(old.startIndex, offsetBy: oldDiffEnd)])
        let newDiff = String(new[new.index(new.startIndex, offsetBy: newDiffStart)..<new.index(new.startIndex, offsetBy: newDiffEnd)])
        
        // Determine change type
        if oldDiff.isEmpty && !newDiff.isEmpty {
            // Insertion
            return .insert(position: newDiffStart, text: newDiff)
        } else if !oldDiff.isEmpty && newDiff.isEmpty {
            // Deletion
            return .delete(startPosition: oldDiffStart, endPosition: oldDiffEnd, deletedText: oldDiff)
        } else if !oldDiff.isEmpty && !newDiff.isEmpty {
            // Replacement
            return .replace(startPosition: oldDiffStart, endPosition: oldDiffEnd, oldText: oldDiff, newText: newDiff)
        }
        
        return nil
    }
    
    /// Convert a change into an undoable command
    /// - Parameters:
    ///   - change: The change to convert
    ///   - file: The target file
    /// - Returns: An undoable command representing the change
    static func createCommand(from change: Change, file: TextFile) -> UndoableCommand {
        switch change {
        case .insert(let position, let text):
            return TextInsertCommand(
                position: position,
                text: text,
                targetFile: file
            )
            
        case .delete(let startPosition, let endPosition, let deletedText):
            return TextDeleteCommand(
                startPosition: startPosition,
                endPosition: endPosition,
                deletedText: deletedText,
                targetFile: file
            )
            
        case .replace(let startPosition, let endPosition, let oldText, let newText):
            return TextReplaceCommand(
                startPosition: startPosition,
                endPosition: endPosition,
                oldText: oldText,
                newText: newText,
                targetFile: file
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private static func findCommonPrefixLength(_ s1: String, _ s2: String) -> Int {
        var length = 0
        let minLength = min(s1.count, s2.count)
        
        for (c1, c2) in zip(s1, s2) {
            if c1 == c2 {
                length += 1
            } else {
                break
            }
            
            if length >= minLength {
                break
            }
        }
        
        return length
    }
    
    private static func findCommonSuffixLength(_ s1: String, _ s2: String) -> Int {
        var length = 0
        let minLength = min(s1.count, s2.count)
        
        for (c1, c2) in zip(s1.reversed(), s2.reversed()) {
            if c1 == c2 {
                length += 1
            } else {
                break
            }
            
            if length >= minLength {
                break
            }
        }
        
        return length
    }
}
