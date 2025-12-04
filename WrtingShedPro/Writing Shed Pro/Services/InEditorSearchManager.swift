//
//  InEditorSearchManager.swift
//  Writing Shed Pro
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace
//

import Foundation
import UIKit
import Combine

/// Manages search and replace operations within the active text editor
@MainActor
class InEditorSearchManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                performSearch()
            }
        }
    }
    
    @Published var replaceText: String = ""
    @Published var currentMatchIndex: Int = 0
    @Published var totalMatches: Int = 0
    @Published var isReplaceMode: Bool = false
    @Published var isCaseSensitive: Bool = false {
        didSet {
            if isCaseSensitive != oldValue {
                performSearch()
            }
        }
    }
    
    @Published var isWholeWord: Bool = false {
        didSet {
            if isWholeWord != oldValue {
                performSearch()
            }
        }
    }
    
    @Published var isRegex: Bool = false {
        didSet {
            if isRegex != oldValue {
                performSearch()
            }
        }
    }
    
    @Published var regexError: String?
    
    // MARK: - Private Properties
    
    private let searchEngine = TextSearchEngine()
    private var matches: [SearchMatch] = []
    private var cancellables = Set<AnyCancellable>()
    
    weak var textView: UITextView?
    weak var textStorage: NSTextStorage?
    
    // Highlight colors
    private let matchHighlightColor = UIColor.systemYellow.withAlphaComponent(0.3)
    private let currentMatchHighlightColor = UIColor.systemOrange.withAlphaComponent(0.5)
    
    // MARK: - Initialization
    
    init() {
        setupDebouncing()
    }
    
    // MARK: - Setup
    
    private func setupDebouncing() {
        // Debounce search text changes to avoid excessive searches while typing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSearchIfNeeded()
            }
            .store(in: &cancellables)
    }
    
    private func performSearchIfNeeded() {
        guard !searchText.isEmpty else {
            clearSearch()
            return
        }
        performSearch()
    }
    
    // MARK: - Search Operations
    
    /// Perform search in the current text
    func performSearch() {
        print("🔍 performSearch called: searchText='\(searchText)'")
        print("  - textView: \(textView != nil ? "✅" : "❌")")
        print("  - textStorage: \(textStorage != nil ? "✅" : "❌")")
        
        guard !searchText.isEmpty, let text = textView?.text else {
            clearSearch()
            return
        }
        
        // Clear previous highlights
        clearHighlights()
        
        // Validate regex if needed
        if isRegex {
            if let error = searchEngine.validateRegex(searchText) {
                regexError = error
                matches = []
                totalMatches = 0
                return
            } else {
                regexError = nil
            }
        }
        
        // Create query
        let query = SearchQuery(
            searchText: searchText,
            isCaseSensitive: isCaseSensitive,
            isWholeWord: isWholeWord,
            isRegex: isRegex
        )
        
        // Perform search
        matches = searchEngine.search(in: text, query: query)
        totalMatches = matches.count
        
        print("  - Found \(totalMatches) matches")
        
        // Reset to first match
        if !matches.isEmpty {
            currentMatchIndex = 0
            highlightMatches()
            scrollToCurrentMatch()
        }
    }
    
    /// Clear all search state
    func clearSearch() {
        searchText = ""
        matches = []
        totalMatches = 0
        currentMatchIndex = 0
        regexError = nil
        clearHighlights()
    }
    
    // MARK: - Navigation
    
    /// Move to the next match (circular)
    func nextMatch() {
        guard !matches.isEmpty else { return }
        
        currentMatchIndex = (currentMatchIndex + 1) % matches.count
        highlightMatches()
        scrollToCurrentMatch()
    }
    
    /// Move to the previous match (circular)
    func previousMatch() {
        guard !matches.isEmpty else { return }
        
        currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        highlightMatches()
        scrollToCurrentMatch()
    }
    
    // MARK: - Highlighting
    
    /// Highlight all matches in the text
    private func highlightMatches() {
        guard let textStorage = textStorage else { return }
        
        // Clear previous highlights
        clearHighlights()
        
        // Highlight all matches
        for (index, match) in matches.enumerated() {
            let color = (index == currentMatchIndex) ? currentMatchHighlightColor : matchHighlightColor
            textStorage.addAttribute(.backgroundColor, value: color, range: match.range)
        }
        
        // Force textStorage to process the changes
        textStorage.edited(.editedAttributes, range: NSRange(location: 0, length: textStorage.length), changeInLength: 0)
    }
    
    /// Clear all highlight attributes
    private func clearHighlights() {
        guard let textStorage = textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
    }
    
    // MARK: - Scrolling
    
    /// Scroll to the current match
    private func scrollToCurrentMatch() {
        guard !matches.isEmpty,
              currentMatchIndex < matches.count,
              let textView = textView else { return }
        
        let match = matches[currentMatchIndex]
        
        // Convert NSRange to UITextRange
        guard let start = textView.position(from: textView.beginningOfDocument, offset: match.range.location),
              let end = textView.position(from: start, offset: match.range.length),
              let textRange = textView.textRange(from: start, to: end) else {
            return
        }
        
        // Get the rect for the match
        let rect = textView.firstRect(for: textRange)
        
        // Scroll to make the rect visible
        textView.scrollRectToVisible(rect, animated: true)
    }
    
    // MARK: - Replace Operations
    
    /// Replace the current match
    func replaceCurrentMatch() -> Bool {
        guard !matches.isEmpty,
              currentMatchIndex < matches.count,
              let textView = textView,
              let textStorage = textStorage else {
            return false
        }
        
        let match = matches[currentMatchIndex]
        
        // Perform replacement
        let newText = searchEngine.replace(
            in: textStorage.string,
            at: match.range,
            with: replaceText
        )
        
        // Update text storage
        textStorage.replaceCharacters(in: match.range, with: replaceText)
        
        // Re-perform search to update matches
        performSearch()
        
        return true
    }
    
    /// Replace all matches
    func replaceAllMatches() -> Int {
        guard !matches.isEmpty,
              let textStorage = textStorage else {
            return 0
        }
        
        let replaceCount = matches.count
        
        // Perform replacement (search engine handles descending order)
        let newText = searchEngine.replaceAll(
            in: textStorage.string,
            matches: matches,
            with: replaceText
        )
        
        // Update text storage
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.replaceCharacters(in: fullRange, with: newText)
        
        // Clear search (no more matches)
        matches = []
        totalMatches = 0
        currentMatchIndex = 0
        clearHighlights()
        
        return replaceCount
    }
    
    /// Replace with regex (including capture groups)
    func replaceWithRegex() -> Bool {
        guard isRegex,
              let textStorage = textStorage,
              let newText = searchEngine.replaceWithRegex(
                in: textStorage.string,
                pattern: searchText,
                template: replaceText
              ) else {
            return false
        }
        
        // Update text storage
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.replaceCharacters(in: fullRange, with: newText)
        
        // Re-perform search
        performSearch()
        
        return true
    }
    
    // MARK: - Computed Properties
    
    /// Current match description (e.g., "3 of 12")
    var matchCountText: String {
        guard totalMatches > 0 else { return "No matches" }
        return "\(currentMatchIndex + 1) of \(totalMatches)"
    }
    
    /// Check if there are any matches
    var hasMatches: Bool {
        totalMatches > 0
    }
    
    /// Check if current match can be replaced (not on locked version)
    var canReplace: Bool {
        hasMatches && !searchText.isEmpty
    }
}

// MARK: - TextView Coordinator

extension InEditorSearchManager {
    
    /// Connect to a text view
    func connect(to textView: UITextView) {
        self.textView = textView
        self.textStorage = textView.textStorage
    }
    
    /// Disconnect from text view
    func disconnect() {
        clearHighlights()
        self.textView = nil
        self.textStorage = nil
    }
}
