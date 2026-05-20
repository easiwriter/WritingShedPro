//
//  SearchMatch.swift
//  Writing Shed Pro
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace
//

import Foundation

/// Represents a single search match within text
struct SearchMatch: Identifiable, Hashable {
    let id: UUID
    let range: NSRange
    let context: String
    let lineNumber: Int
    
    init(
        id: UUID = UUID(),
        range: NSRange,
        context: String,
        lineNumber: Int
    ) {
        self.id = id
        self.range = range
        self.context = context
        self.lineNumber = lineNumber
    }
    
    /// The matched text (extracted from context)
    /// NOTE: Requires context to be populated via enrichMatches().
    /// Returns empty string if context is not available.
    var matchedText: String {
        guard range.length > 0, !context.isEmpty else { return "" }
        
        // Context has been processed (newlines replaced, spaces collapsed, "..." added)
        // We can't reliably extract the original match from modified context
        // Instead, just return an empty string and require using extractMatchedText(from:)
        return ""
    }
    
    /// Extract the matched text from the original source text
    /// This is the proper way to get matched text since context is modified
    /// - Parameter text: The original source text
    /// - Returns: The matched substring
    func extractMatchedText(from text: String) -> String {
        guard range.location >= 0, range.length > 0 else { return "" }
        let nsText = text as NSString
        guard range.location + range.length <= nsText.length else { return "" }
        return nsText.substring(with: range)
    }
}

/// Search result containing all matches for a specific file/version
struct SearchResult: Identifiable {
    let id: UUID
    let file: TextFile
    let version: Version
    let matches: [SearchMatch]
    
    init(
        id: UUID = UUID(),
        file: TextFile,
        version: Version,
        matches: [SearchMatch]
    ) {
        self.id = id
        self.file = file
        self.version = version
        self.matches = matches
    }
    
    /// Total number of matches in this file
    var matchCount: Int {
        matches.count
    }
    
    /// Check if version is locked (cannot replace)
    var isLocked: Bool {
        version.isLocked
    }
    
    /// Warning message for locked versions
    var lockWarning: String? {
        guard isLocked else { return nil }
        return version.lockReason
    }
}
