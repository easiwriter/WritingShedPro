//
//  TextSearchEngineTests.swift
//  Writing Shed ProTests
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace - Search Engine Tests
//

import XCTest
@testable import Writing_Shed_Pro

final class TextSearchEngineTests: XCTestCase {
    
    var engine: TextSearchEngine!
    
    override func setUp() {
        super.setUp()
        engine = TextSearchEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Basic Search Tests
    
    func testSearchFindsSimpleMatch() {
        let text = "The quick brown fox jumps over the lazy dog"
        let query = SearchQuery(searchText: "fox")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].range.location, 16)
        XCTAssertEqual(matches[0].range.length, 3)
    }
    
    func testSearchFindsMultipleMatches() {
        let text = "The fox and the fox ran away"
        let query = SearchQuery(searchText: "fox")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].range.location, 4)
        XCTAssertEqual(matches[1].range.location, 16)
    }
    
    func testSearchWithEmptyTextReturnsNoMatches() {
        let query = SearchQuery(searchText: "test")
        let matches = engine.search(in: "", query: query)
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testSearchWithEmptyQueryReturnsNoMatches() {
        let text = "Some text here"
        let query = SearchQuery(searchText: "")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testSearchWithNoMatchesReturnsEmpty() {
        let text = "The quick brown fox"
        let query = SearchQuery(searchText: "elephant")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    // MARK: - Case Sensitivity Tests
    
    func testSearchCaseInsensitiveByDefault() {
        let text = "The FOX and the fox"
        let query = SearchQuery(searchText: "fox", isCaseSensitive: false)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 2)
    }
    
    func testSearchCaseSensitive() {
        let text = "The FOX and the fox"
        let query = SearchQuery(searchText: "fox", isCaseSensitive: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].range.location, 16)
    }
    
    func testSearchCaseSensitiveNoMatch() {
        let text = "The FOX jumps"
        let query = SearchQuery(searchText: "fox", isCaseSensitive: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    // MARK: - Whole Word Tests
    
    func testSearchWholeWordMatch() {
        let text = "The fox and foxes"
        let query = SearchQuery(searchText: "fox", isWholeWord: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].range.location, 4)
    }
    
    func testSearchWholeWordWithPunctuation() {
        let text = "Hello, world! How are you?"
        let query = SearchQuery(searchText: "world", isWholeWord: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].range.location, 7)
    }
    
    func testSearchWholeWordAtStartOfText() {
        let text = "fox runs fast"
        let query = SearchQuery(searchText: "fox", isWholeWord: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].range.location, 0)
    }
    
    func testSearchWholeWordAtEndOfText() {
        let text = "The quick fox"
        let query = SearchQuery(searchText: "fox", isWholeWord: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].range.location, 10)
    }
    
    func testSearchWholeWordExcludesPartialMatches() {
        let text = "foxes, fox, foxy"
        let query = SearchQuery(searchText: "fox", isWholeWord: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].range.location, 7)
    }
    
    // MARK: - Context Extraction Tests
    
    func testContextExtractionSimple() {
        let text = "The quick brown fox jumps over the lazy dog"
        let query = SearchQuery(searchText: "fox")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertFalse(matches[0].context.isEmpty)
        XCTAssertTrue(matches[0].context.contains("fox"))
    }
    
    func testContextExtractionAtStartOfText() {
        let text = "Test string with more content after"
        let query = SearchQuery(searchText: "Test")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertFalse(matches[0].context.hasPrefix("..."))
    }
    
    func testContextExtractionAtEndOfText() {
        let text = "Content before the end"
        let query = SearchQuery(searchText: "end")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertFalse(matches[0].context.hasSuffix("..."))
    }
    
    func testContextExtractionWithNewlines() {
        let text = "Line one\nLine two has fox\nLine three"
        let query = SearchQuery(searchText: "fox")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        // Newlines should be replaced with spaces
        XCTAssertFalse(matches[0].context.contains("\n"))
    }
    
    // MARK: - Line Number Tests
    
    func testLineNumberFirstLine() {
        let text = "First line\nSecond line"
        let query = SearchQuery(searchText: "First")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].lineNumber, 1)
    }
    
    func testLineNumberSecondLine() {
        let text = "First line\nSecond line"
        let query = SearchQuery(searchText: "Second")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].lineNumber, 2)
    }
    
    func testLineNumberMultipleLines() {
        let text = "Line 1\nLine 2\nLine 3 with test\nLine 4"
        let query = SearchQuery(searchText: "test")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].lineNumber, 3)
    }
    
    // MARK: - Special Characters Tests
    
    func testSearchWithSpecialCharacters() {
        let text = "Price: $19.99 for this item"
        let query = SearchQuery(searchText: "$19.99")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
    }
    
    func testSearchWithUnicode() {
        let text = "Hello 世界 and world"
        let query = SearchQuery(searchText: "世界")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
    }
    
    func testSearchWithEmoji() {
        let text = "Hello 🦊 fox emoji"
        let query = SearchQuery(searchText: "🦊")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
    }
    
    // MARK: - Regex Search Tests
    
    func testRegexSimplePattern() {
        let text = "The number is 123 and then 456"
        let query = SearchQuery(searchText: "\\d+", isRegex: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 2)
    }
    
    func testRegexEmailPattern() {
        let text = "Contact: test@example.com or admin@test.org"
        let query = SearchQuery(searchText: "\\w+@\\w+\\.\\w+", isRegex: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 2)
    }
    
    func testRegexInvalidPatternReturnsNoMatches() {
        let text = "Some text here"
        let query = SearchQuery(searchText: "[invalid(", isRegex: true)
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testValidateRegexValidPattern() {
        let error = engine.validateRegex("\\d+")
        XCTAssertNil(error)
    }
    
    func testValidateRegexInvalidPattern() {
        let error = engine.validateRegex("[invalid(")
        XCTAssertNotNil(error)
    }
    
    // MARK: - Replace Tests
    
    func testReplaceSingleMatch() {
        let text = "The fox runs fast"
        let range = NSRange(location: 4, length: 3)
        
        let result = engine.replace(in: text, at: range, with: "cat")
        
        XCTAssertEqual(result, "The cat runs fast")
    }
    
    func testReplaceAllMatches() {
        let text = "The fox and the fox"
        let query = SearchQuery(searchText: "fox")
        let matches = engine.search(in: text, query: query)
        
        let result = engine.replaceAll(in: text, matches: matches, with: "cat")
        
        XCTAssertEqual(result, "The cat and the cat")
    }
    
    func testReplaceWithShorterText() {
        let text = "Replace this word"
        let range = NSRange(location: 8, length: 4)
        
        let result = engine.replace(in: text, at: range, with: "a")
        
        XCTAssertEqual(result, "Replace a word")
    }
    
    func testReplaceWithLongerText() {
        let text = "Short text"
        let range = NSRange(location: 0, length: 5)
        
        let result = engine.replace(in: text, at: range, with: "Very long")
        
        XCTAssertEqual(result, "Very long text")
    }
    
    func testReplaceWithRegexCaptureGroups() {
        let text = "Name: John, Age: 30"
        let pattern = "(\\w+): (\\w+)"
        let template = "$1=$2"
        
        let result = engine.replaceWithRegex(in: text, pattern: pattern, template: template)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "Name=John, Age=30")
    }
    
    func testReplaceWithRegexInvalidPatternReturnsNil() {
        let text = "Some text"
        let result = engine.replaceWithRegex(in: text, pattern: "[invalid(", template: "")
        
        XCTAssertNil(result)
    }
    
    // MARK: - Edge Cases
    
    func testSearchWithVeryLongText() {
        let longText = String(repeating: "word ", count: 10000) + "target"
        let query = SearchQuery(searchText: "target")
        
        let matches = engine.search(in: longText, query: query)
        
        XCTAssertEqual(matches.count, 1)
    }
    
    func testSearchWithOverlappingMatches() {
        let text = "aaa"
        let query = SearchQuery(searchText: "aa")
        
        let matches = engine.search(in: text, query: query)
        
        // Should find "aa" at position 0, but not the overlapping "aa" at position 1
        XCTAssertEqual(matches.count, 1)
    }
    
    func testSearchMatchedTextProperty() {
        let text = "Find the word test in this sentence"
        let query = SearchQuery(searchText: "test")
        
        let matches = engine.search(in: text, query: query)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].matchedText, "test")
    }
}
