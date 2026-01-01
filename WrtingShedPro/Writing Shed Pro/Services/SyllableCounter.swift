import Foundation

/// Service for counting syllables in English text
/// Uses a combination of rules-based counting and special case handling
@Observable
final class SyllableCounter {
    
    // MARK: - Singleton
    
    static let shared = SyllableCounter()
    
    private init() {
        loadExceptions()
    }
    
    // MARK: - Properties
    
    /// Dictionary of words with known syllable counts that don't follow standard rules
    private var exceptions: [String: Int] = [:]
    
    /// Cache for computed syllable counts to improve performance
    /// Key: lowercase word, Value: syllable count
    private var syllableCache: [String: Int] = [:]
    
    /// Maximum cache size to prevent memory issues
    private let maxCacheSize = 10_000
    
    // MARK: - Public API
    
    /// Count syllables in a single word
    /// - Parameter word: The word to analyze
    /// - Returns: The estimated syllable count
    func countSyllables(in word: String) -> Int {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        guard !cleanWord.isEmpty else { return 0 }
        
        // Check cache first
        if let cached = syllableCache[cleanWord] {
            return cached
        }
        
        let count = computeSyllables(in: cleanWord)
        
        // Cache the result (with size limit)
        if syllableCache.count < maxCacheSize {
            syllableCache[cleanWord] = count
        }
        
        return count
    }
    
    /// Clear the syllable cache (useful for testing or memory pressure)
    func clearCache() {
        syllableCache.removeAll()
    }
    
    /// Internal method to compute syllables (without caching)
    private func computeSyllables(in cleanWord: String) -> Int {
        
        // Handle pure numbers - convert to spoken form syllables
        if let number = Int(cleanWord) {
            return countSyllablesInNumber(number)
        }
        
        // Check if word contains only symbols or non-English characters
        let englishLetters = CharacterSet.letters.subtracting(CharacterSet(charactersIn: "àáâäãåèéêëìíîïòóôöõøùúûüñç"))
        let decimalDigits = CharacterSet.decimalDigits
        if cleanWord.unicodeScalars.allSatisfy({ !englishLetters.contains($0) && !decimalDigits.contains($0) }) {
            // Pure symbols or non-English - return 0
            return 0
        }
        
        // Check for hyphenated words first
        if cleanWord.contains("-") {
            return countSyllablesInHyphenatedWord(cleanWord)
        }
        
        // Check for contractions (words with apostrophes)
        if cleanWord.contains("'") || cleanWord.contains("'") {
            // Normalize curly apostrophe to straight
            let normalized = cleanWord.replacingOccurrences(of: "'", with: "'")
            if let contractionCount = countSyllablesInContraction(normalized) {
                return contractionCount
            }
            // Unknown contraction - remove apostrophe and count the base
            let baseWord = normalized.replacingOccurrences(of: "'", with: "")
            return countSyllablesWithRules(baseWord)
        }
        
        // Check exceptions
        if let exceptionCount = exceptions[cleanWord] {
            return exceptionCount
        }
        
        // Apply rules-based counting
        return countSyllablesWithRules(cleanWord)
    }
    
    /// Count syllables in a number when spoken
    /// - Parameter number: The number to analyze
    /// - Returns: Syllable count when spoken
    private func countSyllablesInNumber(_ number: Int) -> Int {
        // Handle common numbers with known syllable counts
        let numberSyllables: [Int: Int] = [
            0: 2, 1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 2, 8: 1, 9: 1,
            10: 1, 11: 3, 12: 1, 13: 2, 14: 2, 15: 2, 16: 2, 17: 3, 18: 2, 19: 2,
            20: 2, 30: 2, 40: 2, 50: 2, 60: 2, 70: 3, 80: 2, 90: 2,
            100: 2, 1000: 2
        ]
        
        if let syllables = numberSyllables[number] {
            return syllables
        }
        
        // For larger numbers, approximate based on digit count
        let digits = String(abs(number)).count
        return digits // Rough approximation
    }
    
