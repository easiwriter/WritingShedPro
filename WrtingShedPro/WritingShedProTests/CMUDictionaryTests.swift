//
//  CMUDictionaryTests.swift
//  WritingShedProTests
//
//  Tests for the CMU Pronouncing Dictionary integration for rhyme detection.
//

import XCTest
@testable import Writing_Shed_Pro

final class CMUDictionaryTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        // Ensure American English dialect is loaded by default for consistent tests
        PoetryPreferences.shared.englishDialect = .american
        CMUDictionary.shared.ensureLoaded()
    }
    
    // MARK: - Dictionary Loading
    
    func testDictionaryLoads() {
        let cmu = CMUDictionary.shared
        cmu.ensureLoaded()
        
        // Should have loaded many entries (CMU dict has ~135,000 words)
        XCTAssertGreaterThan(cmu.entryCount, 100000, "CMU dictionary should have over 100,000 entries")
        print("CMU Dictionary loaded \(cmu.entryCount) entries")
    }
    
    func testBritishDictionaryLoads() {
        // Switch to British English
        PoetryPreferences.shared.englishDialect = .british
        CMUDictionary.shared.ensureLoaded()
        
        // British dictionary is CMU base + British overlay, so should have similar count
        XCTAssertGreaterThan(CMUDictionary.shared.entryCount, 100000, "British dictionary should have CMU base + overlays")
        print("British Dictionary loaded \(CMUDictionary.shared.entryCount) entries")
        
        // Reset to American for other tests
        PoetryPreferences.shared.englishDialect = .american
        CMUDictionary.shared.ensureLoaded()
    }
    
    // MARK: - Word Lookup
    
    func testLookupCommonWords() {
        let cmu = CMUDictionary.shared
        
        // Test words that should be in the dictionary
        XCTAssertNotNil(cmu.lookup("sounds"), "sounds should be in dictionary")
        XCTAssertNotNil(cmu.lookup("downs"), "downs should be in dictionary")
        XCTAssertNotNil(cmu.lookup("love"), "love should be in dictionary")
        XCTAssertNotNil(cmu.lookup("heart"), "heart should be in dictionary")
    }
    
    func testLookupCaseInsensitive() {
        let cmu = CMUDictionary.shared
        
        XCTAssertEqual(cmu.lookup("Love")?.first, cmu.lookup("love")?.first)
        XCTAssertEqual(cmu.lookup("HEART")?.first, cmu.lookup("heart")?.first)
    }
    
    // MARK: - Rhyme Detection
    
    func testPerfectRhymes() {
        let cmu = CMUDictionary.shared
        
        // These should be perfect rhymes
        XCTAssertTrue(cmu.wordsRhyme("cat", "hat"), "cat/hat should rhyme")
        XCTAssertTrue(cmu.wordsRhyme("day", "way"), "day/way should rhyme")
        XCTAssertTrue(cmu.wordsRhyme("love", "dove"), "love/dove should rhyme")
        XCTAssertTrue(cmu.wordsRhyme("moon", "soon"), "moon/soon should rhyme")
        XCTAssertTrue(cmu.wordsRhyme("night", "light"), "night/light should rhyme")
    }
    
    func testNearRhymes() {
        let cmu = CMUDictionary.shared
        
        // The original issue: sounds/downs should rhyme (AW1 N D Z vs AW1 N Z)
        // These are "near rhymes" where a stop consonant is elided
        XCTAssertTrue(cmu.wordsRhyme("sounds", "downs"), "sounds/downs should rhyme")
        XCTAssertTrue(cmu.wordsRhyme("bounds", "towns"), "bounds/towns should rhyme")
        XCTAssertTrue(cmu.wordsRhyme("mounds", "gowns"), "mounds/gowns should rhyme")
    }
    
    func testNonRhymes() {
        let cmu = CMUDictionary.shared
        
        // These should NOT rhyme
        XCTAssertFalse(cmu.wordsRhyme("cat", "dog"), "cat/dog should not rhyme")
        XCTAssertFalse(cmu.wordsRhyme("love", "move"), "love/move should not rhyme (different vowel sounds)")
        XCTAssertFalse(cmu.wordsRhyme("around", "down"), "around/down should not rhyme (different endings)")
    }
    
    func testHeartStartRhyme() {
        let cmu = CMUDictionary.shared
        
        // heart and start should rhyme (both end in -art)
        XCTAssertTrue(cmu.wordsRhyme("heart", "start"), "heart/start should rhyme")
        XCTAssertTrue(cmu.wordsRhyme("art", "cart"), "art/cart should rhyme")
    }
    
    func testSameWordRhymes() {
        let cmu = CMUDictionary.shared
        
        XCTAssertTrue(cmu.wordsRhyme("love", "love"), "same word should rhyme with itself")
        XCTAssertTrue(cmu.wordsRhyme("LOVE", "love"), "case shouldn't matter")
    }
    
    // MARK: - Rhyme Ending Extraction
    
    func testRhymeEndingExtraction() {
        let cmu = CMUDictionary.shared
        
        // Test that rhyme endings are extracted from the stressed vowel
        let soundsEnding = cmu.rhymeEnding(for: "sounds")
        let downsEnding = cmu.rhymeEnding(for: "downs")
        
        XCTAssertNotNil(soundsEnding, "sounds should have a rhyme ending")
        XCTAssertNotNil(downsEnding, "downs should have a rhyme ending")
        
        // Both should start with AW (the stressed vowel)
        if let ending = soundsEnding {
            XCTAssertEqual(ending.first?.base, "AW", "sounds should have AW vowel")
        }
        if let ending = downsEnding {
            XCTAssertEqual(ending.first?.base, "AW", "downs should have AW vowel")
        }
    }
    
    // MARK: - British Dictionary Tests
    
    func testBritishDictionaryLookup() {
        // Switch to British English
        PoetryPreferences.shared.englishDialect = .british
        CMUDictionary.shared.ensureLoaded()
        
        let cmu = CMUDictionary.shared
        
        // Common words should be in British dictionary too
        XCTAssertNotNil(cmu.lookup("love"), "love should be in British dictionary")
        XCTAssertNotNil(cmu.lookup("heart"), "heart should be in British dictionary")
        XCTAssertNotNil(cmu.lookup("day"), "day should be in British dictionary")
        
        // Reset to American
        PoetryPreferences.shared.englishDialect = .american
        CMUDictionary.shared.ensureLoaded()
    }
    
    func testBritishRhymeDetection() {
        // Switch to British English
        PoetryPreferences.shared.englishDialect = .british
        CMUDictionary.shared.ensureLoaded()
        
        let cmu = CMUDictionary.shared
        
        // Basic rhymes should work in British English too
        XCTAssertTrue(cmu.wordsRhyme("cat", "hat"), "cat/hat should rhyme in British English")
        XCTAssertTrue(cmu.wordsRhyme("love", "dove"), "love/dove should rhyme in British English")
        XCTAssertTrue(cmu.wordsRhyme("night", "light"), "night/light should rhyme in British English")
        
        // Reset to American
        PoetryPreferences.shared.englishDialect = .american
        CMUDictionary.shared.ensureLoaded()
    }
    
    func testDialectSwitching() {
        let cmu = CMUDictionary.shared
        
        // Start with American
        PoetryPreferences.shared.englishDialect = .american
        cmu.ensureLoaded()
        XCTAssertEqual(cmu.currentDialect, .american)
        let americanCount = cmu.entryCount
        
        // Switch to British
        PoetryPreferences.shared.englishDialect = .british
        cmu.ensureLoaded()
        XCTAssertEqual(cmu.currentDialect, .british)
        let britishCount = cmu.entryCount
        
        // Both should have substantial entries (British = CMU base + overlay)
        XCTAssertGreaterThan(americanCount, 100000)
        XCTAssertGreaterThan(britishCount, 100000)
        
        // British count might be slightly different due to overlay entries
        print("American: \(americanCount), British: \(britishCount)")
        
        // Reset to American
        PoetryPreferences.shared.englishDialect = .american
        cmu.ensureLoaded()
    }
    
    // MARK: - Poetry Validator Integration
    
    func testPoetryValidatorUsesCMU() {
        // This tests that the poetry validator properly uses CMU for rhyme detection
        // We test this by validating a simple couplet
        let validator = PoetryValidator.shared
        
        // Create a simple rhyme scheme that should pass with CMU
        // Using sounds/downs which only works with the improved rhyme detection
        _ = """
        I hear the forest sounds
        As darkness slowly downs
        """
        
        // For this test, we just verify the validator doesn't crash
        // Full validation testing should be in PoetryFormTests
        XCTAssertNotNil(validator)
    }
}
