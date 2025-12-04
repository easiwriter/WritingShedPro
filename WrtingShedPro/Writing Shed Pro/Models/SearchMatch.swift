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
    
    /// The matched text (extracted from range)
    var matchedText: String {
        guard range.location >= 0 && range.length > 0 else { return "" }
        let nsContext = context as NSString
        guard range.location < nsContext.length else { return "" }
        let safeLength = min(range.length, nsContext.length - range.location)
        return nsContext.substring(with: NSRange(location: range.location, length: safeLength))
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
