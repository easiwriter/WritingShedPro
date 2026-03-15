import SwiftUI

struct EditContainerSheet: View {
    let navigationTitle: String
    let nameLabel: String
    let synopsisLabel: String
    let synopsisFooter: String
    let initialName: String
    let initialSynopsis: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var synopsis: String

    init(
        navigationTitle: String,
        nameLabel: String,
        synopsisLabel: String,
        synopsisFooter: String,
        initialName: String,
        initialSynopsis: String,
        onSave: @escaping (String, String) -> Void
    ) {
        self.navigationTitle = navigationTitle
        self.nameLabel = nameLabel
        self.synopsisLabel = synopsisLabel
        self.synopsisFooter = synopsisFooter
        self.initialName = initialName
        self.initialSynopsis = initialSynopsis
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _synopsis = State(initialValue: initialSynopsis)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(nameLabel, text: $name)
                }

                Section {
                    TextEditor(text: $synopsis)
                        .frame(minHeight: 80)
                } header: {
                    Text(synopsisLabel)
                } footer: {
                    Text(synopsisFooter)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedSynopsis = synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmedName, trimmedSynopsis)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}