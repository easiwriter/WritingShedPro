import XCTest
@testable import Writing_Shed_Pro

/// Unit tests for StressAnalyzer service
final class StressAnalyzerTests: XCTestCase {
    
    var sut: StressAnalyzer!
    
    override func setUp() {
        super.setUp()
        sut = StressAnalyzer.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Single Word Tests
    
    func testFunctionWordsAreUnstressed() {
        // Articles
        XCTAssertEqual(sut.analyzeWord("the").pattern, [.unstressed])
        XCTAssertEqual(sut.analyzeWord("a").pattern, [.unstressed])
        XCTAssertEqual(sut.analyzeWord("an").pattern, [.unstressed])
        
        // Prepositions
        XCTAssertEqual(sut.analyzeWord("to").pattern, [.unstressed])
        XCTAssertEqual(sut.analyzeWord("of").pattern, [.unstressed])
        XCTAssertEqual(sut.analyzeWord("in").pattern, [.unstressed])
        XCTAssertEqual(sut.analyzeWord("on").pattern, [.unstressed])
    }
    
    func testContentWordsAreStressed() {
        XCTAssertEqual(sut.analyzeWord("love").pattern, [.stressed])
        XCTAssertEqual(sut.analyzeWord("heart").pattern, [.stressed])
        XCTAssertEqual(sut.analyzeWord("dream").pattern, [.stressed])
        XCTAssertEqual(sut.analyzeWord("world").pattern, [.stressed])
    }
    
    func testTwoSyllableFirstStress() {
        // Common pattern: stress on first syllable
        let beauty = sut.analyzeWord("beauty")
        XCTAssertEqual(beauty.pattern.first, .stressed)
        XCTAssertEqual(beauty.pattern.last, .unstressed)
        
        let garden = sut.analyzeWord("garden")
        XCTAssertEqual(garden.pattern.first, .stressed)
    }
    
    func testTwoSyllableSecondStress() {
        // Words with unstressed prefix
        let away = sut.analyzeWord("away")
        XCTAssertEqual(away.pattern.first, .unstressed)
        XCTAssertEqual(away.pattern.last, .stressed)
        
        let above = sut.analyzeWord("above")
        XCTAssertEqual(above.pattern.first, .unstressed)
        XCTAssertEqual(above.pattern.last, .stressed)
    }
    
    func testThreeSyllableWords() {
        let beautiful = sut.analyzeWord("beautiful")
        XCTAssertEqual(beautiful.syllableCount, 3)
        XCTAssertEqual(beautiful.pattern.first, .stressed)
        
        let forever = sut.analyzeWord("forever")
        XCTAssertEqual(forever.syllableCount, 3)
        XCTAssertEqual(forever.pattern[1], .stressed) // middle stress
    }
    
    // MARK: - Line Analysis Tests
    
    func testAnalyzeLine() {
        let line = "The quick brown fox"
        let wordStresses = sut.analyzeLine(line)
        
        XCTAssertEqual(wordStresses.count, 4)
        XCTAssertEqual(wordStresses[0].word, "The")
        XCTAssertEqual(wordStresses[0].pattern, [.unstressed])
        XCTAssertEqual(wordStresses[1].pattern, [.stressed]) // quick
        XCTAssertEqual(wordStresses[2].pattern, [.stressed]) // brown
        XCTAssertEqual(wordStresses[3].pattern, [.stressed]) // fox
    }
    
    func testGetLinePattern() {
        // "To be or not to be" should be u / u / u /
        let hamlet = "To be or not to be"
        let pattern = sut.getLinePattern(hamlet)
        
        // Expected: unstressed, stressed, unstressed, stressed, unstressed, stressed
        XCTAssertEqual(pattern.count, 6)
    }
    
    func testGetPatternString() {
        let pattern = sut.getPatternString("To be or not to be")
        
        // Should produce a string of u and / characters
        XCTAssertTrue(pattern.contains("/"))
        XCTAssertTrue(pattern.contains("u"))
    }
    
    // MARK: - Meter Matching Tests
    
    func testMatchIambicMeter() {
        // Perfect iambic line: "The WORLD is TOO much WITH us"
        // Simplified test: "To BE or NOT"
        let line = "To be"
        let match = sut.matchMeter(line, meter: .iambic)
        
        // Should have at least one iambic foot
        XCTAssertGreaterThanOrEqual(match.totalFeet, 1)
    }
    
    func testMatchTrochaicMeter() {
        // Trochaic: stressed-unstressed
        // "DOUBLE, DOUBLE, TOIL and TROUBLE"
        let match = sut.matchMeter("Double double", meter: .trochaic)
        
        XCTAssertGreaterThan(match.totalFeet, 0)
    }
    
    func testDetectMeter() {
        // Test meter detection for an iambic line
        let detected = sut.detectMeter("To be or not to be")
        
        // Should detect some meter
        XCTAssertNotNil(detected.meter)
        XCTAssertGreaterThan(detected.totalFeet, 0)
    }
    
    // MARK: - Meter Parsing Tests
    
    func testParseMeterStringIambicPentameter() {
        let result = sut.parseMeterString("iambic pentameter")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.meter, .iambic)
        XCTAssertEqual(result?.feet, 5)
    }
    
