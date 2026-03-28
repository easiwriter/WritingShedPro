//
//  SupportResponseView.swift
//  Writing Shed Pro
//
//  Displays the support response with options to dismiss or escalate to email.
//  Feature 037: AI User Support
//

import SwiftUI

struct SupportResponseView: View {
    let responseText: String
    let onDismiss: () -> Void
    let onAskDeveloper: () -> Void

    private var formattedResponse: AttributedString {
        (try? AttributedString(markdown: responseText,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(responseText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    Text(formattedResponse)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                Divider()

                HStack(spacing: 16) {
                    Button {
                        onDismiss()
                    } label: {
                        Label(
                            NSLocalizedString("support.response.thisHelped", comment: ""),
                            systemImage: "checkmark.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onAskDeveloper()
                    } label: {
                        Label(
                            NSLocalizedString("support.response.askDeveloper", comment: ""),
                            systemImage: "envelope"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("support.response.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
