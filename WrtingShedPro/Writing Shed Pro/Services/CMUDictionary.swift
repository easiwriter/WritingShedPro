//
//  CMUDictionary.swift
//  Writing Shed Pro
//
//  A service for looking up word pronunciations using the CMU Pronouncing Dictionary.
//  The CMU dictionary uses ARPAbet phonemes with stress markers (0=unstressed, 1=primary, 2=secondary).
//  This enables accurate phonetic rhyme detection based on actual pronunciations.
//

import Foundation

/// Result of rhyme comparison between two words
enum RhymeResult: Equatable {
    case perfect      // Full rhyme: same vowel and consonants from stressed vowel to end
    case slant        // Slant/half rhyme: similar but not identical sounds
    case none         // No rhyme detected
    
    /// Whether this counts as some form of rhyme
    var isRhyme: Bool {
        self == .perfect || self == .slant
    }
}

/// Represents a phoneme from the CMU dictionary
struct Phoneme: Equatable, Hashable {
    let symbol: String      // The phoneme (e.g., "AW", "N", "D", "Z")
    let stress: Int?        // Stress level for vowels: 0, 1, or 2 (nil for consonants)
    
    /// Check if this is a vowel phoneme (has stress marker)
    var isVowel: Bool { stress != nil }
    
    /// Get the base phoneme without stress (for comparison)
    var base: String { symbol }
    
    init(raw: String) {
        // Parse phoneme like "AW1" or "N"
        let lastChar = raw.last
        if let last = lastChar, let stressVal = Int(String(last)), (0...2).contains(stressVal) {
            self.symbol = String(raw.dropLast())
            self.stress = stressVal
        } else {
            self.symbol = raw
            self.stress = nil
        }
    }
}

/// Service for accessing pronunciation dictionaries (CMU for US, custom for UK)
/// Supports switching between American and British English dialects
final class CMUDictionary {
    
    static let shared = CMUDictionary()
    
    /// Dictionary mapping words to their phoneme sequences
    /// Some words have multiple pronunciations (stored as array)
    private var pronunciations: [String: [[Phoneme]]] = [:]
    
    /// The currently loaded dialect
    private var loadedDialect: EnglishDialect?
    
    /// Loading state for thread safety
    private let loadingQueue = DispatchQueue(label: "com.writingshed.cmu-dictionary")
    
    /// Observer for dialect changes
    private var dialectObserver: NSObjectProtocol?
    
    private init() {
        // Listen for dialect changes
        dialectObserver = NotificationCenter.default.addObserver(
            forName: .dialectDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newDialect = notification.object as? EnglishDialect {
                self?.switchDialect(to: newDialect)
            }
        }
    }
    
