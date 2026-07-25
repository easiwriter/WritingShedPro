import SwiftUI
import SwiftData

/// Sheet for analyzing a file with the Manuscript Analyst service.
struct ManuscriptAnalystActionSheet: View {
    let textFile: TextFile
    @State private var isLoading = false
    @State private var hasStartedAnalysis = false
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
                    Color(.systemBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task {
                guard !hasStartedAnalysis else { return }
                hasStartedAnalysis = true
                performAnalysis()
            }
            .sheet(isPresented: $showPaywall) {
                ManuscriptAnalystPaywallView(
                    onCancel: {
                        showPaywall = false
                        dismiss()
                    },
                    onSubscribe: {
                        showPaywall = false
                        performAnalysis()
                    }
                )
            }
            .alert("Analysis Error", isPresented: $showError, presenting: error) { _ in
                Button("OK") { dismiss() }
            } message: { error in
                Text(error.errorDescription ?? "Unknown error")
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your manuscript...")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("This may take up to 30 seconds")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
                try WriteCoalescer.shared.requestSaveAndFlush(reason: "manuscript-analyst-action-save")
                
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
