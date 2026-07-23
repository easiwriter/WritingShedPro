import SwiftUI

/// Displays a compact sync health indicator in Settings.
/// Shows icon + text for the current state and a secondary "last synced" line
/// when sync is stalled.
struct SyncStatusView: View {
    @Environment(SyncHealthMonitor.self) private var monitor

    var body: some View {
        HStack(spacing: 8) {
            image
            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.healthState.displayText)
                    .font(.subheadline)
                                if monitor.healthState == .stalled || monitor.healthState == .degraded || monitor.healthState == .blocked,
                   let exportTime = monitor.lastSuccessfulExportTime {
                    Text(String(format: NSLocalizedString("sync.status.lastSynced", comment: ""),
                                exportTime.formatted(.relative(presentation: .named))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(monitor.healthState.displayText)
        .task {
            monitor.checkHealth()
        }
    }

    @ViewBuilder
    private var image: some View {
        switch monitor.healthState {
        case .syncing, .recovering:
            ProgressView()
                .controlSize(.small)
        default:
            Image(systemName: monitor.healthState.iconName)
                .foregroundStyle(monitor.healthState.iconColor)
        }
    }
}