    func testParseMeterStringTrochaicTetrameter() {
        let result = sut.parseMeterString("trochaic tetrameter")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.meter, .trochaic)
        XCTAssertEqual(result?.feet, 4)
    }
    
    func testParseMeterStringDactylicHexameter() {
        let result = sut.parseMeterString("dactylic hexameter")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.meter, .dactylic)
        XCTAssertEqual(result?.feet, 6)
    }
    
    func testParseMeterStringCaseInsensitive() {
        let result = sut.parseMeterString("IAMBIC PENTAMETER")
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.meter, .iambic)
    }
    
    func testParseMeterStringUnknown() {
        let result = sut.parseMeterString("some unknown meter")
        
        XCTAssertNil(result)
    }
    
    // MARK: - Stress Level Tests
    
    func testStressLevelSymbols() {
        XCTAssertEqual(StressAnalyzer.StressLevel.stressed.symbol, "/")
        XCTAssertEqual(StressAnalyzer.StressLevel.unstressed.symbol, "u")
        XCTAssertEqual(StressAnalyzer.StressLevel.secondary.symbol, "\\")
    }
    
    func testMeterTypePatterns() {
        XCTAssertEqual(StressAnalyzer.MeterType.iambic.pattern, [.unstressed, .stressed])
        XCTAssertEqual(StressAnalyzer.MeterType.trochaic.pattern, [.stressed, .unstressed])
        XCTAssertEqual(StressAnalyzer.MeterType.anapestic.pattern, [.unstressed, .unstressed, .stressed])
        XCTAssertEqual(StressAnalyzer.MeterType.dactylic.pattern, [.stressed, .unstressed, .unstressed])
    }
    
    // MARK: - WordStress Tests
    
    func testWordStressPatternString() {
        let wordStress = sut.analyzeWord("beautiful")
        
        // Should produce pattern like "/uu"
        XCTAssertTrue(wordStress.patternString.contains("/"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyWord() {
        let result = sut.analyzeWord("")
        XCTAssertEqual(result.syllableCount, 0)
        XCTAssertTrue(result.pattern.isEmpty)
    }
    
    func testEmptyLine() {
        let result = sut.analyzeLine("")
        XCTAssertTrue(result.isEmpty)
    }
    
    func testPunctuationHandling() {
        let with = sut.analyzeWord("love!")
        let without = sut.analyzeWord("love")
        
        XCTAssertEqual(with.pattern, without.pattern)
    }
    
    func testCaseInsensitivity() {
        let lower = sut.analyzeWord("beautiful")
        let upper = sut.analyzeWord("BEAUTIFUL")
        let mixed = sut.analyzeWord("BeAuTiFuL")
        
        XCTAssertEqual(lower.pattern, upper.pattern)
        XCTAssertEqual(lower.pattern, mixed.pattern)
    }
    
    // MARK: - MeterMatch Tests
    
    func testMeterMatchIsExactMatch() {
        let exactMatch = MeterMatch(
            meter: .iambic,
            accuracy: 1.0,
            matchingFeet: 5,
            totalFeet: 5,
            deviations: []
        )
        
        XCTAssertTrue(exactMatch.isExactMatch)
        XCTAssertEqual(exactMatch.percentAccuracy, 100)
    }
    
    func testMeterMatchNotExact() {
        let partialMatch = MeterMatch(
            meter: .iambic,
            accuracy: 0.8,
            matchingFeet: 4,
            totalFeet: 5,
            deviations: []
        )
        
        XCTAssertFalse(partialMatch.isExactMatch)
        XCTAssertEqual(partialMatch.percentAccuracy, 80)
    }
    
    // MARK: - MeterDeviation Tests
    
    func testMeterDeviationStrings() {
        let deviation = MeterDeviation(
            footNumber: 1,
            expected: [.unstressed, .stressed],
            actual: [.stressed, .unstressed]
        )
        
        XCTAssertEqual(deviation.expectedString, "u/")
        XCTAssertEqual(deviation.actualString, "/u")
    }
}
