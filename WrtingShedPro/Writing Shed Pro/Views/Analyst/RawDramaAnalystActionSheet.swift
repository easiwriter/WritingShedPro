import SwiftUI

struct RawDramaAnalysisRequest: Identifiable {
    let id = UUID()
    let content: String
    let fileName: String
}

/// Runs Manuscript Analyst on the current drama text.
struct RawDramaAnalystActionSheet: View {
    let project: Project
    let content: String
    let fileName: String

    @State private var isLoading = false
    @State private var hasStartedAnalysis = false
    @State private var showPaywall = false
    @State private var review: ManuscriptReview?
    @State private var error: String?
    @State private var showError = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    loadingState
                } else if let review {
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
            .alert("Analysis Error", isPresented: $showError) {
                Button("OK") { dismiss() }
            } message: {
                Text(error ?? "Unknown error")
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your drama text...")
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
        Task { @MainActor in
            let hasSubscription = EntitlementManager.shared.isManuscriptAnalystSubscriptionActive()
            if !hasSubscription {
                showPaywall = true
                return
            }

            isLoading = true
            do {
                let service = ManuscriptAnalystService.shared
                let result = try await service.reviewRawDramaText(
                    content,
                    fileName: fileName,
                    projectId: project.id
                )

                withAnimation(.easeInOut(duration: 0.3)) {
                    review = result
                    isLoading = false
                }
            } catch let err as ManuscriptAnalystError {
                error = err.errorDescription ?? "Unknown error"
                showError = true
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}
