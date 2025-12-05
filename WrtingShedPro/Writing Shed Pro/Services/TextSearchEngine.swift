//
//  TextSearchEngine.swift
//  Writing Shed Pro
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace
//

import Foundation

/// Core text search engine for finding matches in text content
class TextSearchEngine {
    
    // MARK: - Public Search Methods
    
    /// Search for matches in text using the provided query
    /// - Parameters:
    ///   - text: The text to search in
    ///   - query: The search query with options
    /// - Returns: Array of SearchMatch objects
    func search(in text: String, query: SearchQuery) -> [SearchMatch] {
        guard query.isValidForSearch else { return [] }
        
        if query.isRegex {
            return searchWithRegex(in: text, pattern: query.searchText)
        } else {
            return searchPlainText(
                in: text,
                searchText: query.searchText,
                caseSensitive: query.isCaseSensitive,
                wholeWord: query.isWholeWord
            )
        }
    }
    
    // MARK: - Plain Text Search
    
    /// Search for plain text matches
    private func searchPlainText(
        in text: String,
        searchText: String,
        caseSensitive: Bool,
        wholeWord: Bool
    ) -> [SearchMatch] {
        // CRITICAL PERFORMANCE: Use NSRegularExpression to find ALL matches in one pass
        // This is 100x faster than repeated NSString.range(of:) calls
        
        // Escape special regex characters in the search text
        let escapedSearch = NSRegularExpression.escapedPattern(for: searchText)
        
        // Build regex pattern with optional word boundaries
        let pattern = wholeWord ? "\\b\(escapedSearch)\\b" : escapedSearch
        
        // Build regex options
        var regexOptions: NSRegularExpression.Options = []
        if !caseSensitive {
            regexOptions.insert(.caseInsensitive)
        }
        
        // Create regex
        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else {
            return []
        }
        
        // Find all matches in ONE pass (O(n) instead of O(n²))
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let regexMatches = regex.matches(in: text, range: fullRange)
        
        // Convert regex matches to SearchMatch objects
        var matches: [SearchMatch] = []
        matches.reserveCapacity(regexMatches.count)
        
        for regexMatch in regexMatches {
            let nsRange = regexMatch.range
            
            // Extract context and create match
            let context = extractContext(for: nsRange, in: text)
            let lineNumber = calculateLineNumber(for: nsRange.location, in: text)
            
            let match = SearchMatch(
                range: nsRange,
                context: context,
                lineNumber: lineNumber
            )
            matches.append(match)
        }
        
        return matches
    }
    
    // MARK: - Regex Search
    
    /// Search using regular expressions
    private func searchWithRegex(in text: String, pattern: String) -> [SearchMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let regexMatches = regex.matches(in: text, range: range)
        
        return regexMatches.map { match in
            let context = extractContext(for: match.range, in: text)
            let lineNumber = calculateLineNumber(for: match.range.location, in: text)
            
            return SearchMatch(
                range: match.range,
                context: context,
                lineNumber: lineNumber
            )
        }
    }
    
    // MARK: - Whole Word Detection
    
    /// Check if a match is a whole word (bounded by word boundaries)
    private func isWholeWordMatch(at range: NSRange, in text: String) -> Bool {
        let nsText = text as NSString
        
        // Check start boundary
        let isStartBoundary: Bool
        if range.location == 0 {
            isStartBoundary = true
        } else {
            let charBefore = nsText.substring(with: NSRange(location: range.location - 1, length: 1))
            isStartBoundary = isWordBoundaryCharacter(charBefore)
        }
        
        // Check end boundary
        let isEndBoundary: Bool
        let endLocation = range.location + range.length
        if endLocation >= nsText.length {
            isEndBoundary = true
        } else {
            let charAfter = nsText.substring(with: NSRange(location: endLocation, length: 1))
            isEndBoundary = isWordBoundaryCharacter(charAfter)
        }
        
        return isStartBoundary && isEndBoundary
    }
    
    /// Check if a character is a word boundary (whitespace, punctuation, etc.)
    private func isWordBoundaryCharacter(_ char: String) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return true }
        
        // Word boundaries include:
        // - Whitespace (space, tab, newline, etc.)
        // - Punctuation
        // - Symbols
        let wordCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return !wordCharacterSet.contains(scalar)
    }
    
    // MARK: - Context Extraction
    
    /// Extract surrounding context for a match (50 characters before and after)
    private func extractContext(for range: NSRange, in text: String, contextLength: Int = 50) -> String {
        let nsText = text as NSString
        
        // Calculate context range
        let startLocation = max(0, range.location - contextLength)
        let endLocation = min(nsText.length, range.location + range.length + contextLength)
        let contextRange = NSRange(location: startLocation, length: endLocation - startLocation)
        
        var context = nsText.substring(with: contextRange)
        
        // Add ellipsis if context is truncated
        if startLocation > 0 {
            context = "..." + context
        }
        if endLocation < nsText.length {
            context = context + "..."
        }
        
        // Replace newlines with spaces for display
        context = context.replacingOccurrences(of: "\n", with: " ")
        context = context.replacingOccurrences(of: "\r", with: " ")
        
        // Collapse multiple spaces
        while context.contains("  ") {
            context = context.replacingOccurrences(of: "  ", with: " ")
        }
        
        return context.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Line Number Calculation
    
    /// Calculate the line number for a character position
    private func calculateLineNumber(for location: Int, in text: String) -> Int {
        guard location >= 0 && location <= text.count else { return 0 }
        
        let nsText = text as NSString
        let substring = nsText.substring(to: location)
        let lineBreaks = substring.components(separatedBy: .newlines).count
        
        return lineBreaks
    }
    
    // MARK: - Regex Validation
    
    /// Validate a regex pattern
    /// - Parameter pattern: The regex pattern to validate
    /// - Returns: nil if valid, error message if invalid
    func validateRegex(_ pattern: String) -> String? {
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - Replace Operations
    
    /// Replace text at a specific range
    /// - Parameters:
    ///   - text: The original text
    ///   - range: The range to replace
    ///   - replacement: The replacement text
    /// - Returns: The modified text
    func replace(in text: String, at range: NSRange, with replacement: String) -> String {
        let nsText = text as NSString
        return nsText.replacingCharacters(in: range, with: replacement)
    }
    
    /// Replace all matches in text
    /// - Parameters:
    ///   - text: The original text
    ///   - matches: The matches to replace (must be sorted by location, descending)
    ///   - replacement: The replacement text
    /// - Returns: The modified text
    func replaceAll(in text: String, matches: [SearchMatch], with replacement: String) -> String {
        var mutableText = text as NSString
        
        // Sort matches by location in descending order to avoid range shifting
        let sortedMatches = matches.sorted { $0.range.location > $1.range.location }
        
        for match in sortedMatches {
            mutableText = mutableText.replacingCharacters(in: match.range, with: replacement) as NSString
        }
        
        return mutableText as String
    }
    
    /// Replace with regex capture groups
    /// - Parameters:
    ///   - text: The original text
    ///   - pattern: The regex pattern
    ///   - template: The replacement template (supports $1, $2, etc.)
    /// - Returns: The modified text, or nil if regex is invalid
    func replaceWithRegex(in text: String, pattern: String, template: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
