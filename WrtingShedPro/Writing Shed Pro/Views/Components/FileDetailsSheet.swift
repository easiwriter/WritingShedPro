//
//  FileDetailsSheet.swift
//  Writing Shed Pro
//
//  Created on 2026-01-07.
//

import SwiftUI

/// A sheet that displays file details: creation date, last modified date, and word count
struct FileDetailsSheet: View {
    let file: TextFile
    
    @Environment(\.dismiss) private var dismiss
    
    private var wordCount: Int {
        guard let content = file.currentVersion?.content else { return 0 }
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    private var characterCount: Int {
        file.currentVersion?.content.count ?? 0
    }
    
    private var lineCount: Int {
        guard let content = file.currentVersion?.content else { return 0 }
        return content.components(separatedBy: .newlines).count
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(NSLocalizedString("fileDetails.dates", comment: "Dates section header"))) {
                    HStack {
                        Text(NSLocalizedString("fileDetails.created", comment: "Created date label"))
                        Spacer()
                        Text(dateFormatter.string(from: file.createdDate))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("fileDetails.modified", comment: "Modified date label"))
                        Spacer()
                        Text(dateFormatter.string(from: file.modifiedDate))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: Text(NSLocalizedString("fileDetails.statistics", comment: "Statistics section header"))) {
                    HStack {
                        Text(NSLocalizedString("fileDetails.words", comment: "Word count label"))
                        Spacer()
                        Text("\(wordCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("fileDetails.characters", comment: "Character count label"))
                        Spacer()
                        Text("\(characterCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("fileDetails.lines", comment: "Line count label"))
                        Spacer()
                        Text("\(lineCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let status = file.workflowStatus {
                    Section(header: Text(NSLocalizedString("fileDetails.status", comment: "Status section header"))) {
                        HStack {
                            Text(NSLocalizedString("fileDetails.workflowStatus", comment: "Workflow status label"))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: status.systemImage)
                                    .foregroundColor(Color(status.color))
                                Text(status.localizedName)
                                    .foregroundColor(Color(status.color))
                            }
                        }
                    }
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
