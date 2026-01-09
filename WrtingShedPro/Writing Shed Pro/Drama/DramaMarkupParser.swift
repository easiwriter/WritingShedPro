//
//  DramaMarkupParser.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Parser for Drama Markup Language (DML) - converts raw text to structured elements
//

import Foundation

/// Parser for Drama Markup Language (DML)
/// Converts raw DML source text into a structured DMLDocument
final class DramaMarkupParser {
    
    // MARK: - Singleton
    
    static let shared = DramaMarkupParser()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Parse DML source text into a structured document
    /// - Parameter source: The raw DML text
    /// - Returns: A parsed DMLDocument with all elements
    func parse(_ source: String) -> DMLDocument {
        let lines = source.components(separatedBy: .newlines)
        var elements: [DMLElement] = []
        var pendingCharacter: DMLElement?
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for each element type
            if let element = parseElement(line: line, trimmed: trimmed, lineNumber: lineNumber, pendingCharacter: &pendingCharacter) {
                elements.append(element)
            }
        }
        
        return DMLDocument(elements: elements, sourceText: source)
    }
    
    /// Convert a DMLDocument back to source text
    /// - Parameter document: The parsed document
    /// - Returns: DML source text
    func toSource(_ document: DMLDocument) -> String {
        return document.sourceText
    }
    
    // MARK: - Private Parsing
    
    private func parseElement(line: String, trimmed: String, lineNumber: Int, pendingCharacter: inout DMLElement?) -> DMLElement? {
        
        // Empty line
        if trimmed.isEmpty {
            // If we had a pending character with no dialogue, add it anyway
            if let char = pendingCharacter {
                pendingCharacter = nil
                return char
            }
            return DMLElement(type: .blank, content: "", rawLine: line, lineNumber: lineNumber)
        }
        
        // Check for escaped prefixes (e.g., \# for literal #)
        let effectiveTrimmed: String
        let isEscaped = trimmed.hasPrefix("\\")
        if isEscaped {
            effectiveTrimmed = String(trimmed.dropFirst())
        } else {
            effectiveTrimmed = trimmed
        }
        
        // If escaped, treat as regular dialogue (if there's a pending character)
        if isEscaped {
            if pendingCharacter != nil {
                pendingCharacter = nil
                return DMLElement(type: .dialogue, content: effectiveTrimmed, rawLine: line, lineNumber: lineNumber)
            }
        }
        
        // Scene heading: # ACT I, Scene 1 or # INT. COFFEE SHOP - DAY
        if effectiveTrimmed.hasPrefix("#") && !isEscaped {
            pendingCharacter = nil
            let content = String(effectiveTrimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return DMLElement(type: .sceneHeading, content: content, rawLine: line, lineNumber: lineNumber)
        }
        
        // Location metadata: @ LOCATION: Living Room or @LOCATION:
        if (effectiveTrimmed.hasPrefix("@ ") || effectiveTrimmed.hasPrefix("@LOCATION")) && !isEscaped {
            pendingCharacter = nil
            return DMLElement(type: .locationMeta, content: effectiveTrimmed, rawLine: line, lineNumber: lineNumber)
        }
        
        // Time/atmosphere: = Night, raining
        if effectiveTrimmed.hasPrefix("=") && !effectiveTrimmed.hasPrefix("==") && !isEscaped {
            pendingCharacter = nil
            let content = String(effectiveTrimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return DMLElement(type: .timeMeta, content: content, rawLine: line, lineNumber: lineNumber)
        }
        
        // Transition: >> CUT TO:
        if effectiveTrimmed.hasPrefix(">>") && !isEscaped {
            pendingCharacter = nil
            let content = String(effectiveTrimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            return DMLElement(type: .transition, content: content, rawLine: line, lineNumber: lineNumber)
        }
        
        // Action/stage direction: > John paces near the window.
        if effectiveTrimmed.hasPrefix(">") && !effectiveTrimmed.hasPrefix(">>") && !isEscaped {
            pendingCharacter = nil
            let content = String(effectiveTrimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return DMLElement(type: .action, content: content, rawLine: line, lineNumber: lineNumber)
        }
        
        // Note: [[Remember to add tension here]]
        if effectiveTrimmed.hasPrefix("[[") && effectiveTrimmed.hasSuffix("]]") && !isEscaped {
            pendingCharacter = nil
            return DMLElement(type: .note, content: effectiveTrimmed, rawLine: line, lineNumber: lineNumber)
        }
        
        // Parenthetical: (hesitantly) - only if following a character or at start of dialogue block
        if effectiveTrimmed.hasPrefix("(") && effectiveTrimmed.hasSuffix(")") {
            // Check if we just saw a character - this is a parenthetical
            if pendingCharacter != nil {
                // This is a parenthetical after character name
                return DMLElement(type: .parenthetical, content: effectiveTrimmed, rawLine: line, lineNumber: lineNumber)
            }
        }
        
        // Character name: ALL CAPS line
        // A line is a character if:
        // 1. It is ALL CAPS (allowing numbers and spaces)
        // 2. It is not preceded by special prefixes
        // 3. It is followed by dialogue or parenthetical
        if isCharacterName(effectiveTrimmed) && pendingCharacter == nil {
            let element = DMLElement(type: .character, content: effectiveTrimmed, rawLine: line, lineNumber: lineNumber)
            pendingCharacter = element
            return element
        }
        
        // If we have a pending character, this must be dialogue
        if pendingCharacter != nil {
            pendingCharacter = nil  // Clear the pending character
            return DMLElement(type: .dialogue, content: effectiveTrimmed, rawLine: line, lineNumber: lineNumber)
        }
        
        // Default: treat as dialogue if none of the above matched
        // (This handles continuation of dialogue without explicit markup)
        return DMLElement(type: .dialogue, content: effectiveTrimmed, rawLine: line, lineNumber: lineNumber)
    }
    
    /// Check if a string looks like a character name (ALL CAPS)
    private func isCharacterName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // Must not be empty
        guard !trimmed.isEmpty else { return false }
        
        // Must not be too long (character names are typically short)
        guard trimmed.count <= 40 else { return false }
        
        // Must not contain lowercase letters
        let lowercaseLetters = CharacterSet.lowercaseLetters
        guard trimmed.unicodeScalars.allSatisfy({ !lowercaseLetters.contains($0) }) else {
            return false
        }
        
        // Must contain at least one uppercase letter
        let uppercaseLetters = CharacterSet.uppercaseLetters
        guard trimmed.unicodeScalars.contains(where: { uppercaseLetters.contains($0) }) else {
            return false
        }
        
        // Must not look like a scene heading (e.g., "INT. COFFEE SHOP - DAY")
        // These typically have periods after INT/EXT and dashes for time
        if (trimmed.hasPrefix("INT.") || trimmed.hasPrefix("EXT.")) && trimmed.contains(" - ") {
            return false
        }
        
        // Must not look like a transition (e.g., "CUT TO:" or "FADE OUT")
        let transitionPatterns = ["CUT TO:", "CUT TO", "FADE IN:", "FADE OUT:", "FADE OUT", 
                                   "DISSOLVE TO:", "DISSOLVE TO", "SMASH CUT:", "MATCH CUT:",
                                   "JUMP CUT:", "IRIS IN:", "IRIS OUT:", "WIPE TO:"]
        for pattern in transitionPatterns {
            if trimmed == pattern || trimmed.hasPrefix(pattern) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Validation
    
    /// Validate DML source and return any errors
    /// - Parameter source: The raw DML text
    /// - Returns: Array of validation errors with line numbers
    func validate(_ source: String) -> [DMLValidationError] {
        var errors: [DMLValidationError] = []
        let document = parse(source)
        
        // Check for orphaned parentheticals (not after a character)
        var lastWasCharacter = false
        for element in document.elements {
            if element.type == .parenthetical && !lastWasCharacter {
                errors.append(DMLValidationError(
                    lineNumber: element.lineNumber,
                    message: NSLocalizedString("drama.validation.orphanedParenthetical", 
                                                comment: "Parenthetical must follow a character name"),
                    severity: .warning
                ))
            }
            // Also check for dialogue that looks like it should be a parenthetical
            if element.type == .dialogue {
                let trimmed = element.content.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") && !lastWasCharacter {
                    errors.append(DMLValidationError(
                        lineNumber: element.lineNumber,
                        message: NSLocalizedString("drama.validation.orphanedParenthetical", 
                                                    comment: "Parenthetical must follow a character name"),
                        severity: .warning
                    ))
                }
            }
            lastWasCharacter = element.type == .character
        }
        
        // Check for unclosed notes
        let lines = source.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.contains("[[") && !line.contains("]]") {
                errors.append(DMLValidationError(
                    lineNumber: index + 1,
                    message: NSLocalizedString("drama.validation.unclosedNote", 
                                                comment: "Note bracket [[ is not closed with ]]"),
                    severity: .warning
                ))
            }
        }
        
        return errors
    }
}

// MARK: - Validation Error

struct DMLValidationError: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let message: String
    let severity: Severity
    
    enum Severity {
        case warning
        case error
    }
}
