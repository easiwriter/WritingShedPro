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
import Observation

/// Manages search and replace operations within the active text editor
@MainActor
@Observable
class InEditorSearchManager {
    
    // MARK: - Observable Properties
    
    // Search text is debounced in setupDebouncing() to avoid performance issues
    // with searches triggering on every keystroke (e.g., "i" finding 1959 matches)
    var searchText: String = "" {
        didSet {
            // Debouncing is handled by Combine publisher
            debounceSubject.send(searchText)
        }
    }
    
    var replaceText: String = ""
    var currentMatchIndex: Int = 0
    var totalMatches: Int = 0
    var isReplaceMode: Bool = false
    
    // Options trigger immediate search since they're toggled, not typed
    var isCaseSensitive: Bool = false {
        didSet {
            if isCaseSensitive != oldValue {
                performSearch()
            }
        }
    }
    
    var isWholeWord: Bool = false {
        didSet {
            if isWholeWord != oldValue {
                performSearch()
            }
        }
    }
    
    var isRegex: Bool = false {
        didSet {
            if isRegex != oldValue {
                performSearch()
            }
        }
    }
    
    var regexError: String?
    
    // MARK: - Private Properties
    
    private let searchEngine = TextSearchEngine()
    private var matches: [SearchMatch] = []
    private var cancellables = Set<AnyCancellable>()
    private var textChangeObserver: NSObjectProtocol?
    
    // Track which ranges we actually highlighted so we can clear only those
    private var highlightedRanges: [NSRange] = []
    
    // Subject for debouncing search text changes
    private let debounceSubject = PassthroughSubject<String, Never>()
    
    // Flag to prevent duplicate undo commands during batch replace
    private(set) var isPerformingBatchReplace: Bool = false
    
    weak var textView: UITextView?
    weak var textStorage: NSTextStorage?
    
    // Reference to the custom undo manager (needed to clear undo stack after Replace All)
    weak var customUndoManager: TextFileUndoManager?
    
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
        debounceSubject
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
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔍 performSearch called: searchText='\(searchText)'")
        print("  - textView: \(textView != nil ? "✅" : "❌")")
        print("  - textStorage: \(textStorage != nil ? "✅" : "❌")")
        
        guard !searchText.isEmpty else {
            clearSearch()
            return
        }
        
        // Use textStorage.string if available (more reliable during batch operations)
        // Otherwise fall back to textView.text
        guard let text = textStorage?.string ?? textView?.text else {
            clearSearch()
            return
        }
        
        // Note: clearHighlights() is now integrated into highlightMatches() for performance
        // This avoids two separate beginEditing/endEditing cycles
        
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
        let searchStart = CFAbsoluteTimeGetCurrent()
        let foundMatches = searchEngine.search(in: text, query: query)
        let searchTime = CFAbsoluteTimeGetCurrent() - searchStart
        print("  ⏱️ search: \(String(format: "%.3f", searchTime))s")
        
        print("  - Found \(foundMatches.count) matches")
        
        // CRITICAL PERFORMANCE: Batch all UI updates together
        // Temporarily store results, then update all @Published properties at once
        let updateStart = CFAbsoluteTimeGetCurrent()
        
        matches = foundMatches
        
        // Update UI state in one batch to avoid multiple SwiftUI redraws
        if !matches.isEmpty {
            currentMatchIndex = 0
            totalMatches = matches.count
            
            let highlightStart = CFAbsoluteTimeGetCurrent()
            highlightMatches()
            let highlightTime = CFAbsoluteTimeGetCurrent() - highlightStart
            print("  ⏱️ highlightMatches: \(String(format: "%.3f", highlightTime))s")
            
            let scrollStart = CFAbsoluteTimeGetCurrent()
            scrollToCurrentMatch()
            let scrollTime = CFAbsoluteTimeGetCurrent() - scrollStart
            print("  ⏱️ scrollToCurrentMatch: \(String(format: "%.3f", scrollTime))s")
        } else {
            currentMatchIndex = 0
            totalMatches = 0
        }
        
        let updateTime = CFAbsoluteTimeGetCurrent() - updateStart
        print("  ⏱️ UI updates: \(String(format: "%.3f", updateTime))s")
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("  ⏱️ TOTAL performSearch: \(String(format: "%.3f", totalTime))s")
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
        
        // Performance optimization: Only highlight first 500 matches + current match
        // This prevents beach ball when searching for common characters like "i"
        let maxHighlights = 500
        let shouldLimitHighlights = matches.count > maxHighlights
        
        // CRITICAL PERFORMANCE: Do EVERYTHING in one beginEditing/endEditing block
        textStorage.beginEditing()
        
        // First, clear old highlights if any exist
        if !highlightedRanges.isEmpty {
            for range in highlightedRanges {
                guard range.location + range.length <= textStorage.length else { continue }
                textStorage.removeAttribute(.backgroundColor, range: range)
                textStorage.removeAttribute(.underlineStyle, range: range)
                textStorage.removeAttribute(.underlineColor, range: range)
            }
            highlightedRanges.removeAll()
        }
        
        // Then add new highlights
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
            
