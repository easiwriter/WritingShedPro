import XCTest
@testable import Writing_Shed_Pro

/// Unit tests for SyllableCounter service
final class SyllableCounterTests: XCTestCase {
    
    var sut: SyllableCounter!
    
    override func setUp() {
        super.setUp()
        sut = SyllableCounter.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Single Word Tests
    
    func testOneSyllableWords() {
        // Basic one-syllable words
        XCTAssertEqual(sut.countSyllables(in: "cat"), 1)
        XCTAssertEqual(sut.countSyllables(in: "dog"), 1)
        XCTAssertEqual(sut.countSyllables(in: "run"), 1)
        XCTAssertEqual(sut.countSyllables(in: "jump"), 1)
        XCTAssertEqual(sut.countSyllables(in: "the"), 1)
        XCTAssertEqual(sut.countSyllables(in: "a"), 1)
        XCTAssertEqual(sut.countSyllables(in: "I"), 1)
    }
    
    func testTwoSyllableWords() {
        XCTAssertEqual(sut.countSyllables(in: "happy"), 2)
        XCTAssertEqual(sut.countSyllables(in: "water"), 2)
        XCTAssertEqual(sut.countSyllables(in: "garden"), 2)
        XCTAssertEqual(sut.countSyllables(in: "summer"), 2)
        XCTAssertEqual(sut.countSyllables(in: "winter"), 2)
    }
    
    func testThreeSyllableWords() {
        XCTAssertEqual(sut.countSyllables(in: "beautiful"), 3)
        XCTAssertEqual(sut.countSyllables(in: "wonderful"), 3)
        XCTAssertEqual(sut.countSyllables(in: "butterfly"), 3)
        XCTAssertEqual(sut.countSyllables(in: "elephant"), 3)
        XCTAssertEqual(sut.countSyllables(in: "family"), 3)
    }
    
    func testFourOrMoreSyllableWords() {
        XCTAssertEqual(sut.countSyllables(in: "incredible"), 4)
        XCTAssertEqual(sut.countSyllables(in: "understanding"), 4)
        XCTAssertEqual(sut.countSyllables(in: "communication"), 5)
        XCTAssertEqual(sut.countSyllables(in: "refrigerator"), 5)
    }
    
    // MARK: - Silent E Tests
    
    func testSilentEWords() {
        XCTAssertEqual(sut.countSyllables(in: "make"), 1)
        XCTAssertEqual(sut.countSyllables(in: "take"), 1)
        XCTAssertEqual(sut.countSyllables(in: "home"), 1)
        XCTAssertEqual(sut.countSyllables(in: "time"), 1)
        XCTAssertEqual(sut.countSyllables(in: "life"), 1)
        XCTAssertEqual(sut.countSyllables(in: "hope"), 1)
        XCTAssertEqual(sut.countSyllables(in: "love"), 1)
    }
    
    func testPronouncedEWords() {
        // Two-letter words where 'e' is pronounced
        XCTAssertEqual(sut.countSyllables(in: "be"), 1)
        XCTAssertEqual(sut.countSyllables(in: "me"), 1)
        XCTAssertEqual(sut.countSyllables(in: "he"), 1)
        XCTAssertEqual(sut.countSyllables(in: "we"), 1)
    }
    
    // MARK: - -ED Ending Tests
    
    func testEdEndingWords() {
        // Words where -ed adds a syllable
        XCTAssertEqual(sut.countSyllables(in: "wanted"), 2)
        XCTAssertEqual(sut.countSyllables(in: "needed"), 2)
        XCTAssertEqual(sut.countSyllables(in: "started"), 2)
        XCTAssertEqual(sut.countSyllables(in: "ended"), 2)
        
        // Words where -ed doesn't add a syllable
        XCTAssertEqual(sut.countSyllables(in: "walked"), 1)
        XCTAssertEqual(sut.countSyllables(in: "played"), 1)
        XCTAssertEqual(sut.countSyllables(in: "jumped"), 1)
        XCTAssertEqual(sut.countSyllables(in: "called"), 1)
    }
    
    // MARK: - -LE Ending Tests
    
    func testLeEndingWords() {
        XCTAssertEqual(sut.countSyllables(in: "table"), 2)
        XCTAssertEqual(sut.countSyllables(in: "bottle"), 2)
        XCTAssertEqual(sut.countSyllables(in: "little"), 2)
        XCTAssertEqual(sut.countSyllables(in: "people"), 2)
        XCTAssertEqual(sut.countSyllables(in: "simple"), 2)
    }
    
    // MARK: - Diphthong Tests
    
    func testDiphthongWords() {
        // Words with diphthongs (two vowels = one syllable)
        XCTAssertEqual(sut.countSyllables(in: "rain"), 1)
        XCTAssertEqual(sut.countSyllables(in: "boat"), 1)
        XCTAssertEqual(sut.countSyllables(in: "meat"), 1)
        XCTAssertEqual(sut.countSyllables(in: "road"), 1)
        XCTAssertEqual(sut.countSyllables(in: "team"), 1)
    }
    
    // MARK: - Poetry-Specific Words
    
    func testPoetryWords() {
        XCTAssertEqual(sut.countSyllables(in: "flower"), 2)
        XCTAssertEqual(sut.countSyllables(in: "power"), 2)
        XCTAssertEqual(sut.countSyllables(in: "heaven"), 2)
        XCTAssertEqual(sut.countSyllables(in: "nature"), 2)
        XCTAssertEqual(sut.countSyllables(in: "spirit"), 2)
        XCTAssertEqual(sut.countSyllables(in: "ancient"), 2)
        XCTAssertEqual(sut.countSyllables(in: "silent"), 2)
        XCTAssertEqual(sut.countSyllables(in: "ocean"), 2)
    }
    
    // MARK: - Line Tests
    
    func testSyllablesInLine() {
        // "The quick brown fox" = 1+1+1+1 = 4
        XCTAssertEqual(sut.countSyllables(inLine: "The quick brown fox"), 4)
        
        // "An old silent pond" (haiku first line) = 1+1+2+1 = 5
        XCTAssertEqual(sut.countSyllables(inLine: "An old silent pond"), 5)
    }
    
    func testEmptyLine() {
        XCTAssertEqual(sut.countSyllables(inLine: ""), 0)
        XCTAssertEqual(sut.countSyllables(inLine: "   "), 0)
    }
    
    // MARK: - Multi-Line Tests
    
    func testSyllablesPerLine() {
        let haiku = """
        An old silent pond
        A frog jumps into the pond
        Splash silence again
        """
        
        let counts = sut.countSyllablesPerLine(in: haiku)
        
        XCTAssertEqual(counts.count, 3)
        XCTAssertEqual(counts[0], 5) // An old silent pond
        XCTAssertEqual(counts[1], 7) // A frog jumps into the pond
        XCTAssertEqual(counts[2], 5) // Splash silence again
    }
    
    // MARK: - Pattern Comparison Tests
    
    func testCompareToPatternExact() {
        let haiku = """
        An old silent pond
        A frog jumps into the pond
        Splash silence again
        """
        
        let pattern = [5, 7, 5]
        let comparisons = sut.compareToPattern(text: haiku, pattern: pattern)
        
        XCTAssertEqual(comparisons.count, 3)
        XCTAssertEqual(comparisons[0].accuracy, .exact)
        XCTAssertEqual(comparisons[1].accuracy, .exact)
        XCTAssertEqual(comparisons[2].accuracy, .exact)
    }
    
    func testCompareToPatternClose() {
        let text = "The quick brown fox" // 4 syllables
        let pattern = [5] // expecting 5
        
        let comparisons = sut.compareToPattern(text: text, pattern: pattern)
        
        XCTAssertEqual(comparisons.count, 1)
        XCTAssertEqual(comparisons[0].accuracy, .close) // off by 1
    }
    
    func testCompareToPatternOff() {
        let text = "Cat" // 1 syllable
        let pattern = [5] // expecting 5
        
        let comparisons = sut.compareToPattern(text: text, pattern: pattern)
        
        XCTAssertEqual(comparisons.count, 1)
        XCTAssertEqual(comparisons[0].accuracy, .off) // off by 4
    }
    
    // MARK: - Detailed Analysis Tests
    
    func testAnalyzeLineDetailed() {
        let line = "The quick brown fox"
        let analysis = sut.analyzeLineDetailed(line)
        
        XCTAssertEqual(analysis.count, 4)
        XCTAssertEqual(analysis[0].word, "The")
        XCTAssertEqual(analysis[0].syllables, 1)
        XCTAssertEqual(analysis[1].word, "quick")
        XCTAssertEqual(analysis[1].syllables, 1)
        XCTAssertEqual(analysis[2].word, "brown")
        XCTAssertEqual(analysis[2].syllables, 1)
        XCTAssertEqual(analysis[3].word, "fox")
        XCTAssertEqual(analysis[3].syllables, 1)
    }
    
    // MARK: - Punctuation Handling
    
    func testPunctuationHandling() {
        XCTAssertEqual(sut.countSyllables(in: "hello!"), 2)
        XCTAssertEqual(sut.countSyllables(in: "world?"), 1)
        XCTAssertEqual(sut.countSyllables(in: "yes,"), 1)
        XCTAssertEqual(sut.countSyllables(in: "\"poetry\""), 3)
        XCTAssertEqual(sut.countSyllables(in: "(beautiful)"), 3)
    }
    
    // MARK: - Case Insensitivity
    
    func testCaseInsensitivity() {
        XCTAssertEqual(sut.countSyllables(in: "Hello"), sut.countSyllables(in: "hello"))
        XCTAssertEqual(sut.countSyllables(in: "WORLD"), sut.countSyllables(in: "world"))
        XCTAssertEqual(sut.countSyllables(in: "BeAuTiFuL"), sut.countSyllables(in: "beautiful"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyString() {
        XCTAssertEqual(sut.countSyllables(in: ""), 0)
    }
    
    func testSingleLetter() {
        XCTAssertEqual(sut.countSyllables(in: "a"), 1)
        XCTAssertEqual(sut.countSyllables(in: "I"), 1)
    }
    
    func testConsonantOnly() {
        // "Hmm" should still return at least 1
        XCTAssertEqual(sut.countSyllables(in: "shh"), 1)
    }
}
