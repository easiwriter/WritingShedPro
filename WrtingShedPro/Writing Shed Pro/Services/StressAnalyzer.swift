import Foundation

/// Service for analyzing stress patterns in English text
/// Uses dictionary lookup and rule-based analysis for syllable stress
@Observable
final class StressAnalyzer {
    
    // MARK: - Singleton
    
    static let shared = StressAnalyzer()
    
    private init() {
        loadStressDictionary()
    }
    
    // MARK: - Types
    
    /// Represents stress level of a syllable
    enum StressLevel: String, Codable {
        case stressed = "/"      // Primary stress
        case unstressed = "u"    // Unstressed
        case secondary = "\\"    // Secondary stress (for longer words)
        
        var symbol: String { rawValue }
        
        var description: String {
            switch self {
            case .stressed: return "stressed"
            case .unstressed: return "unstressed"
            case .secondary: return "secondary"
            }
        }
    }
    
    /// Stress pattern for a single word
    struct WordStress: Identifiable {
        let id = UUID()
        let word: String
        let pattern: [StressLevel]
        let syllableCount: Int
        
        var patternString: String {
            pattern.map { $0.symbol }.joined()
        }
    }
    
    /// Common metrical patterns
    enum MeterType: String, CaseIterable {
        case iambic = "iambic"           // u/
        case trochaic = "trochaic"       // /u
        case anapestic = "anapestic"     // uu/
        case dactylic = "dactylic"       // /uu
        case spondaic = "spondaic"       // //
        case pyrrhic = "pyrrhic"         // uu
        
        var pattern: [StressLevel] {
            switch self {
            case .iambic: return [.unstressed, .stressed]
            case .trochaic: return [.stressed, .unstressed]
            case .anapestic: return [.unstressed, .unstressed, .stressed]
            case .dactylic: return [.stressed, .unstressed, .unstressed]
            case .spondaic: return [.stressed, .stressed]
            case .pyrrhic: return [.unstressed, .unstressed]
            }
        }
        
