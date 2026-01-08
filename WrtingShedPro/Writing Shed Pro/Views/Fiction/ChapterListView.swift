//
//  ChapterListView.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Chapter management (Novel only)
//

import SwiftUI
import SwiftData

/// List view showing all chapters for a Novel fiction project
struct ChapterListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var showAddChapter = false
    @State private var selectedChapter: Chapter?
    @State private var showDeleteConfirmation = false
    @State private var chapterToDelete: Chapter?
    
    // MARK: - Computed
    
    private var sortedChapters: [Chapter] {
        (project.chapters ?? []).sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
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
        .navigationTitle(NSLocalizedString("fiction.chapters.title", comment: "Chapters"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddChapter = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(NSLocalizedString("fiction.chapters.add", comment: "Add chapter"))
            }
        }
        .sheet(isPresented: $showAddChapter) {
            AddChapterSheet(project: project)
        }
        .alert(
            NSLocalizedString("fiction.chapters.deleteConfirm.title", comment: "Delete chapter?"),
            isPresented: $showDeleteConfirmation,
            presenting: chapterToDelete
        ) { chapter in
            Button(NSLocalizedString("button.delete", comment: "Delete"), role: .destructive) {
                deleteChapter(chapter)
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        } message: { chapter in
            Text(String(format: NSLocalizedString("fiction.chapters.deleteConfirm.message", comment: "Delete message"), chapter.name ?? ""))
        }
    }
    
    // MARK: - Chapter List
    
    private var chapterList: some View {
        List {
            ForEach(sortedChapters) { chapter in
                NavigationLink {
                    SceneListView(project: project, chapter: chapter)
                } label: {
                    ChapterRowView(chapter: chapter)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        chapterToDelete = chapter
                        showDeleteConfirmation = true
                    } label: {
                        Label(NSLocalizedString("button.delete", comment: "Delete"), systemImage: "trash")
                    }
                }
            }
            .onMove(perform: moveChapters)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("fiction.chapters.empty.title", comment: "No chapters"))
                .font(.headline)
            
            Text(NSLocalizedString("fiction.chapters.empty.message", comment: "Empty message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAddChapter = true
            } label: {
                Label(NSLocalizedString("fiction.chapters.add", comment: "Add chapter"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func deleteChapter(_ chapter: Chapter) {
        // Also delete all scenes in the chapter
        if let scenes = chapter.scenes {
            for scene in scenes {
                modelContext.delete(scene)
            }
        }
        
        modelContext.delete(chapter)
        try? modelContext.save()
        renumberChapters()
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
}

// MARK: - Chapter Row View

struct ChapterRowView: View {
    let chapter: Chapter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Chapter number
                if let userOrder = chapter.userOrder {
                    Text(String(format: NSLocalizedString("fiction.chapter.number", comment: "Chapter X"), userOrder + 1))
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
                Text(String(format: NSLocalizedString("fiction.chapter.sceneCount", comment: "Scene count"), sceneCount))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
