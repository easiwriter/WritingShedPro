//
//  FileDetailsSheet.swift
//  Writing Shed Pro
//
//  Created on 2026-01-07.
//

import SwiftUI

/// A sheet that lets the user rename a file directly.
struct FileDetailsSheet: View {
    @Bindable var file: TextFile
    var onExport: ((TextFile) -> Void)? = nil
    var onSaveAs: ((TextFile) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editName: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
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
        navigationContainer
        .presentationDetents([.medium, .large])
        .alert(NSLocalizedString("fileDetail.error", comment: "Error alert title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("fileDetail.ok", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            editName = file.name
        }
        .task {
            await computeStats()
        }
    }

    @ViewBuilder
    private var navigationContainer: some View {
        #if targetEnvironment(macCatalyst)
        NavigationView {
            detailsForm
        }
        .navigationViewStyle(.stack)
        #else
        NavigationStack {
            detailsForm
        }
        #endif
    }

    private var detailsForm: some View {
        Form {
            nameSection
            datesSection
            statisticsSection
            workflowSection
            containerInfoSection
            exportSection
        }
        .navigationTitle(NSLocalizedString("fileDetail.title", comment: "File details title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                    closeSheet()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("button.done", comment: "Done")) {
                    saveChanges()
                }
                .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var nameSection: some View {
        Section {
            TextField(NSLocalizedString("fileDetails.name", comment: "Name"), text: $editName)
                .accessibilityLabel(NSLocalizedString("fileDetails.name", comment: "Name"))
                .onSubmit {
                    saveChanges()
                }
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
        if onExport != nil || onSaveAs != nil {
            Section {
                if let onExport = onExport {
                    Button {
                        closeSheet()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onExport(file)
                        }
                    } label: {
                        Label(NSLocalizedString("fileList.export", comment: "Export"), systemImage: "square.and.arrow.up")
                    }
                }

                #if os(macOS) || targetEnvironment(macCatalyst)
                if let onSaveAs = onSaveAs {
                    Button {
                        closeSheet()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onSaveAs(file)
                        }
                    } label: {
                        Label(NSLocalizedString("manuscript.saveAs", comment: "Save As…"), systemImage: "square.and.arrow.down")
                    }
                }
                #endif
            }
        }
    }
    
    // MARK: - Actions

    private func closeSheet() {
        onDismiss?()
        dismiss()
        dismissPresentedSheetOnCatalyst()
    }
    
    private func saveChanges() {
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed != file.name else {
            closeSheet()
            return
        }

        do {
            try NameValidator.validateFileName(trimmed)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }

        if let parentFolder = file.parentFolder,
           !UniquenessChecker.isFileNameUnique(trimmed, in: parentFolder),
           !(parentFolder.textFiles ?? []).contains(where: { $0.id == file.id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            let conflict = UniquenessChecker.getFileNameConflict(trimmed, in: parentFolder)
            errorMessage = conflict == "trash"
                ? NSLocalizedString("fileDetail.duplicateNameInTrash", comment: "File with this name exists in Trash")
                : NSLocalizedString("fileDetail.duplicateName", comment: "Duplicate file name error")
            showErrorAlert = true
            return
        }

        file.name = trimmed
        file.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "file-details-save")
        WriteCoalescer.shared?.flush()
        closeSheet()
    }
}
