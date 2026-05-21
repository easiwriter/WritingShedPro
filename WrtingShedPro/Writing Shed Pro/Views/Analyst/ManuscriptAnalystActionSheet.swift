import SwiftUI
import SwiftData

/// Sheet for analyzing a file with the Manuscript Analyst service.
struct ManuscriptAnalystActionSheet: View {
    let textFile: TextFile
    @State private var isLoading = false
    @State private var showPaywall = false
    @State private var review: ManuscriptReview?
    @State private var error: ManuscriptAnalystError?
    @State private var showError = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    loadingState
                } else if let review = review {
                    AnalystReviewView(review: review)
                } else {
                    initialState
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showPaywall) {
                ManuscriptAnalystPaywallView(onSubscribe: {
                    showPaywall = false
                    // Trigger StoreKit purchase flow
                    Task {
                        // This would be integrated with StoreKit product purchase
                        print("Launching subscription purchase...")
                    }
                })
            }
            .alert("Analysis Error", isPresented: $showError, presenting: error) { _ in
                Button("OK") { dismiss() }
            } message: { error in
                Text(error.errorDescription ?? "Unknown error")
            }
        }
    }

    private var initialState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)
                Text("Analyze This File")
                    .font(.headline)
                Text(textFile.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("You'll receive:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                analyzeRow("Tailored feedback for your writing genre", "sparkles")
                analyzeRow("Specific suggestions by category", "list.bullet")
                analyzeRow("Analysis of key writing strengths", "checkmark.circle")
            }

            Spacer()

            Button(action: performAnalysis) {
                Label("Analyze Now", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(.cyan)
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your manuscript...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("This may take up to 30 seconds")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func analyzeRow(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.cyan)
                .frame(width: 24)
            Text(text)
                .font(.caption)
            Spacer()
        }
    }

    private func performAnalysis() {
        // Check subscription first
        Task { @MainActor in
            let hasSubscription = EntitlementManager.shared.isManuscriptAnalystSubscriptionActive()
            if !hasSubscription {
                showPaywall = true
                return
            }

            isLoading = true
            do {
                let service = ManuscriptAnalystService.shared
                let reviewResult = try await service.reviewFile(textFile, modelContext: modelContext)
                
                // Save the review to the model context
                modelContext.insert(reviewResult)
                try modelContext.save()
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.review = reviewResult
                    isLoading = false
                }
            } catch let err as ManuscriptAnalystError {
                self.error = err
                self.showError = true
                isLoading = false
            } catch {
                self.error = .networkError(error)
                self.showError = true
                isLoading = false
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TextFile.self, ManuscriptReview.self, configurations: config)
    
    let textFile = TextFile(
        name: "Chapter 1",
        initialContent: "Sample content for analysis."
    )
    
    ManuscriptAnalystActionSheet(textFile: textFile)
        .modelContainer(container)
}
