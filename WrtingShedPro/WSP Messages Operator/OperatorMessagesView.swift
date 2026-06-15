import SwiftUI

struct OperatorMessagesView: View {
    @State private var service = OperatorMessagesService()
    @State private var settings = OperatorSettingsStore()
    @State private var includeArchived = false

    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var selectedMessage: OperatorMessage?

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    TextField("Endpoint", text: $settings.endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Admin API Token", text: $settings.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Include Archived", isOn: $includeArchived)
                }

                Section("Create Message") {
                    TextField("Title", text: $draftTitle)
                    TextField("Body", text: $draftBody, axis: .vertical)
                        .lineLimit(3...8)
                    Button("Create") {
                        Task {
                            await service.create(title: draftTitle, body: draftBody, settings: settings)
                            await service.fetch(includeArchived: includeArchived, settings: settings)
                            draftTitle = ""
                            draftBody = ""
                        }
                    }
                    .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              settings.token.isEmpty)
                }

                Section("Messages") {
                    if service.isLoading {
                        ProgressView()
                    }
                    ForEach(service.messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(message.title)
                                    .font(.headline)
                                Spacer()
                                if message.isArchived {
                                    Text("Archived")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(message.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMessage = message
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await service.archive(message.id, settings: settings)
                                    await service.fetch(includeArchived: includeArchived, settings: settings)
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                    }
                }
            }
            .navigationTitle("WSP Messages Operator")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await service.fetch(includeArchived: includeArchived, settings: settings)
                        }
                    }
                    .disabled(settings.token.isEmpty)
                }
            }
            .task {
                if !settings.token.isEmpty {
                    await service.fetch(includeArchived: includeArchived, settings: settings)
                }
            }
            .onChange(of: includeArchived) { _, _ in
                Task {
                    if !settings.token.isEmpty {
                        await service.fetch(includeArchived: includeArchived, settings: settings)
                    }
                }
            }
            .sheet(item: $selectedMessage) { message in
                OperatorMessageEditor(message: message) { updated in
                    Task {
                        await service.update(updated, settings: settings)
                        await service.fetch(includeArchived: includeArchived, settings: settings)
                    }
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { service.errorMessage != nil },
                    set: { if !$0 { service.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { service.errorMessage = nil }
            } message: {
                Text(service.errorMessage ?? "")
            }
        }
    }
}

private struct OperatorMessageEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: OperatorMessage
    let onSave: (OperatorMessage) -> Void

    init(message: OperatorMessage, onSave: @escaping (OperatorMessage) -> Void) {
        _draft = State(initialValue: message)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                    TextField("Body", text: $draft.body, axis: .vertical)
                        .lineLimit(4...10)
                    Toggle("Archived", isOn: $draft.isArchived)
                }
            }
            .navigationTitle("Edit Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
