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
        let nonEmptyLines = lines.enumerated().filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
        let lineCount = nonEmptyLines.count
        
        // Skip validation for Free Verse and Custom forms
        guard form.id != PoetryForm.freeVerseId && !form.isCustom else {
            return ValidationResult(
                form: form,
                issues: [],
                lineCount: lineCount,
                expectedLineCount: nil,
                overallCompliance: 1.0
            )
        }
        
        // Validate line count
        if let expected = form.lineCount, expected > 0 {
            issues.append(contentsOf: validateLineCount(lines: nonEmptyLines.map { $0.element }, expected: expected))
        }
        
        // Validate syllable pattern
        if let pattern = form.syllablePattern, !pattern.isEmpty {
            issues.append(contentsOf: validateSyllablePattern(lines: nonEmptyLines, pattern: pattern))
        }
        
        // Validate meter
        if let meter = form.meterPattern, !meter.isEmpty {
            issues.append(contentsOf: validateMeter(lines: nonEmptyLines, meterString: meter))
        }
        
        // Validate rhyme scheme (form-specific)
        if let scheme = form.rhymeScheme, !scheme.isEmpty {
            issues.append(contentsOf: validateRhymeScheme(lines: nonEmptyLines, scheme: scheme, form: form))
        }
        
        // Special validation for specific forms
        switch form.name.lowercased() {
        case "sestina":
            issues.append(contentsOf: validateSestinaEndWords(lines: nonEmptyLines))
        case "villanelle":
            issues.append(contentsOf: validateVillanelleRefrains(lines: nonEmptyLines))
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
            overallCompliance: compliance
        )
    }
    
    // MARK: - Line Count Validation
    
    private func validateLineCount(lines: [String], expected: Int) -> [LineValidationIssue] {
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
                issues.append(LineValidationIssue(
                    lineNumber: i + 1,
                    lineText: lines[i],
                    issueType: .lineCount,
                    message: NSLocalizedString("poetryValidator.extraLine", comment: "Extra line"),
                    expected: nil,
                    actual: nil
                ))
            }
        }
        
        return issues
    }
    
    // MARK: - Syllable Pattern Validation
    
    private func validateSyllablePattern(lines: [(offset: Int, element: String)], pattern: [Int]) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        for (index, expected) in pattern.enumerated() {
            guard index < lines.count else { break }
            
            let (lineIndex, lineText) = lines[index]
            let actual = syllableCounter.countSyllables(in: lineText)
            
            if actual != expected {
                issues.append(LineValidationIssue(
                    lineNumber: lineIndex + 1,
                    lineText: lineText,
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
    
    private func validateMeter(lines: [(offset: Int, element: String)], meterString: String) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        guard let parsed = stressAnalyzer.parseMeterString(meterString) else {
            return issues
        }
        
        for (lineIndex, lineText) in lines {
            let match = stressAnalyzer.matchMeter(lineText, meter: parsed.meter)
            
            // Allow some tolerance - flag only if accuracy is below 60%
            if match.totalFeet > 0 && match.accuracy < 0.6 {
                issues.append(LineValidationIssue(
                    lineNumber: lineIndex + 1,
                    lineText: lineText,
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
    
    private func validateRhymeScheme(lines: [(offset: Int, element: String)], scheme: String, form: PoetryForm) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        // Parse rhyme scheme - extract letters only
        let schemeLetters = scheme.uppercased().filter { $0.isLetter }
        guard !schemeLetters.isEmpty else { return issues }
        
        // Get end words (last word of each line)
        let endWords = lines.map { getLastWord(from: $0.element) }
        
        // Build expected rhyme groups
        var rhymeGroups: [Character: [Int]] = [:]
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
                
                if !wordsRhyme(firstWord, otherWord) {
                    let (lineIndex, lineText) = lines[otherIndex]
                    issues.append(LineValidationIssue(
                        lineNumber: lineIndex + 1,
                        lineText: lineText,
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
    
    private func validateSestinaEndWords(lines: [(offset: Int, element: String)]) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        // Need at least 6 lines to establish end-words
        guard lines.count >= 6 else { return issues }
        
        // Get end words from first stanza (these are the 6 key words: A B C D E F)
        let keyWords = (0..<min(6, lines.count)).map { getLastWord(from: lines[$0].element).lowercased() }
        
        guard keyWords.count == 6 else { return issues }
        
        // Check each subsequent stanza
        for stanzaIndex in 1..<6 {
            let stanzaStart = stanzaIndex * 6
            guard stanzaStart + 5 < lines.count else { break }
            
            let expectedPattern = sestinaPattern[stanzaIndex]
            
            for lineInStanza in 0..<6 {
                let lineIndex = stanzaStart + lineInStanza
                guard lineIndex < lines.count else { break }
                
                let (originalIndex, lineText) = lines[lineIndex]
                let actualEndWord = getLastWord(from: lineText).lowercased()
                let expectedWordIndex = expectedPattern[lineInStanza]
                let expectedEndWord = keyWords[expectedWordIndex]
                
                if !wordsMatch(actualEndWord, expectedEndWord) {
                    let wordLetter = ["A", "B", "C", "D", "E", "F"][expectedWordIndex]
                    issues.append(LineValidationIssue(
                        lineNumber: originalIndex + 1,
                        lineText: lineText,
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
            // Envoi pattern: Line 1 has B in middle, E at end
            //               Line 2 has D in middle, C at end
            //               Line 3 has F in middle, A at end
            let envoiEnds = [
                (4, "E"),  // Line 37 ends with E
                (2, "C"),  // Line 38 ends with C
                (0, "A")   // Line 39 ends with A
            ]
            
            for (i, (wordIndex, wordLetter)) in envoiEnds.enumerated() {
                let lineIndex = envoiStart + i
                guard lineIndex < lines.count else { break }
                
                let (originalIndex, lineText) = lines[lineIndex]
                let actualEndWord = getLastWord(from: lineText).lowercased()
                let expectedEndWord = keyWords[wordIndex]
                
                if !wordsMatch(actualEndWord, expectedEndWord) {
                    issues.append(LineValidationIssue(
                        lineNumber: originalIndex + 1,
                        lineText: lineText,
                        issueType: .endWord,
                        message: String(format: NSLocalizedString("poetryValidator.wrongEndWord", comment: "Wrong end word"), wordLetter, expectedEndWord),
                        expected: "'\(expectedEndWord)' (\(wordLetter))",
                        actual: "'\(actualEndWord)'"
                    ))
                }
            }
        }
        
        return issues
    }
    
    // MARK: - Villanelle Refrain Validation
    
    private func validateVillanelleRefrains(lines: [(offset: Int, element: String)]) -> [LineValidationIssue] {
        var issues: [LineValidationIssue] = []
        
        guard lines.count >= 3 else { return issues }
        
        // A1 is line 1, A2 is line 3
        let refrain1 = lines[0].element.trimmingCharacters(in: .whitespaces)
        let refrain2 = lines.count > 2 ? lines[2].element.trimmingCharacters(in: .whitespaces) : ""
        
        // Refrain positions in a 19-line villanelle:
        // A1 appears at lines: 1, 6, 12, 18
        // A2 appears at lines: 3, 9, 15, 19
        let a1Positions = [0, 5, 11, 17]
        let a2Positions = [2, 8, 14, 18]
        
        for pos in a1Positions {
            guard pos < lines.count else { continue }
            guard pos > 0 else { continue }  // Skip first occurrence (it defines the refrain)
            
            let (lineIndex, lineText) = lines[pos]
            let trimmed = lineText.trimmingCharacters(in: .whitespaces)
            
            if !trimmed.lowercased().hasPrefix(refrain1.lowercased().prefix(20)) {
                issues.append(LineValidationIssue(
                    lineNumber: lineIndex + 1,
                    lineText: lineText,
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
            
            let (lineIndex, lineText) = lines[pos]
            let trimmed = lineText.trimmingCharacters(in: .whitespaces)
            
            if !trimmed.lowercased().hasPrefix(refrain2.lowercased().prefix(20)) {
                issues.append(LineValidationIssue(
                    lineNumber: lineIndex + 1,
                    lineText: lineText,
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
    
    /// Check if two words rhyme (simple phonetic check)
    private func wordsRhyme(_ word1: String, _ word2: String) -> Bool {
        let w1 = word1.lowercased()
        let w2 = word2.lowercased()
        
        // Same word always rhymes
        if w1 == w2 { return true }
        
        // Check ending sounds (last 2-3 characters as approximation)
        let ending1 = getPhoneticEnding(w1)
        let ending2 = getPhoneticEnding(w2)
        
        return ending1 == ending2
    }
    
    /// Get phonetic ending for rhyme comparison
    private func getPhoneticEnding(_ word: String) -> String {
        let w = word.lowercased()
        
        // Handle common suffix variations
        let suffixMappings: [(String, String)] = [
            ("tion", "shun"),
            ("sion", "shun"),
            ("ight", "ite"),
            ("ough", "uff"),
            ("ould", "ood"),
            ("ould", "ud")
        ]
        
        var processed = w
        for (suffix, normalized) in suffixMappings {
            if processed.hasSuffix(suffix) {
                processed = String(processed.dropLast(suffix.count)) + normalized
                break
            }
        }
        
        // Return last 2-3 characters as rhyme key
        let minLength = min(3, processed.count)
        return String(processed.suffix(minLength))
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
