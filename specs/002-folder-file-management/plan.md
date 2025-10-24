# Architecture Plan: Folder and File Management

**Phase:** 002  
**Status:** Planning  
**Dependencies:** Phase 001 Complete ✅

---

## Executive Summary

Phase 002 adds folder and file management capabilities to Writing Shed Pro, building upon the existing Project, Folder, and File SwiftData models from Phase 001. This phase introduces:

1. **Project Template System**: Auto-generate predefined folder structures when creating projects
2. **Folder Management**: Create, rename, delete, and navigate folders
3. **File Management**: Create, rename, delete files within folders
4. **Hierarchical Navigation**: Navigate nested folder structures

All features maintain CloudKit sync compatibility and follow established patterns from Phase 001.

---

## Architecture Overview

### Reused from Phase 001 ✅
- **Models**: Project, Folder, File (BaseModels.swift) - no changes needed
- **Services**: NameValidator, UniquenessChecker - extend for folder/file context
- **UI Patterns**: SwiftUI sheets, forms, confirmation dialogs
- **Navigation**: NavigationStack patterns
- **Persistence**: SwiftData with CloudKit sync
- **Localization**: Localizable.strings approach
- **Testing**: XCTest unit and integration tests

### New Components (Phase 002)

```
Views/
├── FolderListView.swift          # Display folders and files in current location
├── AddFolderSheet.swift          # Create folder form
├── FolderDetailView.swift        # View/edit folder details
├── AddFileSheet.swift            # Create file form
├── FileDetailView.swift          # View/edit file details
└── ProjectDetailView.swift       # UPDATE: Show folder list, trigger template creation

Services/
├── ProjectTemplateService.swift  # NEW: Generate default folder structure
├── NameValidator.swift           # UPDATE: No changes needed (already validates names)
└── UniquenessChecker.swift       # UPDATE: No changes needed (already context-aware)

Resources/
└── Localizable.strings           # UPDATE: Add folder/file UI strings
```

---

## Key Design Decisions

### Decision 1: Project Template System

**Problem**: Each project needs a predefined folder structure based on project type (blank, novel, poetry, script, short story).

**Solution**: `ProjectTemplateService` that auto-generates folders when a project is created.

**Rationale**:
- Provides consistent organization across all projects
- Type-specific structure (e.g., "YOUR POETRY" vs "YOUR NOVEL" vs "BLANK")
- Users can still create custom folders
- Templates generated once at project creation, then fully editable

**Implementation**:
```swift
struct ProjectTemplateService {
    static func createDefaultFolders(for project: Project, in context: ModelContext) {
        let typeFolder = createTypeFolder(for: project, in: context)
        let publicationsFolder = createPublicationsFolder(for: project, in: context)
        let trashFolder = createTrashFolder(for: project, in: context)
    }
}
```