    /// Count syllables in a line of text
    /// - Parameter line: The line to analyze
    /// - Returns: Total syllable count for the line
    func countSyllables(inLine line: String) -> Int {
        let words = extractWords(from: line)
        return words.reduce(0) { $0 + countSyllables(in: $1) }
    }
    
    /// Count syllables for each line in a text
    /// - Parameter text: The full text to analyze
    /// - Returns: Array of syllable counts, one per line
    func countSyllablesPerLine(in text: String) -> [Int] {
        let lines = text.components(separatedBy: .newlines)
        return lines.map { countSyllables(inLine: $0) }
    }
    
    /// Analyze syllables with detailed breakdown
    /// - Parameter line: The line to analyze
    /// - Returns: Array of word-syllable pairs
    func analyzeLineDetailed(_ line: String) -> [(word: String, syllables: Int)] {
        let words = extractWords(from: line)
        return words.map { ($0, countSyllables(in: $0)) }
    }
    
    /// Compare actual syllables to expected pattern
    /// - Parameters:
    ///   - text: The text to analyze
    ///   - pattern: Expected syllable count per line
    /// - Returns: Array of comparison results
    func compareToPattern(text: String, pattern: [Int]) -> [SyllableComparison] {
        let lines = text.components(separatedBy: .newlines)
        var results: [SyllableComparison] = []
        
        for (index, line) in lines.enumerated() {
            let actual = countSyllables(inLine: line)
            let expected = index < pattern.count ? pattern[index] : nil
            let accuracy = calculateAccuracy(actual: actual, expected: expected)
            
            results.append(SyllableComparison(
                lineNumber: index + 1,
                lineText: line,
                actualCount: actual,
                expectedCount: expected,
                accuracy: accuracy
            ))
        }
        
        return results
    }
    
    // MARK: - Rules-Based Counting
    
    private func countSyllablesWithRules(_ word: String) -> Int {
        var count = 0
        var previousWasVowel = false
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        let characters = Array(word)
        
        for (index, char) in characters.enumerated() {
            let isVowel = vowels.contains(char)
            
            if isVowel && !previousWasVowel {
                count += 1
            }
            
            previousWasVowel = isVowel
            
            // Handle special vowel combinations (diphthongs that count as one syllable)
            if isVowel && index > 0 {
                let prev = characters[index - 1]
                if isDiphthong(first: prev, second: char) {
                    // Already counted in previous iteration, no adjustment needed
                    // The !previousWasVowel check handles this
                }
            }
        }
        
        // Apply adjustments
        count = applySilentERule(word: word, count: count)
        count = applyEdEndingRule(word: word, count: count)
        count = applyLeEndingRule(word: word, count: count)
        count = applyEsEndingRule(word: word, count: count)
        
        // Ensure at least one syllable
        return max(count, 1)
    }
    
    // MARK: - Diphthong Detection
    
    /// Common diphthongs that count as single syllables
    private func isDiphthong(first: Character, second: Character) -> Bool {
        let pair = String([first, second])
        let diphthongs: Set<String> = [
            "ai", "au", "aw", "ay",
            "ea", "ee", "ei", "ew", "ey",
            "ie",
            "oa", "oe", "oi", "oo", "ou", "ow", "oy",
            "ue", "ui"
        ]
        return diphthongs.contains(pair)
    }
    
    // MARK: - Adjustment Rules
    
    /// Silent 'e' at the end of words doesn't add a syllable
    private func applySilentERule(word: String, count: Int) -> Int {
        guard word.count > 2 else { return count }
        
        // Words ending in 'e' (but not 'le' which is handled separately)
        if word.hasSuffix("e") && !word.hasSuffix("le") {
            // Check it's not a word where 'e' is pronounced (like "be", "me", "he")
            let twoLetterEWords: Set<String> = ["be", "he", "me", "we"]
            if !twoLetterEWords.contains(word) {
                return max(count - 1, 1)
            }
        }
        
        return count
    }
    
