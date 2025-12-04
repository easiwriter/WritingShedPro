//
//  SearchOptions.swift
//  Writing Shed Pro
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace
//

import Foundation

/// User preferences for search and replace operations
struct SearchOptions: Codable {
    var caseSensitive: Bool
    var wholeWord: Bool
    var useRegex: Bool
    var searchHistory: [String]
    var replaceHistory: [String]
    var lastUsedScope: SearchScope
    
    // Maximum history items to retain
    static let maxHistoryItems = 20
    
    init(
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        useRegex: Bool = false,
        searchHistory: [String] = [],
        replaceHistory: [String] = [],
        lastUsedScope: SearchScope = .currentFile
    ) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.useRegex = useRegex
        self.searchHistory = searchHistory
        self.replaceHistory = replaceHistory
        self.lastUsedScope = lastUsedScope
    }
    
    /// Add search text to history (most recent first)
    mutating func addSearchHistory(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Remove if already exists
        searchHistory.removeAll { $0 == text }
        
        // Add to front
        searchHistory.insert(text, at: 0)
        
        // Limit size
        if searchHistory.count > Self.maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(Self.maxHistoryItems))
        }
    }
    
    /// Add replace text to history (most recent first)
    mutating func addReplaceHistory(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Remove if already exists
        replaceHistory.removeAll { $0 == text }
        
        // Add to front
        replaceHistory.insert(text, at: 0)
        
        // Limit size
        if replaceHistory.count > Self.maxHistoryItems {
            replaceHistory = Array(replaceHistory.prefix(Self.maxHistoryItems))
        }
    }
    
    /// Clear all history
    mutating func clearHistory() {
        searchHistory.removeAll()
        replaceHistory.removeAll()
    }
}

/// Persistent storage for SearchOptions using UserDefaults
class SearchOptionsStore: ObservableObject {
    private static let userDefaultsKey = "searchOptions"
    
    @Published var options: SearchOptions {
        didSet {
            save()
        }
    }
    
    static let shared = SearchOptionsStore()
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let decoded = try? JSONDecoder().decode(SearchOptions.self, from: data) {
            self.options = decoded
        } else {
            self.options = SearchOptions()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
    
    /// Reset to default options
    func reset() {
        options = SearchOptions()
    }
}
