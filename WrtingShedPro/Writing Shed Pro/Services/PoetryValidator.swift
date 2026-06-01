//
//  PoetryValidator.swift
//  Writing Shed Pro
//
//  Validates poetry against form requirements including line count,
//  syllable patterns, rhyme schemes, meter, and special patterns like Sestina end-words.
//

import Foundation

/// Represents a validation issue for a specific line
struct LineValidationIssue: Identifiable, Equatable {
    let id = UUID()
    let lineNumber: Int  // 1-based
    let lineText: String
    let issueType: IssueType
    let message: String
    let expected: String?
    let actual: String?
    
    enum IssueType: String, CaseIterable {
        case lineCount = "lineCount"
        case stanzaCount = "stanzaCount"
        case syllableCount = "syllableCount"
        case rhymeScheme = "rhymeScheme"
        case meter = "meter"
        case endWord = "endWord"  // For Sestina
        case refrain = "refrain"  // For Villanelle
    }
    
    static func == (lhs: LineValidationIssue, rhs: LineValidationIssue) -> Bool {
        lhs.lineNumber == rhs.lineNumber && 
        lhs.issueType == rhs.issueType &&
        lhs.message == rhs.message
    }
}

/// Result of validating a poem against its form
struct ValidationResult {
    let form: PoetryForm
    let issues: [LineValidationIssue]
    let lineCount: Int
    let expectedLineCount: Int?
    let stanzaCount: Int
    let expectedStanzaCount: Int?
    let overallCompliance: Double  // 0.0 to 1.0
    
    var hasIssues: Bool { !issues.isEmpty }
    var issueCount: Int { issues.count }
    
    /// Group issues by line number for inline display
    var issuesByLine: [Int: [LineValidationIssue]] {
        Dictionary(grouping: issues, by: { $0.lineNumber })
    }
    
    /// Get summary of issues by type
    var issuesByType: [LineValidationIssue.IssueType: Int] {
        var counts: [LineValidationIssue.IssueType: Int] = [:]
        for issue in issues {
            counts[issue.issueType, default: 0] += 1
        }
        return counts
    }
}

/// Service for validating poetry against form requirements
final class PoetryValidator {
    
    static let shared = PoetryValidator()
    
    private let syllableCounter = SyllableCounter.shared
    private let stressAnalyzer = StressAnalyzer.shared
    
    private init() {}
    
    // MARK: - Main Validation
    
    /// Validate text against a poetry form
    /// - Parameters:
    ///   - text: The poem text (plain string - all text is analyzed)
    ///   - form: The poetry form to validate against
    /// - Returns: ValidationResult with all issues found
    func validate(text: String, against form: PoetryForm) -> ValidationResult {
        return validateInternal(text: text, form: form)
    }
    
    /// Validate attributed text against a poetry form, filtering out non-poem sections
    /// - Parameters:
    ///   - attributedText: The poem text with section markers
    ///   - form: The poetry form to validate against
    /// - Returns: ValidationResult with all issues found (only poem body is analyzed)
    func validate(attributedText: NSAttributedString, against form: PoetryForm) -> ValidationResult {
        // Extract only the poem body, excluding title/epigraph/signature etc.
        let poemBody = attributedText.extractPoemBody()
        return validateInternal(text: poemBody, form: form)
    }
    
    /// Internal validation logic
    private func validateInternal(text: String, form: PoetryForm) -> ValidationResult {
        var issues: [LineValidationIssue] = []
        
        let lines = text.components(separatedBy: .newlines)
        
        // Create list of non-empty lines with sequential 1-based numbering
        // This gives us (poemLineNumber: Int, lineText: String) where poemLineNumber starts at 1
        var poemLineNumber = 0
        var numberedLines: [(lineNumber: Int, text: String)] = []
        for line in lines {
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                poemLineNumber += 1
                numberedLines.append((poemLineNumber, line))
            }
        }
        let lineCount = numberedLines.count
        
