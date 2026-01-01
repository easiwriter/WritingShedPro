import SwiftUI

/// A view displaying line-by-line syllable counts with visual feedback
/// Shows actual vs expected counts and color-codes accuracy
struct SyllableCountView: View {
    let text: String
    let expectedPattern: [Int]?
    
    @State private var comparisons: [SyllableComparison] = []
    
    private let syllableCounter = SyllableCounter.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerRow
            
            Divider()
            
            // Empty state or line-by-line analysis
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comparisons) { comparison in
                            SyllableLineRow(comparison: comparison)
                            
                            if comparison.lineNumber < comparisons.count {
                                Divider()
                            }
                        }
                    }
                }
            }
            
            // Summary footer
            if !comparisons.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        let totalActual = comparisons.reduce(0) { $0 + $1.actualCount }
        let totalExpected = expectedPattern?.reduce(0, +)
        let matchCount = comparisons.filter { $0.accuracy == .exact }.count
        let lineCount = comparisons.filter { !$0.lineText.isEmpty }.count
        
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
            
            // Accuracy indicator (only if pattern expected)
            if expectedPattern != nil && lineCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(NSLocalizedString("syllableCount.accuracy", comment: "Accuracy"))
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
        if let pattern = expectedPattern {
            comparisons = syllableCounter.compareToPattern(text: text, pattern: pattern)
        } else {
            // No pattern - just count syllables per line
            let lines = text.components(separatedBy: .newlines)
            comparisons = lines.enumerated().map { index, line in
                SyllableComparison(
                    lineNumber: index + 1,
                    lineText: line,
                    actualCount: syllableCounter.countSyllables(inLine: line),
                    expectedCount: nil,
                    accuracy: .noExpectation
                )
            }
        }
    }
}

// MARK: - Line Row

/// A single row showing syllable count for one line
struct SyllableLineRow: View {
    let comparison: SyllableComparison
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Line number
            Text("\(comparison.lineNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
            
            // Accuracy indicator
            accuracyIndicator
            
            // Line text
            Text(comparison.lineText.isEmpty ? "—" : comparison.lineText)
                .font(.body)
                .foregroundColor(comparison.lineText.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            
            Spacer()
            
            // Expected count (if available)
            if let expected = comparison.expectedCount {
                Text("\(expected)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .center)
            }
            
            // Actual count
            Text("\(comparison.actualCount)")
                .font(.body.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(accuracyColor)
                .frame(width: 32, alignment: .center)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(comparison.accessibilityDescription)
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
