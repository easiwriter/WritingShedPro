import SwiftUI
import StoreKit

/// Paywall view for the Manuscript Analyst subscription service.
struct ManuscriptAnalystPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPresented = true
    var onSubscribe: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Hero section
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 64))
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
                .padding(.vertical, 24)

                Divider()

                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    featureRow("sparkles", "Smart editorial suggestions tailored to your genre", .cyan)
                    featureRow("chart.line", "Track writing improvements over time", .green)
                    featureRow("lightning.bolt", "Analyze entire manuscripts in seconds", .orange)
                    featureRow("brain.fill", "AI powered by Claude 3.5 Sonnet", .purple)
                }
                .padding(.vertical, 16)

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
                .padding(.vertical, 8)

                Spacer()

                // CTA buttons
                VStack(spacing: 12) {
                    Button(action: { 
                        onSubscribe?()
                        dismiss()
                    }) {
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
                VStack(spacing: 4) {
                    Text("Trial terms")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("First month free, then $5.99/month. Cancel anytime. Billed to your App Store account.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
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
