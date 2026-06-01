import SwiftUI
import UIKit

/// A split view layout for iPad that shows the text editor alongside a poetry metrics panel
/// Automatically collapses on compact width devices
struct PoetryEditorSplitView<EditorContent: View>: View {
    let editorContent: EditorContent
    let attributedText: NSAttributedString
    let form: PoetryForm?
    
    @Binding var showMetricsPanel: Bool
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// Minimum width for the metrics panel
    private let metricsMinWidth: CGFloat = 320
    private let metricsPanelFraction: CGFloat = 0.35
    
    init(
        attributedText: NSAttributedString,
        form: PoetryForm?,
        showMetricsPanel: Binding<Bool>,
        @ViewBuilder editorContent: () -> EditorContent
    ) {
        self.attributedText = attributedText
        self.form = form
        self._showMetricsPanel = showMetricsPanel
        self.editorContent = editorContent()
    }
    
    var body: some View {
        GeometryReader { geometry in
            if shouldShowSplitView(in: geometry) && showMetricsPanel {
                // iPad/Mac: Split view with editor and metrics panel
                HStack(spacing: 0) {
                    // Editor (left side)
                    editorContent
                        .frame(width: editorWidth(in: geometry))
                    
                    Divider()
                    
                    // Metrics panel (right side)
                    metricsPanel
                        .frame(width: metricsPanelWidth(in: geometry))
                }
            } else {
                // iPhone or metrics hidden: Full-width editor
                editorContent
            }
        }
    }
    
    // MARK: - Metrics Panel
    
    private var metricsPanel: some View {
        VStack(spacing: 0) {
            // Panel header with close button
            HStack {
                Text(NSLocalizedString("poetryMetrics.title", comment: "Poetry Metrics"))
                    .font(.headline)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMetricsPanel = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("poetryMetrics.closePanel", comment: "Close metrics panel"))
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            // Metrics content
            PoetryMetricsDashboard(attributedText: attributedText, form: form)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Layout Calculations
    
    private func shouldShowSplitView(in geometry: GeometryProxy) -> Bool {
        // Only show split view on iPad/Mac with sufficient width
        let minWidthForSplit: CGFloat = 700
        return horizontalSizeClass == .regular && geometry.size.width >= minWidthForSplit
    }
    
    private func editorWidth(in geometry: GeometryProxy) -> CGFloat {
        let totalWidth = geometry.size.width
        let metricsWidth = metricsPanelWidth(in: geometry)
        return totalWidth - metricsWidth - 1 // -1 for divider
    }
    
    private func metricsPanelWidth(in geometry: GeometryProxy) -> CGFloat {
        let totalWidth = geometry.size.width
        let calculatedWidth = totalWidth * metricsPanelFraction
        return max(metricsMinWidth, calculatedWidth)
    }
}

// MARK: - Metrics Panel Toggle Button

/// A toggle button for showing/hiding the metrics panel
struct MetricsPanelToggle: View {
    @Binding var showMetricsPanel: Bool
    let isAvailable: Bool
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showMetricsPanel.toggle()
            }
        } label: {
            Image(systemName: showMetricsPanel ? "sidebar.right.fill" : "sidebar.right")
        }
        .disabled(!isAvailable)
        .accessibilityLabel(showMetricsPanel 
            ? NSLocalizedString("poetryMetrics.hidePanel", comment: "Hide metrics panel")
            : NSLocalizedString("poetryMetrics.showPanel", comment: "Show metrics panel"))
    }
}

// MARK: - Responsive Poetry Form Card

/// A poetry form card that adapts to available space
struct ResponsivePoetryFormCard: View {
    let form: PoetryForm
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Button(action: action) {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .buttonStyle(.plain)
    }
    
    private var compactLayout: some View {
        HStack(spacing: 12) {
            // Selection indicator
            selectionIndicator
            
            // Form info
            VStack(alignment: .leading, spacing: 4) {
                Text(form.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if !form.requirementsSummary.isEmpty {
                    Text(form.requirementsSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Category badge
            categoryBadge
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var regularLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(form.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                selectionIndicator
            }
            
            // Category badge
            categoryBadge
            
            if !form.description.isEmpty {
                Text(form.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Requirements summary
            if !form.requirementsSummary.isEmpty {
                Text(form.requirementsSummary)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .font(.title3)
    }
    
    private var categoryBadge: some View {
        Text(form.category.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(categoryColor)
            .cornerRadius(6)
    }
    
    private var categoryColor: Color {
        switch form.category {
        case .japanese: return .orange
        case .rhymed: return .purple
        case .structured: return .mint
        case .metered: return .blue
        case .free: return .green
        case .custom: return .gray
        }
    }
}

// MARK: - Animated Syllable Counter

/// An animated syllable count display that updates smoothly
struct AnimatedSyllableCount: View {
    let count: Int
    let expected: Int?
    
    @State private var displayedCount: Int = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(displayedCount)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(countColor)
                .contentTransition(.numericText())
            
            if let exp = expected {
                Text("/\(exp)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            displayedCount = count
        }
        .onChange(of: count) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                displayedCount = newValue
            }
        }
    }
    
    private var countColor: Color {
        guard let expected = expected else { return .primary }
        
        let diff = abs(count - expected)
        switch diff {
        case 0: return .green
        case 1: return .yellow
        default: return .red
        }
    }
}

// MARK: - Stress Pattern Animation

/// An animated stress pattern display
struct AnimatedStressPattern: View {
    let pattern: [StressAnalyzer.StressLevel]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { index, stress in
                Text(stress.symbol)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(stressColor(stress))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.05), value: pattern.count)
            }
        }
    }
    
    private func stressColor(_ stress: StressAnalyzer.StressLevel) -> Color {
        switch stress {
        case .stressed: return .primary
        case .unstressed: return .secondary
        case .secondary: return .orange
        }
    }
}

// MARK: - Form Progress Ring

/// A circular progress indicator for form compliance
struct FormProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(progress: Double, lineWidth: CGFloat = 4, size: CGFloat = 44) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.systemGray4), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
            
            // Percentage text
            Text("\(Int(progress * 100))")
                .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                .foregroundColor(progressColor)
        }
        .frame(width: size, height: size)
    }
    
    private var progressColor: Color {
        switch progress {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .red
        }
    }
}

// MARK: - Accessibility Extensions

extension SyllableComparison {
    /// Accessibility description for VoiceOver
    var accessibilityDescription: String {
        var description = "Line \(lineNumber): "
        
        if lineText.isEmpty {
            description += "empty line"
        } else {
            description += "\(actualCount) syllables"
            
            if let expected = expectedCount {
                if actualCount == expected {
                    description += ", matches expected \(expected)"
                } else {
                    description += ", expected \(expected)"
                }
            }
        }
        
        return description
    }
}

extension StressAnalyzer.WordStress {
    /// Accessibility description for VoiceOver
    var accessibilityDescription: String {
        let stressDescription = pattern.map { $0.description }.joined(separator: ", ")
        return "\(word): \(syllableCount) syllables, pattern: \(stressDescription)"
    }
}

extension MeterMatch {
    /// Accessibility description for VoiceOver
    var accessibilityDescription: String {
        if isExactMatch {
            return "Perfect \(meter.rawValue) meter, \(totalFeet) feet"
        } else {
            return "\(meter.rawValue) meter, \(matchingFeet) of \(totalFeet) feet match, \(percentAccuracy) percent accuracy"
        }
    }
}
