//
//  SearchQuery.swift
//  Writing Shed Pro
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace
//

import Foundation

/// Represents a search query with all search/replace parameters
struct SearchQuery: Identifiable, Codable {
    let id: UUID
    var searchText: String
    var replaceText: String?
    var isCaseSensitive: Bool
    var isWholeWord: Bool
    var isRegex: Bool
    var scope: SearchScope
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        searchText: String,
        replaceText: String? = nil,
        isCaseSensitive: Bool = false,
        isWholeWord: Bool = false,
        isRegex: Bool = false,
        scope: SearchScope = .currentFile,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.searchText = searchText
        self.replaceText = replaceText
        self.isCaseSensitive = isCaseSensitive
        self.isWholeWord = isWholeWord
        self.isRegex = isRegex
        self.scope = scope
        self.timestamp = timestamp
    }
    
    /// Check if this is a replace operation
    var isReplaceMode: Bool {
        replaceText != nil
    }
    
    /// Check if query is valid for searching
    var isValidForSearch: Bool {
        !searchText.isEmpty
    }
}

/// Search scope options
enum SearchScope: String, Codable, CaseIterable {
    case currentFile = "Current File"
    case collection = "Collection"
    case project = "Project"
    
    var description: String {
        self.rawValue
    }
}
