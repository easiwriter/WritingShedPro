# Specification: Project Folder Creation (iOS/MacOS)

**Phase:** 002  
**Status:** Completed ✅  
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
    files: [File]?          // Contains files
    folders: [Folder]?      // Contains subfolders (selective nesting)
    parentFolder: Folder?   // Parent folder (for nested structure)
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

Automatically create type-specific folder structures when projects are created. Each project type (BLANK, POETRY, NOVEL, SCRIPT, SHORT STORY) gets a predefined set of folders in a **flat structure** (all folders created at the project root level). After creation, folders have **selective nesting capabilities** that control whether users can add subfolders, files, or both to each folder.

### UI Reference
The folder navigation displays a hierarchical structure organized by category with custom SF Symbols:

![Folder Navigation UI](/Resources/Screenshot%202025-10-21%20at%2013.16.52.jpeg)

**Project Type Folder Mappings (Selective Nesting):**

**Folder Capability Legend:**
All folders are initially created at the project root level (flat structure). The icons indicate what users can ADD to each folder after creation:
- 📁 **Subfolder-only**: Users can add subfolders but NOT files
- 📄 **File-only**: Users can add files but NOT subfolders

---

#### BLANK Project Type
- Files: `globe` 📄
- Trash: `trash` 📄

#### POETRY Project Type  
- All: `globe` 📄
- Draft: `doc.badge.ellipsis` 📄
- Ready: `checkmark.circle` 📄
- Set Aside: `archivebox` 📄
- Published: `book.circle` 📄
- Collections: `books.vertical` 📁
- Submissions: `paperplane` 📁
- Research: `magnifyingglass` 📄
- Magazines: `magazine` 📁
- Competitions: `medal` 📁
- Commissions: `person.2` 📁
- Other: `tray` 📁

- Trash: `trash` 📄

#### SHORT STORY Project Type
- All: `globe` 📄
- Draft: `doc.badge.ellipsis` 📄
- Ready: `checkmark.circle` 📄
- Set Aside: `archivebox` 📄
- Published: `book.circle` 📄
- Collections: `books.vertical` 📁
- Submissions: `paperplane` 📁
- Research: `magnifyingglass` 📄
- Magazines: `magazine` 📁
- Competitions: `medal` 📁
- Commissions: `person.2` 📁
- Other: `tray` 📁

- Trash: `trash` 📄

#### NOVEL Project Type
- Novel: `book.closed.fill` 📄
- Chapters: `document.on.document` 📁
- Scenes: `document.badge.plus` 📄
- Characters: `person.circle` 📄
- Locations: `mountain.2` 📄
- Set Aside: `archivebox` 📄
- Research: `magnifyingglass` 📄
- Competitions: `medal` 📁
- Commissions: `person.2` 📁
- Other: `tray` 📁

- Trash: `trash` 📄

#### SCRIPT Project Type
- Script: `book.closed.fill` 📄
- Acts: `document.on.document` 📁
- Scenes: `document.badge.plus` 
- Characters: `person.circle` 📄
- Locations: `mountain.2` 📄
- Set Aside: `archivebox` 📄
- Research: `magnifyingglass` 📄
- Competitions: `medal` 📁
- Commissions: `person.2` 📁
- Other: `tray` 📁

- Trash: `trash` 📄

**Common UI Elements:**
- **Item Counts**: Show file counts for each folder
- **Navigation**: Tap folder to view files within folder

---

## Goals

### Primary Goals
1. **Automatic folder creation**: When a project is created, automatically generate type-specific folder structures
2. **Project type differentiation**: Each project type (BLANK, POETRY, NOVEL, SCRIPT, SHORT STORY) gets appropriate folders
3. **Flat initial structure with selective nesting capabilities**: All folders are created at the project root level; folders have different capabilities that control what users can add - some allow only subfolders, others only files, and some allow both
4. **SF Symbol integration**: Each folder type has an appropriate SF Symbol icon
5. **CloudKit sync**: All folder structures sync across devices
6. **Folder structure consistency**: Each project type creates a standard set of folders at the project root (flat structure) with selective nesting capabilities enforced after creation:
    - **Subfolder-only folders**: Magazines, Competitions, Commissions, Other, Collections, Submissions, Chapters, Acts (users can only add subfolders, not files)
    - **File-only folders (manual entry)**: Files, Draft, Research, Scenes, Characters, Locations (users can manually add files)
    - **Read-only folders (auto-populated)**: All, Ready, Set Aside, Published, Trash, Novel, Script (content comes from elsewhere, no manual additions)
    - **User-created folders**: Always file-only (can contain files but not subfolders)

### Non-Goals (Future Phases)
- File creation within folders (Phase 003)
- Manual folder creation/editing (Future phase)
- Rich text editing within files (Phase 003)
- Images embedded within files (Future phase)
- File templates or formatting (Future phase)
- Bulk operations (Future phase)
- Search functionality (Future phase)
- Export/import (Future phase)

---

## User Stories

### Priority 1 (P1) - Automatic Folder Creation

#### US1: Project Type Folder Structure
**As a** writer  
**I want to** have appropriate folders created automatically when I create a new project  
**So that** I have an organized structure ready for my writing type

**Acceptance Criteria:**
- BLANK projects create minimal folder structure (Files + Trash)
- POETRY projects create poetry-specific folders (Draft, Ready, Set Aside, etc.)
- NOVEL projects create novel-specific folders (Chapters, Characters, Locations, etc.)
- SCRIPT projects create script-specific folders (Acts, Scenes, Characters, etc.)
- SHORT STORY projects create story-specific folders (similar to poetry structure)
- All folders sync automatically via CloudKit