    /// Words ending in '-ed' usually don't add a syllable unless preceded by 't' or 'd'
    private func applyEdEndingRule(word: String, count: Int) -> Int {
        guard word.hasSuffix("ed") && word.count > 2 else { return count }
        
        let beforeEd = word.dropLast(2).last
        
        // '-ted' and '-ded' endings add a syllable (wanted, needed)
        if beforeEd == "t" || beforeEd == "d" {
            return count
        }
        
        // Other '-ed' endings don't add a syllable (walked, played)
        // Since we counted 'e' as a vowel, subtract it
        return max(count - 1, 1)
    }
    
    /// Words ending in '-le' preceded by a consonant add a syllable
    private func applyLeEndingRule(word: String, count: Int) -> Int {
        guard word.hasSuffix("le") && word.count > 2 else { return count }
        
        let beforeLe = word.dropLast(2).last
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        
        // '-le' after a consonant adds a syllable (table, bottle)
        // '-le' after a vowel doesn't (ale, pile - already counted)
        if let char = beforeLe, !vowels.contains(char) {
            // The 'e' in '-le' wasn't counted because it followed 'l' (consonant)
            // but this pattern should count as a syllable
            return count + 1
        }
        
        return count
    }
    
    /// Words ending in '-es' sometimes add a syllable
    private func applyEsEndingRule(word: String, count: Int) -> Int {
        guard word.hasSuffix("es") && word.count > 2 else { return count }
        
        let beforeEs = word.dropLast(2)
        
        // Words ending in s, x, z, ch, sh + es add a syllable (boxes, watches)
        if beforeEs.hasSuffix("s") || beforeEs.hasSuffix("x") ||
           beforeEs.hasSuffix("z") || beforeEs.hasSuffix("ch") ||
           beforeEs.hasSuffix("sh") || beforeEs.hasSuffix("ce") ||
           beforeEs.hasSuffix("ge") {
            return count
        }
        
        // Other '-es' doesn't add a syllable (makes, takes)
        return max(count - 1, 1)
    }
    
    // MARK: - Helper Methods
    
