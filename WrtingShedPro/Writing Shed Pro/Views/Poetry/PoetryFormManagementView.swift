//
//  PoetryFormManagementView.swift
//  Writing Shed Pro
//
//  Created by AI Assistant on 2026-01-01.
//  Feature 021 Phase 2: Custom Poetry Form Editor
//

import SwiftUI

/// View for managing all poetry forms (predefined and custom)
/// Allows viewing, creating, editing, and deleting custom forms
struct PoetryFormManagementView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    @State private var predefinedForms: [PoetryForm] = []
    @State private var customForms: [PoetryForm] = []
    @State private var expandedPredefined = true
    @State private var expandedCustom = true
    
    @State private var showingEditor = false
    @State private var editingForm: PoetryForm?
    
    @State private var showingDeleteConfirmation = false
    @State private var formToDelete: PoetryForm?
    @State private var deleteAffectedFilesCount = 0
    
    private let service = PoetryFormService.shared
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Predefined Forms Section
                Section {
                    DisclosureGroup(isExpanded: $expandedPredefined) {
                        ForEach(predefinedForms) { form in
                            formRow(form, isPredefined: true)
                        }
                    } label: {
                        HStack {
                            Text(NSLocalizedString("poetryForms.management.predefined", comment: "Predefined Forms"))
                                .font(.headline)
                            Spacer()
                            Text("\(predefinedForms.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Custom Forms Section
                Section {
                    DisclosureGroup(isExpanded: $expandedCustom) {
                        if customForms.isEmpty {
                            VStack(alignment: .center, spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text(NSLocalizedString("poetryForms.management.empty", comment: "No custom forms yet.\nTap + to create one."))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        } else {
                            ForEach(customForms) { form in
                                formRow(form, isPredefined: false)
                            }
                            .onDelete(perform: deleteCustomForms)
                        }
                    } label: {
                        HStack {
                            Text(NSLocalizedString("poetryForms.management.custom", comment: "Custom Forms"))
                                .font(.headline)
                            Spacer()
                            Text("\(customForms.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("poetryForms.management.title", comment: "Poetry Forms"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingForm = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("poetryForms.management.add", comment: "Add Custom Form"))
                }
            }
            .sheet(isPresented: $showingEditor) {
                PoetryFormEditorView(
                    existingForm: editingForm,
                    onSave: { form in
                        saveForm(form)
                    },
                    onDuplicate: { form in
                        saveForm(form)
                    }
                )
            }
            .confirmationDialog(
                NSLocalizedString("poetryForms.delete.title", comment: "Delete Form?"),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("poetryForms.delete.confirm", comment: "Delete"), role: .destructive) {
                    confirmDelete()
                }
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {
                    formToDelete = nil
                }
            } message: {
                if let form = formToDelete {
                    if deleteAffectedFilesCount > 0 {
                        Text(String(format: NSLocalizedString("poetryForms.delete.message", comment: "Delete message with files"), form.name, deleteAffectedFilesCount))
                    } else {
                        Text(String(format: NSLocalizedString("poetryForms.delete.messageNoFiles", comment: "Delete message no files"), form.name))
                    }
                }
            }
        }
        .onAppear {
            loadForms()
        }
    }
    
    // MARK: - Form Row
    
    private func formRow(_ form: PoetryForm, isPredefined: Bool) -> some View {
        Button {
            editingForm = form
            showingEditor = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(form.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        // Category badge
                        Text(form.category.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(for: form.category).opacity(0.2))
                            .foregroundColor(categoryColor(for: form.category))
                            .cornerRadius(4)
                    }
                    
                    Text(form.requirementsSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isPredefined {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isPredefined {
                Button(role: .destructive) {
                    prepareDelete(form)
                } label: {
                    Label(NSLocalizedString("common.delete", comment: "Delete"), systemImage: "trash")
                }
                
                Button {
                    editingForm = form
                    showingEditor = true
                } label: {
                    Label(NSLocalizedString("common.edit", comment: "Edit"), systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadForms() {
        predefinedForms = service.loadPredefinedForms()
        customForms = service.loadCustomForms()
    }
    
    private func categoryColor(for category: PoetryFormCategory) -> Color {
        switch category {
        case .japanese: return .orange
        case .rhymed: return .purple
        case .metered: return .blue
        case .free: return .green
        case .custom: return .pink
        }
    }
    
    private func saveForm(_ form: PoetryForm) {
        if form.isCustom {
            // Check if this is an update or new form
            if customForms.contains(where: { $0.id == form.id }) {
                _ = service.updateCustomForm(form)
            } else {
                _ = service.saveCustomForm(form)
            }
        }
        loadForms()
    }
    
    private func deleteCustomForms(at offsets: IndexSet) {
        for index in offsets {
            let form = customForms[index]
            prepareDelete(form)
            return // Only delete one at a time to show confirmation
        }
    }
    
    private func prepareDelete(_ form: PoetryForm) {
        formToDelete = form
        deleteAffectedFilesCount = service.countFilesUsingForm(form.id)
        showingDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        guard let form = formToDelete else { return }
        
        // Reassign files to Free Verse before deleting
        if deleteAffectedFilesCount > 0 {
            service.reassignFilesToFreeVerse(fromFormId: form.id)
        }
        
        // Delete the form
        _ = service.deleteCustomForm(form)
        
        formToDelete = nil
        loadForms()
    }
}