---

#### US2: Folder Display and Navigation
**As a** writer  
**I want to** see my project folders organized by category with proper icons  
**So that** I can easily understand and navigate my project structure

**Acceptance Criteria:**
- Folders are grouped by sections (e.g., "YOUR POETRY", "PUBLICATIONS", "TRASH")
- Each folder has an appropriate SF Symbol icon
- Folder sections are displayed in logical order
- Tap folder to navigate into folder view
- Navigation shows current project context

---

#### US3: Project Type Consistency
**As a** writer  
**I want to** have consistent folder structures across projects of the same type  
**So that** I can work efficiently across multiple projects

**Acceptance Criteria:**
- All POETRY projects have identical folder structure
- All NOVEL projects have identical folder structure  
- All SCRIPT projects have identical folder structure
- All SHORT STORY projects have identical folder structure
- BLANK projects provide minimal, flexible structure

---

## Functional Requirements

### FR1: Automatic Folder Creation
- **FR1.1:** ProjectTemplateService creates folders when project is created
- **FR1.2:** Each project type has predefined folder structure
- **FR1.3:** Folder names are localized using NSLocalizedString
- **FR1.4:** Folders are created at the project root level (flat structure)
- **FR1.5:** Context is saved explicitly after folder creation

### FR2: Folder Display
- **FR2.1:** FolderListView displays folders sorted by workflow order (Draft, Ready, Set Aside, Published, etc.)
- **FR2.2:** Each folder displays appropriate SF Symbol icon
- **FR2.3:** Folders show file counts and/or subfolder counts for content indication
- **FR2.4:** Navigation allows selection of individual folders to view contents and navigate into subfolders
- **FR2.5:** Empty folders display appropriate empty state messages
- **FR2.6:** Toolbar buttons (Add Folder, Add File) are shown/hidden based on folder capabilities from FolderCapabilityService

### FR3: Project Type Mapping
- **FR3.1:** BLANK: Creates Files, Trash folders only
- **FR3.2:** POETRY: Creates All, Draft, Ready, Set Aside, Published, Collections, Submissions, Research, Magazines, Competitions, Commissions, Other, Trash (in that display order)
- **FR3.3:** NOVEL: Creates Novel, Chapters, Scenes, Characters, Locations, Set Aside, Research, Competitions, Commissions, Other, Trash (in that display order)
- **FR3.4:** SCRIPT: Creates Script, Acts, Scenes, Characters, Locations, Set Aside, Research, Competitions, Commissions, Other, Trash (in that display order)
- **FR3.5:** SHORT STORY: Same as Poetry - All, Draft, Ready, Set Aside, Published, Collections, Submissions, Research, Magazines, Competitions, Commissions, Other, Trash (in that display order)

### FR4: Data Persistence
- **FR4.1:** All folders persist to SwiftData immediately upon creation
- **FR4.2:** CloudKit sync for folder structures
- **FR4.3:** Proper Project-Folder relationships maintained
- **FR4.4:** Folder creation is atomic (all or nothing)

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
- Unit tests for ProjectTemplateService folder creation logic
- Integration tests for project creation with folders
- UI tests for folder display and navigation

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

## Implementation Notes

1. **Folder Creation Timing:** Folders are created immediately when AddProjectSheet calls ProjectTemplateService.createDefaultFolders()

2. **Localization Strategy:** All folder names use NSLocalizedString() keys defined in Localizable.strings

3. **Icon Mapping:** SF Symbols are mapped per project type in FolderItemView based on folder names

4. **Flat Structure with Capability Controls:** All folders are created at the project root level. FolderListView displays folders in workflow order with toolbar buttons dynamically shown/hidden based on FolderCapabilityService:
   - Subfolder-only folders (Magazines, Competitions, Commissions, Other, Collections, Submissions, Chapters, Acts) - show "+" button for adding subfolders
   - File-only folders (Files, Draft, Research, Scenes, Characters, Locations) - show "+" button for adding files
   - Read-only folders (All, Ready, Set Aside, Published, Trash, Novel, Script) - no "+" button (content populated elsewhere)
   - User-created folders always show "+" button for adding files only
   - Location field removed from add dialogs for simplicity

5. **Data Persistence:** Explicit modelContext.save() ensures immediate persistence of folder structures

---

## Success Metrics

- ✅ All 5 project types automatically create appropriate folder structures
- ✅ Folders display with correct SF Symbol icons per specification
- ✅ Folder sections are properly organized and labeled
- ✅ ProjectTemplateService creates localized folder names
- ✅ All folder operations sync across devices via CloudKit
- ✅ FolderListView displays project type-specific folder hierarchies
- ✅ Zero breaking changes to Phase 001 features
- ✅ Comprehensive test coverage for folder creation logic

---

## References

- [Phase 001 Specification](../001-project-management-ios-macos/spec.md)
- [Phase 001 Architecture Plan](../001-project-management-ios-macos/plan.md)
- [Phase 001 Data Model](../001-project-management-ios-macos/data-model.md)
- [Existing BaseModels.swift](/Users/Projects/WritingShedPro/Writing Shed Pro/Models/BaseModels.swift)

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2025-10-21 | AI Assistant | Initial draft, references Phase 001 |
| 1.0 | 2025-10-25 | AI Assistant | Updated to reflect actual implementation - automatic project folder creation only |
