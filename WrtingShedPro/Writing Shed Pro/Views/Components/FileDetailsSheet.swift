//
//  FileDetailsSheet.swift
//  Writing Shed Pro
//
//  Created on 2026-01-07.
//

import SwiftUI

/// A sheet that displays file details with edit mode for renaming and export support
struct FileDetailsSheet: View {
    @Bindable var file: TextFile
    var onExport: ((TextFile) -> Void)? = nil
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Edit State
    
    @State private var isEditing = false
    @State private var editName: String = ""
    
    // MARK: - Async stats (computed off main thread to avoid blocking on SwiftData faults)
    
    @State private var wordCount: Int = 0
    @State private var characterCount: Int = 0
    @State private var lineCount: Int = 0
    @State private var statsLoaded = false
    
    private func computeStats() async {
        let content = file.currentVersion?.content ?? ""
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let chars = content.count
        let lines = content.components(separatedBy: .newlines).count
        wordCount = words
        characterCount = chars
        lineCount = lines
        statsLoaded = true
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var hasContainerInfo: Bool {
        file.parentFolder != nil ||
        !(file.poetryCollections ?? []).isEmpty ||
        !(file.sections ?? []).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                nameSection
                readOnlySections
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancellationToolbarItem
                confirmationToolbarItem
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await computeStats()
        }
    }

    private var nameSection: some View {
        Section {
            if isEditing {
                TextField(NSLocalizedString("fileDetails.name", comment: "Name"), text: $editName)
            } else {
                LabeledContent(NSLocalizedString("fileDetails.name", comment: "Name")) {
                    Text(file.name)
                }
            }
        }
    }

    @ViewBuilder
    private var readOnlySections: some View {
        if !isEditing {
            datesSection
            statisticsSection
            workflowSection
            containerInfoSection
            exportSection
        }
    }

    private var datesSection: some View {
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
    }

    private var statisticsSection: some View {
        Section(header: Text(NSLocalizedString("fileDetails.statistics", comment: "Statistics section header"))) {
            if !statsLoaded {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
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
        }
    }

    @ViewBuilder
    private var workflowSection: some View {
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

    @ViewBuilder
    private var containerInfoSection: some View {
        if hasContainerInfo {
            Section(header: Text(NSLocalizedString("fileDetails.container", comment: "Container section header"))) {
                if let folder = file.parentFolder {
                    HStack {
                        Text(NSLocalizedString("fileDetails.container.folder", comment: "Folder"))
                        Spacer()
                        Text(folder.name ?? "-")
                            .foregroundStyle(.secondary)
                    }
                }

                if let collections = file.poetryCollections, !collections.isEmpty {
                    ForEach(collections.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { collection in
                        HStack {
                            Text(NSLocalizedString("fileDetails.container.collection", comment: "Collection"))
                            Spacer()
                            Text(collection.name ?? "-")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let sections = file.sections, !sections.isEmpty {
                    ForEach(sections.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }) { section in
                        HStack {
                            Text(NSLocalizedString("fileDetails.container.section", comment: "Section"))
                            Spacer()
                            Text(section.name ?? "-")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if let onExport = onExport {
            Section {
                Button {
                    onExport(file)
                } label: {
                    Label(NSLocalizedString("fileList.export", comment: "Export"), systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var cancellationToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if isEditing {
                Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                    isEditing = false
                }
            } else {
                Button(NSLocalizedString("button.done", comment: "Done")) {
                    dismiss()
                }
            }
        }
    }

    private var confirmationToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if isEditing {
                Button(NSLocalizedString("button.save", comment: "Save")) {
                    saveChanges()
                }
                .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button(NSLocalizedString("button.edit", comment: "Edit")) {
                    editName = file.name
                    isEditing = true
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            file.name = trimmed
            file.modifiedDate = Date()
            try? modelContext.save()
        }
        isEditing = false
    }
}
