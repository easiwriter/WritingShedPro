# Implementation Plan

## Phase 1: Data Model Implementation
- [ ] Create `TextFile` model in `BaseModels.swift`
- [ ] Create `Version` model in `BaseModels.swift`
- [ ] Update `Folder` model to include `textFiles` relationship
- [ ] Implement version management methods on `TextFile`
- [ ] Test data model with sample versioned data
- [ ] Verify CloudKit sync functionality for both models

## Phase 2: UI Components
- [ ] Create `AddTextFileSheet` view for file creation
- [ ] Create `TextFileEditorView` for editing content
- [ ] Create `VersionNavigationView` for version management
- [ ] Create `TextFileRowView` for file list display
- [ ] Update `FolderDetailView` to show text files

## Phase 3: Integration
- [ ] Add text file creation button to folder views
- [ ] Implement file deletion functionality (cascade to versions)
- [ ] Add file rename capability
- [ ] Implement version creation and navigation
- [ ] Add version comments/annotations
- [ ] Test complete user workflow with versioning

## Phase 4: Polish
- [ ] Add file and version validation and error handling
- [ ] Implement auto-save functionality with smart versioning
- [ ] Add loading states and progress indicators
- [ ] Implement version comparison UI (basic)
- [ ] Write comprehensive unit tests for versioning
- [ ] Add version management UI (delete old versions, etc.)

## Timeline Estimate
- Phase 1: 3-4 hours (extended for dual model complexity)
- Phase 2: 6-7 hours (additional version navigation UI)
- Phase 3: 4-5 hours (version management integration)
- Phase 4: 3-4 hours (version-aware testing and polish)
- **Total**: 16-20 hours

## Risk Mitigation
- Start with Phase 1 to validate data model approach
- Test CloudKit sync early to catch integration issues
- Keep UI simple initially, enhance later
- Maintain existing functionality throughout development