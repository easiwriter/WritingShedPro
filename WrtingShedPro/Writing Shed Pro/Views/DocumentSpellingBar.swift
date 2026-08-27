import SwiftUI

struct DocumentSpellingBar: View {
    @Bindable var manager: DocumentSpellingManager
    @Binding var isVisible: Bool
    let canReplace: Bool
    let onReplace: (String) -> Void
    let onRescan: () -> Void
    let onClose: () -> Void

    @State private var replacement = ""

    var body: some View {
        if isVisible {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    ScrollView(.horizontal, showsIndicators: false) {
                        controls
                    }
                } else {
                    controls
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))
            .overlay(alignment: .bottom) {
                Divider()
            }
            .onChange(of: manager.currentIssue?.id, initial: true) {
                replacement = manager.suggestions.first ?? manager.currentIssue?.word ?? ""
            }
            .onChange(of: manager.suggestions) {
                replacement = manager.suggestions.first ?? manager.currentIssue?.word ?? ""
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.badge.checkmark")
                .foregroundStyle(.secondary)

            if manager.isScanning {
                ProgressView()
                    .controlSize(.small)
                Text(NSLocalizedString("spelling.scanning", comment: "Scanning document for spelling errors"))
                    .foregroundStyle(.secondary)
            } else if let issue = manager.currentIssue {
                Text(issue.word)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
                    .lineLimit(1)

                Text(manager.issueCountText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Menu {
                    if manager.suggestions.isEmpty {
                        Text(NSLocalizedString("spelling.noSuggestions", comment: "No spelling suggestions available"))
                    } else {
                        ForEach(manager.suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                replacement = suggestion
                            }
                        }
                    }
                } label: {
                    Label(
                        replacement.isEmpty
                            ? NSLocalizedString("spelling.suggestions", comment: "Spelling suggestions")
                            : replacement,
                        systemImage: "chevron.down"
                    )
                    .lineLimit(1)
                }

                Button {
                    onReplace(replacement)
                } label: {
                    Label(NSLocalizedString("spelling.replace", comment: "Replace misspelled word"), systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                }
                .disabled(!canReplace || replacement.isEmpty || replacement == issue.word)

                Button {
                    manager.ignoreCurrentIssue()
                } label: {
                    Label(NSLocalizedString("spelling.ignore", comment: "Ignore this spelling occurrence"), systemImage: "forward")
                }

                Button {
                    manager.ignoreAllOccurrencesOfCurrentWord()
                } label: {
                    Label(NSLocalizedString("spelling.ignoreAll", comment: "Ignore every occurrence of this word"), systemImage: "forward.end")
                }

                navigationButtons
            } else {
                Text(NSLocalizedString("spelling.noErrors", comment: "No spelling errors found"))
                    .foregroundStyle(.secondary)

                Button {
                    onRescan()
                } label: {
                    Label(NSLocalizedString("spelling.checkAgain", comment: "Check spelling again"), systemImage: "arrow.clockwise")
                }
            }

            languageMenu

            Divider()
                .frame(height: 22)

            Button {
                isVisible = false
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(NSLocalizedString("spelling.close", comment: "Close spelling checker"))
        }
        .buttonStyle(.borderless)
    }

    private var navigationButtons: some View {
        HStack(spacing: 2) {
            Button {
                manager.previousIssue()
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(NSLocalizedString("spelling.previous", comment: "Previous spelling error"))

            Button {
                manager.nextIssue()
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(NSLocalizedString("spelling.next", comment: "Next spelling error"))
        }
    }

    private var languageMenu: some View {
        Menu {
            Picker(
                NSLocalizedString("spelling.language", comment: "Spell checker language"),
                selection: $manager.selectedLanguage
            ) {
                ForEach(DocumentSpellingManager.availableLanguages, id: \.self) { language in
                    Text(Locale.current.localizedString(forIdentifier: language) ?? language)
                        .tag(language)
                }
            }
        } label: {
            Image(systemName: "globe")
                .frame(width: 28, height: 28)
        }
        .accessibilityLabel(NSLocalizedString("spelling.language", comment: "Spell checker language"))
        .onChange(of: manager.selectedLanguage) {
            onRescan()
        }
    }
}