# Phase 2: Publications Management UI - Detailed Tasks

**Start Date:** 9 November 2025  
**Dependencies:** Phase 1 Complete ✅

## Overview

Phase 2 implements the user interface for managing publications (magazines and competitions) with full localization and accessibility support from the start.

## Critical Standards (MANDATORY)

### Localization Requirements
❌ **NEVER** use hard-coded user-facing strings  
✅ **ALWAYS** use `NSLocalizedString` with descriptive keys

```swift
// ❌ WRONG
Text("Publications")

// ✅ CORRECT
Text(NSLocalizedString("publications.title", comment: "Publications screen title"))
```

### Accessibility Requirements
✅ **ALL** interactive elements need accessibility support

```swift
Button(action: { }) {
    Label("Add Publication", systemImage: "plus")
}
.accessibilityLabel(Text(NSLocalizedString("accessibility.add.publication", comment: "Add publication button")))
.accessibilityHint(Text(NSLocalizedString("accessibility.add.publication.hint", comment: "Opens form to create new publication")))
```

### Testing Requirements
- ✅ Test on iOS 16+ simulators (NOT iOS 15)
- ✅ Test with VoiceOver enabled
- ✅ Verify all localized strings display correctly
- ✅ Verify all accessibility labels announce properly

---

## Task 1: Create Localizable.strings File

### 1.1 Create Base Localization File

**File:** `Resources/en.lproj/Localizable.strings`

```strings
/* Publications Management - Phase 2 */

/* Screen Titles */
"publications.title" = "Publications";
"publications.add.title" = "Add Publication";
"publications.edit.title" = "Edit Publication";
"publications.detail.title" = "Publication Details";

/* Form Labels */
"publications.form.name.label" = "Name";
"publications.form.name.placeholder" = "Enter publication name";
"publications.form.type.label" = "Type";
"publications.form.url.label" = "Website (optional)";
"publications.form.url.placeholder" = "https://";
"publications.form.deadline.label" = "Deadline (optional)";
"publications.form.notes.label" = "Notes (optional)";
"publications.form.notes.placeholder" = "Add notes about this publication...";

/* Type Picker */
"publications.type.magazine" = "Magazine";
"publications.type.competition" = "Competition";

/* Buttons */
"publications.button.save" = "Save";
"publications.button.cancel" = "Cancel";
"publications.button.delete" = "Delete";
"publications.button.edit" = "Edit";
"publications.button.add" = "Add Publication";

/* Empty State */
"publications.empty.title" = "No Publications";
"publications.empty.message" = "Add magazines and competitions to track your submissions";

/* Deadline Status */
"publications.deadline.none" = "No deadline";
"publications.deadline.passed" = "Deadline passed";
"publications.deadline.approaching" = "%d days left";
"publications.deadline.future" = "Deadline: %@";

/* Delete Confirmation */
"publications.delete.title" = "Delete Publication?";
"publications.delete.message" = "Are you sure you want to delete \"%@\"? This will also delete all associated submissions.";
"publications.delete.confirm" = "Delete";

/* Validation Errors */
"publications.error.name.empty" = "Publication name cannot be empty";
"publications.error.name.toolong" = "Publication name is too long (max 100 characters)";
"publications.error.url.invalid" = "Please enter a valid URL";

/* Accessibility Labels */
"accessibility.publications.list" = "Publications list";
"accessibility.add.publication" = "Add publication";
"accessibility.add.publication.hint" = "Opens form to create a new publication";
"accessibility.edit.publication" = "Edit publication";
"accessibility.edit.publication.hint" = "Opens form to edit this publication";
"accessibility.delete.publication" = "Delete publication";
"accessibility.delete.publication.hint" = "Removes this publication and all its submissions";
"accessibility.publication.row" = "Publication: %@";
"accessibility.publication.deadline.approaching" = "Deadline approaching: %d days left";
"accessibility.publication.deadline.passed" = "Deadline has passed";
"accessibility.publication.type" = "Type: %@";
"accessibility.deadline.toggle" = "Toggle deadline";
"accessibility.deadline.toggle.hint" = "Enable or disable deadline for this publication";
"accessibility.type.picker" = "Select publication type";

/* Accessibility Hints */
"accessibility.publication.tap.hint" = "Double tap to view details";
"accessibility.save.publication.hint" = "Saves the publication";
"accessibility.cancel.hint" = "Discards changes and returns to previous screen";
```

### 1.2 Add to Project
- Create `en.lproj` folder in `Resources/`
- Add `Localizable.strings` file
- Verify it's included in target

