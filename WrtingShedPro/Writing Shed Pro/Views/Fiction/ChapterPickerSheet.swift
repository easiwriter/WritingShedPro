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
    
    private var isShortFiction: Bool {
        project.fictionClass == .shortFiction
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
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // If all scenes are assigned to the same chapter/story, only show remove option
                if let chapter = assignedChapter {
                    Section {
                        Button {
                            onAssign(nil)
                        } label: {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                                Text(String(format: isShortFiction
                                    ? NSLocalizedString("fiction.scenes.removeFromStoryNamed", comment: "Remove from Story X")
                                    : NSLocalizedString("fiction.scenes.removeFromChapterNamed", comment: "Remove from Chapter X"), chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled")))
                                    .foregroundColor(.primary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("fiction.scenes.currentAssignment", comment: "Current Assignment"))
                    } footer: {
                        Text(String(format: isShortFiction
                            ? NSLocalizedString("fiction.scenes.assignedToStory", comment: "Assigned to story")
                            : NSLocalizedString("fiction.scenes.assignedToChapter", comment: "Assigned to chapter"), chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled")))
                    }
                } else {
                    // Scenes are unassigned - show list of chapters/stories to assign to
                    Section {
                        if sortedChapters.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: isShortFiction ? "doc.text" : "book")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text(isShortFiction
                                    ? NSLocalizedString("fiction.stories.empty.title", comment: "No Stories Yet")
                                    : NSLocalizedString("fiction.chapters.empty.title", comment: "No Chapters Yet"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(isShortFiction
                                    ? NSLocalizedString("fiction.stories.picker.createHint", comment: "Create stories in the Stories folder")
                                    : NSLocalizedString("fiction.chapters.picker.createHint", comment: "Create chapters in the Chapters folder"))
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
                                                Text(String(format: isShortFiction
                                                    ? NSLocalizedString("fiction.story.number", comment: "Story X")
                                                    : NSLocalizedString("fiction.chapter.number", comment: "Chapter X"), userOrder + 1))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Show scene count in this chapter/story
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
                        Text(isShortFiction
                            ? NSLocalizedString("fiction.stories.title", comment: "Stories")
                            : NSLocalizedString("fiction.chapters.title", comment: "Chapters"))
                    } footer: {
                        if !sortedChapters.isEmpty {
                            Text(String(format: NSLocalizedString("fiction.scenes.assignCount", comment: "Assign count"), selectedScenes.count))
                        }
                    }
                }
            }
            .navigationTitle(assignedChapter != nil 
                ? (isShortFiction 
                    ? NSLocalizedString("fiction.scenes.storyAssignment", comment: "Story Assignment")
                    : NSLocalizedString("fiction.scenes.chapterAssignment", comment: "Chapter Assignment"))
                : (isShortFiction 
                    ? NSLocalizedString("fiction.scenes.addToStory", comment: "Add to Story")
                    : NSLocalizedString("fiction.scenes.addToChapter", comment: "Add to Chapter")))
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