            // Track this range so we can clear it efficiently later
            highlightedRanges.append(match.range)
        }
        
        // CRITICAL PERFORMANCE: Re-enable layout and process all changes at once
        textStorage.endEditing()
        
        if shouldLimitHighlights {
            print("⚠️ Highlighted first \(maxHighlights) of \(matches.count) matches (+ current match)")
        }
    }
    
    /// Clear all highlight attributes
    private func clearHighlights() {
        guard let textStorage = textStorage else { return }
        
        // CRITICAL PERFORMANCE: Only clear the ranges we actually highlighted
        // instead of scanning the entire document
        guard !highlightedRanges.isEmpty else { return }
        
        // PERFORMANCE OPTIMIZATION: Instead of calling removeAttribute for each range,
        // which is slow even with beginEditing/endEditing, we enumerate and remove
        // only where attributes exist
        textStorage.beginEditing()
        
        // Enumerate backgroundColor attribute (all highlights have this)
        textStorage.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, stop in
            if value != nil {
                // Remove all highlight attributes at once
                textStorage.removeAttribute(.backgroundColor, range: range)
                textStorage.removeAttribute(.underlineStyle, range: range)
                textStorage.removeAttribute(.underlineColor, range: range)
            }
        }
        
        textStorage.endEditing()
        
        // Clear the tracking array
        highlightedRanges.removeAll()
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
        
        // Explicitly perform search to update match count and UI
        // This ensures buttons disable immediately when no matches remain
        Task { @MainActor in
            performSearch()
        }
        
        return true
    }
    
    /// Replace all matches
    func replaceAllMatches() -> Int {
        guard !matches.isEmpty,
              let textView = textView,
              let textStorage = textStorage else {
            return 0
        }
        
        let replaceCount = matches.count
        
        #if DEBUG
        print("🔄 replaceAllMatches: Replacing \(replaceCount) instances of '\(searchText)' with '\(replaceText)'")
        print("🔄 replaceAllMatches: Text length before: \(textStorage.length)")
        #endif
        
        // Replace in reverse order to maintain valid ranges
        // Sort matches by location in descending order
        let sortedMatches = matches.sorted { $0.range.location > $1.range.location }
        
        // CRITICAL: Temporarily remove notification observer to prevent infinite loops
        // textStorage.endEditing() posts notifications that can trigger more text changes
        // which can cause freezes and undo command creation
        if let observer = textChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            textChangeObserver = nil
        }
        
        // CRITICAL: Set flag FIRST before any other operations
        isPerformingBatchReplace = true
        
        // Check if undo registration is currently enabled (so we can restore it later)
        let wasUndoEnabled = textView.undoManager?.isUndoRegistrationEnabled ?? false
        
        #if DEBUG
        print("🔄 replaceAllMatches: wasUndoEnabled = \(wasUndoEnabled)")
        #endif
        
        // Disable undo registration if it's enabled
        if wasUndoEnabled {
            #if DEBUG
            print("🔄 replaceAllMatches: Calling disableUndoRegistration()")
            #endif
            textView.undoManager?.disableUndoRegistration()
        }
        
        // NOTE: We do NOT call removeAllActions() here because it internally calls
        // enableUndoRegistration() which would unbalance our disable/enable pairs
        
        // Use textStorage.beginEditing/endEditing to batch all replacements efficiently
        textStorage.beginEditing()
        
        for match in sortedMatches {
            // Validate range is still valid
            guard match.range.location + match.range.length <= textStorage.length else {
                continue
            }
            textStorage.replaceCharacters(in: match.range, with: replaceText)
        }
        
        textStorage.endEditing()
        
        #if DEBUG
        print("🔄 replaceAllMatches: Completed \(replaceCount) replacements")
        print("🔄 replaceAllMatches: Text in storage after replace: '\(textStorage.string.prefix(50))'")
        #endif
        
        // CRITICAL: Clear old highlights immediately after replacements
        clearHighlights()
        
        // CRITICAL: Update the search to recalculate matches based on the new text
        performSearch()
        
        #if DEBUG
        print("🔄 replaceAllMatches: After performSearch, totalMatches=\(totalMatches)")
        #endif
        
        #if DEBUG
        print("🔄 replaceAllMatches: Cleanup")
        print("🔄 replaceAllMatches: wasUndoEnabled = \(wasUndoEnabled)")
        #endif
        
        // Re-enable undo registration ONLY if it was enabled before
        // Wrap in try-catch because UITextView's undo manager state can be unpredictable
        if wasUndoEnabled {
            #if DEBUG
            print("🔄 replaceAllMatches: Attempting to re-enable undo registration")
            #endif
            
            // Check if it's actually disabled before trying to enable
            if textView.undoManager?.isUndoRegistrationEnabled == false {
                textView.undoManager?.enableUndoRegistration()
                #if DEBUG
                print("🔄 replaceAllMatches: Re-enabled undo registration")
                #endif
            } else {
                #if DEBUG
                print("🔄 replaceAllMatches: Undo registration already enabled, skipping")
                #endif
            }
        }
        
        // Clear the flag so future text changes work normally
        isPerformingBatchReplace = false
        
        #if DEBUG
        print("🔄 replaceAllMatches: Cleanup complete")
        #endif
        
        // CRITICAL: Reconnect the notification observer
        // We removed it at the start to prevent notification loops during batch replace
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
        
        #if DEBUG
        print("🔄 replaceAllMatches: Complete - replaced \(replaceCount) matches")
        print("🔄 replaceAllMatches: Reconnected notification observer")
        #endif
        
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
        #if DEBUG
        print("🔍 disconnect() called - clearing search state")
        #endif
        
        // Clear search state first
        matches = []
        totalMatches = 0
        currentMatchIndex = 0
        
        // Clear highlights if we still have access to textStorage
        if textStorage != nil {
            clearHighlights()
        }
        
        // Remove text change observer
        if let observer = textChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            textChangeObserver = nil
        }
        
        self.textView = nil
        self.textStorage = nil
        
        #if DEBUG
        print("🔍 disconnect() completed")
        #endif
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