**Acceptance Criteria:**
- ✅ File exists in correct location
- ✅ All Phase 2 strings defined
- ✅ Comments explain context
- ✅ File included in Xcode target

---

## Task 2: Create PublicationsListView

### 2.1 Basic Structure

**File:** `Views/Publications/PublicationsListView.swift`

```swift
import SwiftUI
import SwiftData

struct PublicationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Publication.name) private var publications: [Publication]
    @State private var showingAddSheet = false
    @State private var selectedPublication: Publication?
    
    var body: some View {
        List {
            if publications.isEmpty {
                emptyStateView
            } else {
                ForEach(publications) { publication in
                    PublicationRowView(publication: publication)
                        .onTapGesture {
                            selectedPublication = publication
                        }
                }
                .onDelete(perform: deletePublications)
            }
        }
        .navigationTitle(Text(NSLocalizedString("publications.title", comment: "Publications screen title")))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Label(
                        NSLocalizedString("publications.button.add", comment: "Add publication button"),
                        systemImage: "plus"
                    )
                }
                .accessibilityLabel(Text(NSLocalizedString("accessibility.add.publication", comment: "Add publication button")))
                .accessibilityHint(Text(NSLocalizedString("accessibility.add.publication.hint", comment: "Opens form to create new publication")))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PublicationFormView(project: /* current project */)
        }
        .sheet(item: $selectedPublication) { publication in
            PublicationDetailView(publication: publication)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("accessibility.publications.list", comment: "Publications list")))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("publications.empty.title", comment: "Empty state title"))
                .font(.headline)
            
            Text(NSLocalizedString("publications.empty.message", comment: "Empty state message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func deletePublications(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(publications[index])
        }
    }
}
```

### 2.2 Features
- List of publications with deadline indicators
- Empty state when no publications
- Add button in toolbar
- Swipe to delete
- Tap to view details
- Full localization
- Full accessibility

**Acceptance Criteria:**
- ✅ Displays all publications sorted by name
- ✅ Shows empty state with helpful message
- ✅ Add button opens PublicationFormView
- ✅ Tap opens PublicationDetailView
- ✅ Swipe to delete works
- ✅ All strings localized
- ✅ All interactive elements have accessibility labels
- ✅ VoiceOver announces list correctly

---

## Task 3: Create PublicationRowView

### 3.1 Row Component

**File:** `Views/Publications/PublicationRowView.swift`

```swift
import SwiftUI

struct PublicationRowView: View {
    let publication: Publication
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Text(publication.type?.icon ?? "📄")
                .font(.title2)
                .accessibilityHidden(true) // Announced in label
            
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(publication.name)
                    .font(.headline)
                
                // Type
                if let type = publication.type {
                    Text(type.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Deadline status
                if publication.hasDeadline {
                    deadlineView
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(Text(NSLocalizedString("accessibility.publication.tap.hint", comment: "Tap to view hint")))
    }
    
    private var deadlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: deadlineIcon)
                .font(.caption)
            
            Text(deadlineText)
                .font(.caption)
        }
        .foregroundStyle(deadlineColor)
    }
    
    private var deadlineIcon: String {
        switch publication.deadlineStatus {
        case .passed: return "exclamationmark.triangle.fill"
        case .approaching: return "clock.fill"
        case .future: return "calendar"
        case .none: return ""
        }
    }
    
    private var deadlineText: String {
        guard let days = publication.daysUntilDeadline else {
            return NSLocalizedString("publications.deadline.none", comment: "No deadline")
        }
        
        if publication.isDeadlinePassed {
            return NSLocalizedString("publications.deadline.passed", comment: "Deadline passed")
        }
        
        return String(
            format: NSLocalizedString("publications.deadline.approaching", comment: "Days left format"),
            days
        )
    }
    
    private var deadlineColor: Color {
        switch publication.deadlineStatus {
        case .passed: return .red
        case .approaching: return .orange
        case .future: return .secondary
        case .none: return .secondary
        }
    }
    
    private var accessibilityLabel: Text {
        var label = Text(
            String(format: NSLocalizedString("accessibility.publication.row", comment: "Publication row"), publication.name)
        )
        
        if let type = publication.type {
            label = label + Text(", ") + Text(
                String(format: NSLocalizedString("accessibility.publication.type", comment: "Type label"), type.displayName)
            )
        }
        
        if publication.isDeadlinePassed {
            label = label + Text(", ") + Text(NSLocalizedString("accessibility.publication.deadline.passed", comment: "Deadline passed"))
        } else if publication.isDeadlineApproaching, let days = publication.daysUntilDeadline {
            label = label + Text(", ") + Text(
                String(format: NSLocalizedString("accessibility.publication.deadline.approaching", comment: "Deadline approaching"), days)
            )
        }
        
        return label
    }
}
```