        // Count stanzas (groups of non-empty lines separated by blank lines)
        let stanzaCount = countStanzas(in: lines)
        
        // Skip validation for Free Verse and Custom forms
        guard form.id != PoetryForm.freeVerseId && !form.isCustom else {
            return ValidationResult(
                form: form,
                issues: [],
                lineCount: lineCount,
                expectedLineCount: nil,
                stanzaCount: stanzaCount,
                expectedStanzaCount: nil,
                overallCompliance: 1.0
            )
        }
        
        // Validate line count
        if let expected = form.lineCount, expected > 0 {
            issues.append(contentsOf: validateLineCount(lines: numberedLines, expected: expected))
        }
        
        // Validate stanza count
        if let expected = form.stanzaCount, expected > 0 {
            issues.append(contentsOf: validateStanzaCount(actual: stanzaCount, expected: expected))
        }
        
        // Validate syllable pattern
        if let pattern = form.syllablePattern, !pattern.isEmpty {
            issues.append(contentsOf: validateSyllablePattern(lines: numberedLines, pattern: pattern))
        }
        
        // Validate meter
        if let meter = form.meterPattern, !meter.isEmpty {
            issues.append(contentsOf: validateMeter(lines: numberedLines, meterString: meter))
        }
        
        // Validate rhyme scheme (form-specific)
        if let scheme = form.rhymeScheme, !scheme.isEmpty {
            let isEndWordForm = form.name.lowercased() == "sestina" ||
                scheme.lowercased().contains("rotating end-words")
            if !isEndWordForm {
                issues.append(contentsOf: validateRhymeScheme(lines: numberedLines, scheme: scheme, form: form))
            }
        }
        
        // Special validation for specific forms
        switch form.name.lowercased() {
        case "sestina":
            issues.append(contentsOf: validateSestinaEndWords(lines: numberedLines))
        case "villanelle":
            issues.append(contentsOf: validateVillanelleRefrains(lines: numberedLines))
        default:
            break
        }
        
        // Calculate overall compliance
        let totalChecks = max(1, lineCount)
        let issueWeight = Double(issues.count)
        let compliance = max(0, 1.0 - (issueWeight / Double(totalChecks * 2)))
        