**Template Structure** (from spec Goal #7):
```
Project Root
├── [Type-specific] (e.g., "Your Poetry")
│   ├── All (smart folder - shows all files)
│   ├── Draft
│   ├── Ready
│   ├── Set Aside
│   ├── Published
│   ├── Collections/
│   ├── Submissions/
│   └── Research/
├── Publications/
│   ├── Magazines/
│   ├── Competitions/
│   ├── Commissions/
│   └── Other/
└── Trash/
```

---

### Decision 2: Folder Hierarchy Navigation

**Problem**: Users need to navigate deep folder structures efficiently.

**Solution**: Standard iOS NavigationStack with breadcrumb-style navigation bar.

**Rationale**:
- Familiar iOS pattern
- Back button automatically provided
- Navigation title shows current folder name
- Can display full path in subtitle if needed

**Implementation**:
```swift
NavigationStack {
    FolderListView(folder: currentFolder)
        .navigationTitle(currentFolder.name ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
}
```

---

### Decision 3: Reuse Existing Validation

**Problem**: Need to validate folder and file names.

**Solution**: Existing `NameValidator` and `UniquenessChecker` already handle this.

**Rationale**:
- `NameValidator.validateProjectName()` logic applies to folders/files (non-empty)
- `UniquenessChecker` already checks uniqueness within context (parent folder)
- No new code needed - just call existing methods
- Consistent validation across all entities

**No Changes Required**: Services already work for folder/file validation.

---

### Decision 4: "All" Folder as Smart View

**Problem**: "All" folder in template should show files from multiple folders (Draft, Ready, Set Aside, Published).

**Solution**: Phase 002 treats "All" as a regular folder; Phase 003 can add smart folder logic.

**Rationale**:
- MVP: Create folder structure, users manually organize
- Future: Add `@Query` with predicates to show aggregated view
- Keeps Phase 002 scope manageable
- Template still creates the "All" folder for future use

**For Phase 002**: "All" is an empty folder users can use however they want.

---

### Decision 5: Trash Folder Behavior

**Problem**: Should "Trash" folder implement special delete behavior?

**Solution**: Phase 002 creates "Trash" as a regular folder; special behavior deferred.

**Rationale**:
- MVP: Users can manually move items to Trash folder
- Future: Add "Move to Trash" action that relocates instead of deletes
- Future: Add "Empty Trash" action for permanent deletion
- Keeps Phase 002 scope focused on basic CRUD

**For Phase 002**: "Trash" is a regular folder at project root.

---

## Data Flow

### Create Project with Template
```
User creates project
    ↓
ProjectDetailView calls ProjectTemplateService
    ↓
Service creates folder hierarchy in SwiftData
    ↓
CloudKit syncs folders to other devices
    ↓
User sees pre-populated folder structure
```

### Navigate Folder Hierarchy
```
User taps project → FolderListView (root folders)
    ↓
User taps folder → FolderListView (nested folders/files)
    ↓
User taps file → FileDetailView
    ↓
User edits file name → SwiftData updates → CloudKit syncs
```

### Create Folder
```
User taps "Add Folder" → AddFolderSheet appears
    ↓
User enters name → Validate (NameValidator)
    ↓
Check uniqueness (UniquenessChecker within parent)
    ↓
Create Folder model → Insert into SwiftData
    ↓
CloudKit syncs → Dismiss sheet → List updates
```

---

## UI/UX Design

### Folder List View

**Layout**:
- Grouped list: Folders section, then Files section
- Folder row: 📁 icon + name + chevron
- File row: 📄 icon + name
- Empty states: "No folders yet" / "No files yet"

**Actions**:
- Tap folder → Navigate into it
- Tap file → Open file detail
- Swipe left → Delete (with confirmation)
- "+" button → Add folder or file (context menu)

**Navigation Bar**:
- Title: Current folder name (or "Project Name" if root)
- Back button: Automatic
- Actions: Sort menu, Add button

---

### Add Folder/File Sheets

**Pattern**: Reuse AddProjectSheet pattern from Phase 001

**Form Fields**:
- Name TextField (required, validated)
- Cancel button (left)
- Add button (right, disabled if invalid)

**Validation**:
- Real-time validation on text change
- Alert on submission if duplicate name
- Alert on submission if validation fails

---

### Folder/File Detail Views

**Pattern**: Reuse ProjectDetailView pattern from Phase 001

**Sections**:
- Info: Name (editable), creation date (read-only)
- Actions: Delete button in toolbar

**Folder Detail** (FolderDetailView):
- Shows folder metadata
- Shows item count (# folders + # files)
- Delete with cascade confirmation

**File Detail** (FileDetailView):
- Shows file metadata
- Shows content preview (read-only for Phase 002)
- Edit content deferred to Phase 003

---

## Service Layer

### ProjectTemplateService (NEW)

**Purpose**: Generate default folder structure when project is created.

**Interface**:
```swift
struct ProjectTemplateService {
    /// Creates default folder structure for a project
    static func createDefaultFolders(
        for project: Project,
        in context: ModelContext
    )
    
    /// Returns localized folder name based on project type
    private static func typeSpecificFolderName(
        for type: ProjectType
    ) -> String
}
```

**Implementation Notes**:
- Called once when project is created (in AddProjectSheet.addProject())
- Creates all folders in a single transaction
- Uses existing Folder model
- All folders marked with project relationship
- Top-level folders have `parentFolder = nil`
- Nested folders reference parent via `parentFolder` relationship

**Error Handling**:
- Folder creation failures logged but don't block project creation
- User can manually create folders if template fails

---

### NameValidator (NO CHANGES)

Existing methods work for folders and files:
```swift
// Already exists, works for any entity
NameValidator.validateProjectName(_ name: String) throws
```

Can be called as:
```swift
try NameValidator.validateProjectName(folderName)  // Works for folders
try NameValidator.validateProjectName(fileName)    // Works for files
```

---

### UniquenessChecker (NO CHANGES)

Existing methods already handle folder/file context:
```swift
// Already exists in Phase 001
UniquenessChecker.isFolderNameUnique(_ name: String, in parent: Folder) -> Bool
UniquenessChecker.isFileNameUnique(_ name: String, in folder: Folder) -> Bool
```

---

## Testing Strategy

### Unit Tests

**ProjectTemplateServiceTests.swift**:
- Test template creates correct folder count
- Test type-specific folder names (Blank vs Novel vs Poetry vs Script vs Short Story)
- Test nested folder structure
- Test all folders linked to project

**FolderValidationTests.swift** (extend existing):
- Folder name validation (reuse NameValidator tests)
- Folder uniqueness within parent
- Nested folder validation

**FileValidationTests.swift** (extend existing):
- File name validation (reuse NameValidator tests)
- File uniqueness within folder

---

### Integration Tests

**FolderCRUDIntegrationTests.swift**:
- Create folder in project root
- Create nested folder
- Rename folder
- Delete folder (cascade)
- Navigate folder hierarchy

**FileCRUDIntegrationTests.swift**:
- Create file in folder
- Rename file
- Delete file
- Move file between folders (future)

**ProjectTemplateIntegrationTests.swift**:
- Create project, verify template folders exist
- Verify folder hierarchy structure
- Verify type-specific folder names

---

### UI Tests (Manual/Automated)

- Navigate into/out of folders
- Create folder at various levels
- Create file in folder
- Delete folder with confirmation
- Empty state displays

---

## Localization Strategy

### New Strings Required

**Folder Management**:
```
"folder.new" = "New Folder"
"folder.name" = "Folder Name"
"folder.add" = "Add Folder"
"folder.delete" = "Delete Folder"
"folder.deleteConfirm" = "Are you sure you want to delete \"%@\" and all its contents?"
"folder.folders" = "Folders"
"folder.noFolders" = "No folders yet"
"folder.itemCount" = "%d items"
```

**File Management**:
```
"file.new" = "New File"
"file.name" = "File Name"
"file.add" = "Add File"
"file.delete" = "Delete File"
"file.deleteConfirm" = "Are you sure you want to delete \"%@\"?"
"file.files" = "Files"
"file.noFiles" = "No files yet"
"file.content" = "Content"
```

**Template Folders** (type-specific):
```
"template.yourBlank" = "BLANK"
"template.yourNovel" = "YOUR NOVEL"
"template.yourPoetry" = "YOUR POETRY"
"template.yourScript" = "YOUR SCRIPT"
"template.yourShortStory" = "YOUR STORIES"
"template.all" = "All"
"template.draft" = "Draft"
"template.ready" = "Ready"
"template.setAside" = "Set Aside"
"template.published" = "Published"
"template.collections" = "Collections"
"template.submissions" = "Submissions"
"template.research" = "Research"
"template.publications" = "Publications"
"template.magazines" = "Magazines"
"template.competitions" = "Competitions"
"template.commissions" = "Commissions"
"template.other" = "Other"
"template.trash" = "Trash"
```

---

## Rollout Plan

### Phase 002.1: Foundation (Week 1)
1. Create ProjectTemplateService
2. Update AddProjectSheet to call template service
3. Test template generation
4. Update tests

### Phase 002.2: Folder Management (Week 2)
1. Create FolderListView
2. Create AddFolderSheet
3. Create FolderDetailView
4. Implement folder CRUD
5. Add tests

### Phase 002.3: File Management (Week 3)
1. Create AddFileSheet
2. Create FileDetailView
3. Implement file CRUD
4. Add tests

### Phase 002.4: Polish (Week 4)
1. Add localization strings
2. Add accessibility labels
3. Update documentation
4. Final testing and bug fixes

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Template creation fails | Medium | Log error, allow manual folder creation |
| Deep nesting performance | Low | Test with 100+ levels, add limit if needed |
| CloudKit sync conflicts | Medium | SwiftData auto-resolves, test thoroughly |
| User deletes template folders | Low | Allow it - users have full control |

---

## Success Criteria

- ✅ Project creation auto-generates folder template
- ✅ Users can create custom folders anywhere
- ✅ Users can create files in any folder
- ✅ Navigation works smoothly (no lag)
- ✅ All operations sync via CloudKit
- ✅ Tests pass (100% coverage for new code)
- ✅ No breaking changes to Phase 001

---

## Future Enhancements (Out of Scope)

- Smart folders ("All" aggregates files from multiple folders)
- Move files between folders (drag & drop)
- Trash folder special behavior (move vs delete)
- Folder templates (user-defined)
- Folder color coding
- Folder icons
- Search within folders

---

## References

- [Phase 001 Plan](../001-project-management-ios-macos/plan.md) - Architecture patterns
- [Phase 002 Spec](./spec.md) - Requirements and user stories
- [BaseModels.swift](/Users/Projects/Write/Writing Shed Pro/Writing Shed Pro/Models/BaseModels.swift) - Data models
