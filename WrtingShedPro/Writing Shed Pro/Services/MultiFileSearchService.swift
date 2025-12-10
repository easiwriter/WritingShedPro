//
//  MultiFileSearchService.swift
//  Writing Shed Pro
//
//  Created on 8 December 2025.
//  Extension of Feature 017: Multi-file search for folders and collections
//

import Foundation
import SwiftData
import Observation

/// Result of searching across multiple files
struct MultiFileSearchResult: Identifiable {
    let id = UUID()
    let file: TextFile
    let version: Version
    let matches: [SearchMatch]
    var matchCount: Int { matches.count }
    var isSelected: Bool = false  // For bulk replace operations
}

/// Service for searching across multiple files (folders or collections)
@MainActor
@Observable
class MultiFileSearchService {
    
    // MARK: - Properties
    
    var searchText: String = ""
    var replaceText: String = ""
    var isCaseSensitive: Bool = false
    var isWholeWord: Bool = false
    var isRegex: Bool = false
    var isReplaceMode: Bool = false
    
    var results: [MultiFileSearchResult] = []
    var isSearching: Bool = false
    var errorMessage: String?
    var regexError: String?
    
    private let searchEngine = TextSearchEngine()
    
    // MARK: - Computed Properties
    
    var totalMatchCount: Int {
        results.reduce(0) { $0 + $1.matchCount }
    }
    
    var fileCount: Int {
        results.count
    }
    
    var hasResults: Bool {
        !results.isEmpty
    }
    
    var selectedResultsCount: Int {
        results.filter { $0.isSelected }.count
    }
    
    // MARK: - Search Methods
    
    /// Search across all files in a folder
    func searchInFolder(_ folder: Folder) {
        let files = folder.textFiles ?? []
        searchInFiles(files)
    }
    
    /// Search across all files in a collection
    func searchInCollection(_ collection: Submission) {
        // Get the text files from submitted files
        let files = collection.submittedFiles?.compactMap { $0.textFile } ?? []
        searchInFiles(files)
    }
    
    /// Search across a list of files
    private func searchInFiles(_ files: [TextFile]) {
        guard !searchText.isEmpty else {
            results = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        regexError = nil
        results = []
        
        // Build search query
        let query = SearchQuery(
            searchText: searchText,
            replaceText: isReplaceMode ? replaceText : nil,
            isCaseSensitive: isCaseSensitive,
            isWholeWord: isWholeWord,
            isRegex: isRegex,
            scope: .project  // Doesn't matter for multi-file search
        )
        
        // Validate regex if needed
        if isRegex {
            do {
                _ = try NSRegularExpression(pattern: searchText, options: [])
            } catch {
                regexError = "Invalid regular expression: \(error.localizedDescription)"
                isSearching = false
                return
            }
        }
        
        // Search each file
        for file in files {
            // Use the current version
            guard let version = file.currentVersion else { continue }
            
            // Get the text content (use plain text stored in content property)
            let text = version.content
            
            // Search for matches
            let matches = searchEngine.search(in: text, query: query)
            
            // If there are matches, add to results
            if !matches.isEmpty {
                let result = MultiFileSearchResult(
                    file: file,
                    version: version,
                    matches: matches
                )
                results.append(result)
            }
        }
        
        // Sort results alphabetically by file name (case-insensitive)
        results.sort { lhs, rhs in
            let lhsName = lhs.file.name.isEmpty ? "Untitled" : lhs.file.name
            let rhsName = rhs.file.name.isEmpty ? "Untitled" : rhs.file.name
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
        
        isSearching = false
    }
    
    // MARK: - Replace Methods
    
    /// Replace all matches in selected files
    func replaceInSelectedFiles() throws -> Int {
        guard !replaceText.isEmpty else {
            throw SearchError.emptyReplaceText
        }
        
        var totalReplacements = 0
        
        for i in results.indices where results[i].isSelected {
            let result = results[i]
            let version = result.version
            
            // Get the current content
            var text = version.content
            
            // Sort matches by range location in reverse order to avoid invalidating offsets
            let sortedMatches = result.matches.sorted { $0.range.location > $1.range.location }
            
            // Replace each match
            for match in sortedMatches {
                let nsText = text as NSString
                let range = match.range
                
                // Ensure range is valid
                guard range.location != NSNotFound,
                      range.location >= 0,
                      range.location + range.length <= nsText.length else {
                    continue
                }
                
                // Replace the text
                text = nsText.replacingCharacters(in: range, with: replaceText)
                totalReplacements += 1
            }
            
            // Update the version content
            version.content = text
            
            // Update the file's modified date
            if let file = version.textFile {
                file.modifiedDate = Date()
            }
        }
        
        // Clear results after replace
        results = []
        
        return totalReplacements
    }
    
    /// Toggle selection for a specific result
    func toggleSelection(for resultID: UUID) {
        if let index = results.firstIndex(where: { $0.id == resultID }) {
            results[index].isSelected.toggle()
        }
    }
    
    /// Select all results
    func selectAll() {
        for i in results.indices {
            results[i].isSelected = true
        }
    }
    
    /// Deselect all results
    func deselectAll() {
        for i in results.indices {
            results[i].isSelected = false
        }
    }
    
    /// Clear all search results
    func clear() {
        searchText = ""
        replaceText = ""
        results = []
        errorMessage = nil
        regexError = nil
    }
}

// MARK: - Search Errors

enum SearchError: LocalizedError {
    case emptyReplaceText
    case invalidRegex(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyReplaceText:
            return "Replace text cannot be empty"
        case .invalidRegex(let message):
            return "Invalid regular expression: \(message)"
        }
    }
}
