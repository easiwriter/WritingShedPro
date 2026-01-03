//
//  PoemSectionType.swift
//  Writing Shed Pro
//
//  Defines section types for poetry files to distinguish poem body from
//  title, epigraph, signature, and other non-poem text.
//

import UIKit

/// Types of sections that can appear in a poetry file
/// Only `.poem` sections are included in poetry metrics analysis
enum PoemSectionType: String, Codable, CaseIterable, Identifiable {
    case poem         // Default - included in analysis
    case title        // Excluded from analysis, rendered as heading
    case epigraph     // Excluded, rendered in italics (quotation/dedication)
    case signature    // Excluded, rendered smaller (author attribution)
    case stanzaNumber // Excluded, rendered as small centered number
    case dedication   // Excluded, rendered similar to epigraph
    
    var id: String { rawValue }
    
    /// Whether this section type is included in poetry analysis
    var isAnalyzed: Bool {
        self == .poem
    }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .poem: return NSLocalizedString("poemSection.poem", comment: "Poem")
        case .title: return NSLocalizedString("poemSection.title", comment: "Title")
        case .epigraph: return NSLocalizedString("poemSection.epigraph", comment: "Epigraph")
        case .signature: return NSLocalizedString("poemSection.signature", comment: "Signature")
        case .stanzaNumber: return NSLocalizedString("poemSection.stanzaNumber", comment: "Stanza Number")
        case .dedication: return NSLocalizedString("poemSection.dedication", comment: "Dedication")
        }
    }
    
    /// System icon for this section type
    var iconName: String {
        switch self {
        case .poem: return "text.alignleft"
        case .title: return "textformat.size.larger"
        case .epigraph: return "text.quote"
        case .signature: return "signature"
        case .stanzaNumber: return "number"
        case .dedication: return "heart.text.square"
        }
    }
    
    /// Description of what this section type is for
    var helpText: String {
        switch self {
        case .poem:
            return NSLocalizedString("poemSection.poem.help", comment: "Main poem body - included in metrics analysis")
        case .title:
            return NSLocalizedString("poemSection.title.help", comment: "Poem title - excluded from analysis")
        case .epigraph:
            return NSLocalizedString("poemSection.epigraph.help", comment: "Quotation or motto - excluded from analysis")
        case .signature:
            return NSLocalizedString("poemSection.signature.help", comment: "Author attribution - excluded from analysis")
        case .stanzaNumber:
            return NSLocalizedString("poemSection.stanzaNumber.help", comment: "Stanza numbering - excluded from analysis")
        case .dedication:
            return NSLocalizedString("poemSection.dedication.help", comment: "Dedication text - excluded from analysis")
        }
    }
}

// MARK: - NSAttributedString Integration

extension NSAttributedString.Key {
    /// Custom attribute key for poem section type
    /// Used to mark text as title, epigraph, signature, etc.
    /// Text without this attribute (or with value "poem") is treated as poem body
    static let poemSectionType = NSAttributedString.Key("WritingShedPro.PoemSectionType")
}

// MARK: - NSAttributedString Helpers

extension NSAttributedString {
    
    /// Extract only the poem body text, excluding title/epigraph/signature sections
    /// - Returns: Plain text containing only poem sections
    func extractPoemBody() -> String {
        var poemParts: [String] = []
        
        enumerateAttribute(.poemSectionType, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            // Default to .poem if no attribute set
            let sectionType: PoemSectionType
            if let typeString = value as? String, let type = PoemSectionType(rawValue: typeString) {
                sectionType = type
            } else {
                sectionType = .poem
            }
            
            // Only include poem sections in analysis
            if sectionType.isAnalyzed {
                let substring = attributedSubstring(from: range).string
                poemParts.append(substring)
            }
        }
        
        return poemParts.joined()
    }
    
    /// Get the section type at a specific location
    /// - Parameter location: Character index
    /// - Returns: The section type, defaulting to .poem if not set
    func sectionType(at location: Int) -> PoemSectionType {
        guard location >= 0 && location < length else { return .poem }
        
        if let typeString = attribute(.poemSectionType, at: location, effectiveRange: nil) as? String,
           let type = PoemSectionType(rawValue: typeString) {
            return type
        }
        return .poem
    }
    
    /// Check if the given range contains any non-poem sections
    /// - Parameter range: The range to check
    /// - Returns: true if any part of the range is marked as non-poem
    func hasNonPoemSections(in range: NSRange) -> Bool {
        var hasNonPoem = false
        
        enumerateAttribute(.poemSectionType, in: range, options: []) { value, _, stop in
            if let typeString = value as? String,
               let type = PoemSectionType(rawValue: typeString),
               !type.isAnalyzed {
                hasNonPoem = true
                stop.pointee = true
            }
        }
        
        return hasNonPoem
    }
}

// MARK: - NSMutableAttributedString Helpers

extension NSMutableAttributedString {
    
    /// Mark a range of text as a specific section type
    /// - Parameters:
    ///   - sectionType: The section type to apply
    ///   - range: The range to mark
    func markSection(_ sectionType: PoemSectionType, in range: NSRange) {
        guard range.location >= 0 && NSMaxRange(range) <= length else { return }
        
        if sectionType == .poem {
            // Remove the attribute to revert to default poem type
            removeAttribute(.poemSectionType, range: range)
        } else {
            addAttribute(.poemSectionType, value: sectionType.rawValue, range: range)
        }
    }
    
    /// Clear section marking from a range, reverting to poem body
    /// - Parameter range: The range to clear
    func clearSectionMarking(in range: NSRange) {
        guard range.location >= 0 && NSMaxRange(range) <= length else { return }
        removeAttribute(.poemSectionType, range: range)
    }
    
    /// Extend a range to cover complete lines
    /// - Parameter range: The original range
    /// - Returns: A range extended to line boundaries
    func extendToLinesBoundaries(_ range: NSRange) -> NSRange {
        guard range.location >= 0 && NSMaxRange(range) <= length else { return range }
        
        let text = string as NSString
        
        // Find start of first line
        let lineStart = text.lineRange(for: NSRange(location: range.location, length: 0)).location
        
        // Find end of last line
        let lastCharLocation = max(range.location, NSMaxRange(range) - 1)
        let lineEnd = NSMaxRange(text.lineRange(for: NSRange(location: lastCharLocation, length: 0)))
        
        return NSRange(location: lineStart, length: lineEnd - lineStart)
    }
}
