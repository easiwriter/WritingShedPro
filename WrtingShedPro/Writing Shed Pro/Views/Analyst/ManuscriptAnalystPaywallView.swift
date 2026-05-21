import SwiftUI
import StoreKit

/// Paywall view for the Manuscript Analyst subscription service.
struct ManuscriptAnalystPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPresented = true
    @State private var showStore = false
    @State private var showTrialTerms = false
    var onSubscribe: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Hero section
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan)
                    
                    VStack(spacing: 8) {
                        Text("Manuscript Analyst")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("AI-Powered Editorial Feedback")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 12)

                Divider()

                // Features list
                VStack(alignment: .leading, spacing: 8) {
                    featureRow("sparkles", "Smart editorial suggestions tailored to your genre", .cyan)
                    featureRow("chart.line", "Track writing improvements over time", .green)
                    featureRow("lightning.bolt", "Analyze entire manuscripts in seconds", .orange)
                    featureRow("brain.fill", "AI powered by Claude 3.5 Sonnet", .purple)
                }
                .padding(.vertical, 8)

                Divider()

                // Pricing info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subscription Plans")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("$5.99/month")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.cyan)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("First Month")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                            Text("FREE")
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
                .padding(.vertical, 4)

                Spacer(minLength: 0)

                // CTA buttons
                VStack(spacing: 12) {
                    Button(action: { showStore = true }) {
                        Label("Start Free Trial", systemImage: "star.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(.cyan)
                            .cornerRadius(8)
                    }

                    Button(action: { dismiss() }) {
                        Text("Maybe Later")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.cyan)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Fine print
                Button(action: { showTrialTerms = true }) {
                    Label("Trial Terms", systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showStore) {
                StoreView(autoPurchaseProduct: .manuscriptAnalystSubscription)
            }
            .alert("Trial Terms", isPresented: $showTrialTerms) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("First month free, then $5.99/month. Cancel anytime in App Store subscription settings. Billed to your Apple ID account.")
            }
            .onChange(of: showStore) { _, isShowing in
                guard !isShowing else { return }
                Task {
                    await EntitlementManager.shared.refreshEntitlements()
                    await MainActor.run {
                        if EntitlementManager.shared.isManuscriptAnalystSubscriptionActive() {
                            onSubscribe?()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func featureRow(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    ManuscriptAnalystPaywallView()
}
