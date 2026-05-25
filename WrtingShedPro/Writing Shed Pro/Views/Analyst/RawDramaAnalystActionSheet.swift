import SwiftUI

struct RawDramaAnalysisRequest: Identifiable {
    let id = UUID()
    let input: RawDramaAnalysisInput
}

enum RawDramaAnalysisInput {
    case text(content: String, fileName: String)
    case file(url: URL)
}

/// Runs Manuscript Analyst on raw drama text or a selected text file.
struct RawDramaAnalystActionSheet: View {
    let project: Project
    let input: RawDramaAnalysisInput

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
                    performAnalysis()
                })
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
                let result: ManuscriptReview

                switch input {
                case .text(let content, let fileName):
                    result = try await service.reviewRawDramaText(
                        content,
                        fileName: fileName,
                        projectId: project.id
                    )
                case .file(let url):
                    result = try await service.reviewRawDramaFile(
                        at: url,
                        projectId: project.id
                    )
                }

                withAnimation(.easeInOut(duration: 0.3)) {
                    review = result
                    isLoading = false
                }
            } catch let err as ManuscriptAnalystError {
                error = err.errorDescription ?? "Unknown error"
                showError = true
                isLoading = false
            } catch {
                error = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}
