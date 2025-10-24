# Specification: Folder and File Management (iOS/MacOS)

**Phase:** 002  
**Status:** Planning  
**Dependencies:** [001-project-management-ios-macos](../001-project-management-ios-macos/spec.md)

---

## Context & Prerequisites

### Completed in Phase 001 ✅
- SwiftData models: `Project`, `Folder`, `File` (already defined)
- CloudKit sync with automatic ModelContainer configuration
- Project CRUD operations (create, read, update, delete)
- SwiftUI navigation and list views
- Localization infrastructure with `Localizable.strings`
- Validation services (`NameValidator`, `UniquenessChecker`)
- Comprehensive test coverage (45+ tests)

### Existing Architecture (Reference)
See: [`001-project-management-ios-macos/plan.md`](../001-project-management-ios-macos/plan.md)

**Key Patterns to Maintain:**
- MVVM with SwiftUI `@Query` for reactive data
- Service-based validation and business logic
- Optional properties for CloudKit compatibility
- `NSLocalizedString()` for all UI text
- LOcalization infrastructure
- TDD with unit and integration tests

### Data Models Already Available
```swift
// From Phase 001 - BaseModels.swift
Project {
    folders: [Folder]?  // Relationship ready
}

Folder {
    name: String?
    folders: [Folder]?      // Nested folders
    parentFolder: Folder?   // Hierarchy support
    files: [File]?          // Contains files
    project: Project?       // Parent project
}

File {
    name: String?
    content: String?        // Ready for text editing
    parentFolder: Folder?   // Belongs to folder
}
```

---

## Overview

Enable users to organize their writing projects using folders and files. Users can create nested folder hierarchies within projects and add files to folders, with all data syncing via CloudKit.

### UI Reference
The folder navigation displays a hierarchical structure organized by category with custom SF Symbols:

![Folder Navigation UI](/Resources/Screenshot%202025-10-21%20at%2013.16.52.jpeg)

**Project Type Display Mappings:**

#### BLANK Project Type
- **Section Header**: "BLANK"
- **Folder Icons**: 
  - All: `globe`
- **Section Header**: "TRASH"
  - Trash: `trash`

#### POETRY Project Type  
- **Section Header**: "YOUR POETRY"
- **Folder Icons**: 
  - All: `globe`
  - Draft: `doc.badge.ellipsis`
  - Ready: `checkmark.circle`
  - Set Aside: `archivebox`
  - Published: `book.circle`
  - Collections: `books.vertical`
  - Submissions: `paperplane`
  - Research: `magnifyingglass`
- **Section Header**: "PUBLICATIONS"
  - Magazines: `magazine`
  - Competitions: `medal`
  - Commissions: `person.2`
  - Other: `tray`
- **Section Header**: "TRASH"
  - Trash: `trash`

#### SHORT STORY Project Type
- **Section Header**: "YOUR STORIES"
- **Folder Icons**: 
  - All: `globe`
  - Draft: `doc.badge.ellipsis`
  - Ready: `checkmark.circle`
  - Set Aside: `archivebox`
  - Published: `book.circle`
  - Collections: `books.vertical`
  - Submissions: `paperplane`
  - Research: `magnifyingglass`
- **Section Header**: "PUBLICATIONS"
  - Magazines: `magazine`
  - Competitions: `medal`
  - Commissions: `person.2`
  - Other: `tray`
- **Section Header**: "TRASH"
  - Trash: `trash`

#### NOVEL Project Type
- **Section Header**: "YOUR NOVEL"
- **Folder Icons**: 
  - Novel: `book.closed.fill`
  - Chapters: `document.on.document`
  - Scenes: `document.badge.plus`
  - Characters: `person.circle`
  - Locations: `mountain.2`
  - Set Aside: `archivebox`
  - Research: `magnifyingglass`
- **Section Header**: "PUBLICATIONS"
  - Competitions: `medal`
  - Commissions: `person.2`
  - Other: `tray`
