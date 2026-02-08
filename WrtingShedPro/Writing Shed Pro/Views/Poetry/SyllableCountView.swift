import SwiftUI
import TipKit

/// A view displaying line-by-line syllable counts with visual feedback
/// Shows actual vs expected counts and color-codes accuracy
/// Blank lines and marked sections are filtered out
struct SyllableCountView: View {
    /// The full attributed text (to identify excluded sections)
    let attributedText: NSAttributedString
    let expectedPattern: [Int]?
    
    /// Convenience for plain text when attributed text not available
    init(text: String, expectedPattern: [Int]?) {
        self.attributedText = NSAttributedString(string: text)
        self.expectedPattern = expectedPattern
    }
    
    init(attributedText: NSAttributedString, expectedPattern: [Int]?) {
        self.attributedText = attributedText
        self.expectedPattern = expectedPattern
    }
    
    @State private var comparisons: [SyllableComparison] = []
    
    private let syllableCounter = SyllableCounter.shared
    
    /// Plain text from attributed text
    private var text: String {
        attributedText.string
    }
    
    /// Filtered comparisons - excludes marked sections, keeps blank lines
    /// Returns tuple with optional display line number (nil for blank lines)
    private var displayComparisons: [(displayLineNumber: Int?, comparison: SyllableComparison)] {
        var result: [(Int?, SyllableComparison)] = []
        var displayNumber = 1
        
        for comparison in comparisons {
            // Skip excluded lines entirely
            if comparison.isExcluded {
                continue
            }
            
            // Keep blank lines but don't number them
            let isBlank = comparison.lineText.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank {
                result.append((nil, comparison))
            } else {
                result.append((displayNumber, comparison))
                displayNumber += 1
            }
        }
        
        return result
    }
    
