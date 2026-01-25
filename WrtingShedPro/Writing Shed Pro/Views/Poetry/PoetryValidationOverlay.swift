//
//  PoetryValidationOverlay.swift
//  Writing Shed Pro
//
//  An overlay view that shows inline validation indicators for poetry lines.
//  Displays colored markers and tooltips for lines with form violations.
//

import SwiftUI

/// A compact view showing validation issues for a single line
struct LineValidationIndicator: View {
    let issues: [LineValidationIssue]
    
    var body: some View {
        if issues.isEmpty {
            // Valid line - green checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        } else {
            // Issues - colored indicator with count
            HStack(spacing: 2) {
                Image(systemName: issueIcon)
                    .font(.caption2)
                    .foregroundColor(issueColor)
                
                if issues.count > 1 {
                    Text("\(issues.count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(issueColor)
                }
            }
        }
    }
    
    private var issueIcon: String {
        // Use most severe issue type for icon
        if issues.contains(where: { $0.issueType == .endWord }) {
            return "exclamationmark.circle.fill"
        } else if issues.contains(where: { $0.issueType == .refrain }) {
            return "repeat.circle.fill"
        } else if issues.contains(where: { $0.issueType == .rhymeScheme }) {
            return "text.quote"
        } else if issues.contains(where: { $0.issueType == .syllableCount }) {
            return "textformat.123"
        } else if issues.contains(where: { $0.issueType == .meter }) {
            return "waveform.path"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var issueColor: Color {
        // Use most severe issue type for color
        if issues.contains(where: { $0.issueType == .endWord }) {
            return .red
        } else if issues.contains(where: { $0.issueType == .refrain }) {
            return .pink
        } else if issues.contains(where: { $0.issueType == .rhymeScheme }) {
            return .blue
        } else if issues.contains(where: { $0.issueType == .syllableCount }) {
            return .purple
        } else if issues.contains(where: { $0.issueType == .meter }) {
            return .cyan
        } else {
            return .orange
        }
    }
}

/// A floating panel showing validation summary for the current poem
struct PoetryValidationPanel: View {
    let validation: ValidationResult
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if validation.hasIssues {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(validation.issueCount)")
                            .font(.caption.monospacedDigit())
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded && validation.hasIssues {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(validation.issuesByType.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { issueType in
                        if let count = validation.issuesByType[issueType] {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorForIssueType(issueType))
                                    .frame(width: 8, height: 8)
                                
                                Text(nameForIssueType(issueType))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.top, 4)
            }
        }
    }
    
    private func colorForIssueType(_ type: LineValidationIssue.IssueType) -> Color {
        switch type {
        case .lineCount: return .orange
        case .stanzaCount: return .orange
        case .syllableCount: return .purple
        case .rhymeScheme: return .blue
        case .meter: return .cyan
        case .endWord: return .red
        case .refrain: return .pink
        }
    }
    
    private func nameForIssueType(_ type: LineValidationIssue.IssueType) -> String {
        switch type {
        case .lineCount: return "Line Count"
        case .stanzaCount: return "Stanza Count"
        case .syllableCount: return "Syllables"
        case .rhymeScheme: return "Rhyme"
        case .meter: return "Meter"
        case .endWord: return "End Words"
        case .refrain: return "Refrains"
        }
    }
}

/// A view that shows validation markers in the margin of the text editor
struct PoetryValidationMargin: View {
    let validation: ValidationResult
    let lineHeight: CGFloat
    let lineCount: Int
    let scrollOffset: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...max(1, lineCount), id: \.self) { lineNumber in
                let issues = validation.issuesByLine[lineNumber] ?? []
                
                LineValidationIndicator(issues: issues)
                    .frame(width: 20, height: lineHeight)
            }
        }
        .offset(y: -scrollOffset)
    }
}
