//
//  ChapterListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Chapter/Story management
//

import SwiftUI
import SwiftData

/// List view showing all chapters (Novel) or stories (Short Fiction) for a fiction project
struct ChapterListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddChapter = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedChapterIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var showRenameSheet = false
    @State private var chapterToRename: Chapter?
    @State private var newChapterName: String = ""
    @State private var showCollectionPicker = false
    @State private var showSubmissionPicker = false
    @State private var filesToAddToCollection: [TextFile] = []
    @State private var filesToSubmit: [TextFile] = []
    
    // MARK: - Computed
    
    private var isShortFiction: Bool {
        project.fictionClass == .shortFiction
    }
    
    private var sortedChapters: [Chapter] {
        (project.chapters ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
    }
    
    private var isEditMode: Bool {
        editMode == .active
    }
    
    private var selectedChapters: [Chapter] {
        sortedChapters.filter { selectedChapterIDs.contains($0.id) }
    }
    
    private var showToolbar: Bool {
        isEditMode && !selectedChapterIDs.isEmpty
    }
    
    /// Get all ready text files from selected chapters' scenes
    private var selectedChapterFiles: [TextFile] {
        selectedChapters.flatMap { chapter in
            (chapter.scenes ?? []).compactMap { scene in
                guard let textFile = scene.textFile,
                      textFile.workflowStatus == .ready else { return nil }
                return textFile
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if sortedChapters.isEmpty {
                emptyState
            } else {
                chapterList
            }
        }
        .navigationTitle(isShortFiction 
            ? NSLocalizedString("fiction.stories.title", comment: "Stories")
            : NSLocalizedString("fiction.chapters.title", comment: "Chapters"))
        .navigationBarTitleDisplayMode(.inline)
        // Use native iOS back button - immune to SwiftUI render blocking
        .navigationBarBackButtonHidden(false)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAddChapter = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(isShortFiction
                    ? NSLocalizedString("fiction.stories.add", comment: "Add story")
                    : NSLocalizedString("fiction.chapters.add", comment: "Add chapter"))
                .disabled(isEditMode)
                
                // Edit/Done button
                if !sortedChapters.isEmpty {
                    Button {
                        withAnimation {
                            if editMode == .active {
                                editMode = .inactive
                                selectedChapterIDs.removeAll()
                            } else {
                                editMode = .active
                            }
                        }
                    } label: {
                        Text(isEditMode ? NSLocalizedString("button.done", comment: "Done") : NSLocalizedString("button.edit", comment: "Edit"))
                    }
                }
            }
            
            // Bottom toolbar for multi-select actions
            ToolbarItemGroup(placement: .bottomBar) {
                if showToolbar {
                    bottomToolbarContent
                }
            }
        }
        .sheet(isPresented: $showAddChapter) {
            AddChapterSheet(project: project)
        }
        .alert(
            selectedChapters.count == 1
                ? (isShortFiction
                    ? NSLocalizedString("fiction.stories.deleteConfirm.title", comment: "Delete story?")
                    : NSLocalizedString("fiction.chapters.deleteConfirm.title", comment: "Delete chapter?"))
                : (isShortFiction
                    ? String(format: NSLocalizedString("fiction.stories.deleteMultiple.title", comment: "Delete stories?"), selectedChapters.count)
                    : String(format: NSLocalizedString("fiction.chapters.deleteMultiple.title", comment: "Delete chapters?"), selectedChapters.count)),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSelectedChapters()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            if selectedChapters.count == 1, let chapter = selectedChapters.first {
                Text(String(format: isShortFiction
                    ? NSLocalizedString("fiction.stories.deleteConfirm.message", comment: "Delete message")
                    : NSLocalizedString("fiction.chapters.deleteConfirm.message", comment: "Delete message"), chapter.name ?? ""))
            } else {
                Text(isShortFiction
                    ? NSLocalizedString("fiction.stories.deleteMultiple.message", comment: "All scenes in these stories will also be deleted.")
                    : NSLocalizedString("fiction.chapters.deleteMultiple.message", comment: "All scenes in these chapters will also be deleted."))
            }
        }
        .alert(isShortFiction
            ? NSLocalizedString("fiction.story.rename.title", comment: "Rename Story")
            : NSLocalizedString("fiction.chapter.rename.title", comment: "Rename Chapter"),
            isPresented: $showRenameSheet
        ) {
            TextField(isShortFiction
                ? NSLocalizedString("fiction.story.title", comment: "Title")
                : NSLocalizedString("fiction.chapter.title", comment: "Title"),
                text: $newChapterName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                chapterToRename = nil
                newChapterName = ""
            }
            Button(NSLocalizedString("button.rename", comment: "Rename")) {
                if let chapter = chapterToRename {
                    renameChapter(chapter, to: newChapterName)
                }
                chapterToRename = nil
                newChapterName = ""
            }
            .disabled(newChapterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .sheet(isPresented: $showCollectionPicker) {
            NavigationStack {
                CollectionPickerView(
                    project: project,
                    filesToAddToCollection: filesToAddToCollection,
                    collectionsToAddToPublication: nil,
                    mode: .addFilesToCollection,
                    onCollectionSelected: { collection in
                        addFilesToCollection(collection)
                        showCollectionPicker = false
                        exitEditMode()
                    },
                    onCancel: {
                        showCollectionPicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showSubmissionPicker) {
            NavigationStack {
                SubmissionPickerView(
                    project: project,
                    filesToSubmit: filesToSubmit,
                    collectionToSubmit: nil,
                    onPublicationSelected: { publication, name, expectedDate in
                        createSubmission(for: publication, name: name, expectedResponseDate: expectedDate)
                        showSubmissionPicker = false
                        exitEditMode()
                    },
                    onCancel: {
                        showSubmissionPicker = false
                    }
                )
            }
        }
        .onChange(of: editMode) { _, newValue in
            if newValue == .inactive {
                selectedChapterIDs.removeAll()
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    
    @ViewBuilder
    private var bottomToolbarContent: some View {
        // Rename button (only for single selection)
        if selectedChapters.count == 1 {
            Button {
                if let chapter = selectedChapters.first {
                    chapterToRename = chapter
                    newChapterName = chapter.name ?? ""
                    showRenameSheet = true
                }
            } label: {
                Label(NSLocalizedString("button.rename", comment: "Rename"), systemImage: "pencil")
            }
        }
        
        // Add to Collection button
        if !selectedChapterFiles.isEmpty {
            Button {
                filesToAddToCollection = selectedChapterFiles
                showCollectionPicker = true
            } label: {
                Label(NSLocalizedString("button.addToCollection", comment: "Add to Collection"), systemImage: "folder.badge.plus")
            }
        }
        
        // Submit button
        if !selectedChapterFiles.isEmpty {
            Button {
                filesToSubmit = selectedChapterFiles
                showSubmissionPicker = true
            } label: {
                Label(NSLocalizedString("button.submit", comment: "Submit"), systemImage: "paperplane")
            }
        }
        
        Spacer()
        
        // Delete button
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(
                String(format: isShortFiction
                    ? NSLocalizedString("fiction.stories.deleteCount", comment: "Delete count")
                    : NSLocalizedString("fiction.chapters.deleteCount", comment: "Delete count"),
                    selectedChapters.count),
                systemImage: "trash"
            )
        }
        .disabled(selectedChapters.isEmpty)
    }
    
    // MARK: - Chapter List
    
    private var chapterList: some View {
        List(selection: $selectedChapterIDs) {
            ForEach(sortedChapters) { chapter in
                Group {
                    if isEditMode {
                        ChapterRowView(chapter: chapter, isShortFiction: isShortFiction)
                    } else {
                        NavigationLink {
                            SceneListView(project: project, chapter: chapter, act: nil)
                        } label: {
                            ChapterRowView(chapter: chapter, isShortFiction: isShortFiction)
                        }
                    }
                }
                // Enable drag-to-reorder without edit mode
                .onDrag {
                    return NSItemProvider(object: chapter.id.uuidString as NSString)
                }
            }
            .onMove(perform: moveChapters)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: isShortFiction ? "books.vertical" : "book")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(isShortFiction
                ? NSLocalizedString("fiction.stories.empty.title", comment: "No stories")
                : NSLocalizedString("fiction.chapters.empty.title", comment: "No chapters"))
                .font(.headline)
            
            Text(isShortFiction
                ? NSLocalizedString("fiction.stories.empty.message", comment: "Empty message")
                : NSLocalizedString("fiction.chapters.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddChapter = true
            } label: {
                Label(isShortFiction
                    ? NSLocalizedString("fiction.stories.add", comment: "Add story")
                    : NSLocalizedString("fiction.chapters.add", comment: "Add chapter"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteSelectedChapters() {
        for chapter in selectedChapters {
            // Unassign scenes from the chapter (don't delete for short fiction)
            if isShortFiction {
                if let scenes = chapter.scenes {
                    for scene in scenes {
                        scene.chapter = nil
                    }
                }
            } else {
                // For novels, delete all scenes in the chapter
                if let scenes = chapter.scenes {
                    for scene in scenes {
                        modelContext.delete(scene)
                    }
                }
            }
            
            modelContext.delete(chapter)
        }
        
        try? modelContext.save()
        selectedChapterIDs.removeAll()
        renumberChapters()
        exitEditMode()
    }
    
    private func renameChapter(_ chapter: Chapter, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        chapter.name = trimmedName
        chapter.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func moveChapters(from source: IndexSet, to destination: Int) {
        var chapters = sortedChapters
        chapters.move(fromOffsets: source, toOffset: destination)
        
        // Update order indices
        for (index, chapter) in chapters.enumerated() {
            chapter.userOrder = index
        }
        
        try? modelContext.save()
    }
    
    private func renumberChapters() {
        for (index, chapter) in sortedChapters.enumerated() {
            chapter.userOrder = index
        }
        try? modelContext.save()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
    
    // MARK: - Collection & Submission Actions
    
    private func addFilesToCollection(_ collection: Submission) {
        // Create SubmittedFile records for each file in the collection
        for file in filesToAddToCollection {
            // Check if file is already in collection
            let alreadyInCollection = collection.submittedFiles?.contains { $0.textFile?.id == file.id } ?? false
            guard !alreadyInCollection else { continue }
            
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: collection,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        try? modelContext.save()
        filesToAddToCollection = []
    }
    
    private func createSubmission(for publication: Publication, name: String, expectedResponseDate: Date?) {
        // Create submission
        let submission = Submission(
            publication: publication,
            project: project,
            submittedDate: Date(),
            notes: nil
        )
        submission.name = name
        submission.isCollection = false
        submission.returnExpectedBy = expectedResponseDate
        modelContext.insert(submission)
        
        // Create SubmittedFile records for each file
        for file in filesToSubmit {
            if let currentVersion = file.currentVersion {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        try? modelContext.save()
        filesToSubmit = []
    }
}

// MARK: - Chapter Row View

struct ChapterRowView: View {
    let chapter: Chapter
    var isShortFiction: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Chapter/Story number
                if let userOrder = chapter.userOrder {
                    Text(String(format: isShortFiction 
                        ? NSLocalizedString("fiction.story.number", comment: "Story X")
                        : NSLocalizedString("fiction.chapter.number", comment: "Chapter X"), userOrder + 1))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                .font(.headline)
            
            // Summary preview
            if let synopsis = chapter.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Scene count
            let sceneCount = chapter.scenes?.count ?? 0
            HStack(spacing: 4) {
                Image(systemName: "film")
                    .font(.caption)
                Text(String(format: isShortFiction
                    ? NSLocalizedString("fiction.story.sceneCount", comment: "Scene count")
                    : NSLocalizedString("fiction.chapter.sceneCount", comment: "Scene count"), sceneCount))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
