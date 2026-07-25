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
    private let maxFormattedNotesBytes = 64_000
    
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
                    onTextChange: { change in
                        persistNotes(change.attributedText)
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
        let plainText = notes.string.trimmingCharacters(in: .whitespacesAndNewlines)
        version.notes = plainText.isEmpty ? nil : notes.string

        if plainText.isEmpty {
            version.notesFormattedContent = nil
        } else if shouldPersistFormattedNotes(notes) {
            let encoded = AttributedStringSerializer.encode(notes)
            if encoded.count <= maxFormattedNotesBytes {
                version.notesFormattedContent = encoded
            } else {
                // Fallback to plain text only to avoid oversized/fragile rich payload sync issues.
                version.notesFormattedContent = nil
            }
        } else {
            // Fallback to plain text only to avoid oversized/fragile rich payload sync issues.
            version.notesFormattedContent = nil
        }

        // Ensure notes edits produce CloudKit-visible activity on the owning file.
        version.textFile?.modifiedDate = Date()
        if version.modelContext != nil {
            WriteCoalescer.shared?.requestSave()
        }
    }

    private func shouldPersistFormattedNotes(_ notes: NSAttributedString) -> Bool {
        guard notes.length > 0 else { return false }

        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        var hasRichFormatting = false
        notes.enumerateAttributes(in: NSRange(location: 0, length: notes.length)) { attrs, _, stop in
            if attrs[.attachment] != nil || attrs[.link] != nil {
                hasRichFormatting = true
                stop.pointee = true
                return
            }

            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                let usesRichTraits = traits.contains(.traitBold) || traits.contains(.traitItalic)
                let customSize = abs(font.pointSize - bodyFont.pointSize) > 0.1
                if usesRichTraits || customSize {
                    hasRichFormatting = true
                    stop.pointee = true
                    return
                }
            }

            if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
               paragraphStyle.alignment != .natural,
               paragraphStyle.alignment != .left {
                hasRichFormatting = true
                stop.pointee = true
            }
        }

        return hasRichFormatting
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
