//
//  DramaMarkupTypes.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Types and enums for Drama Markup Language (DML) parsing and rendering
//

import Foundation
import UIKit

// MARK: - Script Type

/// The type of dramatic work - determines formatting conventions
enum DramaScriptType: String, Codable, CaseIterable {
    case film       // Film/Screenplay format
    case stage      // Stage Play format
    
    var localizedName: String {
        switch self {
        case .film:
            return NSLocalizedString("drama.scriptType.film", comment: "Film/Screenplay")
        case .stage:
            return NSLocalizedString("drama.scriptType.stage", comment: "Stage Play")
        }
    }
}

// MARK: - View Mode

/// The display mode for drama scene content
enum DramaViewMode: String, CaseIterable {
    case source     // Raw DML markup
    case formatted  // Live preview with proper styling
    case print      // Paginated, industry-standard layout
    
    var localizedName: String {
        switch self {
        case .source:
            return NSLocalizedString("drama.viewMode.source", comment: "Source")
        case .formatted:
            return NSLocalizedString("drama.viewMode.formatted", comment: "Formatted")
        case .print:
            return NSLocalizedString("drama.viewMode.print", comment: "Print Preview")
        }
    }
    
    var icon: String {
        switch self {
        case .source:
            return "chevron.left.forwardslash.chevron.right"
        case .formatted:
            return "text.alignleft"
        case .print:
            return "doc.richtext"
        }
    }
}

// MARK: - DML Element Types

/// The type of element in a DML document
enum DMLElementType: Equatable {
    case sceneHeading       // # ACT I, Scene 1 or # INT. COFFEE SHOP - DAY
    case locationMeta       // @ LOCATION: Living Room
    case timeMeta           // = Night, raining
    case action             // > John paces near the window.
    case transition         // >> CUT TO:
    case character          // JOHN (detected: ALL CAPS followed by dialogue)
    case parenthetical      // (hesitantly)
    case dialogue           // Regular text after a character
    case note               // [[Remember to add tension here]]
    case blank              // Empty line
}

// MARK: - Parsed Element

/// A parsed element from DML source
struct DMLElement: Identifiable, Equatable {
    let id = UUID()
    let type: DMLElementType
    let content: String
    let rawLine: String
    let lineNumber: Int
    
    /// For character elements, the character name
    var characterName: String? {
        guard type == .character else { return nil }
        return content.trimmingCharacters(in: .whitespaces)
    }
    
    /// For parenthetical elements, the text without parentheses
    var parentheticalText: String? {
        guard type == .parenthetical else { return nil }
        var text = content.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("(") { text.removeFirst() }
        if text.hasSuffix(")") { text.removeLast() }
        return text.trimmingCharacters(in: .whitespaces)
    }
    
    /// For note elements, the text without brackets
    var noteText: String? {
        guard type == .note else { return nil }
        var text = content.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("[[") { text = String(text.dropFirst(2)) }
        if text.hasSuffix("]]") { text = String(text.dropLast(2)) }
        return text.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Parsed Document

/// A complete parsed DML document
struct DMLDocument {
    let elements: [DMLElement]
    let sourceText: String
    
    /// Extract location from metadata elements
    var location: String? {
        elements.first { $0.type == .locationMeta }?.content
            .replacingOccurrences(of: "@ LOCATION:", with: "")
            .replacingOccurrences(of: "@LOCATION:", with: "")
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Extract time/atmosphere from metadata elements
    var timeAtmosphere: String? {
        elements.first { $0.type == .timeMeta }?.content
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Extract scene heading
    var sceneHeading: String? {
        elements.first { $0.type == .sceneHeading }?.content
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Get all unique character names
    var characters: [String] {
        Array(Set(elements.compactMap { $0.characterName })).sorted()
    }
    
    /// Get dialogue blocks grouped by character
    var dialogueBlocks: [(character: String, lines: [DMLElement])] {
        var blocks: [(character: String, lines: [DMLElement])] = []
        var currentCharacter: String?
        var currentLines: [DMLElement] = []
        
        for element in elements {
            switch element.type {
            case .character:
                if let char = currentCharacter, !currentLines.isEmpty {
                    blocks.append((char, currentLines))
                }
                currentCharacter = element.characterName
                currentLines = []
            case .dialogue, .parenthetical:
                if currentCharacter != nil {
                    currentLines.append(element)
                }
            default:
                if let char = currentCharacter, !currentLines.isEmpty {
                    blocks.append((char, currentLines))
                }
                currentCharacter = nil
                currentLines = []
            }
        }
        
        // Don't forget the last block
        if let char = currentCharacter, !currentLines.isEmpty {
            blocks.append((char, currentLines))
        }
        
        return blocks
    }
}

// MARK: - Formatting Constants

/// Constants for script formatting (based on industry standards)
struct DMLFormattingConstants {
    
    // MARK: - Film/Screenplay Format
    
    struct Film {
        /// Left margin for action (in points, assuming 72pt = 1 inch)
        static let actionLeftMargin: CGFloat = 108  // 1.5"
        static let actionRightMargin: CGFloat = 72  // 1"
        
        /// Character name indent (centered, typically 2.5" from left)
        static let characterLeftMargin: CGFloat = 252  // 3.5" from left edge
        
        /// Dialogue margins
        static let dialogueLeftMargin: CGFloat = 180  // 2.5"
        static let dialogueRightMargin: CGFloat = 144 // 2"
        
        /// Parenthetical margins (slightly more indented than dialogue)
        static let parentheticalLeftMargin: CGFloat = 216  // 3"
        static let parentheticalRightMargin: CGFloat = 180 // 2.5"
        
        /// Transition (right-aligned)
        static let transitionRightMargin: CGFloat = 72  // 1"
        
        /// Scene heading (slug line)
        static let sceneHeadingLeftMargin: CGFloat = 108  // 1.5"
    }
    
    // MARK: - Stage Play Format
    
    struct Stage {
        /// Action/stage directions (in parentheses or italics)
        static let stageDirectionLeftMargin: CGFloat = 72   // 1"
        static let stageDirectionRightMargin: CGFloat = 72  // 1"
        
        /// Character name (left-aligned in stage plays)
        static let characterLeftMargin: CGFloat = 72  // 1"
        
        /// Dialogue indent below character name
        static let dialogueLeftMargin: CGFloat = 144  // 2"
        static let dialogueRightMargin: CGFloat = 72  // 1"
        
        /// Scene heading
        static let sceneHeadingLeftMargin: CGFloat = 72  // 1"
    }
    
    // MARK: - Common
    
    /// Standard screenplay font (Courier)
    static let scriptFont = UIFont(name: "Courier", size: 12) ?? UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    
    /// Bold version for character names
    static let scriptFontBold = UIFont(name: "Courier-Bold", size: 12) ?? UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    
    /// Italic version for stage directions
    static let scriptFontItalic = UIFont(name: "Courier-Oblique", size: 12) ?? UIFont.italicSystemFont(ofSize: 12)
    
    /// Line spacing (standard screenplay is 1.0)
    static let lineSpacing: CGFloat = 0
    
    /// Paragraph spacing
    static let paragraphSpacing: CGFloat = 12
}