### 3.2 Features
- Publication name and type
- Type icon (📰 or 🏆)
- Deadline indicator with color coding
- Accessible label combining all info
- Visual hierarchy

**Acceptance Criteria:**
- ✅ Shows publication name
- ✅ Shows type icon and name
- ✅ Shows deadline status with appropriate color
- ✅ Red for passed, orange for approaching
- ✅ All strings localized
- ✅ VoiceOver announces complete information
- ✅ Icon hidden from VoiceOver (info in label)

---

## Task 4: Create PublicationFormView

### 4.1 Form Structure

**File:** `Views/Publications/PublicationFormView.swift`

```swift
import SwiftUI
import SwiftData

struct PublicationFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let project: Project
    let publication: Publication? // nil = add, non-nil = edit
    
    @State private var name: String = ""
    @State private var selectedType: PublicationType = .magazine
    @State private var url: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date().addingTimeInterval(86400 * 30) // 30 days default
    @State private var notes: String = ""
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isEditing: Bool { publication != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // Name section
                Section {
                    TextField(
                        NSLocalizedString("publications.form.name.placeholder", comment: "Name placeholder"),
                        text: $name
                    )
                    .accessibilityLabel(Text(NSLocalizedString("publications.form.name.label", comment: "Name label")))
                } header: {
                    Text(NSLocalizedString("publications.form.name.label", comment: "Name label"))
                }
                
                // Type section
                Section {
                    Picker(
                        NSLocalizedString("publications.form.type.label", comment: "Type label"),
                        selection: $selectedType
                    ) {
                        ForEach([PublicationType.magazine, PublicationType.competition], id: \.self) { type in
                            HStack {
                                Text(type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.type.picker", comment: "Type picker")))
                } header: {
                    Text(NSLocalizedString("publications.form.type.label", comment: "Type label"))
                }
                
                // Deadline section
                Section {
                    Toggle(isOn: $hasDeadline) {
                        Text(NSLocalizedString("publications.form.deadline.label", comment: "Deadline label"))
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.deadline.toggle", comment: "Deadline toggle")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.deadline.toggle.hint", comment: "Toggle deadline hint")))
                    
                    if hasDeadline {
                        DatePicker(
                            "",
                            selection: $deadline,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                } header: {
                    Text(NSLocalizedString("publications.form.deadline.label", comment: "Deadline label"))
                }
                
                // URL section
                Section {
                    TextField(
                        NSLocalizedString("publications.form.url.placeholder", comment: "URL placeholder"),
                        text: $url
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .accessibilityLabel(Text(NSLocalizedString("publications.form.url.label", comment: "URL label")))
                } header: {
                    Text(NSLocalizedString("publications.form.url.label", comment: "URL label"))
                }
                
                // Notes section
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .accessibilityLabel(Text(NSLocalizedString("publications.form.notes.label", comment: "Notes label")))
                } header: {
                    Text(NSLocalizedString("publications.form.notes.label", comment: "Notes label"))
                }
            }
            .navigationTitle(Text(NSLocalizedString(
                isEditing ? "publications.edit.title" : "publications.add.title",
                comment: "Form title"
            )))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("publications.button.cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                    .accessibilityHint(Text(NSLocalizedString("accessibility.cancel.hint", comment: "Cancel hint")))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("publications.button.save", comment: "Save button")) {
                        savePublication()
                    }
                    .accessibilityHint(Text(NSLocalizedString("accessibility.save.publication.hint", comment: "Save hint")))
                }
            }
            .alert(
                NSLocalizedString("publications.error.title", comment: "Error title"),
                isPresented: $showingError
            ) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadPublication()
            }
        }
    }
    
    private func loadPublication() {
        guard let publication = publication else { return }
        name = publication.name
        selectedType = publication.type ?? .magazine
        url = publication.url ?? ""
        hasDeadline = publication.hasDeadline
        deadline = publication.deadline ?? Date().addingTimeInterval(86400 * 30)
        notes = publication.notes ?? ""
    }
    
    private func savePublication() {
        // Validate
        guard validateInput() else { return }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let publication = publication {
            // Edit existing
            publication.name = trimmedName
            publication.type = selectedType
            publication.url = trimmedURL.isEmpty ? nil : trimmedURL
            publication.deadline = hasDeadline ? deadline : nil
            publication.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            publication.modifiedDate = Date()
        } else {
            // Create new
            let newPublication = Publication(
                name: trimmedName,
                type: selectedType,
                url: trimmedURL.isEmpty ? nil : trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                deadline: hasDeadline ? deadline : nil,
                project: project
            )
            modelContext.insert(newPublication)
        }
        
        dismiss()
    }
    
    private func validateInput() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name
        if trimmedName.isEmpty {
            errorMessage = NSLocalizedString("publications.error.name.empty", comment: "Empty name error")
            showingError = true
            return false
        }
        
        if trimmedName.count > 100 {
            errorMessage = NSLocalizedString("publications.error.name.toolong", comment: "Name too long error")
            showingError = true
            return false
        }
        
        // Validate URL if provided
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty {
            if let url = URL(string: trimmedURL), url.scheme != nil {
                // Valid URL
            } else {
                errorMessage = NSLocalizedString("publications.error.url.invalid", comment: "Invalid URL error")
                showingError = true
                return false
            }
        }
        
        return true
    }
}
```