        var displayName: String {
            switch self {
            case .iambic: return "Iambic (u/)"
            case .trochaic: return "Trochaic (/u)"
            case .anapestic: return "Anapestic (uu/)"
            case .dactylic: return "Dactylic (/uu)"
            case .spondaic: return "Spondaic (//)"
            case .pyrrhic: return "Pyrrhic (uu)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Dictionary of words with known stress patterns
    private var stressDictionary: [String: [StressLevel]] = [:]
    
    /// Cache for computed stress patterns
    private var stressCache: [String: [StressLevel]] = [:]
    
    /// Maximum cache size
    private let maxCacheSize = 10_000
    
    private let syllableCounter = SyllableCounter.shared
    
    // MARK: - Public API
    
    /// Analyze stress pattern for a single word
    /// - Parameter word: The word to analyze
    /// - Returns: WordStress containing the stress pattern
    func analyzeWord(_ word: String) -> WordStress {
        let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        guard !cleanWord.isEmpty else {
            return WordStress(word: word, pattern: [], syllableCount: 0)
        }
        
        // Check cache first
        if let cached = stressCache[cleanWord] {
            return WordStress(word: word, pattern: cached, syllableCount: cached.count)
        }
        
        // Check dictionary
        if let knownPattern = stressDictionary[cleanWord] {
            // Cache dictionary hits for faster repeated lookups
            if stressCache.count < maxCacheSize {
                stressCache[cleanWord] = knownPattern
            }
            return WordStress(word: word, pattern: knownPattern, syllableCount: knownPattern.count)
        }
        
        // Fall back to rule-based analysis
        let pattern = analyzeWithRules(cleanWord)
        
        // Cache the computed result
        if stressCache.count < maxCacheSize {
            stressCache[cleanWord] = pattern
        }
        
        return WordStress(word: word, pattern: pattern, syllableCount: pattern.count)
    }
    
    /// Clear the stress pattern cache
    func clearCache() {
        stressCache.removeAll()
    }
    
    /// Analyze stress pattern for a line of text
    /// - Parameter line: The line to analyze
    /// - Returns: Array of WordStress for each word
    func analyzeLine(_ line: String) -> [WordStress] {
        let words = extractWords(from: line)
        return words.map { analyzeWord($0) }
    }
    
    /// Get the combined stress pattern for a line
    /// - Parameter line: The line to analyze
    /// - Returns: Combined stress pattern across all words
    func getLinePattern(_ line: String) -> [StressLevel] {
        let wordStresses = analyzeLine(line)
        return wordStresses.flatMap { $0.pattern }
    }
    
    /// Format stress pattern as a string
    /// - Parameter line: The line to analyze
    /// - Returns: Pattern string like "u/u/u/u/u/"
    func getPatternString(_ line: String) -> String {
        getLinePattern(line).map { $0.symbol }.joined()
    }
    
    /// Check if a line matches a specific meter
    /// - Parameters:
    ///   - line: The line to analyze
    ///   - meter: The expected meter type
    /// - Returns: Match result with accuracy score
    func matchMeter(_ line: String, meter: MeterType) -> MeterMatch {
        let actualPattern = getLinePattern(line)
        let expectedPattern = meter.pattern
        
        guard !actualPattern.isEmpty else {
            return MeterMatch(meter: meter, accuracy: 0, matchingFeet: 0, totalFeet: 0, deviations: [])
        }
        
        // Count metrical feet
        let footSize = expectedPattern.count
        let totalFeet = actualPattern.count / footSize
        var matchingFeet = 0
        var deviations: [MeterDeviation] = []
        
        for foot in 0..<totalFeet {
            let startIndex = foot * footSize
            let endIndex = min(startIndex + footSize, actualPattern.count)
            let actualFoot = Array(actualPattern[startIndex..<endIndex])
            
            if actualFoot == expectedPattern {
                matchingFeet += 1
            } else {
                // Record deviation
                deviations.append(MeterDeviation(
                    footNumber: foot + 1,
                    expected: expectedPattern,
                    actual: actualFoot
                ))
            }
        }
        
        let accuracy = totalFeet > 0 ? Double(matchingFeet) / Double(totalFeet) : 0
        
        return MeterMatch(
            meter: meter,
            accuracy: accuracy,
            matchingFeet: matchingFeet,
            totalFeet: totalFeet,
            deviations: deviations
        )
    }
    
    /// Detect the most likely meter for a line
    /// - Parameter line: The line to analyze
    /// - Returns: Best matching meter with confidence
    func detectMeter(_ line: String) -> MeterMatch {
        let matches = MeterType.allCases.map { matchMeter(line, meter: $0) }
        return matches.max(by: { $0.accuracy < $1.accuracy }) ?? 
               MeterMatch(meter: .iambic, accuracy: 0, matchingFeet: 0, totalFeet: 0, deviations: [])
    }
    
    /// Parse a meter pattern string (e.g., "iambic pentameter")
    /// - Parameter meterString: The meter description
    /// - Returns: Tuple of meter type and number of feet, or nil
    func parseMeterString(_ meterString: String) -> (meter: MeterType, feet: Int)? {
        let lower = meterString.lowercased()
        
        // Detect meter type
        var meterType: MeterType?
        for type in MeterType.allCases {
            if lower.contains(type.rawValue) {
                meterType = type
                break
            }
        }
        
        guard let meter = meterType else { return nil }
        
        // Detect number of feet
        let feet: Int
        if lower.contains("monometer") { feet = 1 }
        else if lower.contains("dimeter") { feet = 2 }
        else if lower.contains("trimeter") { feet = 3 }
        else if lower.contains("tetrameter") { feet = 4 }
        else if lower.contains("pentameter") { feet = 5 }
        else if lower.contains("hexameter") { feet = 6 }
        else if lower.contains("heptameter") { feet = 7 }
        else if lower.contains("octameter") { feet = 8 }
        else { feet = 5 } // Default to pentameter
        
        return (meter, feet)
    }
    
    // MARK: - Rule-Based Analysis
    
    private func analyzeWithRules(_ word: String) -> [StressLevel] {
        let syllableCount = syllableCounter.countSyllables(in: word)
        
        guard syllableCount > 0 else { return [] }
        
        // Single syllable words are typically stressed
        if syllableCount == 1 {
            // Check if it's a function word (usually unstressed)
            if isFunctionWord(word) {
                return [.unstressed]
            }
            return [.stressed]
        }
        
        // Two syllable words
        if syllableCount == 2 {
            return analyzeTwoSyllable(word)
        }
        
        // Three or more syllables - use suffix/prefix rules
        return analyzeMultiSyllable(word, count: syllableCount)
    }
    
    /// Check if word is a function word (articles, prepositions, etc.)
    private func isFunctionWord(_ word: String) -> Bool {
        let functionWords: Set<String> = [
            // Articles
            "a", "an", "the",
            // Prepositions
            "at", "by", "for", "from", "in", "of", "on", "to", "with",
            // Conjunctions
            "and", "but", "or", "nor", "so", "yet",
            // Pronouns (weak forms)
            "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
            // Auxiliary verbs
            "is", "am", "are", "was", "were", "be", "been", "being",
            "has", "have", "had", "do", "does", "did",
            "can", "could", "may", "might", "must", "shall", "should", "will", "would",
            // Other
            "as", "if", "than", "that", "which", "who", "whom"
        ]
        return functionWords.contains(word.lowercased())
    }
    
    /// Analyze two-syllable words
    private func analyzeTwoSyllable(_ word: String) -> [StressLevel] {
        // Most two-syllable nouns/adjectives: stress on first syllable
        // Most two-syllable verbs: stress on second syllable
        
        // Common prefixes that are unstressed
        let unstressedPrefixes = ["a", "be", "de", "re", "pre", "pro", "un", "en", "em", "in", "im"]
        
        for prefix in unstressedPrefixes {
            if word.hasPrefix(prefix) && word.count > prefix.count + 2 {
                return [.unstressed, .stressed]
            }
        }
        
        // Common suffixes that take stress
        let stressedSuffixes = ["ade", "ee", "ese", "eer", "ette", "ique", "ine"]
        
        for suffix in stressedSuffixes {
            if word.hasSuffix(suffix) {
                return [.unstressed, .stressed]
            }
        }
        
        // Default: stress on first syllable (more common in English)
        return [.stressed, .unstressed]
    }
    
    /// Analyze multi-syllable words
    private func analyzeMultiSyllable(_ word: String, count: Int) -> [StressLevel] {
        var pattern = Array(repeating: StressLevel.unstressed, count: count)
        
        // Suffixes that attract stress to preceding syllable
        let stressBeforeSuffixes = ["tion", "sion", "cian", "ic", "ical", "ity", "ify", "ogy", "graphy"]
        
        for suffix in stressBeforeSuffixes {
            if word.hasSuffix(suffix) {
                // Stress falls on syllable before suffix
                let stressPosition = max(0, count - 2)
                pattern[stressPosition] = .stressed
                return pattern
            }
        }
        
        // Suffixes that take the stress themselves
        let stressedSuffixes = ["ee", "eer", "ese", "ette", "ade"]
        
        for suffix in stressedSuffixes {
            if word.hasSuffix(suffix) {
                pattern[count - 1] = .stressed
                return pattern
            }
        }
        
        // Default: stress on antepenultimate (third from last) for 3+ syllables
        // This is common in English
        if count >= 3 {
            pattern[count - 3] = .stressed
            // Add secondary stress if word is long enough
            if count >= 5 {
                pattern[0] = .secondary
            }
        } else {
            pattern[0] = .stressed
        }
        
        return pattern
    }
    
    // MARK: - Helper Methods
    
    private func extractWords(from text: String) -> [String] {
        let components = text.components(separatedBy: .whitespaces)
        return components
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Dictionary Loading
    
    private func loadStressDictionary() {
        // Common words with their stress patterns
        // This is a curated list for poetry-relevant words
        stressDictionary = [
            // One syllable content words (stressed)
            "love": [.stressed], "heart": [.stressed], "soul": [.stressed],
            "life": [.stressed], "death": [.stressed], "dream": [.stressed],
            "hope": [.stressed], "fear": [.stressed], "joy": [.stressed],
            "light": [.stressed], "dark": [.stressed], "night": [.stressed],
            "day": [.stressed], "time": [.stressed], "world": [.stressed],
            
            // Two syllable words
            "away": [.unstressed, .stressed],
            "above": [.unstressed, .stressed],
            "below": [.unstressed, .stressed],
            "before": [.unstressed, .stressed],
            "behind": [.unstressed, .stressed],
            "between": [.unstressed, .stressed],
            "beyond": [.unstressed, .stressed],
            "again": [.unstressed, .stressed],
            "along": [.unstressed, .stressed],
            "alone": [.unstressed, .stressed],
            "across": [.unstressed, .stressed],
            "around": [.unstressed, .stressed],
            "about": [.unstressed, .stressed],
            "upon": [.unstressed, .stressed],
            "within": [.unstressed, .stressed],
            "without": [.unstressed, .stressed],
            "today": [.unstressed, .stressed],
            "tonight": [.unstressed, .stressed],
            "because": [.unstressed, .stressed],
            "become": [.unstressed, .stressed],
            "begin": [.unstressed, .stressed],
            "believe": [.unstressed, .stressed],
            "perhaps": [.unstressed, .stressed],
            "remain": [.unstressed, .stressed],
            "return": [.unstressed, .stressed],
            
            "beauty": [.stressed, .unstressed],
            "shadow": [.stressed, .unstressed],
            "meadow": [.stressed, .unstressed],
            "garden": [.stressed, .unstressed],
            "morning": [.stressed, .unstressed],
            "evening": [.stressed, .unstressed],
            "sunset": [.stressed, .unstressed],
            "moonlight": [.stressed, .unstressed],
            "starlight": [.stressed, .unstressed],
            "silence": [.stressed, .unstressed],
            "moment": [.stressed, .unstressed],
            "spirit": [.stressed, .unstressed],
            "nature": [.stressed, .unstressed],
            "flower": [.stressed, .unstressed],
            "summer": [.stressed, .unstressed],
            "winter": [.stressed, .unstressed],
            "golden": [.stressed, .unstressed],
            "silver": [.stressed, .unstressed],
            "gentle": [.stressed, .unstressed],
            "tender": [.stressed, .unstressed],
            "wonder": [.stressed, .unstressed],
            "whisper": [.stressed, .unstressed],
            "thunder": [.stressed, .unstressed],
            "water": [.stressed, .unstressed],
            "river": [.stressed, .unstressed],
            "mountain": [.stressed, .unstressed],
            "valley": [.stressed, .unstressed],
            "heaven": [.stressed, .unstressed],
            "angel": [.stressed, .unstressed],
            "never": [.stressed, .unstressed],
            "ever": [.stressed, .unstressed],
            "over": [.stressed, .unstressed],
            "under": [.stressed, .unstressed],
            "after": [.stressed, .unstressed],
            "little": [.stressed, .unstressed],
            "only": [.stressed, .unstressed],
            
            // Three syllable words
            "beautiful": [.stressed, .unstressed, .unstressed],
            "wonderful": [.stressed, .unstressed, .unstressed],
            "memory": [.stressed, .unstressed, .unstressed],
            "mystery": [.stressed, .unstressed, .unstressed],
            "yesterday": [.stressed, .unstressed, .unstressed],
            "everything": [.stressed, .unstressed, .unstressed],
            "anything": [.stressed, .unstressed, .unstressed],
            "someone": [.stressed, .unstressed, .unstressed],
            "everyone": [.stressed, .unstressed, .unstressed],
            "happiness": [.stressed, .unstressed, .unstressed],
            "tenderness": [.stressed, .unstressed, .unstressed],
            "forever": [.unstressed, .stressed, .unstressed],
            "together": [.unstressed, .stressed, .unstressed],
            "remember": [.unstressed, .stressed, .unstressed],
            "discover": [.unstressed, .stressed, .unstressed],
            "enchanted": [.unstressed, .stressed, .unstressed],
            "forgotten": [.unstressed, .stressed, .unstressed],
            "horizon": [.unstressed, .stressed, .unstressed],
            "emotion": [.unstressed, .stressed, .unstressed],
            "devotion": [.unstressed, .stressed, .unstressed],
            
            // Four syllable words
            "eternity": [.unstressed, .stressed, .unstressed, .unstressed],
            "serenity": [.unstressed, .stressed, .unstressed, .unstressed],
            "melancholy": [.stressed, .unstressed, .unstressed, .unstressed],
            "imagination": [.unstressed, .stressed, .unstressed, .stressed, .unstressed],
            "celebration": [.stressed, .unstressed, .stressed, .unstressed],
            "understanding": [.stressed, .unstressed, .stressed, .unstressed]
        ]
    }
}

// MARK: - Supporting Types

/// Result of matching a line to a specific meter
struct MeterMatch: Identifiable {
    let id = UUID()
    let meter: StressAnalyzer.MeterType
    let accuracy: Double
    let matchingFeet: Int
    let totalFeet: Int
    let deviations: [MeterDeviation]
    
    var percentAccuracy: Int {
        Int(accuracy * 100)
    }
    
    var isExactMatch: Bool {
        accuracy == 1.0 && totalFeet > 0
    }
}

/// A deviation from expected meter
struct MeterDeviation: Identifiable {
    let id = UUID()
    let footNumber: Int
    let expected: [StressAnalyzer.StressLevel]
    let actual: [StressAnalyzer.StressLevel]
    
    var expectedString: String {
        expected.map { $0.symbol }.joined()
    }
    
    var actualString: String {
        actual.map { $0.symbol }.joined()
    }
}