    /// Count of non-blank lines (for summary)
    private var nonBlankLineCount: Int {
        displayComparisons.filter { $0.displayLineNumber != nil }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // FR-4.2: Syllable Counter tip
            if expectedPattern != nil {
                TipView(SyllableCounterTip())
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .onAppear {
                        SyllableCounterTip.hasPoetryForm = true
                    }
            }
            
            // Header
            headerRow
            
            Divider()
            
            // Empty state or line-by-line analysis
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(Array(displayComparisons.enumerated()), id: \.offset) { _, item in
                        SyllableLineRow(comparison: item.comparison, displayLineNumber: item.displayLineNumber)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .listStyle(.plain)
            }
            
            // Summary footer
            if !displayComparisons.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                summaryFooter
            }
        }
        .onAppear {
            analyzeText()
        }
        .onChange(of: text) { _, _ in
            analyzeText()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("syllableCount.empty", comment: "No text to analyze"))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("syllableCount.emptyHint", comment: "Start writing to see syllable counts"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Header
    
    private var headerRow: some View {
        HStack {
            Text(NSLocalizedString("syllableCount.line", comment: "Line"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 40)
            
            Text(NSLocalizedString("syllableCount.text", comment: "Text"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if expectedPattern != nil {
                Text(NSLocalizedString("syllableCount.expected", comment: "Exp"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }
            
            Text(NSLocalizedString("syllableCount.actual", comment: "Act"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Summary
    
    private var summaryFooter: some View {
        // Use displayComparisons (already filtered), only count non-blank lines
        let nonBlankItems = displayComparisons.filter { $0.displayLineNumber != nil }
        let totalActual = nonBlankItems.reduce(0) { $0 + $1.comparison.actualCount }
        let totalExpected = expectedPattern?.reduce(0, +)
        let matchCount = nonBlankItems.filter { $0.comparison.accuracy == .exact }.count
        let lineCount = nonBlankItems.count
        
        return HStack {
            // Total syllables
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("syllableCount.totalSyllables", comment: "Total Syllables"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text("\(totalActual)")
                        .font(.headline)
                    
                    if let expected = totalExpected {
                        Text("/ \(expected)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Lines matching indicator (only if pattern expected)
            if expectedPattern != nil && lineCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(NSLocalizedString("syllableCount.accuracy", comment: "Lines Matching"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(matchCount)/\(lineCount)")
                        .font(.headline)
                        .foregroundColor(matchCount == lineCount ? .green : (matchCount > 0 ? .yellow : .red))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Analysis
    
    private func analyzeText() {
        // Build a list of excluded line ranges based on section type
        let excludedLines = identifyExcludedLines()
        let lines = text.components(separatedBy: .newlines)
        
        // Build comparisons for all lines, but apply pattern only to poem lines (non-excluded, non-blank)
        var results: [SyllableComparison] = []
        var patternIndex = 0  // Track position in pattern for poem lines only
        
        for (lineIndex, lineText) in lines.enumerated() {
            let isExcluded = excludedLines.contains(lineIndex)
            let isBlank = lineText.trimmingCharacters(in: .whitespaces).isEmpty
            let actual = syllableCounter.countSyllables(inLine: lineText)
            
            if isExcluded || isBlank {
                // Excluded or blank line - no expected count
                results.append(SyllableComparison(
                    lineNumber: lineIndex + 1,
                    lineText: lineText,
                    actualCount: actual,
                    expectedCount: nil,
                    accuracy: .noExpectation,
                    isExcluded: isExcluded
                ))
            } else {
                // Poem line - compare to pattern if available
                let expected = (expectedPattern != nil && patternIndex < expectedPattern!.count) ? expectedPattern![patternIndex] : nil
                let accuracy = syllableCounter.calculateAccuracy(actual: actual, expected: expected)
                
                results.append(SyllableComparison(
                    lineNumber: lineIndex + 1,
                    lineText: lineText,
                    actualCount: actual,
                    expectedCount: expected,
                    accuracy: accuracy,
                    isExcluded: false
                ))
                
                patternIndex += 1
            }
        }
        
        comparisons = results
    }
    
    /// Identify which line indices are excluded (non-poem sections)
    private func identifyExcludedLines() -> Set<Int> {
        var excludedLines = Set<Int>()
        let fullRange = NSRange(location: 0, length: attributedText.length)
        guard fullRange.length > 0 else { return excludedLines }
        
        attributedText.enumerateAttribute(.poemSectionType, in: fullRange, options: []) { value, range, _ in
            if let typeString = value as? String,
               let sectionType = PoemSectionType(rawValue: typeString),
               sectionType != .poem {
                // Find which lines this range covers
                let text = attributedText.string as NSString
                var currentPos = 0
                var lineIndex = 0
                
                while currentPos < text.length {
                    let lineRange = text.lineRange(for: NSRange(location: currentPos, length: 0))
                    
                    // Check if this line overlaps with the excluded range
                    let intersection = NSIntersectionRange(lineRange, range)
                    if intersection.length > 0 {
                        excludedLines.insert(lineIndex)
                    }
                    
                    currentPos = NSMaxRange(lineRange)
                    lineIndex += 1
                }
            }
        }
        
        return excludedLines
    }
}

// MARK: - Line Row

/// A single row showing syllable count for one line
struct SyllableLineRow: View {
    let comparison: SyllableComparison
    let displayLineNumber: Int?
    
    /// Whether this is a blank line (no line number)
    private var isBlankLine: Bool {
        displayLineNumber == nil
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Line number (hidden for blank lines)
            if let lineNum = displayLineNumber {
                Text("\(lineNum)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            } else {
                Text("")
                    .frame(width: 32, alignment: .trailing)
            }
            
            // Accuracy indicator (hidden for blank lines)
            if isBlankLine {
                Color.clear
                    .frame(width: 16, height: 16)
            } else {
                accuracyIndicator
            }
            
            // Line text (empty for blank lines)
            Text(isBlankLine ? "" : comparison.lineText)
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            // Expected count (hidden for blank lines)
            if !isBlankLine, let expected = comparison.expectedCount {
                Text("\(expected)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .center)
            } else if comparison.expectedCount != nil {
                Text("")
                    .frame(width: 32, alignment: .center)
            }
            
            // Actual count (hidden for blank lines)
            if isBlankLine {
                Text("")
                    .frame(width: 32, alignment: .center)
            } else {
                Text("\(comparison.actualCount)")
                    .font(.body.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(accuracyColor)
                    .frame(width: 32, alignment: .center)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, isBlankLine ? 4 : 8)
        .background(isBlankLine ? Color.clear : backgroundColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isBlankLine ? "Blank line" : comparison.accessibilityDescription)
    }
    
    // MARK: - Visual Indicators
    
    private var accuracyIndicator: some View {
        Group {
            switch comparison.accuracy {
            case .exact:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .close:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.yellow)
            case .off:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .noExpectation:
                Image(systemName: "circle")
                    .foregroundColor(.clear)
            }
        }
        .font(.caption)
        .frame(width: 16)
    }
    
    private var accuracyColor: Color {
        switch comparison.accuracy {
        case .exact: return .green
        case .close: return .yellow
        case .off: return .red
        case .noExpectation: return .primary
        }
    }
    
    private var backgroundColor: Color {
        switch comparison.accuracy {
        case .exact: return Color.green.opacity(0.05)
        case .close: return Color.yellow.opacity(0.05)
        case .off: return Color.red.opacity(0.05)
        case .noExpectation: return .clear
        }
    }
}

// MARK: - Compact Syllable Badge

/// A compact badge showing syllable count for inline display
struct SyllableBadge: View {
    let count: Int
    let expected: Int?
    
    var body: some View {
        HStack(spacing: 2) {
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .fontWeight(.medium)
            
            if let exp = expected {
                Text("/\(exp)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .foregroundColor(badgeColor)
        .cornerRadius(4)
    }
    
    private var badgeColor: Color {
        guard let expected = expected else { return .gray }
        
        let diff = abs(count - expected)
        switch diff {
        case 0: return .green
        case 1: return .yellow
        default: return .red
        }
    }
}

// MARK: - Syllable Count Summary

/// Summary view showing total syllable count and pattern match status
struct SyllableCountSummary: View {
    let text: String
    let expectedPattern: [Int]?
    
    private let syllableCounter = SyllableCounter.shared
    
    var body: some View {
        let counts = syllableCounter.countSyllablesPerLine(in: text)
        let total = counts.reduce(0, +)
        
        HStack(spacing: 12) {
            // Total count
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("syllableCount.syllables", comment: "Syllables"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(total)")
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
            }
            
            // Pattern match status
            if let pattern = expectedPattern {
                let expectedTotal = pattern.reduce(0, +)
                let matchingLines = zip(counts, pattern).filter { $0 == $1 }.count
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("syllableCount.match", comment: "Match"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(matchingLines)/\(pattern.count)")
                            .font(.title3.monospacedDigit())
                            .fontWeight(.semibold)
                            .foregroundColor(matchingLines == pattern.count ? .green : .primary)
                        
                        if total != expectedTotal {
                            Text("(\(total)/\(expectedTotal))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
