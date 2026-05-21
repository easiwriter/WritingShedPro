import SwiftUI
import SwiftData

/// Displays editorial suggestions from the Manuscript Analyst service.
struct AnalystReviewView: View {
    let review: ManuscriptReview
    @State private var isArchived: Bool = false
    @State private var selectedCategory: String?
    @State private var sortBy: SortOption = .severity
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
                                SuggestionCard(suggestion: suggestion)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle("Review Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortBy) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Label(option.label, systemImage: option.icon).tag(option)
                            }
                        }
                        Divider()
                        Button(action: { isArchived.toggle() }) {
                            Label(
                                isArchived ? "Show All" : "Hide Addressed",
                                systemImage: isArchived ? "archivebox" : "archivebox.fill"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analysis Summary")
                        .font(.headline)
                    sentimentBadge
                }
                Spacer()
                if let metadata = review.metadata {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(metadata.tokensUsed) tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.analysisTimeMs)ms")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal)

            Text(review.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let focusOrder = review.suggestedFocusOrder, !focusOrder.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested Focus Areas")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(focusOrder, id: \.self) { area in
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text(area)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var sentimentBadge: some View {
        let (icon, color) = sentimentStyle(for: review.overallSentiment)
        return Label(review.overallSentiment.capitalized, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("No Suggestions")
                .font(.headline)
            Text("Great work! The analyst found no issues to address.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("You're approaching your monthly analysis limit. Consider reviewing again next month.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("You have a few analyses remaining this month.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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

// MARK: - Suggestion Card

struct SuggestionCard: View {
    @State var suggestion: ReviewSuggestion
    @State private var isExpanded = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                severityIndicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(suggestion.category)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        if suggestion.isAddressed {
                            Label("Addressed", systemImage: "checkmark")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    if let location = suggestion.location {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Section {
                        Text(suggestion.observation)
                            .font(.caption)
                    } header: {
                        Text("Observation")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Text(suggestion.suggestion)
                            .font(.caption)
                    } header: {
                        Text("Suggestion")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Text(suggestion.rationale)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } header: {
                        Text("Why This Matters")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button(action: toggleAddressed) {
                            Label(
                                suggestion.isAddressed ? "Mark as Unaddressed" : "Mark as Addressed",
                                systemImage: suggestion.isAddressed ? "xmark.circle" : "checkmark.circle"
                            )
                            .font(.caption)
                        }
                        Spacer()
                        if let notes = suggestion.userNotes, !notes.isEmpty {
                            Text("Note added")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var severityIndicator: some View {
        VStack {
            Image(systemName: severityIcon)
                .font(.caption)
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ManuscriptReview.self, ReviewSuggestion.self, configurations: config)
    
    let review = ManuscriptReview(
        reviewId: UUID().uuidString,
        timestamp: Date(),
        projectId: UUID(),
        analysisMode: "file",
        summary: "Your prose is clear and engaging, with strong character development. Focus on tightening dialogue and varying sentence structure for greater impact.",
        overallSentiment: "encouraging",
        analysisProfile: "prose"
    )
    
    review.suggestions = [
        ReviewSuggestion(
            suggestionId: "1",
            category: "Dialogue",
            severity: "medium",
            location: "Page 3, Paragraph 2",
            observation: "The dialogue feels somewhat static.",
            suggestion: "Vary the pacing and add more subtext to make conversations feel more natural.",
            rationale: "Readers connect emotionally through character voice and conflict in dialogue."
        ),
        ReviewSuggestion(
            suggestionId: "2",
            category: "Sentence Structure",
            severity: "low",
            location: nil,
            observation: "Many sentences follow a similar structure.",
            suggestion: "Mix short and long sentences to create rhythm and emphasis.",
            rationale: "Sentence variety improves readability and maintains reader engagement."
        )
    ]
    
    return AnalystReviewView(review: review)
        .modelContainer(container)
}