- **Section Header**: "TRASH"
  - Trash: `trash`

#### SCRIPT Project Type
- **Section Header**: "YOUR SCRIPT"
- **Folder Icons**: 
  - Script: `book.closed.fill`
  - Acts: `document.on.document`
  - Scenes: `document.badge.plus`
  - Characters: `person.circle`
  - Locations: `mountain.2`
  - Set Aside: `archivebox`
  - Research: `magnifyingglass`
- **Section Header**: "PUBLICATIONS"
  - Competitions: `medal`
  - Commissions: `person.2`
  - Other: `tray`
- **Section Header**: "TRASH"
  - Trash: `trash`

**Common UI Elements:**
- **Item Counts**: Show folder and file counts for each folder
- **Navigation**: Tap to drill down into folder hierarchy

---

## Goals

### Primary Goals
1. Allow users to create folders within projects
2. Support nested folder hierarchies (folders within folders)
3. Enable file creation within folders
4. Provide folder and file navigation UI
5. Implement rename and delete for folders and files
6. Maintain CloudKit sync for all operations
7. Creation of each project create a set of top level folders listed and grouped as follows 
    1. Type related e.g Your Poetry
        - All: lists all files from Draft, Ready, Set Aside and Published
        - Draft: for draft files
        - Ready: for files ready for submission
        - Set Aside: for files not being worked on
        - Published: for files that have been published
        - Collections: contains folders that contain files collected prior to submission
        - Submissions: contains collections that have been submitted for publication
        - Research: contains files & folders containing research material.
    1. Publications
        - Magazines: folders named for magazine
        - Competitions: folders named for competitions
        - Commissions; folders name for commissions
        - Other: catch all folders
    1. Trash
        - Trash: folder containing deleted items

### Non-Goals (Future Phases)
- Rich text editing within files (Phase 003)
- Images embedded within files (Phase 3)
- File templates or formatting
- Bulk operations (move multiple items)
- Search functionality
- Export/import

---

## User Stories

### Priority 1 (P1) - Folder Management

#### US1: Create Folder in Project
**As a** writer  
**I want to** create folders within my project  
**So that** I can organize my writing into logical groups

**Acceptance Criteria:**
- Tap "Add Folder" button in project detail view
- Enter folder name (validated, unique within parent)
- Folder appears in project's folder list
- Folder syncs across devices via CloudKit

---

#### US2: Create Nested Folders
**As a** writer  
**I want to** create folders within folders  
**So that** I can create deep hierarchical structures (e.g., Act 1/Scene 1)

**Acceptance Criteria:**
- Tap into a folder to view its contents
- Create new folders within the current folder
- Navigate up/down folder hierarchy
- Breadcrumb or back navigation shows current location

---

#### US3: Rename and Delete Folders
**As a** writer  
**I want to** rename or delete folders  
**So that** I can reorganize my structure as my project evolves

**Acceptance Criteria:**
- Rename folder with validation (non-empty, unique)
- Delete folder with confirmation dialog
- Cascade delete: deleting folder removes all nested folders and files
- UI returns to parent folder after delete

---

### Priority 2 (P2) - File Management

#### US4: Create File in Folder
**As a** writer  
**I want to** create files within folders  
**So that** I can write individual documents (chapters, scenes, poems)

**Acceptance Criteria:**
- Tap "Add File" button in folder view
- Enter file name (validated, unique within folder)
- File appears in folder's file list
- File is created with empty content

---

#### US5: View and Edit File Name
**As a** writer  
**I want to** view file details and rename files  
**So that** I can keep my files organized

**Acceptance Criteria:**
- Tap file to view file detail screen
- Display file name, creation date, content preview
- Rename file with validation
- Delete file with confirmation

---

#### US6: Display Folder/File List
**As a** writer  
**I want to** see all folders and files in the current location  
**So that** I can navigate my project structure

