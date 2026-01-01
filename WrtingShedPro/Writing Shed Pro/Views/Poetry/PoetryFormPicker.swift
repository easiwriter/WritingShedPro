import SwiftUI

/// A view for selecting a poetry form when creating a new poetry file
/// Groups forms by category and shows form details on selection
struct PoetryFormPicker: View {
    @Binding var selectedForm: PoetryForm?
    @State private var expandedCategories: Set<PoetryFormCategory> = Set(PoetryFormCategory.allCases)
    
    private let service = PoetryFormService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text(NSLocalizedString("poetryForm.selectForm", comment: "Select Poetry Form"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            // Form list grouped by category
            ForEach(service.getCategories(), id: \.self) { category in
                categorySection(category)
            }
            
            // Selected form preview
            if let form = selectedForm {
                selectedFormPreview(form)
            }
        }
    }
    
    // MARK: - Category Section
    
    @ViewBuilder
    private func categorySection(_ category: PoetryFormCategory) -> some View {
        let forms = service.getFormsByCategory()[category] ?? []
        
        if !forms.isEmpty {
            VStack(spacing: 0) {
                // Category header (tappable to expand/collapse)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedCategories.contains(category) {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    }
                } label: {
                    HStack {
                        Text(category.displayName)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                .buttonStyle(.plain)
                
                // Forms in this category
                if expandedCategories.contains(category) {
                    ForEach(forms) { form in
                        formRow(form)
                    }
                }
            }
        }
    }
    
    // MARK: - Form Row
    
    private func formRow(_ form: PoetryForm) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedForm = form
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(form.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(formShortDescription(form))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Show checkmark if selected, or if this is Free Verse and nothing is selected (default)
                if selectedForm?.id == form.id || (selectedForm == nil && form.id == PoetryForm.freeVerseId) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background((selectedForm?.id == form.id || (selectedForm == nil && form.id == PoetryForm.freeVerseId)) ? Color.accentColor.opacity(0.1) : Color.clear)
    }
    
    // MARK: - Selected Form Preview
    
    private func selectedFormPreview(_ form: PoetryForm) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.top, 8)
            
            Text(NSLocalizedString("poetryForm.formDetails", comment: "Form Details"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 6) {
                // Form name
                Text(form.name)
                    .font(.headline)
                
                // Description
                Text(form.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Requirements grid
                if form.hasLineCountRequirement || form.hasSyllableRequirements || form.hasRhymeScheme || form.hasMeterRequirements {
                    Divider()
                        .padding(.vertical, 4)
                    
                    requirementsGrid(form)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Requirements Grid
    
    private func requirementsGrid(_ form: PoetryForm) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lineCount = form.lineCount {
                requirementRow(
                    icon: "text.alignleft",
                    label: NSLocalizedString("poetryForm.lines", comment: "Lines"),
                    value: "\(lineCount)"
                )
            }
            
            if let syllables = form.syllablePattern, !syllables.isEmpty {
                requirementRow(
                    icon: "textformat.abc",
                    label: NSLocalizedString("poetryForm.syllables", comment: "Syllables"),
                    value: syllables.map { String($0) }.joined(separator: "-")
                )
            }
            
            if let rhyme = form.rhymeScheme, !rhyme.isEmpty {
                requirementRow(
                    icon: "text.quote",
                    label: NSLocalizedString("poetryForm.rhyme", comment: "Rhyme"),
                    value: rhyme
                )
            }
            
            if let meter = form.meterPattern, !meter.isEmpty {
                requirementRow(
                    icon: "waveform.path",
                    label: NSLocalizedString("poetryForm.meter", comment: "Meter"),
                    value: meter.capitalized
                )
            }
        }
    }
    
    private func requirementRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Helpers
    
    private func formShortDescription(_ form: PoetryForm) -> String {
        var parts: [String] = []
        
        if let lines = form.lineCount {
            parts.append("\(lines) lines")
        }
        
        if let syllables = form.syllablePattern, !syllables.isEmpty {
            parts.append(syllables.map { String($0) }.joined(separator: "-"))
        }
        
        if let rhyme = form.rhymeScheme, !rhyme.isEmpty {
            parts.append(rhyme)
        }
        
        if parts.isEmpty {
            if form.hasMeterRequirements {
                return form.meterPattern?.capitalized ?? ""
            }
            return NSLocalizedString("poetryForm.noRequirements", comment: "No specific requirements")
        }
        
        return parts.joined(separator: " • ")
    }
}

// MARK: - Compact Picker (for inline use)

/// A more compact version of the poetry form picker for use in sheets
struct PoetryFormPickerCompact: View {
    @Binding var selectedForm: PoetryForm?
    @State private var isExpanded = false  // Start collapsed
    
    private let service = PoetryFormService.shared
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                PoetryFormPicker(selectedForm: $selectedForm)
                    .padding(.top, 8)
            },
            label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("poetryForm.poetryForm", comment: "Poetry Form"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(selectedForm?.name ?? NSLocalizedString("poetryForm.freeVerse", comment: "Free Verse"))
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        )
    }
}

// MARK: - Poetry Form Picker Sheet

/// A sheet view for changing the poetry form of an existing file
struct PoetryFormPickerSheet: View {
    @Bindable var file: TextFile
    @State private var selectedForm: PoetryForm?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Current form info
                    if let currentFormName = file.poetryFormName ?? file.poetryForm?.name {
                        Text(String(format: NSLocalizedString("poetryFormPicker.currentForm", comment: "Current form: %@"), currentFormName))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    PoetryFormPicker(selectedForm: $selectedForm)
                }
                .padding(.vertical)
            }
            .navigationTitle(NSLocalizedString("poetryFormPicker.changeForm", comment: "Change Poetry Form"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("poetryFormPicker.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("poetryFormPicker.save", comment: "Save")) {
                        // Update the file's poetry form
                        if let form = selectedForm {
                            file.setPoetryForm(form)
                        }
                        dismiss()
                    }
                    .disabled(selectedForm == nil)
                }
            }
        }
        .onAppear {
            // Pre-select current form if available
            selectedForm = file.poetryForm
        }
    }
}