    /// Extract words from a line of text
    private func extractWords(from text: String) -> [String] {
        // Split on whitespace and filter out empty strings
        let components = text.components(separatedBy: .whitespaces)
        return components
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
    
    /// Handle contractions like "don't", "they're", "it's"
    /// Contractions typically maintain syllable count of the expanded form
    private func countSyllablesInContraction(_ word: String) -> Int? {
        let lower = word.lowercased()
        
        // Common contractions with known syllable counts
        let contractionSyllables: [String: Int] = [
            // 1 syllable
            "i'm": 1, "you're": 1, "we're": 1, "they're": 1,
            "he's": 1, "she's": 1, "it's": 1, "that's": 1, "what's": 1,
            "who's": 1, "here's": 1, "there's": 1, "where's": 1,
            "don't": 1, "won't": 1, "can't": 1, "ain't": 1,
            "isn't": 1, "aren't": 1, "wasn't": 1, "weren't": 1,
            "hasn't": 1, "haven't": 1, "hadn't": 1,
            "doesn't": 1, "didn't": 1, "couldn't": 1, "wouldn't": 1, "shouldn't": 1,
            "let's": 1, "how's": 1,
            "i'll": 1, "you'll": 1, "he'll": 1, "she'll": 1, "it'll": 1,
            "we'll": 1, "they'll": 1, "that'll": 1,
            "i've": 1, "you've": 1, "we've": 1, "they've": 1,
            "could've": 1, "would've": 1, "should've": 1, "might've": 1,
            "i'd": 1, "you'd": 1, "he'd": 1, "she'd": 1, "we'd": 1, "they'd": 1,
            
            // 2 syllables
            "cannot": 2, "o'clock": 2, "ma'am": 1
        ]
        
        return contractionSyllables[lower]
    }
    
    /// Handle hyphenated words by splitting and summing syllables
    private func countSyllablesInHyphenatedWord(_ word: String) -> Int {
        let parts = word.split(separator: "-").map { String($0) }
        return parts.reduce(0) { $0 + countSyllables(in: $1) }
    }
    
    /// Calculate accuracy level for syllable matching
    private func calculateAccuracy(actual: Int, expected: Int?) -> SyllableAccuracy {
        guard let expected = expected else { return .noExpectation }
        
        let difference = abs(actual - expected)
        
        switch difference {
        case 0:
            return .exact
        case 1:
            return .close
        default:
            return .off
        }
    }
    
    // MARK: - Exceptions Loading
    
    /// Load exception words that don't follow standard rules
    private func loadExceptions() {
        // Common words with unusual syllable counts
        exceptions = [
            // One syllable words often miscounted
            "the": 1, "a": 1, "i": 1,
            "fire": 1, "hour": 1, "our": 1,
            "are": 1, "were": 1, "there": 1, "where": 1,
            "here": 1, "sure": 1, "pure": 1,
            "world": 1, "whirl": 1, "girl": 1,
            "real": 1, "deal": 1, "feel": 1, "heal": 1,
            "poem": 2, "poems": 2,
            
            // Two syllable words
            "every": 2, "evening": 2, "being": 2,
            "doing": 2, "going": 2, "seeing": 2,
            "quiet": 2, "diet": 2, "riot": 2,
            "create": 2, "created": 3,
            "opened": 2, "happened": 2,
            "covered": 2, "entered": 2,
            "different": 3, "favorite": 3,
            "beautiful": 3, "wonderful": 3,
            "comfortable": 4, "vegetable": 4,
            "interesting": 4, "everything": 3,
            "chocolate": 3, "separate": 3,
            "desperate": 3, "temperature": 4,
            "literature": 4, "naturally": 4,
            
            // Poetry-specific words
            "flower": 2, "power": 2, "tower": 2, "shower": 2,
            "heaven": 2, "seven": 2, "even": 2,
            "over": 2, "ever": 2, "never": 2,
            "little": 2, "middle": 2, "riddle": 2,
            "people": 2, "purple": 2, "simple": 2,
            "angle": 2, "single": 2, "mingle": 2,
            "gentle": 2, "mental": 2,
            "spirit": 2, "visit": 2, "limit": 2,
            "minute": 2, "second": 2,
            "nature": 2, "future": 2, "picture": 2,
            "creature": 2, "feature": 2,
            "measure": 2, "treasure": 2, "pleasure": 2,
            "ocean": 2, "motion": 2, "nation": 2,
            "special": 2, "social": 2,
            "ancient": 2, "patient": 2,
            "silent": 2, "violent": 3,
            "science": 2, "conscience": 2,
            
            // Three syllable words
            "family": 3, "memory": 3, "history": 3,
            "mystery": 3, "victory": 3, "factory": 3,
            "Saturday": 3, "yesterday": 3,
            "animal": 3, "musical": 3,
            "physical": 3, "magical": 3,
            "possible": 3, "terrible": 3,
            "horrible": 3, "adorable": 4,
            "imagine": 3, "example": 3,
            "remember": 3, "together": 3,
            "forever": 3, "however": 3,
            "another": 3, "discover": 3,
            "beginning": 3, "belonging": 3,
            "continuing": 4, "imagining": 4
        ]
    }
}

// MARK: - Supporting Types

/// Result of comparing actual syllables to expected pattern
struct SyllableComparison: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let lineText: String
    let actualCount: Int
    let expectedCount: Int?
    let accuracy: SyllableAccuracy
}

/// Accuracy level for syllable matching
enum SyllableAccuracy {
    case exact          // Matches exactly
    case close          // Off by 1
    case off            // Off by 2+
    case noExpectation  // No expected count to compare against
    
    /// Color for visual feedback
    var color: String {
        switch self {
        case .exact: return "green"
        case .close: return "yellow"
        case .off: return "red"
        case .noExpectation: return "gray"
        }
    }
}

// MARK: - Character Set Extension

private extension CharacterSet {
    static let punctuationCharacters = CharacterSet.punctuationCharacters
}