    deinit {
        if let observer = dialectObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Switch to a different dialect's dictionary
    private func switchDialect(to dialect: EnglishDialect) {
        loadingQueue.sync {
            guard loadedDialect != dialect else { return }
            pronunciations.removeAll()
            loadedDialect = nil
            loadDictionary(for: dialect)
            loadedDialect = dialect
            print("CMUDictionary: Switched to \(dialect.displayName)")
        }
    }
    
    /// Get the current dialect (defaults to user preference)
    var currentDialect: EnglishDialect {
        loadedDialect ?? PoetryPreferences.shared.englishDialect
    }
    
    /// Ensure the dictionary is loaded before use
    func ensureLoaded() {
        let targetDialect = PoetryPreferences.shared.englishDialect
        loadingQueue.sync {
            guard loadedDialect != targetDialect else { return }
            loadDictionary(for: targetDialect)
            loadedDialect = targetDialect
        }
    }
    
    /// Load a pronunciation dictionary for the specified dialect
    private func loadDictionary(for dialect: EnglishDialect) {
        pronunciations.removeAll()
        
        // Try to find the bundled dictionary file for this dialect
        let fileName = dialect.dictionaryFileName
        
        // Search in multiple bundles (main app bundle and the bundle containing this class)
        let bundlesToSearch = [Bundle.main, Bundle(for: CMUDictionary.self)]
        var url: URL?
        for bundle in bundlesToSearch {
            if let foundUrl = bundle.url(forResource: fileName, withExtension: "txt") {
                url = foundUrl
                break
            }
        }
        
        guard let dictionaryUrl = url else {
            print("CMUDictionary: \(fileName).txt not found in any bundle")
            // Fall back to CMU dictionary if British dictionary not found
            if dialect == .british {
                print("CMUDictionary: Falling back to American English dictionary")
                for bundle in bundlesToSearch {
                    if let fallbackUrl = bundle.url(forResource: "cmudict", withExtension: "txt") {
                        do {
                            let content = try String(contentsOf: fallbackUrl, encoding: .utf8)
                            parseDictionary(content)
                            print("CMUDictionary: Loaded \(pronunciations.count) words (US fallback)")
                        } catch {
                            print("CMUDictionary: Error loading fallback dictionary: \(error)")
                        }
                        return
                    }
                }
            }
            return
        }
        
        do {
            let content = try String(contentsOf: dictionaryUrl, encoding: .utf8)
            parseDictionary(content)
            print("CMUDictionary: Loaded \(pronunciations.count) words (\(dialect.displayName))")
        } catch {
            print("CMUDictionary: Error loading dictionary: \(error)")
        }
    }
    
    /// Parse the CMU dictionary content
    private func parseDictionary(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            // Skip comments and empty lines
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(";;;") || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse: "WORD PHONEME1 PHONEME2 ..." or "WORD(2) PHONEME1 PHONEME2 ..."
            let parts = trimmed.components(separatedBy: "  ") // Double space separates word from phonemes
            guard parts.count >= 2 else {
                // Try single space (some variants use single space)
                let singleParts = trimmed.split(separator: " ", maxSplits: 1)
                guard singleParts.count == 2 else { continue }
                let word = normalizeWord(String(singleParts[0]))
                let phonemes = parsePhonemes(String(singleParts[1]))
                addPronunciation(word: word, phonemes: phonemes)
                continue
            }
            
            let word = normalizeWord(parts[0])
            let phonemes = parsePhonemes(parts[1])
            addPronunciation(word: word, phonemes: phonemes)
        }
    }
    
    /// Normalize word for lookup (lowercase, remove variant markers like "(2)")
    private func normalizeWord(_ word: String) -> String {
        var normalized = word.lowercased()
        
        // Remove variant markers like (2), (3), etc.
        if let parenIndex = normalized.firstIndex(of: "(") {
            normalized = String(normalized[..<parenIndex])
        }
        
        // Remove apostrophes for lookup consistency
        normalized = normalized.replacingOccurrences(of: "'", with: "")
        
        return normalized
    }
    
    /// Parse phoneme string into Phoneme array
    private func parsePhonemes(_ phonemeString: String) -> [Phoneme] {
        return phonemeString
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { Phoneme(raw: $0) }
    }
    
    /// Add a pronunciation to the dictionary
    private func addPronunciation(word: String, phonemes: [Phoneme]) {
        guard !phonemes.isEmpty else { return }
        
        if pronunciations[word] == nil {
            pronunciations[word] = [phonemes]
        } else {
            pronunciations[word]?.append(phonemes)
        }
    }
    
    // MARK: - Public API
    
    /// Look up pronunciations for a word
    /// - Parameter word: The word to look up (case-insensitive)
    /// - Returns: Array of possible pronunciations, or nil if not found
    func lookup(_ word: String) -> [[Phoneme]]? {
        ensureLoaded()
        let normalized = normalizeWord(word.trimmingCharacters(in: .punctuationCharacters))
        return pronunciations[normalized]
    }
    
    /// Get the primary (first) pronunciation for a word
    func primaryPronunciation(for word: String) -> [Phoneme]? {
        return lookup(word)?.first
    }
    
    /// Check if a word exists in the dictionary
    func contains(_ word: String) -> Bool {
        ensureLoaded()
        let normalized = normalizeWord(word.trimmingCharacters(in: .punctuationCharacters))
        return pronunciations[normalized] != nil
    }
    
