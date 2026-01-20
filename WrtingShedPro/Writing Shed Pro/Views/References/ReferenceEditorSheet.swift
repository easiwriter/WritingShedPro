//
//  ReferenceEditorSheet.swift
//  Writing Shed Pro
//
//  Feature 029: Reference Editor
//  Sheet for editing referenced back matter entries via reference markers
//

import SwiftUI
import SwiftData

/// Sheet for editing a referenced entry (note, citation, glossary term, etc.) via a reference marker
struct ReferenceEditorSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project?
    let referenceAttachment: ReferenceAttachment
    
    // MARK: - State
    
    @State private var entryContent: String = ""
    @State private var entryTitle: String = ""
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                        .onAppear {
                            loadContent()
                        }
                } else {
                    VStack(spacing: 0) {
                        // Content editor
                        TextEditor(text: $entryContent)
                            .font(.body)
                            .padding()
                            .background(Color(.systemBackground))
                        
                        Divider()
                        
                        // Button bar
                        HStack(spacing: 12) {
                            Button(role: .cancel) {
                                dismiss()
                            } label: {
                                Text(NSLocalizedString("button.cancel", comment: "Cancel"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                saveChanges()
                            } label: {
                                Text(NSLocalizedString("button.save", comment: "Save"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Edit \(referenceAttachment.displayText)")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button(NSLocalizedString("button.ok", comment: "OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadContent() {
        guard let project = project else {
            isLoading = false
            return
        }
        
        defer { isLoading = false }
        
        // Fetch the referenced entry based on type
        switch referenceAttachment.referenceType {
        case .note, .endnote:
            if let note = project.noteEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                entryContent = note.content
                entryTitle = note.tag ?? ""
            }
            
        case .citation:
            if let citation = project.citationEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                entryContent = citation.title
                entryTitle = citation.title
            }
            
        case .glossary:
            if let term = project.glossaryEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                entryContent = term.definition
                entryTitle = term.term
            }
            
        case .index:
            if let entry = project.indexEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                entryContent = entry.keyword
                entryTitle = entry.keyword
            }
            
        case .figure, .table:
            // For figures and tables, we don't have these in the model yet
            // Just show empty content
            entryContent = ""
            entryTitle = referenceAttachment.displayText
        }
    }
    
    private func saveChanges() {
        guard let project = project else {
            dismiss()
            return
        }
        
        // Save changes based on reference type
        switch referenceAttachment.referenceType {
        case .note, .endnote:
            if let note = project.noteEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                note.content = entryContent
            }
            
        case .citation:
            if let citation = project.citationEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                citation.title = entryContent
            }
            
        case .glossary:
            if let term = project.glossaryEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                term.definition = entryContent
            }
            
        case .index:
            if let entry = project.indexEntries?.first(where: { $0.id == referenceAttachment.entryID }) {
                entry.keyword = entryContent
            }
            
        case .figure, .table:
            // No changes needed for now
            break
        }
        
        // Save to database
        do {
            try modelContext.save()
        } catch {
            errorMessage = NSLocalizedString("error.saveFailed", comment: "Failed to save changes")
            showError = true
            return
        }
        
        // Regenerate back matter files to reflect changes
        regenerateBackMatterFiles(project)
        
        dismiss()
    }
    
    private func regenerateBackMatterFiles(_ project: Project) {
        // Find the Back Matter folder
        guard let backMatterFolder = project.folders?.first(where: { $0.isBackMatterFolder }) else {
            return
        }
        
        let backMatterGenerator = BackMatterGenerator(context: modelContext, project: project)
        
        let backMatterItems: [(item: BackMatterItem, shouldUpdate: Bool)] = [
            (.endnotes, true),
            (.glossary, backMatterFolder.backMatterSettings.isEnabled(.glossary)),
            (.bibliography, backMatterFolder.backMatterSettings.isEnabled(.bibliography)),
            (.index, backMatterFolder.backMatterSettings.isEnabled(.index))
        ]
        
        for (item, shouldUpdate) in backMatterItems {
            guard shouldUpdate else { continue }
            
            // Find the back matter file
            let folderID = backMatterFolder.id
            let fileName = item.fileName
            let descriptor = FetchDescriptor<TextFile>(
                predicate: #Predicate<TextFile> { file in
                    file.parentFolder?.id == folderID && file.name == fileName
                }
            )
            
            guard let backMatterFile = try? modelContext.fetch(descriptor).first else {
                continue
            }
            
            // Generate fresh content for this back matter item
            let generatedContent: NSAttributedString
            
            switch item {
            case .endnotes:
                generatedContent = backMatterGenerator.generateNotesSection() ?? NSAttributedString()
            case .glossary:
                generatedContent = backMatterGenerator.generateGlossarySection() ?? NSAttributedString()
            case .bibliography:
                generatedContent = backMatterGenerator.generateBibliographySection() ?? NSAttributedString()
            case .index:
                generatedContent = backMatterGenerator.generateIndexSection(pageMap: [:]) ?? NSAttributedString()
            }
            
            // Update the file's content
            if backMatterFile.currentVersion == nil {
                let newVersion = Version(versionNumber: 1)
                newVersion.textFile = backMatterFile
                newVersion.attributedContent = generatedContent
                modelContext.insert(newVersion)
                backMatterFile.currentVersionIndex = 0
            } else {
                backMatterFile.currentVersion?.attributedContent = generatedContent
            }
            
            backMatterFile.modifiedDate = Date()
        }
        
        // Save the updated back matter files
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ Failed to save updated back matter files: \(error)")
            #endif
        }
    }
}

#if DEBUG
struct ReferenceEditorSheet_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Project.self, configurations: config)
        
        let project = Project(name: "Test", type: .fiction)
        let note = NoteEntry(content: "This is test content", isEndnote: false, tag: "test-note")
        project.noteEntries = [note]
        
        let reference = ReferenceAttachment(referenceType: .note, entryID: note.id, tag: "test-note")
        
        return ReferenceEditorSheet(project: project, referenceAttachment: reference)
            .modelContainer(container)
    }
}
#endif
