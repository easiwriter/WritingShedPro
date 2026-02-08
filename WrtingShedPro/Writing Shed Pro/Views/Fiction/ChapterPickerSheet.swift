//
//  ChapterPickerSheet.swift
//  Writing Shed Pro
//
//  Sheet for selecting a chapter/story to assign scenes to (Fiction projects)
//

import SwiftUI
import SwiftData

/// Sheet for picking a chapter (Novel) or story (Short Fiction) to assign selected scenes to
struct ChapterPickerSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    let selectedScenes: [StoryScene]
    let onAssign: (Chapter?) -> Void
    let onCancel: () -> Void
    
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
    
    /// Check if all selected scenes are assigned to the same chapter
    private var assignedChapter: Chapter? {
        // Get the chapter of the first scene
        guard let firstChapter = selectedScenes.first?.chapter else { return nil }
        // Check if all scenes are assigned to the same chapter
        let allSameChapter = selectedScenes.allSatisfy { $0.chapter?.id == firstChapter.id }
        return allSameChapter ? firstChapter : nil
    }
    
    // MARK: - Localized Labels
    
    private var removeFromNamedLabel: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.scenes.removeFromChapterNamed", comment: "Remove from Chapter X")
        case .shortFiction: return NSLocalizedString("fiction.scenes.removeFromStoryNamed", comment: "Remove from Story X")
        case .verseNovel: return NSLocalizedString("fiction.episodes.removeFromBookNamed", comment: "Remove from Book X")
        }
    }
    
    private var assignedToLabel: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.scenes.assignedToChapter", comment: "Assigned to chapter")
        case .shortFiction: return NSLocalizedString("fiction.scenes.assignedToStory", comment: "Assigned to story")
        case .verseNovel: return NSLocalizedString("fiction.episodes.assignedToBook", comment: "Assigned to book")
        }
    }
    
    private var emptyIcon: String {
        switch fictionClass {
        case .novel: return "book"
        case .shortFiction: return "doc.text"
        case .verseNovel: return "text.book.closed"
        }
    }
    
    private var emptyTitle: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapters.empty.title", comment: "No Chapters Yet")
        case .shortFiction: return NSLocalizedString("fiction.stories.empty.title", comment: "No Stories Yet")
        case .verseNovel: return NSLocalizedString("fiction.books.empty.title", comment: "No Books Yet")
        }
    }
    
    private var createHint: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapters.picker.createHint", comment: "Create chapters in the Chapters folder")
        case .shortFiction: return NSLocalizedString("fiction.stories.picker.createHint", comment: "Create stories in the Stories folder")
        case .verseNovel: return NSLocalizedString("fiction.books.picker.createHint", comment: "Create books in the Books folder")
        }
    }
    
    private var itemNumberLabel: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.number", comment: "Chapter X")
        case .shortFiction: return NSLocalizedString("fiction.story.number", comment: "Story X")
        case .verseNovel: return NSLocalizedString("fiction.book.number", comment: "Book X")
        }
    }
    
    private var assignmentTitle: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.scenes.chapterAssignment", comment: "Chapter Assignment")
        case .shortFiction: return NSLocalizedString("fiction.scenes.storyAssignment", comment: "Story Assignment")
        case .verseNovel: return NSLocalizedString("fiction.episodes.bookAssignment", comment: "Book Assignment")
        }
    }
    
    private var addToTitle: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.scenes.addToChapter", comment: "Add to Chapter")
        case .shortFiction: return NSLocalizedString("fiction.scenes.addToStory", comment: "Add to Story")
        case .verseNovel: return NSLocalizedString("fiction.episodes.addToBook", comment: "Add to Book")
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // If all scenes are assigned to the same chapter/story/book, only show remove option
                if let chapter = assignedChapter {
                    Section {
                        Button {
                            onAssign(nil)
                        } label: {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                                Text(String(format: removeFromNamedLabel, chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled")))
                                    .foregroundColor(.primary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.scenes.currentAssignment", comment: "Current Assignment"))
                    } footer: {
                        Text(String(format: assignedToLabel, chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled")))
                    }
                } else {
                    // Scenes are unassigned - show list of chapters/stories/books to assign to
                    Section {
                        if sortedChapters.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: emptyIcon)
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text(emptyTitle)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(createHint)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(sortedChapters) { chapter in
                                Button {
                                    onAssign(chapter)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let userOrder = chapter.userOrder {
                                                Text(String(format: itemNumberLabel, userOrder + 1))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Show scene count in this chapter/story/book
                                        let sceneCount = chapter.scenes?.count ?? 0
                                        Text("\(sceneCount)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(fictionClass.chapterDisplayName)
                    } footer: {
                        if !sortedChapters.isEmpty {
                            Text(String(format: isVerseNovel
                                ? NSLocalizedString("fiction.episodes.assignCount", comment: "Assign count")
                                : NSLocalizedString("fiction.scenes.assignCount", comment: "Assign count"), selectedScenes.count))
                        }
                    }
                }
            }
            .navigationTitle(assignedChapter != nil ? assignmentTitle : addToTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
