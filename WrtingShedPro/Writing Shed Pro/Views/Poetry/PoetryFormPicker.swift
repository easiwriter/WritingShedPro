import SwiftUI

/// A view for selecting a poetry form when creating a new poetry file
/// Groups forms by category and shows form details on selection
struct PoetryFormPicker: View {
    @Binding var selectedForm: PoetryForm?
    @State private var expandedCategories: Set<PoetryFormCategory> = Set(PoetryFormCategory.allCases)
    @State private var showingManagement = false
    @State private var showingFormEditor = false
    @State private var formsByCategory: [PoetryFormCategory: [PoetryForm]] = [:]
    @State private var categories: [PoetryFormCategory] = []
    @State private var showingDeleteConfirmation = false
    @State private var formToDelete: PoetryForm?
    @State private var deleteAffectedFilesCount = 0
    
    private let service = PoetryFormService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with Manage button
            HStack {
                Text(NSLocalizedString("poetryForm.selectForm", comment: "Select Poetry Form"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showingManagement = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption)
                        Text(NSLocalizedString("poetryForms.picker.manageButton", comment: "Manage Forms"))
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Form list grouped by category
            ForEach(categories, id: \.self) { category in
                categorySection(category)
            }
            
            // Selected form preview
            if let form = selectedForm {
                selectedFormPreview(form)
            }
        }
        .onAppear {
            loadForms()
        }
        .sheet(isPresented: $showingManagement) {
            PoetryFormManagementView()
        }
        .onChange(of: showingManagement) { _, isShowing in
            if !isShowing {
                // Clear cache when management sheet closes so forms refresh
                service.clearCache()
                loadForms()
            }
        }
        .sheet(isPresented: $showingFormEditor) {
            PoetryFormEditorView(
                existingForm: nil,
                onSave: { form in
                    _ = service.saveCustomForm(form)
                    service.clearCache()
                    loadForms()
                    selectedForm = form
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
    
    // MARK: - Delete Custom Form
    
    private func prepareDelete(_ form: PoetryForm) {
        formToDelete = form
        deleteAffectedFilesCount = service.countFilesUsingForm(form.id)
        showingDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        guard let form = formToDelete else { return }
        if deleteAffectedFilesCount > 0 {
            service.reassignFilesToFreeVerse(fromFormId: form.id)
        }
        _ = service.deleteCustomForm(form)
        formToDelete = nil
        if selectedForm?.id == form.id {
            selectedForm = nil
        }
        service.clearCache()
        loadForms()
    }
    
    private func loadForms() {
        service.clearCache()  // Clear cache to ensure fresh data
        categories = service.getCategories()
        formsByCategory = service.getFormsByCategory()
    }
    
    // MARK: - Category Section
    
    @ViewBuilder
    private func categorySection(_ category: PoetryFormCategory) -> some View {
        let forms = formsByCategory[category] ?? []
        
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
                        
                        // Show custom badge for custom category
                        if category == .custom {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
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
                    
                    // Show "Create Custom Form" in custom category
                    if category == .custom {
                        Button {
                            showingFormEditor = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text(NSLocalizedString("poetryForms.picker.createCustom", comment: "Create Custom Form"))
                                    .font(.body)
                                    .foregroundColor(.accentColor)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Form Row
    
    private func formRow(_ form: PoetryForm) -> some View {
        let isFormSelected: Bool = selectedForm?.id == form.id || (selectedForm == nil && form.id == PoetryForm.freeVerseId)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedForm = form
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(form.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        // Show custom badge for user-created forms
                        if form.isCustom {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(formShortDescription(form))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Show checkmark if selected, or if this is Free Verse and nothing is selected (default)
                if isFormSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isFormSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contextMenu {
            if form.isCustom {
                Button(role: .destructive) {
                    prepareDelete(form)
                } label: {
                    Label(NSLocalizedString("common.delete", comment: "Delete"), systemImage: "trash")
                }
            }
        }
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
/// Uses flat list structure to avoid duplication issues
struct PoetryFormPickerCompact: View {
    @Binding var selectedForm: PoetryForm?
    @State private var isExpanded = true  // Start expanded
    @State private var formsByCategory: [PoetryFormCategory: [PoetryForm]] = [:]
    @State private var categories: [PoetryFormCategory] = []
    @State private var showingFormEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var formToDelete: PoetryForm?
    @State private var deleteAffectedFilesCount = 0
    
    private let service = PoetryFormService.shared
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(categories, id: \.self) { category in
                        if let forms = formsByCategory[category], !forms.isEmpty {
                            // Category header
                            Text(category.displayName)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                            
                            // Forms in category
                            ForEach(forms) { form in
                                Button {
                                    selectedForm = form
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(form.name)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            Text(formShortDescription(form))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        let isSelected: Bool = selectedForm?.id == form.id || (selectedForm == nil && form.id == PoetryForm.freeVerseId)
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background({
                                    let isFormSelected: Bool = selectedForm?.id == form.id || (selectedForm == nil && form.id == PoetryForm.freeVerseId)
                                    return isFormSelected ? Color.accentColor.opacity(0.1) : Color.clear
                                }())
                                .contextMenu {
                                    if form.isCustom {
                                        Button(role: .destructive) {
                                            prepareDelete(form)
                                        } label: {
                                            Label(NSLocalizedString("common.delete", comment: "Delete"), systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            
                            // Show "Create Custom Form" button in the custom category
                            if category == .custom {
                                createCustomFormButton
                            }
                        }
                    }
                    
                    // Show "Create Custom Form" button at the end if custom category doesn't exist yet
                    if !categories.contains(.custom) || (formsByCategory[.custom] ?? []).isEmpty {
                        // Custom category header
                        Text(PoetryFormCategory.custom.displayName)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                        
                        createCustomFormButton
                    }
                }
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
        .onAppear {
            loadForms()
        }
        .sheet(isPresented: $showingFormEditor) {
            PoetryFormEditorView(
                existingForm: nil,
                onSave: { form in
                    saveNewCustomForm(form)
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
    
    // MARK: - Create Custom Form Button
    
    private var createCustomFormButton: some View {
        Button {
            showingFormEditor = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("poetryForms.picker.createCustom", comment: "Create Custom Form"))
                    .font(.body)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func saveNewCustomForm(_ form: PoetryForm) {
        _ = service.saveCustomForm(form)
        service.clearCache()
        loadForms()
        selectedForm = form
    }
    
    // MARK: - Delete Custom Form
    
    private func prepareDelete(_ form: PoetryForm) {
        formToDelete = form
        deleteAffectedFilesCount = service.countFilesUsingForm(form.id)
        showingDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        guard let form = formToDelete else { return }
        if deleteAffectedFilesCount > 0 {
            service.reassignFilesToFreeVerse(fromFormId: form.id)
        }
        _ = service.deleteCustomForm(form)
        formToDelete = nil
        if selectedForm?.id == form.id {
            selectedForm = nil
        }
        service.clearCache()
        loadForms()
    }
    
    private func loadForms() {
        service.clearCache()  // Clear cache to ensure fresh data
        categories = service.getCategories()
        formsByCategory = service.getFormsByCategory()
    }
    
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

// MARK: - Poetry Form Picker Sheet

/// A sheet view for changing the poetry form of an existing file
/// Uses a flat List with sections for each category (avoids duplication issues)
struct PoetryFormPickerSheet: View {
    @Bindable var file: TextFile
    @State private var selectedForm: PoetryForm?
    @State private var formsByCategory: [PoetryFormCategory: [PoetryForm]] = [:]
    @State private var categories: [PoetryFormCategory] = []
    @State private var showingFormEditor = false
    @State private var showingFormReference = false
    @State private var showingDeleteConfirmation = false
    @State private var formToDelete: PoetryForm?
    @State private var deleteAffectedFilesCount = 0
    @Environment(\.dismiss) private var dismiss
    
    private let service = PoetryFormService.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Current form info
                if let currentFormName = file.poetryFormName ?? file.poetryForm?.name {
                    Section {
                        Text(String(format: NSLocalizedString("poetryFormPicker.currentForm", comment: "Current form: %@"), currentFormName))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Form categories with forms
                ForEach(categories, id: \.self) { category in
                    if let forms = formsByCategory[category], !forms.isEmpty {
                        Section(header: Text(category.displayName)) {
                            ForEach(forms) { form in
                                formRow(form)
                            }
                            
                            if category == .custom {
                                createCustomFormRow
                            }
                        }
                    }
                }
                
                // Show create button even if no custom forms exist yet
                if !categories.contains(.custom) || (formsByCategory[.custom] ?? []).isEmpty {
                    Section(header: Text(PoetryFormCategory.custom.displayName)) {
                        createCustomFormRow
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("poetryFormPicker.changeForm", comment: "Change Poetry Form"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("poetryFormPicker.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("View") {
                        showingFormReference = true
                    }
                    .disabled(referenceForm == nil)
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
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Load forms first
            loadForms()
            // Pre-select current form if available
            selectedForm = file.poetryForm
        }
        .sheet(isPresented: $showingFormEditor) {
            PoetryFormEditorView(
                existingForm: nil,
                onSave: { form in
                    saveNewCustomForm(form)
                }
            )
        }
        .sheet(isPresented: $showingFormReference) {
            if let form = referenceForm {
                PoetryFormReference(form: form)
            }
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
    
    private func loadForms() {
        service.clearCache()  // Clear cache to ensure fresh data
        categories = service.getCategories()
        formsByCategory = service.getFormsByCategory()
    }
    
    // MARK: - Delete Custom Form
    
    private func prepareDelete(_ form: PoetryForm) {
        formToDelete = form
        deleteAffectedFilesCount = service.countFilesUsingForm(form.id)
        showingDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        guard let form = formToDelete else { return }
        if deleteAffectedFilesCount > 0 {
            service.reassignFilesToFreeVerse(fromFormId: form.id)
        }
        _ = service.deleteCustomForm(form)
        formToDelete = nil
        if selectedForm?.id == form.id {
            selectedForm = nil
        }
        service.clearCache()
        loadForms()
    }
    
    // MARK: - Create Custom Form
    
    private var createCustomFormRow: some View {
        Button {
            showingFormEditor = true
        } label: {
            Label(NSLocalizedString("poetryForms.picker.createCustom", comment: "Create Custom Form"), systemImage: "plus.circle.fill")
                .foregroundColor(.accentColor)
        }
    }
    
    private func saveNewCustomForm(_ form: PoetryForm) {
        _ = service.saveCustomForm(form)
        service.clearCache()
        loadForms()
        selectedForm = form
    }
    
    // MARK: - Form Row
    
    private func formRow(_ form: PoetryForm) -> some View {
        Button {
            selectedForm = form
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(form.name)
                            .foregroundColor(.primary)
                        
                        if form.isCustom {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(formShortDescription(form))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedForm?.id == form.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if form.isCustom {
                Button(role: .destructive) {
                    prepareDelete(form)
                } label: {
                    Label(NSLocalizedString("common.delete", comment: "Delete"), systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - Helper
    
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

    private var referenceForm: PoetryForm? {
        selectedForm ?? file.poetryForm ?? service.getFreeVerse()
    }
}
