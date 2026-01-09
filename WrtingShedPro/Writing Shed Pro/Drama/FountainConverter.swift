//
//  FountainConverter.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Import/Export support for Fountain screenplay format (.fountain)
//

import Foundation

/// Converter between DML (Drama Markup Language) and Fountain format
/// Fountain is the industry-standard plain text screenplay format
/// https://fountain.io/syntax
final class FountainConverter {
    
    // MARK: - Singleton
    
    static let shared = FountainConverter()
    
    private init() {}
    
    // MARK: - Import (Fountain → DML)
    
    /// Convert Fountain format to DML
    /// - Parameter fountain: Fountain-formatted text
    /// - Returns: DML-formatted text
    func fountainToDML(_ fountain: String) -> String {
        var dmlLines: [String] = []
        let lines = fountain.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Empty line
            if trimmed.isEmpty {
                dmlLines.append("")
                i += 1
                continue
            }
            
            // Forced scene heading (starts with . but not ..)
            if trimmed.hasPrefix(".") && !trimmed.hasPrefix("..") {
                let heading = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                dmlLines.append("# \(heading)")
                i += 1
                continue
            }
            
            // Scene heading (INT./EXT.)
            if isSceneHeading(trimmed) {
                dmlLines.append("# \(trimmed)")
                i += 1
                continue
            }
            
            // Forced action (starts with !)
            if trimmed.hasPrefix("!") {
                let action = String(trimmed.dropFirst())
                dmlLines.append("> \(action)")
                i += 1
                continue
            }
            
            // Transition (ends with TO: and is uppercase, or forced with >)
            if trimmed.hasPrefix(">") && !trimmed.hasPrefix(">>") {
                // Centered text in Fountain, but we'll treat as action for now
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if text.hasSuffix("<") {
                    // Centered text - treat as action
                    dmlLines.append("> \(String(text.dropLast()).trimmingCharacters(in: .whitespaces))")
                } else {
                    // Forced transition
                    dmlLines.append(">> \(text)")
                }
                i += 1
                continue
            }
            
            if isTransition(trimmed) {
                dmlLines.append(">> \(trimmed)")
                i += 1
                continue
            }
            
            // Character (uppercase, possibly with extension like (V.O.))
            if isCharacterLine(trimmed, nextLine: i + 1 < lines.count ? lines[i + 1] : nil) {
                // Check for forced character (@CHARACTER)
                var charName = trimmed
                if charName.hasPrefix("@") {
                    charName = String(charName.dropFirst())
                }
                dmlLines.append(charName)
                i += 1
                
                // Look for parenthetical and dialogue
                while i < lines.count {
                    let nextTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    
                    if nextTrimmed.isEmpty {
                        break
                    }
                    
                    // Parenthetical
                    if nextTrimmed.hasPrefix("(") && nextTrimmed.hasSuffix(")") {
                        dmlLines.append(nextTrimmed)
                        i += 1
                        continue
                    }
                    
                    // Dialogue
                    dmlLines.append(nextTrimmed)
                    i += 1
                }
                continue
            }
            
            // Notes [[note]]
            if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
                dmlLines.append(trimmed)
                i += 1
                continue
            }
            
            // Boneyard (comments) /* */
            if trimmed.hasPrefix("/*") {
                // Skip until */
                while i < lines.count && !lines[i].contains("*/") {
                    i += 1
                }
                i += 1
                continue
            }
            
            // Synopsis (=)
            if trimmed.hasPrefix("=") && !trimmed.hasPrefix("==") {
                // Convert to DML time/atmosphere for now
                dmlLines.append(trimmed)
                i += 1
                continue
            }
            
            // Section headers (#, ##, ###)
            if trimmed.hasPrefix("#") {
                // Could be converted to scene heading or note
                dmlLines.append(trimmed)
                i += 1
                continue
            }
            
