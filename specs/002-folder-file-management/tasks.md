# Tasks: Folder and File Management (Phase 002)

**Phase:** 002  
**Dependencies:** Phase 001 Complete ✅

---

## Prerequisites Check

- [X] Phase 001 complete and tested
- [X] BaseModels.swift has Folder and File models
- [X] NameValidator and UniquenessChecker services exist
- [X] Test infrastructure in place
- [X] Localization infrastructure in place

---

## Phase 002.1: Project Template System

### Setup & Planning
- [ ] T001 Review Phase 001 architecture and patterns
- [ ] T002 Review BaseModels.swift Folder/File relationships
- [ ] T003 Document template folder structure specification

### Template Service Implementation
- [ ] T004 Create ProjectTemplateService.swift in Services/
- [ ] T005 Implement `createDefaultFolders(for:in:)` method
- [ ] T006 Implement type-specific folder name method (Poetry/Prose/Drama)
- [ ] T007 Add folder creation helper methods (createTypeFolder, createPublicationsFolder, createTrashFolder)
- [ ] T008 Add nested folder creation logic (Collections, Submissions, Research subfolders)

### Template Integration
- [ ] T009 Update AddProjectSheet to call ProjectTemplateService after project creation
- [ ] T010 Handle template creation errors gracefully (log but don't block)
- [ ] T011 Verify template folders appear in project's folder list

### Template Testing
- [ ] T012 Create ProjectTemplateServiceTests.swift
- [ ] T013 Test: Template creates correct number of folders
- [ ] T014 Test: Type-specific folder names (Poetry vs Prose vs Drama)
- [ ] T015 Test: Nested folder structure is correct
- [ ] T016 Test: All folders linked to project
- [ ] T017 Test: Top-level folders have no parent
- [ ] T018 Test: Nested folders have correct parent references
- [ ] T019 Integration test: Create project, verify template exists

---

## Phase 002.2: Folder Management

### Folder List View
- [ ] T020 Create FolderListView.swift in Views/
- [ ] T021 Implement `@Query` to fetch folders for current parent
- [ ] T022 Implement `@Query` to fetch files for current folder
- [ ] T023 Display folders section (grouped) with folder icon
- [ ] T024 Display files section (grouped) with file icon
- [ ] T025 Add empty state messages ("No folders yet", "No files yet")
- [ ] T026 Add navigation on folder tap (navigate to FolderListView for that folder)
- [ ] T027 Add navigation on file tap (navigate to FileDetailView)
- [ ] T028 Add swipe-to-delete for folders and files

### Add Folder Sheet
- [ ] T029 Create AddFolderSheet.swift in Views/
- [ ] T030 Implement form with folder name TextField
- [ ] T031 Add Cancel and Add buttons
- [ ] T032 Implement validation (call NameValidator)
- [ ] T033 Implement uniqueness check (call UniquenessChecker)
- [ ] T034 Show error alert on validation failure
- [ ] T035 Show error alert on duplicate name
- [ ] T036 Create Folder model and insert into ModelContext on success
- [ ] T037 Set parent folder relationship
- [ ] T038 Dismiss sheet after creation

### Folder Detail View
- [ ] T039 Create FolderDetailView.swift in Views/
- [ ] T040 Display folder name (editable TextField with validation)
- [ ] T041 Display creation date (read-only)
- [ ] T042 Display item count (number of folders + files)
- [ ] T043 Add delete button in toolbar
- [ ] T044 Implement delete confirmation dialog
- [ ] T045 Delete folder and dismiss on confirmation
- [ ] T046 Handle validation errors on rename

### Update Project Detail View
- [ ] T047 Update ProjectDetailView to show folder list
- [ ] T048 Add "New Folder" button in ProjectDetailView
- [ ] T049 Show AddFolderSheet when button tapped
- [ ] T050 Navigate to FolderListView when folder tapped

### Folder Testing
- [ ] T051 Unit test: Folder name validation
- [ ] T052 Unit test: Folder uniqueness within parent
- [ ] T053 Integration test: Create folder in project root
- [ ] T054 Integration test: Create nested folder
- [ ] T055 Integration test: Rename folder
- [ ] T056 Integration test: Delete folder (cascade deletes children)
- [ ] T057 Integration test: Navigate folder hierarchy

---

## Phase 002.3: File Management

### Add File Sheet
- [ ] T058 Create AddFileSheet.swift in Views/
- [ ] T059 Implement form with file name TextField
- [ ] T060 Add Cancel and Add buttons
- [ ] T061 Implement validation (call NameValidator)
- [ ] T062 Implement uniqueness check (call UniquenessChecker)
- [ ] T063 Show error alert on validation failure
- [ ] T064 Show error alert on duplicate name
- [ ] T065 Create File model with empty content
- [ ] T066 Set parentFolder relationship
- [ ] T067 Insert into ModelContext and dismiss

### File Detail View
- [ ] T068 Create FileDetailView.swift in Views/
- [ ] T069 Display file name (editable TextField with validation)
- [ ] T070 Display creation date (read-only)
- [ ] T071 Display content length (read-only)
- [ ] T072 Show content preview (read-only, first 500 chars)
- [ ] T073 Add delete button in toolbar
- [ ] T074 Implement delete confirmation dialog
- [ ] T075 Delete file and dismiss on confirmation
- [ ] T076 Handle validation errors on rename

### Update Folder List View
- [ ] T077 Add "New File" button in FolderListView
- [ ] T078 Show AddFileSheet when button tapped
- [ ] T079 Add context menu or split button for "New Folder" / "New File"

### File Testing
- [ ] T080 Unit test: File name validation
- [ ] T081 Unit test: File uniqueness within folder
- [ ] T082 Integration test: Create file in folder
- [ ] T083 Integration test: Rename file
- [ ] T084 Integration test: Delete file
- [ ] T085 Integration test: File appears in folder list

---

## Phase 002.4: Localization

### Add Localization Strings
- [ ] T086 Add folder management strings to Localizable.strings
  - [ ] folder.new, folder.name, folder.add
  - [ ] folder.delete, folder.deleteConfirm
  - [ ] folder.folders, folder.noFolders, folder.itemCount
- [ ] T087 Add file management strings to Localizable.strings
  - [ ] file.new, file.name, file.add
  - [ ] file.delete, file.deleteConfirm
  - [ ] file.files, file.noFiles, file.content
- [ ] T088 Add template folder name strings to Localizable.strings
  - [ ] template.yourPoetry, template.yourProse, template.yourDrama
  - [ ] template.all, template.draft, template.ready, template.setAside
  - [ ] template.published, template.collections, template.submissions
  - [ ] template.research, template.publications, template.magazines
  - [ ] template.competitions, template.commissions, template.other, template.trash
- [ ] T089 Update all folder/file UI to use NSLocalizedString()
- [ ] T090 Add accessibility labels to all new interactive elements

---

## Phase 002.5: Testing & Quality

### Integration Testing
- [ ] T091 Test: Create project, verify template folders created
- [ ] T092 Test: Navigate folder hierarchy (root → nested → file)
- [ ] T093 Test: Create custom folder alongside template folders
- [ ] T094 Test: Delete template folder (allowed, user has control)
- [ ] T095 Test: Rename template folder (allowed)
- [ ] T096 Test: Create file in template folder (Draft, Ready, etc.)
- [ ] T097 Test: CloudKit sync for folders across devices
- [ ] T098 Test: CloudKit sync for files across devices

### Edge Cases
- [ ] T099 Test: Create folder with very long name
- [ ] T100 Test: Create deeply nested folders (20+ levels)
- [ ] T101 Test: Delete folder with many nested items (100+)
- [ ] T102 Test: Empty folder display
- [ ] T103 Test: Folder with only files (no subfolders)
- [ ] T104 Test: Folder with only subfolders (no files)

### Performance Testing
- [ ] T105 Test: Load folder with 1000+ items
- [ ] T106 Test: Navigate deep hierarchy (50+ levels)
- [ ] T107 Test: CloudKit sync with large folder structure

---

## Phase 002.6: Polish & Documentation

### UI/UX Polish
- [ ] T108 Add folder/file sort options (alphabetical, creation date)
- [ ] T109 Verify all confirmation dialogs are clear and descriptive
- [ ] T110 Add loading indicators for CloudKit operations (if needed)
- [ ] T111 Verify empty state messages are helpful
- [ ] T112 Test VoiceOver support for folder/file navigation
- [ ] T113 Test Dynamic Type support (text scaling)

### Error Handling
- [ ] T114 Add user-friendly error messages for all validation failures
- [ ] T115 Handle template creation failures gracefully
- [ ] T116 Handle CloudKit sync errors gracefully
- [ ] T117 Add retry logic for failed operations (if needed)

### Code Quality
- [ ] T118 Code review: Ensure patterns match Phase 001
- [ ] T119 Code review: Check CloudKit compatibility (optional properties)
- [ ] T120 Refactor: Remove any duplicated code
- [ ] T121 Refactor: Ensure service methods are reusable
- [ ] T122 Add code comments for complex logic (especially template generation)

### Documentation
- [ ] T123 Update quickstart.md with folder/file management instructions
- [ ] T124 Document template folder structure in quickstart.md
- [ ] T125 Add screenshots or diagrams of folder hierarchy (optional)
- [ ] T126 Update data-model.md (if created) with Folder/File relationships
- [ ] T127 Create migration guide (if any breaking changes, expect none)

---

## Phase 002.7: Final Verification

### Feature Verification
- [ ] T128 Verify: Project creation generates template folders
- [ ] T129 Verify: Users can create custom folders
- [ ] T130 Verify: Users can create nested folders
- [ ] T131 Verify: Users can create files in folders
- [ ] T132 Verify: Rename folder works with validation
- [ ] T133 Verify: Delete folder cascades to children
- [ ] T134 Verify: Rename file works with validation
- [ ] T135 Verify: Delete file shows confirmation
- [ ] T136 Verify: Navigation works (into/out of folders)
- [ ] T137 Verify: Empty states display correctly
- [ ] T138 Verify: All text is localized
- [ ] T139 Verify: All interactive elements have accessibility labels

### Cross-Device Testing
- [ ] T140 Test: Create folder on iPhone, verify on Mac
- [ ] T141 Test: Create file on Mac, verify on iPhone
- [ ] T142 Test: Delete folder on iPhone, verify deletion on Mac
- [ ] T143 Test: Rename file on Mac, verify on iPhone
- [ ] T144 Test: CloudKit conflict resolution (edit same folder on two devices)

### Regression Testing
- [ ] T145 Verify: Phase 001 project management still works
- [ ] T146 Verify: Create project works
- [ ] T147 Verify: Rename project works
- [ ] T148 Verify: Delete project works (cascades to folders/files)
- [ ] T149 Verify: Project list display works
- [ ] T150 Verify: Project sorting works

---

## Dependencies

### Task Dependencies
- Phase 002.1 (Template) → Phase 002.2 (Folders) → Phase 002.3 (Files) → Phase 002.4+ (Polish)
- Template service must be done before folder management
- Folder management must be done before file management
- Localization can be done in parallel with implementation

### Parallel Execution Opportunities
- T012-T019 (Template tests) can be done in parallel with T020-T028 (Folder UI)
- T086-T090 (Localization) can be done in parallel with implementation
- T108-T113 (Polish) can be done in parallel after core features complete
- T140-T144 (Cross-device testing) can be done in parallel with T145-T150 (Regression)

---

## Definition of Done (Phase 002)

### Must Have ✅
- [X] Project template generates on creation
- [X] Users can create folders in projects
- [X] Users can create nested folders
- [X] Users can create files in folders
- [X] Rename and delete work for folders and files
- [X] Navigation works (into/out of folders)
- [X] All operations sync via CloudKit
- [X] All features tested (unit + integration)
- [X] All text localized
- [X] Accessibility supported
- [X] No breaking changes to Phase 001

### Quality Gates
- [ ] All unit tests passing (100% coverage for new code)
- [ ] All integration tests passing
- [ ] Tested on iOS simulator and real device
- [ ] Tested on Mac (MacCatalyst)
- [ ] CloudKit sync verified across devices
- [ ] VoiceOver tested
- [ ] Dynamic Type tested
- [ ] Code reviewed
- [ ] Documentation updated

---

## Implementation Strategy

### Week 1: Template System (T001-T019)
Focus: Get project template generation working and tested.

### Week 2: Folder Management (T020-T057)
Focus: Complete folder CRUD operations and navigation.

### Week 3: File Management (T058-T085)
Focus: Complete file CRUD operations.

### Week 4: Polish & Testing (T086-T150)
Focus: Localization, accessibility, testing, documentation.

### Risk Mitigation
- Start with template service (foundational)
- Test each component before moving to next
- Verify CloudKit sync early and often
- Keep Phase 001 features regression tested

---

## Notes

- Reuse existing validation services (NameValidator, UniquenessChecker)
- Follow Phase 001 UI patterns (sheets, forms, confirmation dialogs)
- Maintain CloudKit compatibility (optional properties, defaults)
- Keep code consistent with Phase 001 style
- Add tests for every feature before implementation (TDD)
