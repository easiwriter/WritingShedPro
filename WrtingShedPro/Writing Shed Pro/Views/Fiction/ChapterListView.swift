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
    @State private var showSubmissionNamePrompt = false
    @State private var newSubmissionName: String = ""
    @State private var showSubmissionCreated = false
    @State private var createdSubmissionName: String = ""
    @State private var showDuplicateSubmission = false
    
    // MARK: - Computed
    
    private var fictionClass: FictionClass {
        project.fictionClass ?? .novel
    }
    
    private var isShortFiction: Bool {
        fictionClass == .shortFiction
    }
    
    private var isVerseNovel: Bool {
        fictionClass == .verseNovel
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
    

    
    // MARK: - Localized Strings (Fiction Class Dependent)
    
    private var deleteConfirmTitle: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapters.deleteConfirm.title", comment: "Delete chapter?")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.deleteConfirm.title", comment: "Delete story?")
        case .verseNovel:
            return NSLocalizedString("fiction.books.deleteConfirm.title", comment: "Delete book?")
        }
    }
    
    private var deleteMultipleTitle: String {
        switch fictionClass {
        case .novel:
            return String(format: NSLocalizedString("fiction.chapters.deleteMultiple.title", comment: "Delete chapters?"), selectedChapters.count)
        case .shortFiction:
            return String(format: NSLocalizedString("fiction.stories.deleteMultiple.title", comment: "Delete stories?"), selectedChapters.count)
        case .verseNovel:
            return String(format: NSLocalizedString("fiction.books.deleteMultiple.title", comment: "Delete books?"), selectedChapters.count)
        }
    }
    
    private var deleteConfirmMessage: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapters.deleteConfirm.message", comment: "Delete message")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.deleteConfirm.message", comment: "Delete message")
        case .verseNovel:
            return NSLocalizedString("fiction.books.deleteConfirm.message", comment: "Delete message")
        }
    }
    
    private var deleteMultipleMessage: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapters.deleteMultiple.message", comment: "All scenes will also be deleted.")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.deleteMultiple.message", comment: "Scenes will be unassigned.")
        case .verseNovel:
            return NSLocalizedString("fiction.books.deleteMultiple.message", comment: "Episodes will be unassigned.")
        }
    }
    
    private var renameTitle: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapter.rename.title", comment: "Rename Chapter")
        case .shortFiction:
            return NSLocalizedString("fiction.story.rename.title", comment: "Rename Story")
        case .verseNovel:
            return NSLocalizedString("fiction.book.rename.title", comment: "Rename Book")
        }
    }
    
    private var itemTitle: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapter.title", comment: "Title")
        case .shortFiction:
            return NSLocalizedString("fiction.story.title", comment: "Title")
        case .verseNovel:
            return NSLocalizedString("fiction.book.title", comment: "Title")
        }
    }
    
    private var emptyTitle: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapters.empty.title", comment: "No chapters")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.empty.title", comment: "No stories")
        case .verseNovel:
            return NSLocalizedString("fiction.books.empty.title", comment: "No books")
        }
    }
    
    private var emptyMessage: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapters.empty.message", comment: "Empty message")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.empty.message", comment: "Empty message")
        case .verseNovel:
            return NSLocalizedString("fiction.books.empty.message", comment: "Empty message")
        }
    }
    
    private var addButtonLabel: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapters.add", comment: "Add chapter")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.add", comment: "Add story")
        case .verseNovel:
            return NSLocalizedString("fiction.books.add", comment: "Add book")
        }
    }
    
    private var deleteCountFormat: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapters.deleteCount", comment: "Delete count")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.deleteCount", comment: "Delete count")
        case .verseNovel:
            return NSLocalizedString("fiction.books.deleteCount", comment: "Delete count")
        }
    }
    
    private var itemNumberFormat: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapter.number", comment: "Chapter X")
        case .shortFiction:
            return NSLocalizedString("fiction.story.number", comment: "Story X")
        case .verseNovel:
            return NSLocalizedString("fiction.book.number", comment: "Book X")
        }
    }
    
    private var sceneCountFormat: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapter.sceneCount", comment: "Scene count")
        case .shortFiction:
            return NSLocalizedString("fiction.story.sceneCount", comment: "Scene count")
        case .verseNovel:
            return NSLocalizedString("fiction.book.episodeCount", comment: "Episode count")
        }
    }
    
    private var emptyStateIcon: String {
        switch fictionClass {
        case .novel:
            return "book"
        case .shortFiction:
            return "books.vertical"
        case .verseNovel:
            return "text.book.closed"
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
        .navigationTitle(fictionClass.chapterDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAddChapter = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(isVerseNovel
                    ? NSLocalizedString("fiction.books.add", comment: "Add book")
                    : (isShortFiction
                        ? NSLocalizedString("fiction.stories.add", comment: "Add story")
                        : NSLocalizedString("fiction.chapters.add", comment: "Add chapter")))
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
                ? deleteConfirmTitle
                : deleteMultipleTitle,
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteSelectedChapters()
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: {
            if selectedChapters.count == 1, let chapter = selectedChapters.first {
                Text(String(format: deleteConfirmMessage, chapter.name ?? ""))
            } else {
                Text(deleteMultipleMessage)
            }
        }
        .alert(renameTitle,
            isPresented: $showRenameSheet
        ) {
            TextField(itemTitle,
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
        .alert(NSLocalizedString("submissions.name.title", comment: "Name Submission"), isPresented: $showSubmissionNamePrompt) {
            TextField(NSLocalizedString("submissions.name.placeholder", comment: "Name"), text: $newSubmissionName)
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) {
                newSubmissionName = ""
            }
            Button(NSLocalizedString("button.create", comment: "Create")) {
                createSubmissionFromChapters(name: newSubmissionName)
                newSubmissionName = ""
            }
            .disabled(newSubmissionName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text(NSLocalizedString("submissions.name.message", comment: "Enter a name"))
        }
        .alert(NSLocalizedString("submissions.created.title", comment: "Submission Created"), isPresented: $showSubmissionCreated) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.created.message", comment: "Created message"), createdSubmissionName))
        }
        .alert(NSLocalizedString("submissions.duplicate.title", comment: "Duplicate Submission"), isPresented: $showDuplicateSubmission) {
            Button(NSLocalizedString("button.ok", comment: "OK")) { }
        } message: {
            Text(String(format: NSLocalizedString("submissions.duplicate.message", comment: "Duplicate message"), createdSubmissionName))
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
        
        // Add to submission button
        Button {
            showSubmissionNamePrompt = true
        } label: {
            Label(NSLocalizedString("fileList.addToSubmission", comment: "Add to submission"), systemImage: "tray.and.arrow.down")
        }
        
        Spacer()
        
        // Delete button
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label(
                String(format: deleteCountFormat, selectedChapters.count),
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
                        ChapterRowView(chapter: chapter, fictionClass: fictionClass)
                    } else {
                        NavigationLink {
                            SceneListView(project: project, chapter: chapter, act: nil)
                        } label: {
                            ChapterRowView(chapter: chapter, fictionClass: fictionClass)
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
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(emptyTitle)
                .font(.headline)
            
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddChapter = true
            } label: {
                Label(addButtonLabel, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteSelectedChapters() {
        for chapter in selectedChapters {
            // Unassign scenes from the chapter (don't delete for short fiction or verse novel)
            if isShortFiction || isVerseNovel {
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
    
    private func createSubmissionFromChapters(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check for duplicate
        let projectID = project.id
        var descriptor = FetchDescriptor<Submission>(predicate: #Predicate<Submission> { sub in
            sub.name == trimmedName && sub.project?.id == projectID && sub.isCollection == false
        })
        descriptor.fetchLimit = 1
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            createdSubmissionName = trimmedName
            showDuplicateSubmission = true
            return
        }
        
        let submission = Submission(
            project: project,
            submittedDate: Date()
        )
        submission.name = trimmedName
        submission.isCollection = false
        modelContext.insert(submission)
        
        // Link files from all selected chapters' scenes
        for chapter in selectedChapters {
            let files = (chapter.scenes ?? []).compactMap { $0.textFile }.filter { $0.trashItem == nil }
            for file in files {
                let submittedFile = SubmittedFile(
                    submission: submission,
                    textFile: file,
                    version: file.currentVersion,
                    status: .pending,
                    statusDate: Date(),
                    project: project
                )
                modelContext.insert(submittedFile)
            }
        }
        
        try? modelContext.save()
        createdSubmissionName = trimmedName
        showSubmissionCreated = true
        selectedChapterIDs.removeAll()
        exitEditMode()
    }
    
    private func exitEditMode() {
        withAnimation {
            editMode = .inactive
        }
    }
}

// MARK: - Chapter Row View

struct ChapterRowView: View {
    let chapter: Chapter
    var fictionClass: FictionClass = .novel
    
    private var itemNumberFormat: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapter.number", comment: "Chapter X")
        case .shortFiction:
            return NSLocalizedString("fiction.story.number", comment: "Story X")
        case .verseNovel:
            return NSLocalizedString("fiction.book.number", comment: "Book X")
        }
    }
    
    private var sceneCountFormat: String {
        switch fictionClass {
        case .novel:
            return NSLocalizedString("fiction.chapter.sceneCount", comment: "Scene count")
        case .shortFiction:
            return NSLocalizedString("fiction.story.sceneCount", comment: "Scene count")
        case .verseNovel:
            return NSLocalizedString("fiction.book.episodeCount", comment: "Episode count")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                // Chapter/Story/Book number
                if let userOrder = chapter.userOrder {
                    Text(String(format: itemNumberFormat, userOrder + 1))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                .font(.body)
                .fontWeight(.semibold)
            
            // Summary preview
            if let synopsis = chapter.synopsis, !synopsis.isEmpty {
                Text(synopsis)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Scene/Episode count
            let sceneCount = chapter.scenes?.count ?? 0
            HStack(spacing: 4) {
                Image(systemName: fictionClass == .verseNovel ? "music.note.list" : "film")
                    .font(.footnote)
                Text(String(format: sceneCountFormat, sceneCount))
                    .font(.footnote)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
