//
//  SubmissionPickerView.swift
//  Writing Shed Pro
//
//  Feature 008b Phase 3: Submission workflow from Ready folder
//

import SwiftUI
import SwiftData

struct SubmissionPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let filesToSubmit: [TextFile]?
    let collectionToSubmit: Submission?
    let onPublicationSelected: (Publication, String, Date?, Date?) -> Void  // Includes submission name, optional expected response date, and optional reminder date
    let onCancel: () -> Void
    
    @Query private var allPublications: [Publication]
    @State private var showingNewPublicationSheet = false
    @State private var submissionName: String = ""
    @State private var selectedPublication: Publication? = nil
    
    private var projectID: UUID {
        project.id
    }

    // Filter publications for this project
    private var projectPublications: [Publication] {
        let filtered = allPublications.filter { publication in
            publication.projectId == projectID || publication.project?.id == projectID
        }
        return filtered.sorted { lhs, rhs in
            lhs.name < rhs.name
        }
    }
    
    // Generate a default name based on files
    private var defaultSubmissionName: String {
        if let collection = collectionToSubmit, let name = collection.name {
            return name
        } else if let files = filesToSubmit {
            if files.count == 1 {
                return files[0].name
            } else if files.count > 1 {
                return "\(files[0].name) + \(files.count - 1) more"
            }
        }
        return "Submission"
    }
    
    private var submissionTitle: String {
        if let collection = collectionToSubmit, let name = collection.name {
            return "Submit: \(name)"
        } else if collectionToSubmit != nil {
            return "Submit Collection"
        } else {
            return "Submit Files"
        }
    }

    private var trimmedSubmissionName: String {
        submissionName.trimmingCharacters(in: .whitespaces)
    }

    private var resolvedSubmissionName: String {
        trimmedSubmissionName.isEmpty ? defaultSubmissionName : trimmedSubmissionName
    }

    @ViewBuilder
    private var submissionNameSection: some View {
        Section {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Submission name placeholder"), text: $submissionName)
                .textInputAutocapitalization(.words)
                .accessibilityLabel(Text("submissions.name.label"))
        } header: {
            Text(NSLocalizedString("submissions.name.header", comment: "Submission Name"))
        }
    }

    private var addPublicationSection: some View {
        Section {
            Button(action: { showingNewPublicationSheet = true }) {
                Label("publications.button.add", systemImage: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
            .accessibilityLabel(Text("accessibility.add.publication"))
        }
    }

    private func selectPublication(_ publication: Publication) {
        onPublicationSelected(publication, resolvedSubmissionName, nil, nil)
        dismiss()
    }

    @ViewBuilder
    private func publicationRow(_ publication: Publication) -> some View {
        Button(action: {
            selectPublication(publication)
        }) {
            HStack {
                Text(publication.publicationType?.icon ?? "")
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(publication.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let type = publication.publicationType {
                        Text(type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel(Text(String(format: NSLocalizedString("accessibility.submit.to", comment: "Submit to"), publication.name)))
    }

    @ViewBuilder
    private var existingPublicationsSection: some View {
        if !projectPublications.isEmpty {
            Section {
                ForEach(projectPublications) { publication in
                    publicationRow(publication)
                }
            } header: {
                Text("publications.existing.title")
            }
        } else {
            Section {
                ContentUnavailableView {
                    Label("publications.empty.title", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("publications.empty.message")
                }
            }
        }
    }

    private var pickerList: some View {
        List {
            submissionNameSection
            addPublicationSection
            existingPublicationsSection
        }
    }

    private var newPublicationSheet: some View {
        NavigationStack {
            NewPublicationForSubmissionView(
                project: project,
                filesToSubmit: filesToSubmit,
                collectionToSubmit: collectionToSubmit,
                onPublicationCreated: { publication in
                    showingNewPublicationSheet = false
                    onPublicationSelected(publication, resolvedSubmissionName, nil, nil)
                },
                onCancel: {
                    showingNewPublicationSheet = false
                }
            )
        }
    }
    
    var body: some View {
        pickerList
        .navigationTitle("submissions.submit.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    onCancel()
                    dismiss()
                }
            }
        }
        .onAppear {
            // Set default name on appear
            if submissionName.isEmpty {
                submissionName = defaultSubmissionName
            }
        }
        .sheet(isPresented: $showingNewPublicationSheet) {
            newPublicationSheet
        }
    }
}

/// View for creating a new publication during submission flow
struct NewPublicationForSubmissionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let filesToSubmit: [TextFile]?
    let collectionToSubmit: Submission?
    let onPublicationCreated: (Publication) -> Void
    let onCancel: () -> Void
    
    @Query private var allPublications: [Publication]
    
    @State private var name: String = ""
    @State private var selectedType: PublicationType = .magazine
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateWarning = false
    @State private var pendingSaveName: String = ""
    
    /// Available publication types based on project type
    private var availableTypes: [PublicationType] {
        PublicationType.availableTypes(for: project.type)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var projectPublications: [Publication] {
        let projectID = project.id
        return allPublications.filter { publication in
            publication.projectId == projectID || publication.project?.id == projectID
        }
    }

    private var selectedFileNames: [String] {
        if let filesToSubmit {
            return filesToSubmit.map { $0.name }
        }
        if let collection = collectionToSubmit, let files = collection.submittedFiles {
            return files.compactMap { $0.textFile?.name }
        }
        return []
    }

    private var selectedFilesHeaderText: String {
        if let filesToSubmit {
            return String(format: NSLocalizedString("submissions.files.selected", comment: "Files selected"), filesToSubmit.count)
        }
        if let collection = collectionToSubmit {
            let count = collection.submittedFiles?.count ?? 0
            return String(format: NSLocalizedString("submissions.files.selected", comment: "Files selected"), count)
        }
        return NSLocalizedString("submissions.no.files.selected", comment: "No files selected")
    }

    private var nameSection: some View {
        Section {
            TextField("publications.form.name.placeholder", text: $name)
                .accessibilityLabel(Text("publications.form.name.label"))
        } header: {
            Text("publications.form.name.label")
        }
    }

    private var typeSection: some View {
        Section {
            Picker("publications.form.type.label", selection: $selectedType) {
                ForEach(availableTypes, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("publications.form.type.label")
        }
    }

    private var selectedFilesSection: some View {
        Section {
            ForEach(selectedFileNames, id: \.self) { fileName in
                Text(fileName)
                    .font(.body)
            }
        } header: {
            Text(selectedFilesHeaderText)
        }
    }

    private var publicationForm: some View {
        Form {
            nameSection
            typeSection
            selectedFilesSection
        }
    }
    
    var body: some View {
        publicationForm
        .navigationTitle("publications.new.quick.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    onCancel()
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("publications.button.create") {
                    createPublicationAndSubmit()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
        .alert("publications.error.title", isPresented: $showingError) {
            Button("button.ok", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "publications.duplicate.title",
            isPresented: $showingDuplicateWarning,
            titleVisibility: .visible
        ) {
            Button("publications.duplicate.useOriginal") {
                performCreate(withName: pendingSaveName)
            }
            Button("publications.duplicate.makeUnique") {
                let uniqueName = makeUniqueName(pendingSaveName)
                name = uniqueName
                performCreate(withName: uniqueName)
            }
            Button("button.cancel", role: .cancel) {
                pendingSaveName = ""
            }
        } message: {
            Text("publications.duplicate.message")
        }
        .onAppear {
            // Set default type for project
            selectedType = availableTypes.first ?? .other
        }
    }
    
    private func createPublicationAndSubmit() {
        guard !trimmedName.isEmpty else {
            errorMessage = NSLocalizedString("publications.error.name.empty", comment: "Name required")
            showingError = true
            return
        }
        
        guard trimmedName.count <= 100 else {
            errorMessage = NSLocalizedString("publications.error.name.toolong", comment: "Name too long")
            showingError = true
            return
        }
        
        // Check for duplicates
        if hasDuplicateName(trimmedName) {
            pendingSaveName = trimmedName
            showingDuplicateWarning = true
            return
        }
        
        performCreate(withName: trimmedName)
    }
    
    private func performCreate(withName finalName: String) {
        // Create publication
        let publication = Publication(
            name: finalName,
            type: selectedType,
            project: project
        )
        project.modifiedDate = Date()
        modelContext.insert(publication)

        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "submission-picker-save")
            NotificationCenter.default.post(name: .projectContentCountsDidChange, object: nil)
            // Notify parent to create submission
            onPublicationCreated(publication)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func hasDuplicateName(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        return projectPublications.contains { publication in
            publication.name.lowercased() == lowercasedName
        }
    }
    
    private func makeUniqueName(_ baseName: String) -> String {
        let existingNames = Set(projectPublications.map { $0.name.lowercased() })
        
        var counter = 1
        var uniqueName = "\(baseName)-1"
        
        while existingNames.contains(uniqueName.lowercased()) {
            counter += 1
            uniqueName = "\(baseName)-\(counter)"
        }
        
        return uniqueName
    }
}
