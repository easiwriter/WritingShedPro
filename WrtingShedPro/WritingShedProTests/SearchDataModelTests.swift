//
//  SearchDataModelTests.swift
//  Writing Shed ProTests
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace - Data Model Tests
//

import XCTest
@testable import Writing_Shed_Pro

final class SearchDataModelTests: XCTestCase {
    
    // MARK: - SearchQuery Tests
    
    func testSearchQueryInitialization() {
        let query = SearchQuery(searchText: "test")
        
        XCTAssertEqual(query.searchText, "test")
        XCTAssertNil(query.replaceText)
        XCTAssertFalse(query.isCaseSensitive)
        XCTAssertFalse(query.isWholeWord)
        XCTAssertFalse(query.isRegex)
        XCTAssertEqual(query.scope, .currentFile)
    }
    
    func testSearchQueryIsReplaceMode() {
        var query = SearchQuery(searchText: "find")
        XCTAssertFalse(query.isReplaceMode)
        
        query.replaceText = "replace"
        XCTAssertTrue(query.isReplaceMode)
    }
    
    func testSearchQueryIsValidForSearch() {
        let validQuery = SearchQuery(searchText: "test")
        XCTAssertTrue(validQuery.isValidForSearch)
        
        let invalidQuery = SearchQuery(searchText: "")
        XCTAssertFalse(invalidQuery.isValidForSearch)
    }
    
    func testSearchQueryCodable() throws {
        let original = SearchQuery(
            searchText: "test",
            replaceText: "replacement",
            isCaseSensitive: true,
            isWholeWord: true,
            isRegex: false,
            scope: .project
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SearchQuery.self, from: encoded)
        
        XCTAssertEqual(decoded.searchText, original.searchText)
        XCTAssertEqual(decoded.replaceText, original.replaceText)
        XCTAssertEqual(decoded.isCaseSensitive, original.isCaseSensitive)
        XCTAssertEqual(decoded.isWholeWord, original.isWholeWord)
        XCTAssertEqual(decoded.isRegex, original.isRegex)
        XCTAssertEqual(decoded.scope, original.scope)
    }
    
    // MARK: - SearchScope Tests
    
