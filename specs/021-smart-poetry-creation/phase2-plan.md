# Phase 2 Implementation Plan: Custom Poetry Form Editor

**Feature**: 021-smart-poetry-creation  
**Phase**: 2  
**Created**: 2026-01-01  
**Status**: Planning

## Overview

This phase adds the ability for users to create, edit, and manage custom poetry forms. It also migrates form storage from bundled JSON to the database for a unified data access pattern.

## Dependencies

- Phase 1 complete ✅
- Existing PoetryForm struct
- Existing PoetryFormService
- Existing PoetryFormPicker views
- CloudKit sync infrastructure

## Implementation Tasks

### Task 1: Create PoetryFormModel (SwiftData @Model)

**Priority**: P0 - Foundation  
**Estimated effort**: 1 hour  
**Files**: `Models/PoetryFormModel.swift` (new)

Create the SwiftData model for storing poetry forms in the database.

```swift
@Model
final class PoetryFormModel {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""  // Store as string, map to PoetryFormCategory
    var lineCount: Int?
    var syllablePatternData: Data?  // JSON-encoded [Int] array
    var rhymeScheme: String?
    var meterPattern: String?
    var formDescription: String = ""  // 'description' is reserved
    var templateContent: String = ""
    var isCustom: Bool = true
    var isPredefined: Bool = false
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Computed property to decode syllablePattern
    var syllablePattern: [Int]? { get/set }
    
    // Convert to PoetryForm struct
    func toPoetryForm() -> PoetryForm
    
    // Create from PoetryForm struct
    static func from(_ form: PoetryForm) -> PoetryFormModel
}
```

**Acceptance criteria**:
- [ ] Model compiles without errors
- [ ] Can encode/decode syllable pattern array
- [ ] Can convert to/from PoetryForm struct
- [ ] CloudKit compatible (optional fields, no unique constraints)

---

### Task 2: Database Migration Service

**Priority**: P0 - Foundation  
**Estimated effort**: 2 hours  
**Files**: `Services/PoetryFormMigrationService.swift` (new)

Create service to seed predefined forms from JSON to database on first launch.

```swift
struct PoetryFormMigrationService {
    /// Check if migration is needed and perform it
    static func migrateIfNeeded(modelContext: ModelContext)
    
    /// Seed all predefined forms from JSON
    static func seedPredefinedForms(modelContext: ModelContext)
    
    /// Check if a specific form exists by ID
    static func formExists(id: UUID, modelContext: ModelContext) -> Bool
    
    /// Reset predefined forms to JSON defaults (for troubleshooting)
    static func resetPredefinedForms(modelContext: ModelContext)
}
```

**Migration logic**:
1. Query database for any PoetryFormModel with isPredefined = true
2. If none exist, load PoetryForms.json and insert all as isPredefined = true, isCustom = false
3. If predefined forms exist, check for any new forms in JSON (by ID) and add missing ones
4. Never modify or delete existing predefined forms (user may have files referencing them)

**Acceptance criteria**:
- [ ] Fresh install seeds all predefined forms
- [ ] Subsequent launches don't duplicate forms
- [ ] New predefined forms in JSON are added on upgrade
- [ ] Migration completes in < 2 seconds

---

### Task 3: Update PoetryFormService for Database

**Priority**: P0 - Foundation  
**Estimated effort**: 2 hours  
**Files**: `Services/PoetryFormService.swift` (modify)

Update the existing service to load forms from database instead of JSON.

**Changes**:
- Add `ModelContext` dependency (or use shared container)
- `loadPredefinedForms()` → queries database instead of JSON
- `loadAllForms()` → returns predefined + custom forms
- `loadCustomForms()` → returns only custom forms
- Add `saveCustomForm(_ form: PoetryForm)` method
- Add `deleteCustomForm(_ form: PoetryForm)` method
- Add `updateCustomForm(_ form: PoetryForm)` method
- Keep JSON fallback for empty database (calls migration)

**Acceptance criteria**:
- [ ] Forms load from database
- [ ] Custom forms can be saved/updated/deleted
- [ ] Predefined forms are read-only (save/delete rejected)
- [ ] Cache invalidation on database changes
- [ ] Fallback to JSON + migration if database empty

---

### Task 4: Form Editor View

**Priority**: P1 - Core Feature  
**Estimated effort**: 3 hours  
**Files**: `Views/Poetry/PoetryFormEditorView.swift` (new)

Create the form editor UI for creating/editing custom forms.

**UI Components**:
- Form name (required, TextField)
- Category picker (Picker with PoetryFormCategory cases)
- Description (TextEditor, multiline)
- Line count (optional, NumberField)
- Syllable pattern (optional, TextField with format hint "5,7,5" or "5-7-5")
- Rhyme scheme (optional, TextField with format hint "ABAB CDCD")
- Meter pattern (optional, TextField with examples dropdown)
- Template content (optional, TextEditor)
- Save/Cancel buttons
- Validation feedback

**Modes**:
- Create new: all fields empty, isCustom = true
- Edit existing: fields pre-populated, only custom forms editable
- View predefined: fields pre-populated, read-only, "Duplicate as Custom" button

