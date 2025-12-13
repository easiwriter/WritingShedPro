//
//  NotesEditorSheet.swift
//  Writing Shed Pro
//
//  Feature: File Notes
//  Sheet for adding and editing notes on a text file
//

import SwiftUI

struct NotesEditorSheet: View {
    @Bindable var textFile: TextFile
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: Binding(
                    get: { textFile.notes ?? "" },
                    set: { textFile.notes = $0.isEmpty ? nil : $0 }
                ))
                .font(.body)
                .padding()
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
            }
        }
    }
}
