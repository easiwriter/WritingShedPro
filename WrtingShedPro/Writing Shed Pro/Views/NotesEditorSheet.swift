//
//  NotesEditorSheet.swift
//  Writing Shed Pro
//
//  Feature: Version Notes
//  Sheet for adding and editing notes on a text file version
//

import SwiftUI
import UIKit

struct NotesEditorSheet: View {
    @Bindable var version: Version
    @Environment(\.dismiss) var dismiss
    @State private var showClearConfirmation = false
    @State private var attributedNotes = NSAttributedString(string: "")
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @StateObject private var textViewCoordinator = TextViewCoordinator()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                FormattedTextEditor(
                    attributedText: $attributedNotes,
                    selectedRange: $selectedRange,
                    textViewCoordinator: textViewCoordinator,
                    font: .preferredFont(forTextStyle: .body),
                    textColor: .label,
                    backgroundColor: .systemBackground,
                    textContainerInset: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
                    isEditable: true,
                    onTextChange: { newText in
                        persistNotes(newText)
                    }
                )
                .background(Color(uiColor: .systemBackground))
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .disabled(attributedNotes.string.isEmpty)
                }
            }
            .confirmationDialog(
                "Clear Notes?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    clearNotes()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all text in Notes.")
            }
            .onAppear {
                loadNotes()
            }
        }
        .navigationViewStyle(.stack)
    }

    private func loadNotes() {
        if let data = version.notesFormattedContent, !data.isEmpty {
            attributedNotes = AttributedStringSerializer.decode(data, text: version.notes ?? "")
        } else {
            attributedNotes = NSAttributedString(
                string: version.notes ?? "",
                attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
            )
        }
        selectedRange = NSRange(location: attributedNotes.length, length: 0)
    }

    private func persistNotes(_ notes: NSAttributedString) {
        attributedNotes = notes
        version.notes = notes.string.isEmpty ? nil : notes.string
        version.notesFormattedContent = notes.string.isEmpty ? nil : AttributedStringSerializer.encode(notes)
    }

    private func clearNotes() {
        let cleared = NSAttributedString(
            string: "",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        selectedRange = NSRange(location: 0, length: 0)
        persistNotes(cleared)
    }
}
