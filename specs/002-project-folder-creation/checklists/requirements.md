# Requirements Checklist: Folder and File Management

**Phase:** 002  
**Dependencies:** Phase 001 Complete ✅

---

## Prerequisites from Phase 001

- [x] SwiftData models (Project, Folder, File) exist in BaseModels.swift
- [x] CloudKit sync configured
- [x] Validation services (NameValidator, UniquenessChecker) working
- [x] Localization infrastructure (Localizable.strings)
- [x] Test infrastructure (XCTest setup)
- [x] Project CRUD operations complete

---

## Phase 002 Requirements

### Folder Management

#### Folder Creation
- [ ] Add "New Folder" button in project detail view
- [ ] Create `AddFolderSheet.swift` view
- [ ] Validate folder name (non-empty, unique within parent)
- [ ] Insert folder into SwiftData context
- [ ] Display folder in project's folder list
- [ ] Support creating folders within folders (nested)
- [ ] Unit tests for folder validation
- [ ] Integration tests for folder creation

#### Folder Display
- [ ] Create `FolderListView.swift` to show folders and files
- [ ] Display folder icon (SF Symbol: folder.fill)
- [ ] Show folder name and item count (optional)
- [ ] Group folders above files in list
- [ ] Tap folder to navigate into it
- [ ] Breadcrumb or back navigation

#### Folder Operations
- [ ] Create `FolderDetailView.swift` for folder details
- [ ] Rename folder with validation
- [ ] Delete folder with confirmation (cascade delete)
- [ ] Show folder metadata (name, creation date, item count)
- [ ] Return to parent after delete
- [ ] Unit tests for rename/delete
- [ ] Integration tests for folder operations

### File Management

#### File Creation
- [ ] Add "New File" button in folder view
- [ ] Create `AddFileSheet.swift` view
- [ ] Validate file name (non-empty, unique within folder)
- [ ] Insert file into SwiftData context
- [ ] Display file in folder's file list
- [ ] Initialize with empty content
- [ ] Unit tests for file validation
- [ ] Integration tests for file creation

#### File Display
- [ ] Display file icon (SF Symbol: doc.text)
- [ ] Show file name
- [ ] Show file metadata (creation date, content length)
- [ ] Tap file to view details
- [ ] Swipe to delete

#### File Operations
- [ ] Create `FileDetailView.swift` for file details
- [ ] Display file name, metadata
- [ ] Rename file with validation
- [ ] Delete file with confirmation
- [ ] Show content preview (read-only for now)
- [ ] Unit tests for file operations
- [ ] Integration tests for file CRUD

### Navigation

- [ ] Implement hierarchical navigation (NavigationStack)
- [ ] Show current location in navigation bar
- [ ] Back button to parent folder
- [ ] Root level shows project's folders
- [ ] Navigate into folders recursively
- [ ] Handle deep linking (if needed)

### Validation & Business Logic

- [ ] Extend `NameValidator` for folder/file names
- [ ] Extend `UniquenessChecker` for folder/file context
- [ ] Validate folder name uniqueness within parent
- [ ] Validate file name uniqueness within folder
- [ ] Handle edge cases (empty folders, deep nesting)

### Data Persistence

- [ ] Verify Folder model relationships work with SwiftData
- [ ] Verify File model relationships work with SwiftData
- [ ] Test cascade delete (folder → nested folders/files)
- [ ] Test CloudKit sync for folders
- [ ] Test CloudKit sync for files
- [ ] Verify parent-child relationships persist

### Localization

- [ ] Add folder-related strings to Localizable.strings
  - [ ] "New Folder", "Folder Name", "Add Folder"
  - [ ] "Delete Folder", "Delete folder confirmation"
  - [ ] "Folders", "Items"
- [ ] Add file-related strings to Localizable.strings
  - [ ] "New File", "File Name", "Add File"
  - [ ] "Delete File", "Delete file confirmation"
  - [ ] "Files", "Content"
- [ ] Accessibility labels for all new UI elements

### Testing

- [ ] Unit tests: Folder name validation
- [ ] Unit tests: File name validation
- [ ] Unit tests: Folder uniqueness checking
- [ ] Unit tests: File uniqueness checking
- [ ] Integration tests: Create folder in project
- [ ] Integration tests: Create nested folders
- [ ] Integration tests: Create file in folder
- [ ] Integration tests: Rename folder
- [ ] Integration tests: Delete folder (cascade)
- [ ] Integration tests: Rename file
- [ ] Integration tests: Delete file
- [ ] UI tests: Folder navigation flow
- [ ] UI tests: File creation flow

### Polish

- [ ] User-friendly error messages for validation failures
- [ ] Confirmation dialogs for destructive actions
- [ ] Accessibility support (VoiceOver, Dynamic Type)
- [ ] Empty state messages ("No folders yet", "No files yet")
- [ ] Loading states for CloudKit sync
- [ ] Update quickstart.md with new features

---

## Acceptance Criteria

### Must Have (MVP)
- ✅ Create folders within projects
- ✅ Create nested folders (unlimited depth)
- ✅ Create files within folders
- ✅ Rename folders and files
- ✅ Delete folders and files (with confirmation)
- ✅ Navigate folder hierarchy
- ✅ All operations sync via CloudKit
- ✅ All features tested

### Should Have
- ✅ Display item counts in folder list
- ✅ Sort folders/files (alphabetically)
- ✅ Empty state messages
- ✅ Breadcrumb navigation

### Could Have (Future)
- ⏭ Drag and drop to move files
- ⏭ Folder/file search
- ⏭ Bulk operations
- ⏭ File templates

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Deep nesting performance | Medium | Test with 100+ nested levels, add limit if needed |
| CloudKit sync conflicts | High | Use SwiftData's automatic conflict resolution |
| Cascade delete accidents | High | Strong confirmation dialogs, clear messaging |
| Navigation complexity | Medium | Follow iOS HIG, use standard NavigationStack patterns |

---

## Definition of Done

- [ ] All "Must Have" requirements implemented
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Tested on iOS simulator and real device
- [ ] Tested on Mac (MacCatalyst)
- [ ] CloudKit sync verified across devices
- [ ] Code reviewed for maintainability
- [ ] Documentation updated (quickstart.md)
- [ ] No breaking changes to Phase 001 features
- [ ] Localization complete
- [ ] Accessibility verified

---

## Notes

- Reuse existing validation patterns from Phase 001
- Follow existing UI patterns (sheets, forms, lists)
- Maintain consistent navigation flow
- Keep CloudKit compatibility (optional properties, defaults)
