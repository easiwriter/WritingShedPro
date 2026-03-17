//
//  AddChapterSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add chapter/story form
//

import SwiftUI
import SwiftData

/// Sheet for adding a new chapter (Novel) or story (Short Fiction) to a fiction project
struct AddChapterSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextOrderIndex: Int {
        if isVerseNovel {
            let books = project.books ?? []
            return (books.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
        }

        let chapters = project.chapters ?? []
        return (chapters.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    private var suggestedTitle: String {
        switch fictionClass {
        case .novel:
            return String(format: NSLocalizedString("fiction.chapter.defaultTitle", comment: "Chapter X"), nextOrderIndex + 1)
        case .shortFiction:
            return String(format: NSLocalizedString("fiction.story.defaultTitle", comment: "Story X"), nextOrderIndex + 1)
        case .verseNovel:
            return String(format: NSLocalizedString("fiction.book.defaultTitle", comment: "Book X"), nextOrderIndex + 1)
        }
    }
    
    // Localized strings based on fiction class
    private var titleLabel: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.title", comment: "Title")
        case .shortFiction: return NSLocalizedString("fiction.story.title", comment: "Title")
        case .verseNovel: return NSLocalizedString("fiction.book.title", comment: "Title")
        }
    }
    
    private var titleAccessibility: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.title.accessibility", comment: "Chapter title")
        case .shortFiction: return NSLocalizedString("fiction.story.title.accessibility", comment: "Story title")
        case .verseNovel: return NSLocalizedString("fiction.book.title.accessibility", comment: "Book title")
        }
    }
    
    private var sectionBasic: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.section.basic", comment: "Basic Info")
        case .shortFiction: return NSLocalizedString("fiction.story.section.basic", comment: "Basic Info")
        case .verseNovel: return NSLocalizedString("fiction.book.section.basic", comment: "Basic Info")
        }
    }
    
    private var numberLabel: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.number", comment: "Chapter X")
        case .shortFiction: return NSLocalizedString("fiction.story.number", comment: "Story X")
        case .verseNovel: return NSLocalizedString("fiction.book.number", comment: "Book X")
        }
    }
    
    private var summaryAccessibility: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.summary.accessibility", comment: "Chapter summary")
        case .shortFiction: return NSLocalizedString("fiction.story.summary.accessibility", comment: "Story summary")
        case .verseNovel: return NSLocalizedString("fiction.book.summary.accessibility", comment: "Book summary")
        }
    }
    
    private var summaryLabel: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.summary", comment: "Summary")
        case .shortFiction: return NSLocalizedString("fiction.story.summary", comment: "Summary")
        case .verseNovel: return NSLocalizedString("fiction.book.summary", comment: "Summary")
        }
    }
    
    private var summaryFooter: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.summary.footer", comment: "Brief overview of the chapter")
        case .shortFiction: return NSLocalizedString("fiction.story.summary.footer", comment: "Brief overview of the story")
        case .verseNovel: return NSLocalizedString("fiction.book.summary.footer", comment: "Brief overview of this book")
        }
    }
    
    private var addTitle: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.add.title", comment: "Add Chapter")
        case .shortFiction: return NSLocalizedString("fiction.story.add.title", comment: "Add Story")
        case .verseNovel: return NSLocalizedString("fiction.book.add.title", comment: "Add Book")
        }
    }
    
    private var errorTitleRequired: String {
        switch fictionClass {
        case .novel: return NSLocalizedString("fiction.chapter.error.titleRequired", comment: "Title required")
        case .shortFiction: return NSLocalizedString("fiction.story.error.titleRequired", comment: "Title required")
        case .verseNovel: return NSLocalizedString("fiction.book.error.titleRequired", comment: "Title required")
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(titleLabel, text: $title)
                        .accessibilityLabel(titleAccessibility)
                } header: {
                    Text(sectionBasic)
                } footer: {
                    Text(String(format: numberLabel, nextOrderIndex + 1))
                }
                
                // Summary
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                        .accessibilityLabel(summaryAccessibility)
                } header: {
                    Text(summaryLabel)
                } footer: {
                    Text(summaryFooter)
                }
            }
            .navigationTitle(addTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if title.isEmpty {
                    title = suggestedTitle
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.add", comment: "Add")) {
                        addChapter()
                    }
                    .disabled(!isValid)
                }
            }
            .alert(NSLocalizedString("error.title", comment: "Error"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Actions
    
    private func addChapter() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = errorTitleRequired
            showErrorAlert = true
            return
        }
        
        if isVerseNovel {
            let book = Book(
                name: trimmedTitle,
                synopsis: summary.isEmpty ? nil : summary,
                userOrder: nextOrderIndex
            )
            book.project = project
            modelContext.insert(book)
        } else {
            let chapter = Chapter(
                name: trimmedTitle,
                synopsis: summary.isEmpty ? nil : summary,
                userOrder: nextOrderIndex
            )
            chapter.project = project
            modelContext.insert(chapter)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
