import SwiftUI

/// A view displaying stress patterns with visual indicators
struct StressPatternView: View {
    let text: String
    let expectedMeter: String?
    
    @State private var lineAnalyses: [LineStressAnalysis] = []
    @State private var detectedMeter: MeterMatch?
    
    private let analyzer = StressAnalyzer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with meter info
            headerSection
            
            Divider()
            
            // Empty state or line-by-line analysis
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(lineAnalyses) { analysis in
                            StressLineRow(analysis: analysis)
                            
                            if analysis.lineNumber < lineAnalyses.count {
                                Divider()
                            }
                        }
                    }
                }
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
            Image(systemName: "waveform.path")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("stressPattern.empty", comment: "No text to analyze"))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("stressPattern.emptyHint", comment: "Start writing to see stress patterns"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Expected meter (if specified)
            if let meter = expectedMeter, !meter.isEmpty {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("stressPattern.expectedMeter", comment: "Expected Meter"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(meter.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Detected meter
            if let detected = detectedMeter, detected.totalFeet > 0 {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("stressPattern.detectedMeter", comment: "Detected"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(detected.meter.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Accuracy badge
                    Text("\(detected.percentAccuracy)%")
                        .font(.caption.monospacedDigit())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accuracyColor(detected.accuracy))
                        .cornerRadius(4)
                }
            }
            
            // Legend
            legendRow
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(symbol: "/", label: NSLocalizedString("stressPattern.stressed", comment: "Stressed"))
            legendItem(symbol: "u", label: NSLocalizedString("stressPattern.unstressed", comment: "Unstressed"))
            legendItem(symbol: "\\", label: NSLocalizedString("stressPattern.secondary", comment: "Secondary"))
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private func legendItem(symbol: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
            Text("= \(label)")
        }
    }
    
    // MARK: - Analysis
    
    private func analyzeText() {
        let lines = text.components(separatedBy: .newlines)
        
        // Parse expected meter if provided
        var meterType: StressAnalyzer.MeterType?
        if let expected = expectedMeter {
            if let parsed = analyzer.parseMeterString(expected) {
                meterType = parsed.meter
            }
        }
        
        // Analyze each line
        lineAnalyses = lines.enumerated().map { index, line in
            let wordStresses = analyzer.analyzeLine(line)
            let pattern = wordStresses.flatMap { $0.pattern }
            
            var meterMatch: MeterMatch?
            if let meter = meterType {
                meterMatch = analyzer.matchMeter(line, meter: meter)
            }
            
            return LineStressAnalysis(
                lineNumber: index + 1,
                lineText: line,
                wordStresses: wordStresses,
                combinedPattern: pattern,
                meterMatch: meterMatch
            )
        }
        
        // Detect overall meter from first non-empty line
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            detectedMeter = analyzer.detectMeter(firstLine)
        }
    }
    
    private func accuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .yellow
        default: return .red
        }
    }
}

// MARK: - Line Analysis

struct LineStressAnalysis: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let lineText: String
    let wordStresses: [StressAnalyzer.WordStress]
    let combinedPattern: [StressAnalyzer.StressLevel]
    let meterMatch: MeterMatch?
    
    var patternString: String {
        combinedPattern.map { $0.symbol }.joined()
    }
}

// MARK: - Line Row

struct StressLineRow: View {
    let analysis: LineStressAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Line number and text
            HStack(alignment: .top, spacing: 8) {
                Text("\(analysis.lineNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .trailing)
                
                Text(analysis.lineText.isEmpty ? "—" : analysis.lineText)
                    .font(.body)
                    .foregroundColor(analysis.lineText.isEmpty ? .secondary : .primary)
                
                Spacer()
                
                // Meter accuracy indicator (if matching)
                if let match = analysis.meterMatch, match.totalFeet > 0 {
                    accuracyBadge(match)
                }
            }
            
            // Stress pattern visualization
            if !analysis.combinedPattern.isEmpty {
                HStack(spacing: 0) {
                    // Spacer for line number
                    Color.clear
                        .frame(width: 32)
                    
                    // Word-by-word stress pattern
                    stressPatternDisplay
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var accessibilityDescription: String {
        var description = "Line \(analysis.lineNumber): "
        if analysis.lineText.isEmpty {
            description += "empty line"
        } else {
            description += analysis.lineText + ". "
            description += "Pattern: " + analysis.wordStresses.map { $0.accessibilityDescription }.joined(separator: ", ")
            if let match = analysis.meterMatch, match.totalFeet > 0 {
                description += ". " + match.accessibilityDescription
            }
        }
        return description
    }
    
    private var stressPatternDisplay: some View {
        HStack(spacing: 8) {
            ForEach(analysis.wordStresses) { wordStress in
                VStack(spacing: 2) {
                    // Stress symbols
                    HStack(spacing: 2) {
                        ForEach(Array(wordStress.pattern.enumerated()), id: \.offset) { _, stress in
                            stressSymbol(stress)
                        }
                    }
                    
                    // Word (abbreviated if needed)
                    Text(abbreviate(wordStress.word))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
    }
    
    private func stressSymbol(_ stress: StressAnalyzer.StressLevel) -> some View {
        Text(stress.symbol)
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(stressColor(stress))
            .frame(width: 14, height: 14)
    }
    
    private func stressColor(_ stress: StressAnalyzer.StressLevel) -> Color {
        switch stress {
        case .stressed: return .primary
        case .unstressed: return .secondary
        case .secondary: return .orange
        }
    }
    
    private func abbreviate(_ word: String) -> String {
        if word.count > 8 {
            return String(word.prefix(6)) + "…"
        }
        return word
    }
    
    private func accuracyBadge(_ match: MeterMatch) -> some View {
        HStack(spacing: 4) {
            if match.isExactMatch {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("\(match.matchingFeet)/\(match.totalFeet)")
                    .font(.caption2.monospacedDigit())
            }
        }
        .font(.caption)
        .foregroundColor(match.isExactMatch ? .green : .secondary)
    }
    
    private var rowBackground: Color {
        guard let match = analysis.meterMatch, match.totalFeet > 0 else {
            return .clear
        }
        
        if match.isExactMatch {
            return Color.green.opacity(0.05)
        } else if match.accuracy >= 0.7 {
            return Color.yellow.opacity(0.05)
        } else {
            return Color.red.opacity(0.05)
        }
    }
}

// MARK: - Compact Stress Badge

/// A compact badge showing stress pattern
struct StressPatternBadge: View {
    let pattern: [StressAnalyzer.StressLevel]
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { _, stress in
                Text(stress.symbol)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(stress == .stressed ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.systemGray5))
        .cornerRadius(4)
    }
}

// MARK: - Meter Indicator

/// Shows the detected or expected meter type
struct MeterIndicator: View {
    let text: String
    let expectedMeter: String?
    
    private let analyzer = StressAnalyzer.shared
    
    var body: some View {
        let detected = analyzer.detectMeter(text)
        
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("stressPattern.meter", comment: "Meter"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(detected.meter.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Match indicator if expected meter specified
            if let expected = expectedMeter,
               let parsed = analyzer.parseMeterString(expected) {
                let isMatch = parsed.meter == detected.meter
                
                Image(systemName: isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isMatch ? .green : .red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
