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
    
    private var isShortFiction: Bool {
        project.fictionClass == .shortFiction
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextOrderIndex: Int {
        let chapters = project.chapters ?? []
        return (chapters.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    private var suggestedTitle: String {
        String(format: isShortFiction 
            ? NSLocalizedString("fiction.story.defaultTitle", comment: "Story X")
            : NSLocalizedString("fiction.chapter.defaultTitle", comment: "Chapter X"), nextOrderIndex + 1)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField(isShortFiction 
                        ? NSLocalizedString("fiction.story.title", comment: "Title")
                        : NSLocalizedString("fiction.chapter.title", comment: "Title"), text: $title)
                        .accessibilityLabel(isShortFiction
                            ? NSLocalizedString("fiction.story.title.accessibility", comment: "Story title")
                            : NSLocalizedString("fiction.chapter.title.accessibility", comment: "Chapter title"))
                } header: {
                    Text(isShortFiction
                        ? NSLocalizedString("fiction.story.section.basic", comment: "Basic Info")
                        : NSLocalizedString("fiction.chapter.section.basic", comment: "Basic Info"))
                } footer: {
                    Text(String(format: isShortFiction
                        ? NSLocalizedString("fiction.story.number", comment: "Story X")
                        : NSLocalizedString("fiction.chapter.number", comment: "Chapter X"), nextOrderIndex + 1))
                }
                
                // Summary
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                        .accessibilityLabel(isShortFiction
                            ? NSLocalizedString("fiction.story.summary.accessibility", comment: "Story summary")
                            : NSLocalizedString("fiction.chapter.summary.accessibility", comment: "Chapter summary"))
                } header: {
                    Text(isShortFiction
                        ? NSLocalizedString("fiction.story.summary", comment: "Summary")
                        : NSLocalizedString("fiction.chapter.summary", comment: "Summary"))
                } footer: {
                    Text(isShortFiction
                        ? NSLocalizedString("fiction.story.summary.footer", comment: "Brief overview of the story")
                        : NSLocalizedString("fiction.chapter.summary.footer", comment: "Brief overview of the chapter"))
                }
            }
            .navigationTitle(isShortFiction
                ? NSLocalizedString("fiction.story.add.title", comment: "Add Story")
                : NSLocalizedString("fiction.chapter.add.title", comment: "Add Chapter"))
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
            errorMessage = isShortFiction
                ? NSLocalizedString("fiction.story.error.titleRequired", comment: "Title required")
                : NSLocalizedString("fiction.chapter.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        let chapter = Chapter(
            name: trimmedTitle,
            synopsis: summary.isEmpty ? nil : summary,
            userOrder: nextOrderIndex
        )
        chapter.project = project
        
        modelContext.insert(chapter)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