        return ValidationResult(
            form: form,
            issues: issues,
            lineCount: lineCount,
            expectedLineCount: form.lineCount,
            stanzaCount: stanzaCount,
            expectedStanzaCount: form.stanzaCount,
            overallCompliance: compliance
        )
    }
    
    // MARK: - Line Count Validation
    
    private func validateLineCount(lines: [(lineNumber: Int, text: String)], expected: Int) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        let actual = lines.count
        
        if actual < expected {
            issues.append(LineValidationIssue(
                lineNumber: 0,  // 0 = overall issue, not specific line
                lineText: "",
                issueType: .lineCount,
                message: String(format: NSLocalizedString("poetryValidator.needMoreLines", comment: "Need more lines"), expected - actual),
                expected: "\(expected)",
                actual: "\(actual)"
            ))
        } else if actual > expected {
            // Mark extra lines
            for i in expected..<actual {
                let line = lines[i]
                issues.append(LineValidationIssue(
                    lineNumber: line.lineNumber,
                    lineText: line.text,
                    issueType: .lineCount,
                    message: NSLocalizedString("poetryValidator.extraLine", comment: "Extra line"),
                    expected: nil,
                    actual: nil
                ))
            }
        }
        
        return issues
    }
    
    // MARK: - Stanza Count Validation
    
    /// Count stanzas in a poem (groups of non-empty lines separated by blank lines)
    private func countStanzas(in lines: [String]) -> Int {
        var stanzaCount = 0
        var inStanza = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                // Blank line - end of current stanza if we were in one
                if inStanza {
                    inStanza = false
                }
            } else {
                // Non-empty line - start new stanza if not already in one
                if !inStanza {
                    stanzaCount += 1
                    inStanza = true
                }
            }
        }
        
        return stanzaCount
    }
    
    /// Validate stanza count against expected
    private func validateStanzaCount(actual: Int, expected: Int) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        if actual != expected {
            let message: String
            if actual < expected {
                message = String(format: NSLocalizedString("poetryValidator.needMoreStanzas", comment: "Need more stanzas"), expected - actual)
            } else {
                message = String(format: NSLocalizedString("poetryValidator.tooManyStanzas", comment: "Too many stanzas"), actual - expected)
            }
            
            issues.append(LineValidationIssue(
                lineNumber: 0,  // 0 = overall issue, not specific line
                lineText: "",
                issueType: .stanzaCount,
                message: message,
                expected: "\(expected)",
                actual: "\(actual)"
            ))
        }
        
        return issues
    }
    
    // MARK: - Syllable Pattern Validation
    
    private func validateSyllablePattern(lines: [(lineNumber: Int, text: String)], pattern: [Int]) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        for (index, expected) in pattern.enumerated() {
            guard index < lines.count else { break }
            
            let line = lines[index]
            let actual = syllableCounter.countSyllables(inLine: line.text)
            
            if actual != expected {
                issues.append(LineValidationIssue(
                    lineNumber: line.lineNumber,
                    lineText: line.text,
                    issueType: .syllableCount,
                    message: String(format: NSLocalizedString("poetryValidator.wrongSyllables", comment: "Wrong syllable count"), expected, actual),
                    expected: "\(expected) syllables",
                    actual: "\(actual) syllables"
                ))
            }
        }
        
        return issues
    }
    
    // MARK: - Meter Validation
    
    private func validateMeter(lines: [(lineNumber: Int, text: String)], meterString: String) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        guard let parsed = stressAnalyzer.parseMeterString(meterString) else {
            return issues
        }
        
        for line in lines {
            let match = stressAnalyzer.matchMeter(line.text, meter: parsed.meter)
            
            // Allow some tolerance - flag only if accuracy is below 60%
            if match.totalFeet > 0 && match.accuracy < 0.6 {
                issues.append(LineValidationIssue(
                    lineNumber: line.lineNumber,
                    lineText: line.text,
                    issueType: .meter,
                    message: String(format: NSLocalizedString("poetryValidator.meterMismatch", comment: "Meter mismatch"), Int(match.accuracy * 100)),
                    expected: meterString,
                    actual: "\(Int(match.accuracy * 100))% match"
                ))
            }
        }
        
        return issues
    }
    
    // MARK: - Rhyme Scheme Validation
    
    private func validateRhymeScheme(lines: [(lineNumber: Int, text: String)], scheme: String, form: PoetryForm) -> [LineValidationIssue] {
        let schemeOptions = parseRhymeSchemeOptions(scheme)
        guard !schemeOptions.isEmpty else { return [] }

        // Evaluate all allowed scheme options (e.g., "ABAB or ABCB") and keep the best fit.
        var bestIssues: [LineValidationIssue] = []
        var foundBest = false

        for option in schemeOptions {
            let optionIssues = validateRhymeSchemeOption(lines: lines, schemeLetters: option)

            if optionIssues.isEmpty {
                return []
            }

            if !foundBest || optionIssues.count < bestIssues.count {
                bestIssues = optionIssues
                foundBest = true
            }
        }

        return bestIssues
    }

    private func parseRhymeSchemeOptions(_ scheme: String) -> [[Swift.Character]] {
        let normalized = scheme.uppercased().replacingOccurrences(of: "\n", with: " ")

        var rawOptions = [normalized]
        for separator in [" OR ", "/", "|"] {
            rawOptions = rawOptions.flatMap { $0.components(separatedBy: separator) }
        }

        let options = rawOptions.compactMap { raw -> [Swift.Character]? in
            let withoutComment = raw.components(separatedBy: "(").first ?? raw
            let letters = withoutComment.filter { $0.isLetter }
            return letters.isEmpty ? nil : Array(letters)
        }

        if options.isEmpty {
            let letters = normalized.filter { $0.isLetter }
            return letters.isEmpty ? [] : [Array(letters)]
        }

        return options
    }

    private func validateRhymeSchemeOption(
        lines: [(lineNumber: Int, text: String)],
        schemeLetters: [Swift.Character]
    ) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []

        guard !schemeLetters.isEmpty else { return issues }

        // Get end words (last word of each line)
        let endWords = lines.map { getLastWord(from: $0.text) }

        // Build expected rhyme groups
        var rhymeGroups: [Swift.Character: [Int]] = [:]
        for (index, letter) in schemeLetters.enumerated() {
            if index < lines.count {
                rhymeGroups[letter, default: []].append(index)
            }
        }

        // Check that lines in the same rhyme group actually rhyme
        for (letter, lineIndices) in rhymeGroups {
            guard lineIndices.count > 1 else { continue }

            let firstIndex = lineIndices[0]
            let firstWord = endWords[firstIndex]

            for otherIndex in lineIndices.dropFirst() {
                guard otherIndex < endWords.count else { continue }
                let otherWord = endWords[otherIndex]

                let rhymeResult = checkRhyme(firstWord, otherWord)

                switch rhymeResult {
                case .perfect:
                    // Perfect rhyme - no issue
                    break

                case .slant:
                    // Slant rhyme is accepted for scheme matching.
                    break

                case .none:
                    // No rhyme - error
                    let line = lines[otherIndex]
                    issues.append(LineValidationIssue(
                        lineNumber: line.lineNumber,
                        lineText: line.text,
                        issueType: .rhymeScheme,
                        message: String(format: NSLocalizedString("poetryValidator.shouldRhyme", comment: "Should rhyme"), String(letter), firstWord),
                        expected: "Rhymes with '\(firstWord)' (\(letter))",
                        actual: "'\(otherWord)'"
                    ))
                }
            }
        }

        return issues
    }
    
    // MARK: - Sestina End-Word Validation
    
    /// The Sestina end-word rotation pattern
    /// Stanza 1: A B C D E F
    /// Stanza 2: F A E B D C
    /// Stanza 3: C F D A B E
    /// Stanza 4: E C B F A D
    /// Stanza 5: D E A C F B
    /// Stanza 6: B D F E C A
    /// Envoi: BE DC FA (middle and end)
    private let sestinaPattern: [[Int]] = [
        [0, 1, 2, 3, 4, 5],  // Stanza 1: A B C D E F
        [5, 0, 4, 1, 3, 2],  // Stanza 2: F A E B D C
        [2, 5, 3, 0, 1, 4],  // Stanza 3: C F D A B E
        [4, 2, 1, 5, 0, 3],  // Stanza 4: E C B F A D
        [3, 4, 0, 2, 5, 1],  // Stanza 5: D E A C F B
        [1, 3, 5, 4, 2, 0]   // Stanza 6: B D F E C A
    ]
    
    private func validateSestinaEndWords(lines: [(lineNumber: Int, text: String)]) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        // Need at least 6 lines to establish end-words
        guard lines.count >= 6 else { return issues }
        
        // Get end words from first stanza (these are the 6 key words: A B C D E F)
        let keyWords = (0..<min(6, lines.count)).map { getLastWord(from: lines[$0].text).lowercased() }
        
        guard keyWords.count == 6 else { return issues }
        
        // Check each subsequent stanza
        for stanzaIndex in 1..<6 {
            let stanzaStart = stanzaIndex * 6
            guard stanzaStart + 5 < lines.count else { break }
            
            let expectedPattern = sestinaPattern[stanzaIndex]
            
            for lineInStanza in 0..<6 {
                let lineIndex = stanzaStart + lineInStanza
                guard lineIndex < lines.count else { break }
                
                let line = lines[lineIndex]
                let actualEndWord = getLastWord(from: line.text).lowercased()
                let expectedWordIndex = expectedPattern[lineInStanza]
                let expectedEndWord = keyWords[expectedWordIndex]
                
                if !wordsMatch(actualEndWord, expectedEndWord) {
                    let wordLetter = ["A", "B", "C", "D", "E", "F"][expectedWordIndex]
                    issues.append(LineValidationIssue(
                        lineNumber: line.lineNumber,
                        lineText: line.text,
                        issueType: .endWord,
                        message: String(format: NSLocalizedString("poetryValidator.wrongEndWord", comment: "Wrong end word"), wordLetter, expectedEndWord),
                        expected: "'\(expectedEndWord)' (\(wordLetter))",
                        actual: "'\(actualEndWord)'"
                    ))
                }
            }
        }
        
        // Check envoi (last 3 lines) - each should contain 2 of the key words
        let envoiStart = 36
        if lines.count >= 39 {
            // Common envoi pairing variants:
            // 1) BE / DC / FA
            // 2) EC / BA / DF
            let envoiPairingOptions: [[(Int, Int)]] = [
                [(1, 4), (3, 2), (5, 0)],
                [(4, 2), (1, 0), (3, 5)]
            ]

            var bestEnvoiIssues: [LineValidationIssue] = []
            var foundBest = false

            for pairing in envoiPairingOptions {
                var pairingIssues: [LineValidationIssue] = []

                for (i, (firstWordIndex, secondWordIndex)) in pairing.enumerated() {
                    let lineIndex = envoiStart + i
                    guard lineIndex < lines.count else { break }

                    let line = lines[lineIndex]
                    let expectedFirst = keyWords[firstWordIndex]
                    let expectedSecond = keyWords[secondWordIndex]
                    let lineWords = extractNormalizedWords(from: line.text)

                    let hasFirst = lineWords.contains { wordsMatch($0, expectedFirst) }
                    let hasSecond = lineWords.contains { wordsMatch($0, expectedSecond) }

                    if !hasFirst || !hasSecond {
                        pairingIssues.append(LineValidationIssue(
                            lineNumber: line.lineNumber,
                            lineText: line.text,
                            issueType: .endWord,
                            message: NSLocalizedString("poetryValidator.wrongEndWord", comment: "Wrong end word"),
                            expected: "Contains both '\(expectedFirst)' and '\(expectedSecond)'",
                            actual: "\(lineWords.joined(separator: ", "))"
                        ))
                    }
                }

                if pairingIssues.isEmpty {
                    bestEnvoiIssues = []
                    foundBest = true
                    break
                }

                if !foundBest || pairingIssues.count < bestEnvoiIssues.count {
                    bestEnvoiIssues = pairingIssues
                    foundBest = true
                }
            }

            issues.append(contentsOf: bestEnvoiIssues)
        }
        
        return issues
    }
    
    // MARK: - Villanelle Refrain Validation
    
    private func validateVillanelleRefrains(lines: [(lineNumber: Int, text: String)]) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        guard lines.count >= 3 else { return issues }
        
        // A1 is line 1, A2 is line 3
        let refrain1 = lines[0].text.trimmingCharacters(in: .whitespaces)
        let refrain2 = lines.count > 2 ? lines[2].text.trimmingCharacters(in: .whitespaces) : ""
        
        // Refrain positions in a 19-line villanelle:
        // A1 appears at lines: 1, 6, 12, 18
        // A2 appears at lines: 3, 9, 15, 19
        let a1Positions = [0, 5, 11, 17]
        let a2Positions = [2, 8, 14, 18]
        
        for pos in a1Positions {
            guard pos < lines.count else { continue }
            guard pos > 0 else { continue }  // Skip first occurrence (it defines the refrain)
            
            let line = lines[pos]
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            
            if !trimmed.lowercased().hasPrefix(refrain1.lowercased().prefix(20)) {
                issues.append(LineValidationIssue(
                    lineNumber: line.lineNumber,
                    lineText: line.text,
                    issueType: .refrain,
                    message: NSLocalizedString("poetryValidator.shouldBeRefrain1", comment: "Should be first refrain"),
                    expected: refrain1,
                    actual: trimmed
                ))
            }
        }
        
        for pos in a2Positions {
            guard pos < lines.count else { continue }
            guard pos > 2 else { continue }  // Skip first occurrence
            
            let line = lines[pos]
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            
            if !trimmed.lowercased().hasPrefix(refrain2.lowercased().prefix(20)) {
                issues.append(LineValidationIssue(
                    lineNumber: line.lineNumber,
                    lineText: line.text,
                    issueType: .refrain,
                    message: NSLocalizedString("poetryValidator.shouldBeRefrain2", comment: "Should be second refrain"),
                    expected: refrain2,
                    actual: trimmed
                ))
            }
        }
        
        return issues
    }
    
    // MARK: - Helper Methods
    
    /// Extract the last word from a line
    private func getLastWord(from line: String) -> String {
        let words = line.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        return words.last ?? ""
    }

    /// Extract normalized words from a line for containment checks.
    private func extractNormalizedWords(from line: String) -> [String] {
        line.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }
    }
    
    /// Check if two words rhyme (uses CMU dictionary with heuristic fallback)
    /// Returns RhymeResult indicating perfect, slant, or no rhyme
    private func checkRhyme(_ word1: String, _ word2: String) -> RhymeResult {
        let w1 = word1.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let w2 = word2.lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        // Same word always rhymes perfectly
        if w1 == w2 { return .perfect }
        
        // Try CMU dictionary first for accurate phonetic rhyme detection
        let cmu = CMUDictionary.shared
        if cmu.contains(w1) && cmu.contains(w2) {
            return cmu.checkRhyme(w1, w2)
        }
        
        // Fallback to heuristic method if words not in dictionary
        return heuristicCheckRhyme(w1, w2)
    }
    
    /// Heuristic rhyme check (fallback when words not in CMU dictionary)
    /// Returns RhymeResult instead of just Bool
    private func heuristicCheckRhyme(_ w1: String, _ w2: String) -> RhymeResult {
        // Get phonetic endings from the last vowel sound
        let ending1 = getPhoneticEnding(w1)
        let ending2 = getPhoneticEnding(w2)
        
        // Exact match = perfect rhyme
        if ending1 == ending2 { return .perfect }
        
        // Near-rhyme: normalize consonant clusters and compare
        let normalized1 = normalizeConsonantClusters(ending1)
        let normalized2 = normalizeConsonantClusters(ending2)
        
        if normalized1 == normalized2 { return .perfect }
        
        // Check for slant rhyme using heuristics
        if isHeuristicSlantRhyme(ending1, ending2) {
            return .slant
        }
        
        return .none
    }
    
    /// Check for slant rhyme using string-based heuristics
    private func isHeuristicSlantRhyme(_ ending1: String, _ ending2: String) -> Bool {
        guard !ending1.isEmpty && !ending2.isEmpty else { return false }
        
        // Extract vowels and consonants
        let vowels = CharacterSet(charactersIn: "aeiouAEIOU")
        
        let vowels1 = ending1.unicodeScalars.filter { vowels.contains($0) }.map { String($0) }.joined()
        let vowels2 = ending2.unicodeScalars.filter { vowels.contains($0) }.map { String($0) }.joined()
        let consonants1 = ending1.unicodeScalars.filter { !vowels.contains($0) }.map { String($0) }.joined()
        let consonants2 = ending2.unicodeScalars.filter { !vowels.contains($0) }.map { String($0) }.joined()
        
        // Consonance: same consonants, different vowels
        if !consonants1.isEmpty && consonants1 == consonants2 && vowels1 != vowels2 {
            return true
        }
        
        // Assonance: same vowels, different consonants
        if !vowels1.isEmpty && vowels1 == vowels2 && consonants1 != consonants2 {
            return true
        }
        
        return false
    }
    
    /// Check if two words rhyme (uses CMU dictionary with heuristic fallback)
    private func wordsRhyme(_ word1: String, _ word2: String) -> Bool {
        let w1 = word1.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let w2 = word2.lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        // Same word always rhymes
        if w1 == w2 { return true }
        
        // Try CMU dictionary first for accurate phonetic rhyme detection
        let cmu = CMUDictionary.shared
        if cmu.contains(w1) && cmu.contains(w2) {
            return cmu.wordsRhyme(w1, w2)
        }
        
        // Fallback to heuristic method if words not in dictionary
        return heuristicWordsRhyme(w1, w2)
    }
    
    /// Heuristic rhyme check (fallback when words not in CMU dictionary)
    private func heuristicWordsRhyme(_ w1: String, _ w2: String) -> Bool {
        // Get phonetic endings from the last vowel sound
        let ending1 = getPhoneticEnding(w1)
        let ending2 = getPhoneticEnding(w2)
        
        // Exact match
        if ending1 == ending2 { return true }
        
        // Near-rhyme: normalize consonant clusters and compare
        let normalized1 = normalizeConsonantClusters(ending1)
        let normalized2 = normalizeConsonantClusters(ending2)
        
        return normalized1 == normalized2
    }
    
    /// Normalize consonant clusters that sound similar in rhymes
    /// Handles cases like "sounds/downs" where nds ≈ ns
    private func normalizeConsonantClusters(_ ending: String) -> String {
        var result = ending
        
        // Common cluster reductions (the middle consonant is often barely pronounced)
        // nds → nz (sounds/downs), mps → mz, nts → nz, lds → lz, etc.
        let clusterReductions = [
            ("ndz", "nz"),   // sounds → sownz, downs → ownz
            ("nds", "nz"),
            ("nts", "nz"),   // wants/ants
            ("mps", "mz"),   // jumps/bumps  
            ("mbs", "mz"),   // bombs/tombs
            ("lds", "lz"),   // fields/yields
            ("rds", "rz"),   // words/birds
            ("sts", "sz"),   // tests/rests
            ("sks", "sz"),   //asks/tasks
            ("fts", "fs"),   // lifts/gifts
            ("pts", "ps"),   // scripts/crypts
            ("cts", "ks"),   // acts/facts
            ("xts", "ks"),   // texts/nexts
        ]
        
        for (cluster, reduced) in clusterReductions {
            if result.hasSuffix(cluster) {
                result = String(result.dropLast(cluster.count)) + reduced
                break
            }
        }
        
        return result
    }
    
    /// Get phonetic ending for rhyme comparison - extracts from last vowel sound
    private func getPhoneticEnding(_ word: String) -> String {
        var w = word.lowercased()
        
        // Normalize common spelling variations that sound the same
        let spellingNormalizations: [(String, String)] = [
            // Endings that sound the same
            ("tion", "shun"),
            ("sion", "zhun"),
            ("cian", "shun"),
            ("eous", "yus"),
            ("ious", "yus"),
            ("uous", "yuwus"),
            // ight/ite sounds
            ("ight", "ite"),
            ("yte", "ite"),
            // ough variations
            ("ough", "ow"),     // though, dough
            ("augh", "aw"),     // caught, taught
            // ould sounds
            ("ould", "ud"),
            // Silent e patterns
            ("ue", "oo"),
            // ph sounds
            ("ph", "f"),
        ]
        
        for (spelling, sound) in spellingNormalizations {
            if w.contains(spelling) {
                w = w.replacingOccurrences(of: spelling, with: sound)
            }
        }
        
        // Find the rhyme portion: from the last stressed vowel to end
        // For simplicity, find the last vowel cluster and include trailing consonants
        let vowels: Set<Swift.Character> = ["a", "e", "i", "o", "u", "y"]
        let chars = Array(w)
        
        // Find position of last vowel
        var lastVowelIndex = -1
        for i in stride(from: chars.count - 1, through: 0, by: -1) {
            if vowels.contains(chars[i]) {
                lastVowelIndex = i
                break
            }
        }

        // Handle common silent-e endings (e.g., "alone"), where final 'e' is not pronounced.
        if lastVowelIndex == chars.count - 1,
           chars.count >= 3,
           chars[lastVowelIndex] == "e",
           !vowels.contains(chars[lastVowelIndex - 1]) {
            for i in stride(from: lastVowelIndex - 1, through: 0, by: -1) {
                if vowels.contains(chars[i]) {
                    lastVowelIndex = i
                    break
                }
            }
        }
        
        // If no vowel found, use whole word
        guard lastVowelIndex >= 0 else {
            return w
        }
        
        // Look for vowel cluster start (handle diphthongs like "ou", "ow", "ai", etc.)
        var clusterStart = lastVowelIndex
        
        // Check for common vowel digraphs/diphthongs before the last vowel
        if lastVowelIndex > 0 {
            let twoCharEnding = String(chars.suffix(from: max(0, lastVowelIndex - 1)))
            let diphthongs = ["ou", "ow", "oi", "oy", "ai", "ay", "au", "aw", "ea", "ee", "oo", "ie", "ei"]
            
            for diphthong in diphthongs {
                if twoCharEnding.hasPrefix(diphthong) {
                    clusterStart = lastVowelIndex - 1
                    break
                }
            }
        }
        
        // Extract from vowel cluster to end
        let rhymePortion = String(chars.suffix(from: clusterStart))
        
        // Normalize diphthongs that sound the same for rhyming
        var normalized = rhymePortion
        
        // ou/ow sound the same (as in "sound" / "down")
        normalized = normalized.replacingOccurrences(of: "ou", with: "ow")
        
        // oi/oy sound the same (as in "coin" / "boy")
        normalized = normalized.replacingOccurrences(of: "oi", with: "oy")
        
        // ai/ay/ei/ey sound the same (as in "rain" / "day" / "vein" / "grey")
        normalized = normalized.replacingOccurrences(of: "ai", with: "ay")
        normalized = normalized.replacingOccurrences(of: "ei", with: "ay")
        normalized = normalized.replacingOccurrences(of: "ey", with: "ay")
        
        // au/aw sound the same (as in "cause" / "law")
        normalized = normalized.replacingOccurrences(of: "au", with: "aw")
        
        // ea/ee sound the same when long e (as in "sea" / "see")
        normalized = normalized.replacingOccurrences(of: "ea", with: "ee")

        // Long-o ending variants (alone/stone/phone often rhyme with own/known/mown).
        if normalized.hasSuffix("one") {
            let shortOExceptions: Set<String> = ["one", "none", "done", "gone", "won", "someone", "anyone", "everyone", "noone"]
            if !shortOExceptions.contains(w) {
                normalized = String(normalized.dropLast(3)) + "own"
            }
        }
        
        // Handle s/z at end (sounds similar in rhymes)
        if normalized.hasSuffix("s") || normalized.hasSuffix("z") {
            // Keep the sibilant but normalize
            let base = String(normalized.dropLast())
            normalized = base + "z"
        }
        
        // Handle -ed endings (often sounds like -t or -d)
        if normalized.hasSuffix("ed") && normalized.count > 2 {
            let beforeEd = normalized[normalized.index(normalized.endIndex, offsetBy: -3)]
            if ["t", "d"].contains(beforeEd) {
                // "wanted" -> keeps -ed sound
            } else {
                // "jumped" sounds like "jumpt", "buzzed" sounds like "buzzd"
                normalized = String(normalized.dropLast(2)) + "d"
            }
        }
        
        return normalized
    }
    
    /// Check if two words match (same word or variation)
    private func wordsMatch(_ word1: String, _ word2: String) -> Bool {
        let w1 = word1.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let w2 = word2.lowercased().trimmingCharacters(in: .punctuationCharacters)
        
        // Exact match
        if w1 == w2 { return true }
        
        // Allow slight variations (e.g., plurals, verb forms)
        if w1.hasPrefix(w2) || w2.hasPrefix(w1) {
            let diff = abs(w1.count - w2.count)
            return diff <= 3  // Allow up to 3 character difference for variations
        }
        
        return false
    }
}
