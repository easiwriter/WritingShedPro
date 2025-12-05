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
    
    // Search text is debounced in setupDebouncing() to avoid performance issues
    // with searches triggering on every keystroke (e.g., "i" finding 1959 matches)
    @Published var searchText: String = ""
    
    @Published var replaceText: String = ""
    @Published var currentMatchIndex: Int = 0
    @Published var totalMatches: Int = 0
    @Published var isReplaceMode: Bool = false
    
    // Options trigger immediate search since they're toggled, not typed
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
    private var textChangeObserver: NSObjectProtocol?
    
    weak var textView: UITextView?
    weak var textStorage: NSTextStorage?
    
    // MARK: - Public Methods for Text Change Notification
    
    /// Called by FormattedTextEditor coordinator when text changes (including undo/redo)
    /// This allows search to update even though we don't control the delegate
    func notifyTextChanged() {
        // Only re-search if we have an active search
        if !searchText.isEmpty {
            performSearch()
        }
    }
    
    // Highlight colors - accessible for color-blind users
    // All matches: Light yellow background
    private let matchHighlightColor = UIColor.systemYellow.withAlphaComponent(0.3)
    // Current match: Slightly darker yellow background + border for non-color distinction
    private let currentMatchHighlightColor = UIColor.systemYellow.withAlphaComponent(0.4)
    private let currentMatchBorderColor = UIColor.systemOrange.withAlphaComponent(0.8)
    
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
        
        // Performance optimization: Only highlight first 500 matches + current match
        // This prevents beach ball when searching for common characters like "i"
        let maxHighlights = 500
        let shouldLimitHighlights = matches.count > maxHighlights
        
        // Highlight all matches (or first 500 + current)
        for (index, match) in matches.enumerated() {
            // Always highlight current match, otherwise only first maxHighlights
            let isCurrent = (index == currentMatchIndex)
            if !isCurrent && shouldLimitHighlights && index >= maxHighlights {
                continue
            }
            
            let backgroundColor = isCurrent ? currentMatchHighlightColor : matchHighlightColor
            
            // Apply background color to all matches
            textStorage.addAttribute(.backgroundColor, value: backgroundColor, range: match.range)
            
            // Add border to current match for accessibility (color-blind users can distinguish)
            if isCurrent {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.thick.rawValue, range: match.range)
                textStorage.addAttribute(.underlineColor, value: currentMatchBorderColor, range: match.range)
            }
        }
        
        // Force textStorage to process the changes
        textStorage.edited(.editedAttributes, range: NSRange(location: 0, length: textStorage.length), changeInLength: 0)
        
        if shouldLimitHighlights {
            print("⚠️ Highlighted first \(maxHighlights) of \(matches.count) matches (+ current match)")
        }
    }
    
    /// Clear all highlight attributes
    private func clearHighlights() {
        guard let textStorage = textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        // Remove both background color and underline attributes
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.removeAttribute(.underlineStyle, range: fullRange)
        textStorage.removeAttribute(.underlineColor, range: fullRange)
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
              let textView = textView else {
            return false
        }
        
        let match = matches[currentMatchIndex]
        
        // Convert NSRange to UITextRange
        guard let textRange = textView.textRange(from: match.range) else {
            return false
        }
        
        // Use textView's replace method to ensure proper delegate calls and undo registration
        textView.replace(textRange, withText: replaceText)
        
        // Note: performSearch() will be called automatically via textDidChangeNotification
        
        return true
    }
    
    /// Replace all matches
    func replaceAllMatches() -> Int {
        guard !matches.isEmpty,
              let textView = textView else {
            return 0
        }
        
        let replaceCount = matches.count
        
        // Replace in reverse order to maintain valid ranges
        // Sort matches by location in descending order
        let sortedMatches = matches.sorted { $0.range.location > $1.range.location }
        
        // Replace each match using textView's replace method
        for match in sortedMatches {
            // Convert NSRange to UITextRange
            guard let textRange = textView.textRange(from: match.range) else {
                continue
            }
            textView.replace(textRange, withText: replaceText)
        }
        
        // Note: performSearch() will be called automatically via textDidChangeNotification
        
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
        
        // Observe text changes (including undo/redo)
        textChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Re-run search if we have an active search
            Task { @MainActor in
                if !self.searchText.isEmpty {
                    self.performSearch()
                }
            }
        }
    }
    
    /// Disconnect from text view
    func disconnect() {
        clearHighlights()
        
        // Remove text change observer
        if let observer = textChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            textChangeObserver = nil
        }
        
        self.textView = nil
        self.textStorage = nil
    }
}

// MARK: - UITextView Extension

extension UITextView {
    /// Convert NSRange to UITextRange
    func textRange(from range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length) else {
            return nil
        }
        return textRange(from: start, to: end)
    }
}