**Acceptance criteria**:
- [ ] Can create new form with minimum name + description
- [ ] Validation shows errors for invalid syllable pattern
- [ ] Can edit existing custom form
- [ ] Predefined forms show as read-only
- [ ] "Duplicate as Custom" creates editable copy
- [ ] Save persists to database and refreshes picker

---

### Task 5: Form Management List View

**Priority**: P1 - Core Feature  
**Estimated effort**: 2 hours  
**Files**: `Views/Poetry/PoetryFormManagementView.swift` (new)

Create the list view for managing all poetry forms.

**UI Components**:
- Section: "Predefined Forms" (read-only, expandable/collapsible)
- Section: "Custom Forms" (editable, with swipe-to-delete)
- Each row: form name, category badge, requirements summary
- Tap: opens editor (view mode for predefined, edit mode for custom)
- Add button: opens editor in create mode
- Empty state for custom forms section

**Navigation**:
- Accessible from Poetry project settings
- Accessible from form picker ("Manage Forms" button)

**Acceptance criteria**:
- [ ] Lists all predefined and custom forms
- [ ] Predefined forms cannot be deleted
- [ ] Custom forms can be deleted with confirmation
- [ ] Add button creates new custom form
- [ ] Changes reflect immediately in form picker

---

### Task 6: Update Form Picker

**Priority**: P1 - Core Feature  
**Estimated effort**: 1 hour  
**Files**: `Views/Poetry/PoetryFormPicker.swift` (modify)

Update the existing picker to show custom forms and link to management.

**Changes**:
- Add "Custom" category section showing user's custom forms
- Add "Manage Forms" or gear button linking to management view
- Custom forms sorted by name (or creation date)
- Visual indicator for custom vs predefined (subtle badge or icon)

**Acceptance criteria**:
- [ ] Custom forms appear in picker
- [ ] Can navigate to form management
- [ ] Newly created forms appear without app restart
- [ ] Deleted forms disappear from picker

---

### Task 7: Handle Orphaned Form References

**Priority**: P1 - Core Feature  
**Estimated effort**: 1 hour  
**Files**: `Services/PoetryFormService.swift` (modify)

When a custom form is deleted, handle files that reference it.

**Strategy**:
1. Before delete: query all TextFiles with matching poetryFormId
2. Show confirmation with count of affected files
3. On confirm: update affected files to Free Verse (or null)
4. Delete the form

**Alternative display approach**:
- If form lookup returns nil, display "Unknown Form" with option to reassign
- This is more resilient to sync race conditions

**Acceptance criteria**:
- [ ] Delete confirmation shows affected file count
- [ ] Affected files gracefully handle missing form
- [ ] Form reference panel shows helpful message for unknown forms

---

### Task 8: Integration with File Creation

**Priority**: P2 - Polish  
**Estimated effort**: 1 hour  
**Files**: `Views/Files/AddFileSheet.swift` or equivalent (modify)

Ensure the file creation flow works with database-backed forms.

**Changes**:
- Verify form picker loads from updated service
- Verify selected form ID is saved to TextFile
- Verify template generation works with custom forms

**Acceptance criteria**:
- [ ] Can create file with predefined form
- [ ] Can create file with custom form
- [ ] Template content applies correctly

---

### Task 9: Import/Export (Optional - P3)

**Priority**: P3 - Enhancement  
**Estimated effort**: 2 hours  
**Files**: 
- `Services/PoetryFormImportExportService.swift` (new)
- `Views/Poetry/PoetryFormImportExportView.swift` (new)

Add ability to share custom forms as JSON files.

**Export**:
- Select forms to export (checkboxes)
- Generate JSON array of PoetryForm objects
- Share sheet for saving/sending

**Import**:
- Accept JSON file via document picker or share sheet
- Parse and validate forms
- Handle duplicates (rename, replace, skip)
- Add valid forms to database

**Acceptance criteria**:
- [ ] Can export selected custom forms
- [ ] Exported JSON is valid and re-importable
- [ ] Can import forms from JSON file
- [ ] Duplicate handling works correctly

---

### Task 10: Unit Tests

**Priority**: P1 - Quality  
**Estimated effort**: 2 hours  
**Files**: `WritingShedProTests/PoetryFormTests.swift` (new or extend)

**Test cases**:
- PoetryFormModel encoding/decoding
- Migration service seeds correctly
- Migration is idempotent
- Custom form CRUD operations
- Orphaned reference handling
- Form validation (syllable pattern format)
- Predefined forms are read-only

**Acceptance criteria**:
- [ ] All tests pass
- [ ] Coverage for critical paths

---

## Task Order / Dependencies

```
Task 1 (Model) ──────┬──→ Task 2 (Migration) ──→ Task 3 (Service Update)
                     │                                    │
                     │                                    ▼
                     │                           Task 4 (Editor)
                     │                                    │
                     │                                    ▼
                     └──────────────────────────→ Task 5 (Management)
                                                          │
                                                          ▼
                                                   Task 6 (Picker Update)
                                                          │
                                                          ▼
                                                   Task 7 (Orphans)
                                                          │
                                                          ▼
                                                   Task 8 (Integration)
                                                          │
                                                          ▼
                                                   Task 10 (Tests)
                                                          │
                                                          ▼
                                               Task 9 (Import/Export - Optional)
```

