import SwiftUI
import StoreKit

/// Paywall view for the Manuscript Analyst subscription service.
struct ManuscriptAnalystPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var onCancel: (() -> Void)?
    @State private var isPurchasing = false
    @State private var showTrialTerms = false
    @State private var purchaseError: String?
    var onSubscribe: (() -> Void)?

    private var purchaseErrorPresented: Binding<Bool> {
        Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            paywallContent
        }
    }

    private var paywallContent: some View {
            VStack(spacing: 10) {
                heroSection

                Divider()

                featuresList

                Divider()

                pricingInfo

                Spacer(minLength: 0)

                ctaButtons

                finePrint
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { cancelFlow() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Trial Terms", isPresented: $showTrialTerms) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("First month free, then $5.99/month. Cancel anytime in App Store subscription settings. Billed to your Apple ID account.")
            }
            .alert("Purchase Error", isPresented: purchaseErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseError ?? "")
            }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
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
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow("text.magnifyingglass", "Smart editorial suggestions tailored to your genre", .cyan)
            featureRow("chart.line", "Track writing improvements over time", .green)
            featureRow("lightning.bolt", "Analyze entire manuscripts in seconds", .orange)
            featureRow("brain.fill", "AI powered by Claude 3.5 Sonnet", .purple)
        }
        .padding(.vertical, 8)
    }

    private var pricingInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subscription Plans")
                .font(.headline)

            subscriptionPlanCard

            Text("Includes AI-powered editorial feedback for one manuscript or file at a time. Billed monthly after the free first month until cancelled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var subscriptionPlanCard: some View {
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

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await purchaseSubscription() } }) {
                purchaseButtonLabel
            }
            .disabled(isPurchasing)

            Button(action: { cancelFlow() }) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.cyan)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private var purchaseButtonLabel: some View {
        if isPurchasing {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.cyan)
                .cornerRadius(8)
        } else {
            Label("Start Free Trial", systemImage: "star.fill")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.cyan)
                .cornerRadius(8)
        }
    }

    private var finePrint: some View {
        VStack(spacing: 8) {
            Button(action: { showTrialTerms = true }) {
                Label("Trial Terms", systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://writingshedpro.com/terms")!)
                Text("•")
                    .foregroundStyle(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://writingshedpro.com/privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func cancelFlow() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    private func purchaseSubscription() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let productID = WSPProduct.manuscriptAnalystSubscription.rawValue
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                purchaseError = "Subscription not available. Please try again later."
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    EntitlementManager.shared.recordVerifiedPurchase(transaction.productID)
                    await EntitlementManager.shared.refreshEntitlements()
                    onSubscribe?()
                    dismiss()
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
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
