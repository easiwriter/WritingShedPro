//
//  InEditorSearchManagerTests.swift
//  Writing Shed ProTests
//
//  Created on 4 December 2025.
//  Feature 017: Search and Replace - Search Manager Tests
//

import XCTest
import UIKit
@testable import Writing_Shed_Pro

@MainActor
final class InEditorSearchManagerTests: XCTestCase {
    
    var manager: InEditorSearchManager!
    var textView: UITextView!
    
    override func setUp() async throws {
        try await super.setUp()
        manager = InEditorSearchManager()
        textView = UITextView()
        textView.text = "The quick brown fox jumps over the lazy dog. The fox is quick."
        manager.connect(to: textView)
    }
    
    override func tearDown() async throws {
        manager.disconnect()
        manager = nil
        textView = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(manager.searchText, "")
        XCTAssertEqual(manager.replaceText, "")
        XCTAssertEqual(manager.currentMatchIndex, 0)
        XCTAssertEqual(manager.totalMatches, 0)
        XCTAssertFalse(manager.isReplaceMode)
        XCTAssertFalse(manager.isCaseSensitive)
        XCTAssertFalse(manager.isWholeWord)
        XCTAssertFalse(manager.isRegex)
    }
    
    func testConnectionToTextView() {
        XCTAssertNotNil(manager.textView)
        XCTAssertNotNil(manager.textStorage)
        XCTAssertTrue(manager.textView === textView)
    }
    
    func testDisconnection() {
        manager.disconnect()
        
        XCTAssertNil(manager.textView)
        XCTAssertNil(manager.textStorage)
    }
    
    // MARK: - Search Tests
    
    func testPerformSearchFindsMatches() {
        manager.searchText = "fox"
        
        // Wait for debounce
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 2)
        XCTAssertEqual(manager.currentMatchIndex, 0)
    }
    
    func testPerformSearchWithNoMatches() {
        manager.searchText = "elephant"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 0)
    }
    
    func testSearchWithEmptyText() {
        manager.searchText = ""
        
        XCTAssertEqual(manager.totalMatches, 0)
        XCTAssertFalse(manager.hasMatches)
    }
    
    func testCaseSensitiveSearch() {
        manager.isCaseSensitive = true
        manager.searchText = "The"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 2) // "The" appears twice
    }
    
    func testCaseInsensitiveSearch() {
        manager.isCaseSensitive = false
        manager.searchText = "the"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 3) // "The" and "the"
    }
    
    func testWholeWordSearch() {
        textView.text = "The fox and foxes"
        manager.isWholeWord = true
        manager.searchText = "fox"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 1) // Only "fox", not "foxes"
    }
    
    func testRegexSearch() {
        textView.text = "Numbers: 123 and 456"
        manager.isRegex = true
        manager.searchText = "\\d+"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 2)
        XCTAssertNil(manager.regexError)
    }
    
    func testRegexInvalidPattern() {
        manager.isRegex = true
        manager.searchText = "[invalid("
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 0)
        XCTAssertNotNil(manager.regexError)
    }
    
    // MARK: - Navigation Tests
    
    func testNextMatch() {
        manager.searchText = "fox"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.currentMatchIndex, 0)
        
        manager.nextMatch()
        XCTAssertEqual(manager.currentMatchIndex, 1)
        
        manager.nextMatch()
        XCTAssertEqual(manager.currentMatchIndex, 0) // Circular
    }
    
    func testPreviousMatch() {
        manager.searchText = "fox"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.currentMatchIndex, 0)
        
        manager.previousMatch()
        XCTAssertEqual(manager.currentMatchIndex, 1) // Circular to end
        
        manager.previousMatch()
        XCTAssertEqual(manager.currentMatchIndex, 0)
    }
    
    func testNavigationWithNoMatches() {
        manager.searchText = "elephant"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        manager.nextMatch()
        XCTAssertEqual(manager.currentMatchIndex, 0)
        
        manager.previousMatch()
        XCTAssertEqual(manager.currentMatchIndex, 0)
    }
    
    // MARK: - Replace Tests
    
    func testReplaceCurrentMatch() {
        manager.searchText = "fox"
        manager.replaceText = "cat"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.totalMatches, 2)
        
        let success = manager.replaceCurrentMatch()
        
        XCTAssertTrue(success)
        XCTAssertTrue(textView.text.contains("cat"))
    }
    
    func testReplaceAllMatches() {
        manager.searchText = "fox"
        manager.replaceText = "cat"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let replaceCount = manager.replaceAllMatches()
        
        XCTAssertEqual(replaceCount, 2)
        XCTAssertEqual(manager.totalMatches, 0)
        XCTAssertFalse(textView.text.contains("fox"))
        XCTAssertTrue(textView.text.contains("cat"))
    }
    
    func testReplaceWithNoMatches() {
        manager.searchText = "elephant"
        manager.replaceText = "cat"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let success = manager.replaceCurrentMatch()
        
        XCTAssertFalse(success)
    }
    
    // MARK: - Clear Search Tests
    
    func testClearSearch() {
        manager.searchText = "fox"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(manager.totalMatches, 0)
        
        manager.clearSearch()
        
        XCTAssertEqual(manager.searchText, "")
        XCTAssertEqual(manager.totalMatches, 0)
        XCTAssertEqual(manager.currentMatchIndex, 0)
    }
    
    // MARK: - Computed Properties Tests
    
    func testMatchCountText() {
        XCTAssertEqual(manager.matchCountText, "No matches")
        
        manager.searchText = "fox"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(manager.matchCountText, "1 of 2")
        
        manager.nextMatch()
        XCTAssertEqual(manager.matchCountText, "2 of 2")
    }
    
    func testHasMatches() {
        XCTAssertFalse(manager.hasMatches)
        
        manager.searchText = "fox"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(manager.hasMatches)
    }
    
    func testCanReplace() {
        XCTAssertFalse(manager.canReplace)
        
        manager.searchText = "fox"
        
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(manager.canReplace)
    }
    
    // MARK: - Options Change Tests
    
    func testChangingOptionsTriggersNewSearch() {
        manager.searchText = "the"
        
        let expectation1 = XCTestExpectation(description: "Initial search")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        let initialCount = manager.totalMatches
        
        manager.isCaseSensitive = true
        
        let expectation2 = XCTestExpectation(description: "Re-search after option change")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        XCTAssertNotEqual(manager.totalMatches, initialCount)
    }
}
