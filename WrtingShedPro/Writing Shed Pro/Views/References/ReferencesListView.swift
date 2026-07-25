//
//  ReferencesListView.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  List view for managing references
//

import SwiftUI
import SwiftData

/// List view for displaying and managing references
struct ReferencesListView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var selectedReference: ReferenceEntry?
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var referenceToDelete: ReferenceEntry?
    @Query private var references: [ReferenceEntry]
    
    // MARK: - Computed Properties
    
    private var filteredReferences: [ReferenceEntry] {
        let projectID: UUID = project.id
        let refs: [ReferenceEntry] = references.filter { (ref: ReferenceEntry) -> Bool in ref.project?.id == projectID }
        
        if searchText.isEmpty {
            return refs.sorted { (a: ReferenceEntry, b: ReferenceEntry) -> Bool in a.author < b.author }
        }
        
        return refs.filter { (reference: ReferenceEntry) -> Bool in
            reference.author.localizedCaseInsensitiveContains(searchText) ||
            reference.publicationDate.localizedCaseInsensitiveContains(searchText) ||
            reference.details.localizedCaseInsensitiveContains(searchText)
        }.sorted { (a: ReferenceEntry, b: ReferenceEntry) -> Bool in a.author < b.author }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if filteredReferences.isEmpty {
                    emptyStateView
                } else {
                    referencesList
                }
            }
            .navigationTitle(NSLocalizedString("references.title", comment: "References"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("button.close", comment: "Close")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        selectedReference = nil
                        showingEditor = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                ReferenceCreatorSheet(project: project, existingReference: selectedReference)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                NSLocalizedString("references.delete.title", comment: "Delete Reference?"),
                isPresented: $showingDeleteConfirmation,
                presenting: referenceToDelete
            ) { reference in
                Button(NSLocalizedString("references.delete.button", comment: "Delete"), role: .destructive) {
                    deleteReference(reference)
                }
            } message: { reference in
                Text(NSLocalizedString(
                    "references.delete.message",
                    comment: "Are you sure? This cannot be undone."
                ))
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("references.empty.title", comment: "No References"))
                .font(.headline)
            
            Text(NSLocalizedString(
                "references.empty.message",
                comment: "Add your first reference to get started."
            ))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            
            Button(action: {
                selectedReference = nil
                showingEditor = true
            }) {
                Label(
                    NSLocalizedString("references.empty.button", comment: "Add Reference"),
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding()
    }
    
    // MARK: - References List
    
    private var referencesList: some View {
        List {
            Section {
                SearchableTextField(
                    placeholder: NSLocalizedString("references.search.placeholder", comment: "Search references..."),
                    text: $searchText
                )
            }
            
            ForEach(filteredReferences) { reference in
                referenceRow(for: reference)
                    .onTapGesture {
                        selectedReference = reference
                        showingEditor = true
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Reference Row
    
    @ViewBuilder
    private func referenceRow(for reference: ReferenceEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(reference.author), \(reference.publicationDate)")
                        .font(.headline)
                        .lineLimit(2)
                    
                    if !reference.details.isEmpty {
                        Text(reference.details)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption)
                        Text("\(reference.referenceCount)")
                            .font(.caption)
                    }
                    .foregroundColor(reference.referenceCount == 0 ? .orange : .secondary)
                    
                    Menu {
                        Button(NSLocalizedString("references.menu.edit", comment: "Edit"), action: {
                            selectedReference = reference
                            showingEditor = true
                        })
                        
                        Button(
                            NSLocalizedString("references.menu.delete", comment: "Delete"),
                            role: .destructive,
                            action: {
                                referenceToDelete = reference
                                showingDeleteConfirmation = true
                            }
                        )
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                    }
                    .tint(.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func deleteReference(_ reference: ReferenceEntry) {
        guard reference.referenceCount == 0 else {
            // Cannot delete if still referenced
            return
        }
        
        modelContext.delete(reference)
        
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "references-list-save")
            #if DEBUG
            print("📚 Deleted reference: \(reference.author)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error deleting reference: \(error)")
            #endif
        }
    }
}

// MARK: - SearchableTextField Component

/// Simple search field component for the references list
private struct SearchableTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Localization Keys

/*
 Add these to Localizable.strings:
 
 "references.title" = "References";
 "references.search.placeholder" = "Search references...";
 "references.empty.title" = "No References";
 "references.empty.message" = "Add your first reference to get started.";
 "references.empty.button" = "Add Reference";
 "references.delete.title" = "Delete Reference?";
 "references.delete.button" = "Delete";
 "references.delete.message" = "Are you sure? This cannot be undone.";
 "references.menu.edit" = "Edit";
 "references.menu.delete" = "Delete";
 */
