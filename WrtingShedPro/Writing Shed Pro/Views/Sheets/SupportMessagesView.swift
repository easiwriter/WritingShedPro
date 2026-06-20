import SwiftUI

struct SupportMessagesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = SupportMessagesService()

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading && service.visibleMessages.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.visibleMessages.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("messages.empty.title", comment: ""),
                        systemImage: "text.bubble",
                        description: Text(NSLocalizedString("messages.empty.body", comment: ""))
                    )
                } else {
                    List {
                        ForEach(service.visibleMessages) { message in
                            messageRow(message)
                        }
                        .onDelete(perform: deleteMessages)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(NSLocalizedString("messages.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.done", comment: "")) {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await service.fetchMessages()
            }
            .task {
                await service.fetchMessages()
            }
            .alert(
                NSLocalizedString("messages.error.title", comment: ""),
                isPresented: Binding(
                    get: { service.errorMessage != nil },
                    set: { if !$0 { service.errorMessage = nil } }
                )
            ) {
                Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) {
                    service.errorMessage = nil
                }
            } message: {
                Text(service.errorMessage ?? "")
            }
        }
    }

    private func deleteMessages(at offsets: IndexSet) {
        let visible = service.visibleMessages
        for index in offsets {
            guard visible.indices.contains(index) else { continue }
            service.hideMessage(visible[index].id)
        }
    }

    @ViewBuilder
    private func messageRow(_ message: SupportMessage) -> some View {
        let isRead = service.isRead(message)

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isRead ? "checkmark.circle.fill" : "circle.fill")
                .font(.caption)
                .foregroundColor(isRead ? .secondary : .blue)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(message.title)
                            .font(.headline)
                            .fontWeight(isRead ? .regular : .semibold)

                        if message.isMarkedCritical {
                            criticalBadge
                        }
                    }

                    Spacer(minLength: 8)

                    Button(isRead ? NSLocalizedString("messages.markUnread", comment: "") : NSLocalizedString("messages.markRead", comment: "")) {
                        if isRead {
                            service.markAsUnread(message.id)
                        } else {
                            service.markAsRead(message)
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                Text(message.body)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text(relativeDateText(from: message.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel(
            message.isMarkedCritical
                ? String(
                    format: NSLocalizedString("messages.accessibility.criticalLabel", comment: "Accessibility label for critical support message row"),
                    message.title
                )
                : message.title
        )
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(isRead ? NSLocalizedString("messages.markUnread", comment: "") : NSLocalizedString("messages.markRead", comment: "")) {
                if isRead {
                    service.markAsUnread(message.id)
                } else {
                    service.markAsRead(message)
                }
            }
            .tint(isRead ? .orange : .blue)
        }
    }

    private func relativeDateText(from timestampMs: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestampMs / 1000.0)
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private var criticalBadge: some View {
        Label(NSLocalizedString("messages.critical", comment: "Critical message badge text"), systemImage: "exclamationmark.triangle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel(NSLocalizedString("messages.critical", comment: "Critical message badge text"))
    }
}
