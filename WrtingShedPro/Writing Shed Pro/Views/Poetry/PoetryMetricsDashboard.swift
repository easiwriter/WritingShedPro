import SwiftUI

/// A comprehensive dashboard showing poetry metrics including syllables, stress, and form compliance
struct PoetryMetricsDashboard: View {
    let text: String
    let form: PoetryForm?
    
    @State private var selectedTab: MetricsTab = .overview
    
    enum MetricsTab: String, CaseIterable {
        case overview = "overview"
        case issues = "issues"
        case syllables = "syllables"
        case stress = "stress"
        
        var title: String {
            switch self {
            case .overview: return NSLocalizedString("poetryMetrics.tab.overview", comment: "Overview")
            case .issues: return NSLocalizedString("poetryMetrics.tab.issues", comment: "Issues")
            case .syllables: return NSLocalizedString("poetryMetrics.tab.syllables", comment: "Syllables")
            case .stress: return NSLocalizedString("poetryMetrics.tab.stress", comment: "Stress")
            }
        }
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar"
            case .issues: return "exclamationmark.triangle"
            case .syllables: return "textformat.123"
            case .stress: return "waveform.path"
            }
        }
    }
    
    /// Computed validation result
    private var validationResult: ValidationResult? {
        guard let form = form else { return nil }
        return PoetryValidator.shared.validate(text: text, against: form)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            tabPicker
            
            Divider()
            
            // Content based on selected tab
            switch selectedTab {
            case .overview:
                overviewTab
            case .issues:
                issuesTab
            case .syllables:
                syllablesTab
            case .stress:
                stressTab
            }
        }
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(MetricsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.icon)
                                .font(.body)
                            
                            // Show badge on Issues tab if there are issues
                            if tab == .issues, let validation = validationResult, validation.hasIssues {
                                Text("\(min(validation.issueCount, 99))")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -4)
                            }
                        }
                        Text(tab.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Issues Tab
    
    private var issuesTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let validation = validationResult {
                    if validation.hasIssues {
                        // Summary card
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(String(format: NSLocalizedString("poetryValidator.issuesFound", comment: "Issues found"), validation.issueCount))
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Issues grouped by type
                        ForEach(LineValidationIssue.IssueType.allCases, id: \.self) { issueType in
                            let issuesOfType = validation.issues.filter { $0.issueType == issueType }
                            if !issuesOfType.isEmpty {
                                issueTypeSection(type: issueType, issues: issuesOfType)
                            }
                        }
                    } else {
                        // No issues - show success
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            
                            Text(NSLocalizedString("poetryValidator.noIssues", comment: "No issues"))
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            if let form = form {
                                Text(form.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    // Free Verse or no form
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Free Verse - No form requirements")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
    }
    
    private func issueTypeSection(type: LineValidationIssue.IssueType, issues: [LineValidationIssue]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: issueTypeIcon(type))
                    .foregroundColor(issueTypeColor(type))
                Text(issueTypeName(type))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("(\(issues.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Individual issues
            ForEach(issues) { issue in
                issueRow(issue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func issueRow(_ issue: LineValidationIssue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if issue.lineNumber > 0 {
                HStack {
                    Text("Line \(issue.lineNumber)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(issue.lineText)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(4)
            }
            
            Text(issue.message)
                .font(.caption)
                .foregroundColor(issueTypeColor(issue.issueType))
            
            if let expected = issue.expected, let actual = issue.actual {
                HStack(spacing: 8) {
                    Label(expected, systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Label(actual, systemImage: "xmark")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func issueTypeIcon(_ type: LineValidationIssue.IssueType) -> String {
        switch type {
        case .lineCount: return "text.alignleft"
        case .syllableCount: return "textformat.123"
        case .rhymeScheme: return "text.quote"
        case .meter: return "waveform.path"
        case .endWord: return "text.cursor"
        case .refrain: return "repeat"
        }
    }
    
    private func issueTypeColor(_ type: LineValidationIssue.IssueType) -> Color {
        switch type {
        case .lineCount: return .orange
        case .syllableCount: return .purple
        case .rhymeScheme: return .blue
        case .meter: return .cyan
        case .endWord: return .red
        case .refrain: return .pink
        }
    }
    
    private func issueTypeName(_ type: LineValidationIssue.IssueType) -> String {
        switch type {
        case .lineCount: return "Line Count"
        case .syllableCount: return "Syllables"
        case .rhymeScheme: return "Rhyme Scheme"
        case .meter: return "Meter"
        case .endWord: return "End Words"
        case .refrain: return "Refrains"
        }
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Form info card
                if let form = form {
                    formInfoCard(form)
                }
                
                // Quick stats
                quickStatsSection
                
                // Progress toward form requirements
                if let form = form, form.id != PoetryForm.freeVerseId {
                    progressSection(form)
                }
                
                // Tips
                tipsSection
            }
            .padding()
        }
    }
    
    private func formInfoCard(_ form: PoetryForm) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(form.name)
                    .font(.headline)
                
                Spacer()
                
                Text(form.category.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(form.category))
                    .cornerRadius(8)
            }
            
            if !form.requirementsSummary.isEmpty {
                Text(form.requirementsSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var quickStatsSection: some View {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let syllableCounts = SyllableCounter.shared.countSyllablesPerLine(in: text)
        let totalSyllables = syllableCounts.reduce(0, +)
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("poetryMetrics.quickStats", comment: "Quick Stats"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                statCard(
                    value: "\(lines.count)",
                    label: NSLocalizedString("poetryMetrics.lines", comment: "Lines"),
                    icon: "text.alignleft"
                )
                
                statCard(
                    value: "\(totalSyllables)",
                    label: NSLocalizedString("poetryMetrics.syllables", comment: "Syllables"),
                    icon: "textformat.123"
                )
                
                statCard(
                    value: "\(wordCount)",
                    label: NSLocalizedString("poetryMetrics.words", comment: "Words"),
                    icon: "character.cursor.ibeam"
                )
            }
        }
    }
    
    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title2.monospacedDigit())
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func progressSection(_ form: PoetryForm) -> some View {
        let analysis = analyzeFormCompliance(form)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("poetryMetrics.formProgress", comment: "Form Progress"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                // Line count progress
                if let expected = form.lineCount, expected > 0 {
                    progressRow(
                        label: NSLocalizedString("poetryMetrics.lineCount", comment: "Line Count"),
                        current: analysis.lineCount,
                        expected: expected,
                        icon: "text.alignleft"
                    )
                }
                
                // Syllable pattern progress
                if let pattern = form.syllablePattern, !pattern.isEmpty {
                    let matchingLines = analysis.syllableMatches
                    let totalLines = pattern.count
                    progressRow(
                        label: NSLocalizedString("poetryMetrics.syllablePattern", comment: "Syllable Pattern"),
                        current: matchingLines,
                        expected: totalLines,
                        icon: "textformat.123"
                    )
                }
                
                // Meter progress (if applicable)
                if let meter = form.meterPattern, !meter.isEmpty {
                    let meterAccuracy = Int(analysis.meterAccuracy * 100)
                    HStack {
                        Image(systemName: "waveform.path")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        Text(NSLocalizedString("poetryMetrics.meter", comment: "Meter"))
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(meterAccuracy)%")
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.medium)
                            .foregroundColor(meterAccuracy >= 80 ? .green : (meterAccuracy >= 50 ? .yellow : .red))
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private func progressRow(label: String, current: Int, expected: Int, icon: String) -> some View {
        let isComplete = current >= expected
        let progress = expected > 0 ? min(Double(current) / Double(expected), 1.0) : 0
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(current)/\(expected)")
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(isComplete ? .green : .primary)
                
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            ProgressView(value: progress)
                .tint(isComplete ? .green : .accentColor)
        }
    }
    
    private var tipsSection: some View {
        let tips = generateTips()
        
        guard !tips.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("poetryMetrics.tips", comment: "Tips"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                        
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        )
    }
    
    // MARK: - Syllables Tab
    
    private var syllablesTab: some View {
        SyllableCountView(
            text: text,
            expectedPattern: form?.syllablePattern
        )
    }
    
    // MARK: - Stress Tab
    
    private var stressTab: some View {
        StressPatternView(
            text: text,
            expectedMeter: form?.meterPattern
        )
    }
    
    // MARK: - Analysis Helpers
    
    private struct FormAnalysis {
        var lineCount: Int = 0
        var syllableMatches: Int = 0
        var totalSyllables: Int = 0
        var meterAccuracy: Double = 0
    }
    
    private func analyzeFormCompliance(_ form: PoetryForm) -> FormAnalysis {
        var analysis = FormAnalysis()
        
        let lines = text.components(separatedBy: .newlines)
        analysis.lineCount = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        
        // Check syllable pattern
        if let pattern = form.syllablePattern, !pattern.isEmpty {
            let syllableCounts = SyllableCounter.shared.countSyllablesPerLine(in: text)
            analysis.totalSyllables = syllableCounts.reduce(0, +)
            
            for (index, expected) in pattern.enumerated() {
                if index < syllableCounts.count && syllableCounts[index] == expected {
                    analysis.syllableMatches += 1
                }
            }
        }
        
        // Check meter accuracy
        if let meterString = form.meterPattern, !meterString.isEmpty {
            let analyzer = StressAnalyzer.shared
            if let parsed = analyzer.parseMeterString(meterString) {
                var totalAccuracy = 0.0
                var lineCount = 0
                
                for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let match = analyzer.matchMeter(line, meter: parsed.meter)
                    if match.totalFeet > 0 {
                        totalAccuracy += match.accuracy
                        lineCount += 1
                    }
                }
                
                analysis.meterAccuracy = lineCount > 0 ? totalAccuracy / Double(lineCount) : 0
            }
        }
        
        return analysis
    }
    
    private func generateTips() -> [String] {
        var tips: [String] = []
        
        guard let form = form, form.id != PoetryForm.freeVerseId else { return tips }
        
        let analysis = analyzeFormCompliance(form)
        
        // Line count tip
        if let expected = form.lineCount, expected > 0 {
            if analysis.lineCount < expected {
                tips.append(String(format: NSLocalizedString("poetryMetrics.tip.needMoreLines", comment: "Tip for more lines"), expected - analysis.lineCount))
            } else if analysis.lineCount > expected {
                tips.append(String(format: NSLocalizedString("poetryMetrics.tip.tooManyLines", comment: "Tip for too many lines"), analysis.lineCount - expected))
            }
        }
        
        // Syllable pattern tip
        if let pattern = form.syllablePattern, !pattern.isEmpty {
            let totalLines = min(pattern.count, analysis.lineCount)
            if totalLines > 0 && analysis.syllableMatches < totalLines {
                tips.append(NSLocalizedString("poetryMetrics.tip.checkSyllables", comment: "Tip for syllables"))
            }
        }
        
        // Meter tip
        if form.meterPattern != nil && analysis.meterAccuracy < 0.7 {
            tips.append(NSLocalizedString("poetryMetrics.tip.checkMeter", comment: "Tip for meter"))
        }
        
        return tips
    }
    
    private func categoryColor(_ category: PoetryFormCategory) -> Color {
        switch category {
        case .japanese: return .orange
        case .rhymed: return .purple
        case .metered: return .blue
        case .free: return .green
        case .custom: return .gray
        }
    }
}

// MARK: - Compact Metrics Summary

/// A compact summary of poetry metrics for inline display
struct PoetryMetricsSummary: View {
    let text: String
    let form: PoetryForm?
    
    var body: some View {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let syllableCounts = SyllableCounter.shared.countSyllablesPerLine(in: text)
        let totalSyllables = syllableCounts.reduce(0, +)
        
        HStack(spacing: 16) {
            // Line count
            metricBadge(
                value: lines.count,
                expected: form?.lineCount,
                label: "L",
                icon: "text.alignleft"
            )
            
            // Total syllables
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "textformat.123")
                        .font(.caption2)
                    Text("\(totalSyllables)")
                        .font(.caption.monospacedDigit())
                        .fontWeight(.medium)
                }
                Text("syl")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Form compliance indicator
            if let form = form, form.id != PoetryForm.freeVerseId {
                complianceIndicator(form, syllableCounts: syllableCounts)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func metricBadge(value: Int, expected: Int?, label: String, icon: String) -> some View {
        let isMatch = expected.map { value == $0 } ?? true
        
        return VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption2)
                Text("\(value)")
                    .font(.caption.monospacedDigit())
                    .fontWeight(.medium)
                if let exp = expected {
                    Text("/\(exp)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(isMatch ? .primary : .orange)
        }
    }
    
    private func complianceIndicator(_ form: PoetryForm, syllableCounts: [Int]) -> some View {
        var matchCount = 0
        var totalChecks = 0
        
        // Check syllable pattern
        if let pattern = form.syllablePattern, !pattern.isEmpty {
            for (index, expected) in pattern.enumerated() {
                totalChecks += 1
                if index < syllableCounts.count && syllableCounts[index] == expected {
                    matchCount += 1
                }
            }
        }
        
        let percentage = totalChecks > 0 ? Int(Double(matchCount) / Double(totalChecks) * 100) : 100
        let color: Color = percentage >= 80 ? .green : (percentage >= 50 ? .yellow : .red)
        
        return HStack(spacing: 4) {
            Image(systemName: percentage >= 80 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(color)
            Text("\(percentage)%")
                .font(.caption.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}