    /// Get the rhyming portion of a word (from last stressed vowel to end)
    /// - Parameter word: The word to get rhyme ending for
    /// - Returns: Array of phonemes from the stressed vowel to end, or nil if not found
    func rhymeEnding(for word: String) -> [Phoneme]? {
        guard let phonemes = primaryPronunciation(for: word), !phonemes.isEmpty else {
            return nil
        }
        
        return extractRhymeEnding(from: phonemes)
    }
    
    /// Extract rhyme ending from phoneme sequence
    /// Finds the last stressed vowel (stress 1 or 2) and returns from there to end
    private func extractRhymeEnding(from phonemes: [Phoneme]) -> [Phoneme]? {
        // Find the last vowel with primary or secondary stress
        // If none found, use the last vowel regardless of stress
        var lastStressedIndex = -1
        var lastVowelIndex = -1
        
        for (index, phoneme) in phonemes.enumerated() {
            if phoneme.isVowel {
                lastVowelIndex = index
                if phoneme.stress == 1 || phoneme.stress == 2 {
                    lastStressedIndex = index
                }
            }
        }
        
        // Prefer stressed vowel, fallback to any vowel
        let startIndex = lastStressedIndex >= 0 ? lastStressedIndex : lastVowelIndex
        
        guard startIndex >= 0 else { return nil }
        
        return Array(phonemes.suffix(from: startIndex))
    }
    
    /// Check the rhyme relationship between two words
    /// - Parameters:
    ///   - word1: First word
    ///   - word2: Second word
    /// - Returns: RhymeResult indicating perfect, slant, or no rhyme
    func checkRhyme(_ word1: String, _ word2: String) -> RhymeResult {
        let w1 = word1.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let w2 = word2.lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        // Same word always rhymes
        if w1 == w2 { return .perfect }
        
        // Get rhyme endings
        guard let ending1 = rhymeEnding(for: w1),
              let ending2 = rhymeEnding(for: w2),
              !ending1.isEmpty, !ending2.isEmpty else {
            return .none
        }
        
        // Check for perfect rhyme first
        if rhymeEndingsMatch(ending1, ending2) {
            return .perfect
        }
        
        // Check for slant rhyme
        if isSlantRhyme(ending1, ending2) {
            return .slant
        }
        
        return .none
    }
    
    /// Check if two endings form a slant rhyme
    /// Slant rhymes share either:
    /// - Same final consonants but different vowels (consonance): "bat" / "bit"
    /// - Same vowel but different final consonants (assonance): "lake" / "fate"
    private func isSlantRhyme(_ ending1: [Phoneme], _ ending2: [Phoneme]) -> Bool {
        // Extract vowels and consonants from each ending
        let vowels1 = ending1.filter { $0.isVowel }.map { $0.base }
        let vowels2 = ending2.filter { $0.isVowel }.map { $0.base }
        let consonants1 = ending1.filter { !$0.isVowel }.map { $0.base }
        let consonants2 = ending2.filter { !$0.isVowel }.map { $0.base }
        
        // Must have at least a vowel in each
        guard !vowels1.isEmpty && !vowels2.isEmpty else { return false }
        
        // Consonance: same final consonants, different vowels
        // The last consonant(s) must match
        if !consonants1.isEmpty && consonants1 == consonants2 && vowels1 != vowels2 {
            return true
        }
        
        // Assonance: same vowel sound, different consonants
        // The main vowel should match
        if let lastVowel1 = vowels1.last, let lastVowel2 = vowels2.last {
            if lastVowel1 == lastVowel2 && consonants1 != consonants2 {
                return true
            }
        }
        
        // Near-consonance: similar consonant sounds (voiced/unvoiced pairs)
        // E.g., "bed" / "bet" (D vs T are voiced/unvoiced pair)
        if vowels1 == vowels2 && areSimilarConsonants(consonants1, consonants2) {
            return true
        }
        
        return false
    }
    