## Estimated Total Effort

| Priority | Tasks | Effort |
|----------|-------|--------|
| P0 | 1, 2, 3 | 5 hours |
| P1 | 4, 5, 6, 7, 10 | 9 hours |
| P2 | 8 | 1 hour |
| P3 | 9 | 2 hours |

**Total P0-P2**: ~15 hours  
**Total with P3**: ~17 hours

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| CloudKit sync conflicts with custom forms | Medium | Medium | Use standard CloudKit conflict resolution; forms have unique IDs |
| Migration corrupts existing data | Low | High | Migration is additive only; never deletes; test thoroughly |
| Syllable pattern validation too strict | Medium | Low | Allow flexible formats (comma, hyphen, space separated) |
| Performance with many custom forms | Low | Low | Forms are small; pagination unlikely needed |

## UI Mockups

### Form Management List
```
┌─────────────────────────────────────┐
│  ← Poetry Forms              + Add  │
├─────────────────────────────────────┤
│ ▼ Predefined Forms (12)             │
│   ├─ Haiku          Japanese  5-7-5 │
│   ├─ Sonnet (Shak.) Metered  14 ln  │
│   └─ ...                            │
├─────────────────────────────────────┤
│ ▼ Custom Forms (3)                  │
│   ├─ Pantoum ←swipe→ [Edit][Delete] │
│   ├─ Terza Rima                     │
│   └─ My Invention                   │
├─────────────────────────────────────┤
│     No custom forms yet.            │
│     Tap + to create one.            │
└─────────────────────────────────────┘
```

### Form Editor
```
┌─────────────────────────────────────┐
│  Cancel    New Form           Save  │
├─────────────────────────────────────┤
│ Name *                              │
│ ┌─────────────────────────────────┐ │
│ │ Pantoum                         │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Category                            │
│ ┌─────────────────────────────────┐ │
│ │ Rhymed                        ▼ │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Description *                       │
│ ┌─────────────────────────────────┐ │
│ │ Malaysian form with repeating   │ │
│ │ lines. Each stanza's 2nd and    │ │
│ │ 4th lines become the next...    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ─── Structure (Optional) ─────────  │
│                                     │
│ Line Count        Syllable Pattern  │
│ ┌──────────┐     ┌────────────────┐ │
│ │          │     │ e.g., 5,7,5    │ │
│ └──────────┘     └────────────────┘ │
│                                     │
│ Rhyme Scheme      Meter             │
│ ┌──────────────┐ ┌────────────────┐ │
│ │ ABAB         │ │                │ │
│ └──────────────┘ └────────────────┘ │
│                                     │
│ Template Content                    │
│ ┌─────────────────────────────────┐ │
│ │ Line 1 (will become line 2...) │ │
│ │ Line 2 (will become line 1...) │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

## Localization Keys Needed

```
poetryForms.management.title = "Poetry Forms"
poetryForms.management.predefined = "Predefined Forms"
poetryForms.management.custom = "Custom Forms"
poetryForms.management.empty = "No custom forms yet.\nTap + to create one."
poetryForms.management.add = "Add Custom Form"

poetryForms.editor.newTitle = "New Form"
poetryForms.editor.editTitle = "Edit Form"
poetryForms.editor.viewTitle = "Form Details"
poetryForms.editor.name = "Name"
poetryForms.editor.nameRequired = "Name is required"
poetryForms.editor.category = "Category"
poetryForms.editor.description = "Description"
poetryForms.editor.descriptionRequired = "Description is required"
poetryForms.editor.structure = "Structure (Optional)"
poetryForms.editor.lineCount = "Line Count"
poetryForms.editor.syllablePattern = "Syllable Pattern"
poetryForms.editor.syllablePatternHint = "e.g., 5,7,5 or 5-7-5"
poetryForms.editor.syllablePatternInvalid = "Use numbers separated by commas or hyphens"
poetryForms.editor.rhymeScheme = "Rhyme Scheme"
poetryForms.editor.rhymeSchemeHint = "e.g., ABAB CDCD"
poetryForms.editor.meterPattern = "Meter"
poetryForms.editor.meterPatternHint = "e.g., iambic pentameter"
poetryForms.editor.templateContent = "Template Content"
poetryForms.editor.duplicateAsCustom = "Duplicate as Custom"
poetryForms.editor.readOnly = "Predefined forms cannot be edited"

poetryForms.delete.title = "Delete Form?"
poetryForms.delete.message = "This will delete "%@". %d file(s) using this form will be changed to Free Verse."
poetryForms.delete.messageNoFiles = "This will delete "%@"."
poetryForms.delete.confirm = "Delete"

poetryForms.picker.manageButton = "Manage Forms"
poetryForms.reference.unknownForm = "Unknown Form"
poetryForms.reference.unknownFormMessage = "This form is no longer available. Tap to select a different form."
```