### 4.2 Features
- Add/Edit mode with single view
- Name input with validation
- Type picker (Magazine/Competition)
- Optional deadline with toggle
- Optional URL field
- Optional notes field
- Input validation with error messages
- Full localization
- Full accessibility

**Acceptance Criteria:**
- ✅ Works for both add and edit
- ✅ Pre-fills fields when editing
- ✅ Validates name (required, max 100 chars)
- ✅ Validates URL format if provided
- ✅ Shows error alerts for validation failures
- ✅ Saves to SwiftData correctly
- ✅ All strings localized
- ✅ All form fields have accessibility labels
- ✅ VoiceOver can navigate form correctly

---

## Task 5: Create PublicationDetailView

### 5.1 Detail View Structure

**File:** `Views/Publications/PublicationDetailView.swift`

```swift
import SwiftUI
import SwiftData

struct PublicationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var publication: Publication
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Info section
                Section {
                    LabeledContent(NSLocalizedString("publications.form.name.label", comment: "Name")) {
                        Text(publication.name)
                    }
                    
                    LabeledContent(NSLocalizedString("publications.form.type.label", comment: "Type")) {
                        HStack {
                            Text(publication.type?.icon ?? "")
                            Text(publication.type?.displayName ?? "")
                        }
                    }
                    
                    if let url = publication.url {
                        LabeledContent(NSLocalizedString("publications.form.url.label", comment: "URL")) {
                            Link(url, destination: URL(string: url)!)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Deadline section
                if publication.hasDeadline {
                    Section {
                        LabeledContent(NSLocalizedString("publications.form.deadline.label", comment: "Deadline")) {
                            VStack(alignment: .trailing, spacing: 4) {
                                if let deadline = publication.deadline {
                                    Text(deadline, style: .date)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: deadlineIcon)
                                        .font(.caption)
                                    Text(deadlineText)
                                        .font(.caption)
                                }
                                .foregroundStyle(deadlineColor)
                            }
                        }
                    }
                }
                
                // Notes section
                if let notes = publication.notes, !notes.isEmpty {
                    Section {
                        Text(notes)
                    } header: {
                        Text(NSLocalizedString("publications.form.notes.label", comment: "Notes"))
                    }
                }
                
                // Submissions section (placeholder for Phase 3)
                Section {
                    if let submissions = publication.submissions, !submissions.isEmpty {
                        Text("\(submissions.count) submission(s)")
                    } else {
                        Text("No submissions yet")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Submissions")
                }
                
                // Delete section
                Section {
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label(
                            NSLocalizedString("publications.button.delete", comment: "Delete button"),
                            systemImage: "trash"
                        )
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.delete.publication", comment: "Delete publication")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.delete.publication.hint", comment: "Delete hint")))
                }
            }
            .navigationTitle(Text(NSLocalizedString("publications.detail.title", comment: "Detail title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(NSLocalizedString("publications.button.edit", comment: "Edit button")) {
                        showingEditSheet = true
                    }
                    .accessibilityLabel(Text(NSLocalizedString("accessibility.edit.publication", comment: "Edit publication")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility.edit.publication.hint", comment: "Edit hint")))
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                PublicationFormView(project: publication.project!, publication: publication)
            }
            .confirmationDialog(
                String(format: NSLocalizedString("publications.delete.title", comment: "Delete title"), publication.name),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    NSLocalizedString("publications.delete.confirm", comment: "Delete confirm"),
                    role: .destructive
                ) {
                    deletePublication()
                }
            } message: {
                Text(String(format: NSLocalizedString("publications.delete.message", comment: "Delete message"), publication.name))
            }
        }
    }
    
    private var deadlineIcon: String {
        switch publication.deadlineStatus {
        case .passed: return "exclamationmark.triangle.fill"
        case .approaching: return "clock.fill"
        case .future: return "calendar"
        case .none: return ""
        }
    }
    
    private var deadlineText: String {
        guard let days = publication.daysUntilDeadline else { return "" }
        
        if publication.isDeadlinePassed {
            return NSLocalizedString("publications.deadline.passed", comment: "Deadline passed")
        }
        
        return String(
            format: NSLocalizedString("publications.deadline.approaching", comment: "Days left"),
            days
        )
    }
    
    private var deadlineColor: Color {
        switch publication.deadlineStatus {
        case .passed: return .red
        case .approaching: return .orange
        case .future: return .secondary
        case .none: return .secondary
        }
    }
    
    private func deletePublication() {
        modelContext.delete(publication)
        dismiss()
    }
}
```

