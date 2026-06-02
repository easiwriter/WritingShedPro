import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Displays editorial suggestions from the Manuscript Analyst service.
struct AnalystReviewView: View {
    let review: ManuscriptReview
    @State private var isArchived: Bool = false
    @State private var selectedCategory: String?
    @State private var sortBy: SortOption = .severity
    @State private var useLargeText = true
    @State private var expandedSuggestionId: String?
    @State private var headerContentHeight: CGFloat = 0
    @State private var headerViewportHeight: CGFloat = 0
    @State private var headerScrollOffset: CGFloat = 0
    @State private var showCopyToast: Bool = false
    @State private var copyToastTask: Task<Void, Never>?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                headerBar

                // Header: Summary & Sentiment
                headerSection
                
                // Soft-cap state warning
                if let softCapState = review.metadata?.softCapState {
                    softCapWarning(for: softCapState)
                }
                
                // Suggestions list
                ScrollView {
                    VStack(spacing: 12) {
                        if filteredSuggestions.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredSuggestions, id: \.suggestionId) { suggestion in
                                SuggestionCard(
                                    suggestion: suggestion,
                                    isExpanded: expandedSuggestionId == suggestion.suggestionId,
                                    useLargeText: useLargeText,
                                    onToggleExpanded: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if expandedSuggestionId == suggestion.suggestionId {
                                                expandedSuggestionId = nil
                                            } else {
                                                expandedSuggestionId = suggestion.suggestionId
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .overlay(alignment: .top) {
                if showCopyToast {
                    Label("Copied", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.green, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Review Suggestions")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Menu {
                Picker("Sort", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Label(option.label, systemImage: option.icon).tag(option)
                    }
                }
                Divider()
                Button(action: { useLargeText.toggle() }) {
                    Label(
                        useLargeText ? "Standard Text" : "Larger Text",
                        systemImage: useLargeText ? "textformat.size.smaller" : "textformat.size.larger"
                    )
                }
                Divider()
                Button(action: { isArchived.toggle() }) {
                    Label(
                        isArchived ? "Show All" : "Hide Addressed",
                        systemImage: isArchived ? "archivebox" : "archivebox.fill"
                    )
                }
                Divider()
                Button(action: copyFullReviewToClipboard) {
                    Label("Copy Full Review", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analysis Summary")
                        .font(.title3)
                        .fontWeight(.semibold)
                    if shouldShowSentimentBadge {
                        sentimentBadge
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            if shouldPinEditorialNoteAboveScroll {
                Text("These notes are an editorial reading of the piece, not a definitive judgment. Treat them as revision prompts from a second reader.")
                    .font(useLargeText ? .body : .callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !shouldPinEditorialNoteAboveScroll {
                            Text("These notes are an editorial reading of the piece, not a definitive judgment. Treat them as revision prompts from a second reader.")
                                .font(useLargeText ? .body : .callout)
                                .foregroundStyle(.secondary)
                        }

                        Text(review.summary)
                            .font(useLargeText ? .title3 : .body)
                            .foregroundStyle(.primary)

                        if let focusOrder = review.suggestedFocusOrder, !focusOrder.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Suggested Focus Areas")
                                    .font(useLargeText ? .title3 : .headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(focusOrder, id: \.self) { area in
                                        HStack(spacing: 8) {
                                            Image(systemName: "star.fill")
                                                .font(useLargeText ? .body : .callout)
                                                .foregroundStyle(.orange)
                                            Text(area)
                                                .font(useLargeText ? .title3 : .body)
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: HeaderContentHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: HeaderScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("AnalystHeaderScroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "AnalystHeaderScroll")
                .scrollIndicators(.visible)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: HeaderViewportHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
                .frame(maxHeight: 220)

                if shouldShowHeaderScrollCue {
                    headerScrollCue
                }
            }
            .onPreferenceChange(HeaderContentHeightPreferenceKey.self) { value in
                headerContentHeight = value
            }
            .onPreferenceChange(HeaderViewportHeightPreferenceKey.self) { value in
                headerViewportHeight = value
            }
            .onPreferenceChange(HeaderScrollOffsetPreferenceKey.self) { value in
                headerScrollOffset = value
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var shouldShowHeaderScrollCue: Bool {
        headerContentHeight > headerViewportHeight + 12 && headerScrollOffset > -8
    }

    private var headerScrollCue: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.down")
            Text("Scroll for more")
        }
        .font(useLargeText ? .callout : .caption)
        .foregroundStyle(.secondary)
        .padding(.top, 6)
        .allowsHitTesting(false)
    }

    private var sentimentBadge: some View {
        let (icon, color) = sentimentStyle(for: review.overallSentiment)
        return Label(review.overallSentiment.capitalized, systemImage: icon)
            .font(useLargeText ? .headline : .callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }

    private var shouldShowSentimentBadge: Bool {
        review.overallSentiment.lowercased() != "mixed"
    }

    private var shouldPinEditorialNoteAboveScroll: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("No Suggestions")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Great work! The analyst found no issues to address.")
                .font(useLargeText ? .title3 : .body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func softCapWarning(for state: String) -> some View {
        Group {
            if state == "throttled" {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usage Limit Approaching")
                            .font(useLargeText ? .title3 : .body)
                            .fontWeight(.semibold)
                        Text("You're approaching your monthly analysis limit. Consider reviewing again next month.")
                            .font(useLargeText ? .body : .callout)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemOrange).opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            } else if state == "approaching_limit" {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Approaching Limit")
                            .font(useLargeText ? .title3 : .body)
                            .fontWeight(.semibold)
                        Text("You have a few analyses remaining this month.")
                            .font(useLargeText ? .body : .callout)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemOrange).opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private var filteredSuggestions: [ReviewSuggestion] {
        var suggestions = review.suggestions
        
        // Filter addressed
        if !isArchived {
            suggestions = suggestions.filter { !$0.isAddressed }
        }
        
        // Sort
        switch sortBy {
        case .severity:
            suggestions.sort { severityOrder($0.severity) < severityOrder($1.severity) }
        case .category:
            suggestions.sort { $0.category < $1.category }
        case .newest:
            break  // Already in order as stored
        }
        
        return suggestions
    }

    private func severityOrder(_ severity: String) -> Int {
        switch severity {
        case "high": return 0
        case "medium": return 1
        case "low": return 2
        default: return 3
        }
    }

    private func sentimentStyle(for sentiment: String) -> (icon: String, color: Color) {
        switch sentiment.lowercased() {
        case "encouraging":
            return ("checkmark.circle.fill", .green)
        case "mixed":
            return ("minus.circle.fill", .orange)
        case "critical":
            return ("xmark.circle.fill", .red)
        default:
            return ("question.circle.fill", .gray)
        }
    }

    private func copyFullReviewToClipboard() {
        let plainText = makeFlatReviewPlainText()
        let attributedText = makeFlatReviewAttributedText()

        var clipboardItem: [String: Any] = [:]

        if let rtfData = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            clipboardItem[UTType.rtf.identifier] = rtfData
        }

        if let htmlData = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ) {
            clipboardItem[UTType.html.identifier] = htmlData
        }

        // Always include plain text fallback in the primary item so plain editors
        // (including TextEditor-based notes) can paste reliably.
        clipboardItem[UTType.plainText.identifier] = plainText

        if clipboardItem.isEmpty {
            UIPasteboard.general.string = plainText
        } else {
            // Prefer rich content where available while preserving plain text fallback.
            UIPasteboard.general.items = [clipboardItem]
        }

        copyToastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopyToast = true
        }

        copyToastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopyToast = false
            }
        }
    }

    private func makeFlatReviewPlainText() -> String {
        var lines: [String] = []

        lines.append(plainTextBold("Analysis Summary"))
        lines.append(review.summary)

        lines.append("")
        lines.append(plainTextBold("Overall Sentiment"))
        lines.append(review.overallSentiment.capitalized)

        if let focusOrder = review.suggestedFocusOrder, !focusOrder.isEmpty {
            lines.append("")
            lines.append(plainTextBold("Suggested Focus Areas"))
            for area in focusOrder {
                lines.append("- \(area)")
            }
        }

        lines.append("")
        lines.append(plainTextBold("Review Suggestions"))

        if filteredSuggestions.isEmpty {
            lines.append("No Suggestions")
        } else {
            for (index, suggestion) in filteredSuggestions.enumerated() {
                lines.append("")
                lines.append(plainTextBold("Suggestion \(index + 1)"))
                lines.append("Category: \(suggestion.category)")
                lines.append("Severity: \(suggestion.severity.capitalized)")
                if let location = suggestion.location, !location.isEmpty {
                    lines.append("Location: \(location)")
                }
                lines.append("Status: \(suggestion.isAddressed ? "Addressed" : "Unaddressed")")

                lines.append("")
                lines.append(plainTextBold("Editorial Reading"))
                lines.append(suggestion.observation)

                lines.append("")
                lines.append(plainTextBold("Possible Revision Focus"))
                lines.append(suggestion.suggestion)

                lines.append("")
                lines.append(plainTextBold("Reasoning"))
                lines.append(suggestion.rationale)
            }
        }

        return lines.joined(separator: "\n")
    }

    // Plain-text editors (like NotesEditorSheet) cannot render attributed bold.
    // Use Unicode bold characters so section emphasis survives paste in plain text.
    private func plainTextBold(_ input: String) -> String {
        let mappedScalars = input.unicodeScalars.map { scalar in
            let value = scalar.value

            // A-Z
            if (65...90).contains(value),
               let transformed = UnicodeScalar(0x1D5D4 + (value - 65)) {
                return transformed
            }

            // a-z
            if (97...122).contains(value),
               let transformed = UnicodeScalar(0x1D5EE + (value - 97)) {
                return transformed
            }

            // 0-9
            if (48...57).contains(value),
               let transformed = UnicodeScalar(0x1D7EC + (value - 48)) {
                return transformed
            }

            return scalar
        }

        return mappedScalars.reduce(into: "") { result, scalar in
            result.unicodeScalars.append(scalar)
        }
    }

    private func makeFlatReviewAttributedText() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let headingFont = UIFont.boldSystemFont(ofSize: bodyFont.pointSize)

        func appendHeading(_ text: String) {
            result.append(NSAttributedString(
                string: text + "\n",
                attributes: [.font: headingFont]
            ))
        }

        func appendBody(_ text: String) {
            result.append(NSAttributedString(
                string: text + "\n",
                attributes: [.font: bodyFont]
            ))
        }

        appendHeading("Analysis Summary")
        appendBody(review.summary)

        appendBody("")
        appendHeading("Overall Sentiment")
        appendBody(review.overallSentiment.capitalized)

        if let focusOrder = review.suggestedFocusOrder, !focusOrder.isEmpty {
            appendBody("")
            appendHeading("Suggested Focus Areas")
            for area in focusOrder {
                appendBody("- \(area)")
            }
        }

        appendBody("")
        appendHeading("Review Suggestions")

        if filteredSuggestions.isEmpty {
            appendBody("No Suggestions")
        } else {
            for (index, suggestion) in filteredSuggestions.enumerated() {
                appendBody("")
                appendHeading("Suggestion \(index + 1)")
                appendBody("Category: \(suggestion.category)")
                appendBody("Severity: \(suggestion.severity.capitalized)")
                if let location = suggestion.location, !location.isEmpty {
                    appendBody("Location: \(location)")
                }
                appendBody("Status: \(suggestion.isAddressed ? "Addressed" : "Unaddressed")")

                appendBody("")
                appendHeading("Editorial Reading")
                appendBody(suggestion.observation)

                appendBody("")
                appendHeading("Possible Revision Focus")
                appendBody(suggestion.suggestion)

                appendBody("")
                appendHeading("Reasoning")
                appendBody(suggestion.rationale)
            }
        }

        return result
    }

    enum SortOption: Hashable, CaseIterable {
        case severity
        case category
        case newest

        var label: String {
            switch self {
            case .severity: return "By Severity"
            case .category: return "By Category"
            case .newest: return "Newest First"
            }
        }

        var icon: String {
            switch self {
            case .severity: return "exclamationmark.triangle"
            case .category: return "list.bullet"
            case .newest: return "clock"
            }
        }
    }
}

private struct HeaderContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HeaderViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HeaderScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let suggestion: ReviewSuggestion
    let isExpanded: Bool
    let useLargeText: Bool
    let onToggleExpanded: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                severityIndicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(suggestion.category)
                            .font(useLargeText ? .title3 : .headline)
                            .fontWeight(.semibold)
                        Spacer()
                        if suggestion.isAddressed {
                            Label("Addressed", systemImage: "checkmark")
                                .font(useLargeText ? .body : .footnote)
                                .foregroundStyle(.green)
                        }
                    }
                    if let location = suggestion.location {
                        Text(location)
                            .font(useLargeText ? .body : .callout)
                            .foregroundStyle(.primary)
                    }
                }
            }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Section {
                        Text(suggestion.observation)
                            .font(useLargeText ? .title3 : .body)
                            .foregroundStyle(.primary)
                    } header: {
                        Text("Editorial Reading")
                            .font(useLargeText ? .headline : .callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    Section {
                        Text(suggestion.suggestion)
                            .font(useLargeText ? .title3 : .body)
                            .foregroundStyle(.primary)
                    } header: {
                        Text("Possible Revision Focus")
                            .font(useLargeText ? .headline : .callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    Section {
                        Text(suggestion.rationale)
                            .font(useLargeText ? .body : .callout)
                            .foregroundStyle(.primary)
                    } header: {
                        Text("Reasoning")
                            .font(useLargeText ? .headline : .callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 12) {
                        Button(action: toggleAddressed) {
                            Label(
                                suggestion.isAddressed ? "Mark as Unaddressed" : "Mark as Addressed",
                                systemImage: suggestion.isAddressed ? "xmark.circle" : "checkmark.circle"
                            )
                            .font(useLargeText ? .title3 : .body)
                        }
                        Spacer()
                        if let notes = suggestion.userNotes, !notes.isEmpty {
                            Text("Note added")
                                .font(useLargeText ? .body : .footnote)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .border(severityBorderColor, width: 1)
        .cornerRadius(8)
        .onTapGesture(perform: onToggleExpanded)
    }

    private var severityIndicator: some View {
        VStack {
            Image(systemName: severityIcon)
                .font(useLargeText ? .headline : .callout)
                .foregroundStyle(severityColor)
            Spacer()
        }
        .frame(width: 24)
    }

    private var severityIcon: String {
        switch suggestion.severity {
        case "high": return "exclamationmark.circle.fill"
        case "medium": return "exclamationmark.circle"
        case "low": return "circle.fill"
        default: return "circle"
        }
    }

    private var severityColor: Color {
        switch suggestion.severity {
        case "high": return .red
        case "medium": return .orange
        case "low": return .blue
        default: return .gray
        }
    }

    private var severityBorderColor: Color {
        switch suggestion.severity {
        case "high": return .red.opacity(0.3)
        case "medium": return .orange.opacity(0.3)
        case "low": return .blue.opacity(0.3)
        default: return .gray.opacity(0.3)
        }
    }

    private func toggleAddressed() {
        suggestion.isAddressed.toggle()
        try? modelContext.save()
    }
}