    /// Check if two consonant sequences are similar (voiced/unvoiced pairs)
    private func areSimilarConsonants(_ c1: [String], _ c2: [String]) -> Bool {
        guard c1.count == c2.count && !c1.isEmpty else { return false }
        
        // Voiced/unvoiced consonant pairs
        let pairs: Set<Set<String>> = [
            ["B", "P"], ["D", "T"], ["G", "K"],
            ["V", "F"], ["Z", "S"], ["ZH", "SH"],
            ["JH", "CH"], ["DH", "TH"]
        ]
        
        for (p1, p2) in zip(c1, c2) {
            if p1 == p2 { continue }
            // Check if they form a voiced/unvoiced pair
            let pair = Set([p1, p2])
            if !pairs.contains(pair) {
                return false
            }
        }
        return true
    }
    
    /// Check if two words rhyme based on CMU pronunciations
    /// - Parameters:
    ///   - word1: First word
    ///   - word2: Second word
    /// - Returns: True if the words rhyme (same sound from stressed vowel to end)
    func wordsRhyme(_ word1: String, _ word2: String) -> Bool {
        // Same word always rhymes
        let w1 = word1.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let w2 = word2.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if w1 == w2 { return true }
        
        // Get rhyme endings
        guard let ending1 = rhymeEnding(for: word1),
              let ending2 = rhymeEnding(for: word2),
              !ending1.isEmpty, !ending2.isEmpty else {
            // One or both words not in dictionary - caller should use fallback
            return false
        }
        
        // Compare phoneme sequences (ignoring stress differences)
        // Also allows for common near-rhyme patterns
        return rhymeEndingsMatch(ending1, ending2)
    }
    
    /// Check if two rhyme endings match (comparing phonemes ignoring stress)
    /// Supports both perfect rhymes and common near-rhymes (consonant cluster variations)
    private func rhymeEndingsMatch(_ ending1: [Phoneme], _ ending2: [Phoneme]) -> Bool {
        // Perfect match (same length, same phonemes)
        if ending1.count == ending2.count {
            var match = true
            for (p1, p2) in zip(ending1, ending2) {
                if p1.base != p2.base {
                    match = false
                    break
                }
            }
            if match { return true }
        }
        
        // Near-rhyme check for consonant cluster variations
        // Common in English poetry: sounds/downs, fields/yields, etc.
        // The vowel and final consonants should match, allowing for one extra/missing consonant
        
        // Normalize endings to compare (handle clusters like ND vs N, or NDZ vs NZ)
        let norm1 = normalizeRhymeEnding(ending1)
        let norm2 = normalizeRhymeEnding(ending2)
        
        if norm1.count == norm2.count {
            for (p1, p2) in zip(norm1, norm2) {
                if p1.base != p2.base {
                    return false
                }
            }
            return true
        }
        
        return false
    }
    
    /// Normalize a rhyme ending to handle common consonant cluster variations
    /// E.g., NDZ → NZ, NTS → NS (these sound very similar in connected speech)
    private func normalizeRhymeEnding(_ ending: [Phoneme]) -> [Phoneme] {
        guard ending.count >= 2 else { return ending }
        
        var result = ending
        
        // Check for consonant clusters that can be reduced for rhyme purposes
        // These are consonants that are often elided in fast speech
        let reducibleClusters: Set<String> = ["D", "T", "P", "K", "B", "G"]
        
        // Look for patterns like [vowel, cons1, cons2, cons3] where cons2 can be dropped
        // E.g., N-D-Z → N-Z (sounds vs downs)
        if result.count >= 3 {
            let lastThree = Array(result.suffix(3))
            // Check if middle consonant of last three is a stop consonant before a fricative
            if !lastThree[0].isVowel && 
               reducibleClusters.contains(lastThree[1].base) &&
               ["S", "Z"].contains(lastThree[2].base) {
                // Remove the middle consonant (e.g., NDZ → NZ)
                result.remove(at: result.count - 2)
            }
        }
        
        return result
    }
    
    /// Get number of loaded entries (for debugging)
    var entryCount: Int {
        ensureLoaded()
        return pronunciations.count
    }
}