### 5.2 Features
- Display all publication info
- Edit button in toolbar
- Clickable URL link
- Deadline with status indicator
- Submissions count (placeholder)
- Delete with confirmation
- Full localization
- Full accessibility

**Acceptance Criteria:**
- ✅ Shows all publication details
- ✅ URL is clickable link
- ✅ Deadline shows status with color
- ✅ Edit button opens form
- ✅ Delete shows confirmation dialog
- ✅ Delete removes publication and submissions
- ✅ All strings localized
- ✅ All buttons have accessibility labels
- ✅ VoiceOver reads all information

---

## Task 6: Integration and Navigation

### 6.1 Add to Project Navigation

Update main navigation to include Publications:

```swift
// In main tab/sidebar navigation
NavigationLink(destination: PublicationsListView()) {
    Label("Publications", systemImage: "doc.text.magnifyingglass")
}
.accessibilityLabel(Text(NSLocalizedString("accessibility.publications.navigation", comment: "Publications navigation")))
```

### 6.2 Pass Project Context

Ensure current project is available to PublicationFormView when creating publications.

**Acceptance Criteria:**
- ✅ Publications accessible from main navigation
- ✅ Current project passed correctly
- ✅ Navigation works smoothly
- ✅ Back navigation works

---

## Task 7: Testing

### 7.1 Manual Testing Checklist

**Functionality:**
- [ ] Create publication with all fields
- [ ] Create publication with minimal fields (name + type)
- [ ] Edit existing publication
- [ ] Delete publication
- [ ] Validation errors show correctly
- [ ] Deadline calculations correct
- [ ] Deadline status colors correct
- [ ] Empty state displays when no publications
- [ ] Swipe to delete works

**Localization:**
- [ ] No hard-coded strings visible
- [ ] All UI text uses localized strings
- [ ] Error messages localized
- [ ] Date formats use system locale

**Accessibility:**
- [ ] Enable VoiceOver
- [ ] All buttons announce correctly
- [ ] Form fields announce with labels
- [ ] List announces count
- [ ] Deadline status announced
- [ ] Error alerts announced
- [ ] Navigation works with VoiceOver
- [ ] Gestures work with VoiceOver

### 7.2 Test on Device
- [ ] Test on iOS 16 device/simulator
- [ ] Test on iOS 17 device/simulator
- [ ] Test portrait orientation
- [ ] Test landscape orientation (iPad)
- [ ] Test different text sizes
- [ ] Test light and dark mode

---

## Completion Criteria

Phase 2 is complete when:

✅ All 7 tasks implemented  
✅ All views created with full code  
✅ Localizable.strings file complete  
✅ No hard-coded user-facing strings  
✅ All interactive elements have accessibility  
✅ Manual testing checklist passed  
✅ VoiceOver testing passed  
✅ App builds and runs on iOS 16+  
✅ Code committed with descriptive messages  

---

## Files to Create

1. `Resources/en.lproj/Localizable.strings` - All localized strings
2. `Views/Publications/PublicationsListView.swift` - Main list view
3. `Views/Publications/PublicationRowView.swift` - Row component
4. `Views/Publications/PublicationFormView.swift` - Add/Edit form
5. `Views/Publications/PublicationDetailView.swift` - Detail view

## Estimated Time

- Task 1 (Localization): 30 minutes
- Task 2 (List View): 45 minutes
- Task 3 (Row View): 30 minutes
- Task 4 (Form View): 1 hour
- Task 5 (Detail View): 45 minutes
- Task 6 (Integration): 15 minutes
- Task 7 (Testing): 30 minutes

**Total: ~4 hours**

---

**Next Phase:** Phase 3 - Submissions Management UI