            // Default: treat as action
            dmlLines.append("> \(trimmed)")
            i += 1
        }
        
        return dmlLines.joined(separator: "\n")
    }
    
    // MARK: - Export (DML → Fountain)
    
    /// Convert DML to Fountain format
    /// - Parameter dml: DML-formatted text
    /// - Returns: Fountain-formatted text
    func dmlToFountain(_ dml: String) -> String {
        let document = DramaMarkupParser.shared.parse(dml)
        var fountainLines: [String] = []
        
        for element in document.elements {
            switch element.type {
            case .sceneHeading:
                // Ensure proper Fountain scene heading format
                var heading = element.content
                if !heading.hasPrefix("INT.") && !heading.hasPrefix("EXT.") && 
                   !heading.hasPrefix("INT/EXT") && !heading.hasPrefix("I/E") {
                    // Force it with a period prefix
                    heading = ".\(heading)"
                }
                fountainLines.append("")
                fountainLines.append(heading)
                
            case .action:
                fountainLines.append("")
                fountainLines.append(element.content)
                
            case .character:
                fountainLines.append("")
                fountainLines.append(element.content.uppercased())
                
            case .parenthetical:
                fountainLines.append(element.content)
                
            case .dialogue:
                fountainLines.append(element.content)
                
            case .transition:
                fountainLines.append("")
                // Fountain transitions must end with TO: or be forced with >
                var trans = element.content.uppercased()
                if !trans.hasSuffix("TO:") && !trans.hasSuffix("OUT") && trans != "BLACKOUT" {
                    trans = ">\(trans)"
                }
                fountainLines.append(trans)
                
            case .locationMeta, .timeMeta:
                // Convert to Fountain synopsis
                fountainLines.append("= \(element.content)")
                
            case .note:
                fountainLines.append(element.content)
                
            case .blank:
                fountainLines.append("")
            }
        }
        
        // Clean up multiple blank lines
        return cleanupBlankLines(fountainLines.joined(separator: "\n"))
    }
    
    // MARK: - Helpers
    
    private func isSceneHeading(_ line: String) -> Bool {
        let prefixes = ["INT.", "EXT.", "INT./EXT.", "INT/EXT.", "I/E.", "INT ", "EXT "]
        let upper = line.uppercased()
        return prefixes.contains { upper.hasPrefix($0) }
    }
    
    private func isTransition(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()
        
        // Must be uppercase and end with TO: or be a known transition
        guard trimmed == line.trimmingCharacters(in: .whitespaces).uppercased() else {
            return false
        }
        
        let transitions = ["CUT TO:", "FADE OUT.", "FADE OUT", "FADE IN:", "DISSOLVE TO:", 
                          "SMASH CUT TO:", "MATCH CUT TO:", "JUMP CUT TO:", "FADE TO BLACK.",
                          "FADE TO BLACK", "CUT TO BLACK.", "CUT TO BLACK"]
        
        return transitions.contains { trimmed == $0 || trimmed.hasSuffix(" TO:") }
    }
    
    private func isCharacterLine(_ line: String, nextLine: String?) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Forced character starts with @
        if trimmed.hasPrefix("@") {
            return true
        }
        
        // Must be uppercase (allowing parenthetical extensions like (V.O.))
        let nameOnly = trimmed.replacingOccurrences(of: "\\s*\\([^)]*\\)\\s*$", with: "", options: .regularExpression)
        
        guard !nameOnly.isEmpty else { return false }
        
        // Check if all letters are uppercase
        let letters = nameOnly.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        
        let isUppercase = letters.allSatisfy { CharacterSet.uppercaseLetters.contains($0) }
        guard isUppercase else { return false }
        
        // Must not be a scene heading or transition
        guard !isSceneHeading(trimmed) && !isTransition(trimmed) else {
            return false
        }
        
        // In Fountain, character must be followed by dialogue (non-empty next line)
        if let next = nextLine {
            let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
            return !nextTrimmed.isEmpty
        }
        
        return true
    }
    
    private func cleanupBlankLines(_ text: String) -> String {
        // Replace 3+ consecutive newlines with 2
        var result = text
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