**Acceptance Criteria:**
- Display folders first, then files (grouped)
- Show folder icon, file icon, and names
- Tap folder to navigate into it
- Tap file to view/edit it
- Swipe to delete folders/files

---

## Functional Requirements

### FR1: Folder Operations
- **FR1.1:** Create folder with unique name validation (case-insensitive within parent)
- **FR1.2:** Support unlimited nesting depth
- **FR1.3:** Rename folder (validates uniqueness at same level)
- **FR1.4:** Delete folder (cascade deletes children)
- **FR1.5:** Display folder count (number of items inside)

### FR2: File Operations
- **FR2.1:** Create file with unique name validation (within folder)
- **FR2.2:** Rename file (validates uniqueness within folder)
- **FR2.3:** Delete file with confirmation
- **FR2.4:** Display file metadata (name, creation date, content length)
- **FR2.5:** Empty content field by default

### FR3: Navigation
- **FR3.1:** Breadcrumb or hierarchical navigation
- **FR3.2:** Back button to parent folder
- **FR3.3:** Display current location in navigation bar
- **FR3.4:** Root level shows folders directly in project

### FR4: Data Persistence
- **FR4.1:** All operations persist to SwiftData
- **FR4.2:** CloudKit sync for folders and files
- **FR4.3:** Cascade delete rules enforced
- **FR4.4:** Maintain parent-child relationships

---

## Non-Functional Requirements

### NFR1: Performance
- Folder/file lists load instantly (< 100ms for < 1000 items)
- CloudKit sync happens in background without blocking UI

### NFR2: Usability
- Consistent UI patterns with Phase 001 (sheets, forms, alerts)
- Clear visual distinction between folders and files (SF Symbols)
- Intuitive navigation (standard iOS patterns)

### NFR3: Localization
- All new UI text uses `NSLocalizedString()`
- Support same languages as Phase 001 (initially English)

### NFR4: Accessibility
- All interactive elements have accessibility labels
- VoiceOver support for folder/file navigation
- Dynamic Type support for text

### NFR5: Testing
- Unit tests for folder/file validation
- Integration tests for CRUD operations
- UI tests for navigation flows

---

## Technical Constraints

### TC1: Existing Architecture
- Must use existing `Folder` and `File` models from Phase 001
- No changes to Project model structure
- Maintain CloudKit compatibility (optional properties, defaults)

### TC2: Platform Support
- iOS 18.5+ and macOS 14+ (MacCatalyst)
- Same multiplatform approach as Phase 001

### TC3: Dependencies
- SwiftUI for all UI
- SwiftData for persistence
- CloudKit for sync (automatic via ModelContainer)

---

## Open Questions

1. **Q:** Should we limit folder nesting depth?  
   **A:** TBD - Start with unlimited, monitor performance

2. **Q:** File extensions (e.g., .txt, .md)?  
   **A:** TBD - Defer to Phase 003 (text editing)

3. **Q:** Folder/file sorting options?  
   **A:** Follow Phase 001 pattern (alphabetical, creation date)

4. **Q:** Show item counts in folder list?  
   **A:** Nice-to-have, not MVP

---

## Success Metrics

- ✅ Users can create folders within projects
- ✅ Users can create nested folder hierarchies
- ✅ Users can create files within folders
- ✅ All operations sync across devices
- ✅ 100% test coverage for new features
- ✅ Zero breaking changes to Phase 001 features

---

## References

- [Phase 001 Specification](../001-project-management-ios-macos/spec.md)
- [Phase 001 Architecture Plan](../001-project-management-ios-macos/plan.md)
- [Phase 001 Data Model](../001-project-management-ios-macos/data-model.md)
- [Existing BaseModels.swift](/Users/Projects/Write/Writing Shed Pro/Writing Shed Pro/Models/BaseModels.swift)

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2025-10-21 | AI Assistant | Initial draft, references Phase 001 |
