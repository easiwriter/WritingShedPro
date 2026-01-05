//
//  AddChapterSheet.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation - Add chapter form (Novel only)
//

import SwiftUI
import SwiftData

/// Sheet for adding a new chapter to a Novel fiction project
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
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var nextOrderIndex: Int {
        let chapters = project.chapters ?? []
        return (chapters.map { $0.userOrder ?? 0 }.max() ?? -1) + 1
    }
    
    private var suggestedTitle: String {
        String(format: NSLocalizedString("fiction.chapter.defaultTitle", comment: "Chapter X"), nextOrderIndex + 1)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField(NSLocalizedString("fiction.chapter.title", comment: "Title"), text: $title)
                        .accessibilityLabel(NSLocalizedString("fiction.chapter.title.accessibility", comment: "Chapter title"))
                } header: {
                    Text(NSLocalizedString("fiction.chapter.section.basic", comment: "Basic Info"))
                } footer: {
                    Text(String(format: NSLocalizedString("fiction.chapter.number", comment: "Chapter X"), nextOrderIndex + 1))
                }
                
                // Summary
                Section {
                    TextEditor(text: $summary)
                        .frame(minHeight: 80)
                        .accessibilityLabel(NSLocalizedString("fiction.chapter.summary.accessibility", comment: "Chapter summary"))
                } header: {
                    Text(NSLocalizedString("fiction.chapter.summary", comment: "Summary"))
                } footer: {
                    Text(NSLocalizedString("fiction.chapter.summary.footer", comment: "Brief overview of the chapter"))
                }
            }
            .navigationTitle(NSLocalizedString("fiction.chapter.add.title", comment: "Add Chapter"))
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
    }
    
    // MARK: - Actions
    
    private func addChapter() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = NSLocalizedString("fiction.chapter.error.titleRequired", comment: "Title required")
            showErrorAlert = true
            return
        }
        
        let chapter = FictionChapter(
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