    func testSearchScopeAllCases() {
        let allCases = SearchScope.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.currentFile))
        XCTAssertTrue(allCases.contains(.collection))
        XCTAssertTrue(allCases.contains(.project))
    }
    
    func testSearchScopeDescription() {
        XCTAssertEqual(SearchScope.currentFile.description, "Current File")
        XCTAssertEqual(SearchScope.collection.description, "Collection")
        XCTAssertEqual(SearchScope.project.description, "Project")
    }
    
    // MARK: - SearchMatch Tests
    
    func testSearchMatchInitialization() {
        let range = NSRange(location: 5, length: 4)
        let match = SearchMatch(
            range: range,
            context: "Find test here",
            lineNumber: 1
        )
        
        XCTAssertEqual(match.range, range)
        XCTAssertEqual(match.context, "Find test here")
        XCTAssertEqual(match.lineNumber, 1)
    }
    
    func testSearchMatchMatchedText() {
        let text = "Find test here"
        let match = SearchMatch(
            range: NSRange(location: 5, length: 4),
            context: "Find test here",
            lineNumber: 1
        )
        
        XCTAssertEqual(match.extractMatchedText(from: text), "test")
    }
    
    func testSearchMatchHashable() {
        let match1 = SearchMatch(
            id: UUID(),
            range: NSRange(location: 0, length: 4),
            context: "test",
            lineNumber: 1
        )
        
        let match2 = SearchMatch(
            id: match1.id,
            range: NSRange(location: 0, length: 4),
            context: "test",
            lineNumber: 1
        )
        
        XCTAssertEqual(match1, match2)
    }
    
    // MARK: - SearchOptions Tests
    
    func testSearchOptionsInitialization() {
        let options = SearchOptions()
        
        XCTAssertFalse(options.caseSensitive)
        XCTAssertFalse(options.wholeWord)
        XCTAssertFalse(options.useRegex)
        XCTAssertTrue(options.searchHistory.isEmpty)
        XCTAssertTrue(options.replaceHistory.isEmpty)
        XCTAssertEqual(options.lastUsedScope, .currentFile)
    }
    
    func testSearchOptionsAddSearchHistory() {
        var options = SearchOptions()
        
        options.addSearchHistory("first")
        options.addSearchHistory("second")
        options.addSearchHistory("third")
        
        XCTAssertEqual(options.searchHistory.count, 3)
        XCTAssertEqual(options.searchHistory[0], "third")  // Most recent first
        XCTAssertEqual(options.searchHistory[1], "second")
        XCTAssertEqual(options.searchHistory[2], "first")
    }
    
    func testSearchOptionsAddSearchHistoryRemovesDuplicates() {
        var options = SearchOptions()
        
        options.addSearchHistory("test")
        options.addSearchHistory("other")
        options.addSearchHistory("test")  // Duplicate
        
        XCTAssertEqual(options.searchHistory.count, 2)
        XCTAssertEqual(options.searchHistory[0], "test")  // Moved to front
        XCTAssertEqual(options.searchHistory[1], "other")
    }
    
    func testSearchOptionsAddSearchHistoryLimitsSize() {
        var options = SearchOptions()
        
        // Add more than max items
        for i in 1...25 {
            options.addSearchHistory("item\(i)")
        }
        
        XCTAssertEqual(options.searchHistory.count, SearchOptions.maxHistoryItems)
        XCTAssertEqual(options.searchHistory[0], "item25")  // Most recent
    }
    
    func testSearchOptionsAddReplaceHistory() {
        var options = SearchOptions()
        
        options.addReplaceHistory("first")
        options.addReplaceHistory("second")
        
        XCTAssertEqual(options.replaceHistory.count, 2)
        XCTAssertEqual(options.replaceHistory[0], "second")  // Most recent first
        XCTAssertEqual(options.replaceHistory[1], "first")
    }
    
    func testSearchOptionsClearHistory() {
        var options = SearchOptions()
        
        options.addSearchHistory("test1")
        options.addReplaceHistory("replace1")
        
        options.clearHistory()
        
        XCTAssertTrue(options.searchHistory.isEmpty)
        XCTAssertTrue(options.replaceHistory.isEmpty)
    }
    
    func testSearchOptionsCodable() throws {
        var original = SearchOptions()
        original.caseSensitive = true
        original.wholeWord = false
        original.useRegex = true
        original.addSearchHistory("test")
        original.addReplaceHistory("replacement")
        original.lastUsedScope = .project
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SearchOptions.self, from: encoded)
        
        XCTAssertEqual(decoded.caseSensitive, original.caseSensitive)
        XCTAssertEqual(decoded.wholeWord, original.wholeWord)
        XCTAssertEqual(decoded.useRegex, original.useRegex)
        XCTAssertEqual(decoded.searchHistory, original.searchHistory)
        XCTAssertEqual(decoded.replaceHistory, original.replaceHistory)
        XCTAssertEqual(decoded.lastUsedScope, original.lastUsedScope)
    }
    
    // MARK: - SearchOptionsStore Tests
    
    func testSearchOptionsStoreSingleton() {
        let store1 = SearchOptionsStore.shared
        let store2 = SearchOptionsStore.shared
        
        XCTAssertTrue(store1 === store2)
    }
    
    func testSearchOptionsStoreReset() {
        let store = SearchOptionsStore.shared
        
        store.options.caseSensitive = true
        store.options.useRegex = true
        store.options.addSearchHistory("test")
        
        store.reset()
        
        XCTAssertFalse(store.options.caseSensitive)
        XCTAssertFalse(store.options.useRegex)
        XCTAssertTrue(store.options.searchHistory.isEmpty)
    }
}
