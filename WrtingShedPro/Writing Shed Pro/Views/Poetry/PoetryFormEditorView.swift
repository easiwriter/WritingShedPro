//
//  PoetryFormEditorView.swift
//  Writing Shed Pro
//
//  Created by AI Assistant on 2026-01-01.
//  Feature 021 Phase 2: Custom Poetry Form Editor
//

import SwiftUI

/// View for creating and editing custom poetry forms
/// Supports three modes: create new, edit existing custom, view predefined (read-only)
struct PoetryFormEditorView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The form being edited (nil for create mode)
    let existingForm: PoetryForm?
    
    /// Callback when form is saved
    var onSave: ((PoetryForm) -> Void)?
    
    /// Callback when form is duplicated as custom
    var onDuplicate: ((PoetryForm) -> Void)?
    
    // MARK: - State
    
    @State private var name: String = ""
    @State private var category: PoetryFormCategory = .custom
    @State private var formDescription: String = ""
    @State private var lineCountText: String = ""
    @State private var syllablePatternText: String = ""
    @State private var rhymeScheme: String = ""
    @State private var meterPattern: String = ""
    @State private var templateContent: String = ""
    
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    
    // MARK: - Computed Properties
    
    private var isEditMode: Bool {
        existingForm != nil && existingForm?.isCustom == true
    }
    
    private var isViewMode: Bool {
        existingForm != nil && existingForm?.isCustom == false
    }
    
    private var isCreateMode: Bool {
        existingForm == nil
    }
    
    private var navigationTitle: String {
        if isCreateMode {
            return NSLocalizedString("poetryForms.editor.newTitle", comment: "New Form")
        } else if isEditMode {
            return NSLocalizedString("poetryForms.editor.editTitle", comment: "Edit Form")
        } else {
            return NSLocalizedString("poetryForms.editor.viewTitle", comment: "Form Details")
        }
    }
    
    private var lineCount: Int? {
        Int(lineCountText.trimmingCharacters(in: .whitespaces))
    }
    
    private var syllablePattern: [Int]? {
        parseSyllablePattern(syllablePatternText)
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !formDescription.trimmingCharacters(in: .whitespaces).isEmpty &&
        (syllablePatternText.isEmpty || syllablePattern != nil)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                Section {
                    TextField(NSLocalizedString("poetryForms.editor.name", comment: "Name"), text: $name)
                        .disabled(isViewMode)
                    
                    Picker(NSLocalizedString("poetryForms.editor.category", comment: "Category"), selection: $category) {
                        ForEach(PoetryFormCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .disabled(isViewMode)
                }
                
                Section {
                    TextEditor(text: $formDescription)
                        .frame(minHeight: 80)
                        .disabled(isViewMode)
                } header: {
                    Text(NSLocalizedString("poetryForms.editor.description", comment: "Description"))
                } footer: {
                    if formDescription.trimmingCharacters(in: .whitespaces).isEmpty && !isViewMode {
                        Text(NSLocalizedString("poetryForms.editor.descriptionRequired", comment: "Description is required"))
                            .foregroundColor(.red)
                    }
                }
                
                // Structure Section (Optional)
                Section {
                    HStack {
                        Text(NSLocalizedString("poetryForms.editor.lineCount", comment: "Line Count"))
                        Spacer()
                        TextField("", text: $lineCountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .disabled(isViewMode)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("poetryForms.editor.syllablePattern", comment: "Syllable Pattern"))
                            Spacer()
                            TextField(NSLocalizedString("poetryForms.editor.syllablePatternHint", comment: "e.g., 5,7,5 or 5-7-5"), text: $syllablePatternText)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .disabled(isViewMode)
                        }
                        
                        if !syllablePatternText.isEmpty && syllablePattern == nil {
                            Text(NSLocalizedString("poetryForms.editor.syllablePatternInvalid", comment: "Use numbers separated by commas or hyphens"))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text(NSLocalizedString("poetryForms.editor.rhymeScheme", comment: "Rhyme Scheme"))
                        Spacer()
                        TextField(NSLocalizedString("poetryForms.editor.rhymeSchemeHint", comment: "e.g., ABAB CDCD"), text: $rhymeScheme)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150)
                            .disabled(isViewMode)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("poetryForms.editor.meterPattern", comment: "Meter"))
                        Spacer()
                        TextField(NSLocalizedString("poetryForms.editor.meterPatternHint", comment: "e.g., iambic pentameter"), text: $meterPattern)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 180)
                            .disabled(isViewMode)
                    }
                } header: {
                    Text(NSLocalizedString("poetryForms.editor.structure", comment: "Structure (Optional)"))
                }
                
                // Template Content Section
                Section {
                    TextEditor(text: $templateContent)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                        .disabled(isViewMode)
                } header: {
                    Text(NSLocalizedString("poetryForms.editor.templateContent", comment: "Template Content"))
                } footer: {
                    Text("Optional starting content for new files using this form.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Read-only message for predefined forms
                if isViewMode {
                    Section {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("poetryForms.editor.readOnly", comment: "Predefined forms cannot be edited"))
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            duplicateAsCustom()
                        } label: {
                            Label(NSLocalizedString("poetryForms.editor.duplicateAsCustom", comment: "Duplicate as Custom"), systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                if !isViewMode {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("common.save", comment: "Save")) {
                            saveForm()
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .alert(NSLocalizedString("common.error", comment: "Error"), isPresented: $showingValidationError) {
                Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {}
            } message: {
                Text(validationErrorMessage)
            }
        }
        .onAppear {
            loadExistingForm()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadExistingForm() {
        guard let form = existingForm else { return }
        
        name = form.name
        category = form.category
        formDescription = form.description
        lineCountText = form.lineCount.map { String($0) } ?? ""
        syllablePatternText = form.syllablePattern?.map { String($0) }.joined(separator: ", ") ?? ""
        rhymeScheme = form.rhymeScheme ?? ""
        meterPattern = form.meterPattern ?? ""
        templateContent = form.templateContent
    }
    
    private func parseSyllablePattern(_ text: String) -> [Int]? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        // Support comma, hyphen, or space separation
        let separators = CharacterSet(charactersIn: ",-").union(.whitespaces)
        let parts = trimmed.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var result: [Int] = []
        for part in parts {
            if let num = Int(part), num > 0 {
                result.append(num)
            } else {
                return nil // Invalid format
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    private func saveForm() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            validationErrorMessage = NSLocalizedString("poetryForms.editor.nameRequired", comment: "Name is required")
            showingValidationError = true
            return
        }
        
        let trimmedDescription = formDescription.trimmingCharacters(in: .whitespaces)
        guard !trimmedDescription.isEmpty else {
            validationErrorMessage = NSLocalizedString("poetryForms.editor.descriptionRequired", comment: "Description is required")
            showingValidationError = true
            return
        }
        
        // Validate syllable pattern if provided
        if !syllablePatternText.isEmpty && syllablePattern == nil {
            validationErrorMessage = NSLocalizedString("poetryForms.editor.syllablePatternInvalid", comment: "Invalid syllable pattern")
            showingValidationError = true
            return
        }
        
        let form = PoetryForm(
            id: existingForm?.id ?? UUID(),
            name: trimmedName,
            category: category,
            lineCount: lineCount,
            syllablePattern: syllablePattern,
            rhymeScheme: rhymeScheme.isEmpty ? nil : rhymeScheme,
            meterPattern: meterPattern.isEmpty ? nil : meterPattern,
            description: trimmedDescription,
            templateContent: templateContent,
            isCustom: true
        )
        
        onSave?(form)
        dismiss()
    }
    
    private func duplicateAsCustom() {
        guard let original = existingForm else { return }
        
        let duplicate = PoetryForm(
            id: UUID(),
            name: "\(original.name) (Copy)",
            category: original.category,
            lineCount: original.lineCount,
            syllablePattern: original.syllablePattern,
            rhymeScheme: original.rhymeScheme,
            meterPattern: original.meterPattern,
            description: original.description,
            templateContent: original.templateContent,
            isCustom: true
        )
        
        onDuplicate?(duplicate)
        dismiss()
    }
}
