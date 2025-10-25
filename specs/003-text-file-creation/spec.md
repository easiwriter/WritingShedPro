# Specification: Text File Creation & Editing (iOS/MacOS)

**Phase:** 003  
**Status:** In Progress 🚧  
**Dependencies:** [002-project-folder-creation](../002-project-folder-creation/spec.md)

---

## Context & Prerequisites

### Completed in Phase 002 ✅
- Folder structure creation for all project types
- Folder capability service (subfolder-only, file-only, read-only)
- File model with `name` and `content` properties ready for text storage
- AddFileSheet for creating files with validation
- FolderListView with capability-based toolbar buttons

### File-Only Folders (Where Users Can Create Text Files)
From Phase 002, users can manually create files in these folders:
- **BLANK**: Files
- **POETRY/SHORT STORY**: Draft, Research
- **NOVEL/SCRIPT**: Draft, Research, Scenes, Characters, Locations

---

## Overview

Enable text file creation and editing across all file-only folders in all project types. Users can create text files, edit content using a simple TextEditor, and view their files in a list. This phase uses SwiftUI's TextEditor with AttributedString storage as a temporary solution before implementing the Proton editor in future phases.

**Key Design Decisions:**
- Use existing `File` model (no new models needed)
- Store content as `AttributedString` in `File.content`
- Simple TextEditor for now (will be replaced by Proton later)
- Files appear in file list within their parent folder
- Selecting a file opens a simple text editing view

---

## Goals

### Primary Goals
1. **Universal file creation**: Enable text file creation in all file-only folders across all project types
2. **Simple text editing**: Provide basic text editing functionality with TextEditor
3. **Content persistence**: Save text content as AttributedString in the File model
4. **File list display**: Show files in FolderDetailView with file count indicators
5. **Navigation**: Seamless navigation from file list to editor and back
6. **Data integrity**: Maintain existing folder structure and capabilities

### Non-Goals (Future Phases)
- Rich text formatting (Phase 004+ with Proton)
- Version history (Future phase)
- File templates (Future phase)
- Auto-save (Future phase)
- File search (Future phase)
- File import/export (Future phase)
- Collaboration features (Future phase)

---

## User Stories

### Priority 1 (P1) - Text File Creation & Editing

#### US1: Create Text File
**As a** writer  
**I want to** create a new text file in any file-only folder  
**So that** I can start writing content in the appropriate location

**Acceptance Criteria:**
- "+" button appears in file-only folders (Files, Draft, Research, Scenes, Characters, Locations)
- Tapping "+" opens AddFileSheet with name input
- File name validation prevents empty or duplicate names
- Created files appear in the file list immediately
- Files sync to CloudKit automatically

---

#### US2: Edit Text Content
**As a** writer  
**I want to** edit the content of my text files  
**So that** I can write and revise my work

**Acceptance Criteria:**
- Tapping a file in the list opens a text editor view
- TextEditor allows typing and editing content
- Content auto-saves when navigating away
- Text persists across app sessions
- Changes sync to CloudKit

---

#### US3: View File List
**As a** writer  
**I want to** see all files in a folder  
**So that** I can find and select the file I want to edit

**Acceptance Criteria:**
- Files displayed in list within FolderDetailView
- Files show name and last modified date
- File count indicator shows number of files in folder
- Empty state message when folder has no files
- Files sorted by name or date (configurable)

---

## Functional Requirements

### FR1: File Model Usage
- **FR1.1:** Use existing `File` model from Phase 001
- **FR1.2:** Store text content in `File.content` property as String
- **FR1.3:** Maintain `File.name`, `File.parentFolder`, and `File.createdDate` properties
- **FR1.4:** Add `File.modifiedDate` property for tracking last edit time

### FR2: Text Editing Interface
- **FR2.1:** FileEditView displays file name in navigation bar
- **FR2.2:** TextEditor fills main content area for text input
- **FR2.3:** Toolbar provides "Done" button to save and exit
- **FR2.4:** Content saves automatically on "Done" or navigation away
- **FR2.5:** Back button returns to file list

### FR3: File List Display
- **FR3.1:** FolderDetailView shows files in a List
- **FR3.2:** FileRowView displays file name and modified date
- **FR3.3:** Tapping file navigates to FileEditView
- **FR3.4:** Empty state shows "No files yet" message
- **FR3.5:** File count badge appears on folder row

### FR4: File Operations
- **FR4.1:** Create file via AddFileSheet (already implemented)
- **FR4.2:** Edit file content via FileEditView (new)
- **FR4.3:** Delete file via swipe-to-delete in file list (future)
- **FR4.4:** Rename file via context menu (future)

---

## Non-Functional Requirements

### NFR1: Performance
- File list loads instantly (< 100ms for < 1000 files)
- Text editor opens immediately with existing content
- Auto-save completes in background without blocking UI
- CloudKit sync happens asynchronously

### NFR2: Usability
- TextEditor uses system font and text input behaviors
- Keyboard shortcuts work (Cmd+S for save, Cmd+W to close)
- Dynamic Type support for accessibility
- VoiceOver support for all interactive elements

### NFR3: Data Integrity
- Content never lost during editing or navigation
- CloudKit conflicts resolved automatically (last-write-wins)
- Validation prevents duplicate file names within folder
- Proper parent-child relationships maintained

### NFR4: Platform Support
- iOS 18.5+ and macOS 14+ (MacCatalyst)
- Consistent behavior across iPhone, iPad, and Mac
- Adaptive layout for different screen sizes

---

## Technical Design

### Data Model Changes
```swift
// Extend existing File model (BaseModels.swift)
@Model
final class File {
    var id: UUID = UUID()
    var name: String?
    var content: String?           // Store text content here
    var createdDate: Date = Date()
    var modifiedDate: Date = Date() // NEW: Track last edit
    
    var parentFolder: Folder?
    
    init(name: String, content: String = "") {
        self.name = name
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
}
```

### View Structure
```
FolderDetailView
├── List of Files (FileRowView)
│   ├── File name
│   ├── Modified date
│   └── Navigation to FileEditView
└── "+" Button (if folder allows files)

FileEditView
├── Navigation Bar (file name as title)
├── TextEditor (main content area)
└── Toolbar
    └── Done button
```

### Key Components

**FileEditView.swift** (NEW)
- SwiftUI view for editing file content
- Uses TextEditor for text input
- Auto-saves content on Done or navigation
- Updates `modifiedDate` timestamp

**FileRowView.swift** (EXISTING - in FolderListView.swift)
- Already displays files in folder list
- May need modification to show modified date
- Needs NavigationLink to FileEditView

**File Model** (EXISTING)
- Add `modifiedDate` property
- Content stored as String in `content` property

---

## Implementation Plan

### Phase 3.1: Data Model Update
1. Add `modifiedDate: Date` property to File model
2. Update File initializer to set modifiedDate
3. Test SwiftData persistence and CloudKit sync

### Phase 3.2: File Edit View
1. Create FileEditView.swift
2. Implement TextEditor with content binding
3. Add save logic (update content and modifiedDate)
4. Add Done button in toolbar
5. Handle navigation back to file list

### Phase 3.3: File List Integration
1. Update FileRowView to show modified date
2. Add NavigationLink from FileRowView to FileEditView
3. Test navigation flow (folder → file list → editor → back)
4. Verify "+" button only appears in file-only folders

### Phase 3.4: Testing & Polish
1. Test file creation in all file-only folders
2. Test text editing and persistence
3. Verify CloudKit sync
4. Test across iOS and macOS
5. Accessibility testing (VoiceOver, Dynamic Type)

---

## Implementation Notes

1. **Temporary TextEditor**: We're using SwiftUI's TextEditor as a placeholder. This will be replaced with Proton editor in Phase 004+.

2. **AttributedString Storage**: For now, store plain text as String. When Proton is integrated, we'll migrate to proper AttributedString format.

3. **Auto-Save Timing**: Save on "Done" button tap or when view disappears (via `.onDisappear`).

4. **File List Context**: Files appear in the FolderDetailView (same view that shows subfolders). The view already exists from Phase 002.

5. **Read-Only Folders**: The "+" button logic is already implemented via FolderCapabilityService. No changes needed there.

6. **Existing AddFileSheet**: File creation UI already exists and works. We only need to add the editing capability.

---

## Success Metrics

- ✅ Files can be created in all file-only folders (Files, Draft, Research, Scenes, Characters, Locations)
- ✅ TextEditor allows typing and editing content
- ✅ Content persists across app sessions and devices (CloudKit)
- ✅ File list shows files with names and modified dates
- ✅ Navigation flows smoothly: folder → file list → editor → back
- ✅ "+" button appears only in appropriate folders
- ✅ No breaking changes to existing folder/project functionality
- ✅ Consistent behavior on iOS and macOS

---

## Future Enhancements (Post-Phase 003)

### Phase 004: Proton Editor Integration
- Replace TextEditor with Proton rich text editor
- Support formatting (bold, italic, headings, etc.)
- Proper AttributedString storage and rendering

### Phase 005: Advanced Features
- Version history and undo/redo
- File templates
- Auto-save with draft recovery
- File search and filtering
- File rename and delete operations
- File statistics (word count, character count)

### Phase 006: Content Population
- Implement logic to populate read-only folders (All, Ready, Set Aside, Published, Trash, Novel, Script)
- Workflow for moving files between folders
- Status tracking and management

---

## References

- [Phase 002 Specification](../002-project-folder-creation/spec.md)
- [Phase 001 Specification](../001-project-management/spec.md)
- [Existing File Model](/Users/Projects/WritingShedPro/WrtingShedPro/Writing Shed Pro/Models/BaseModels.swift)
- [FolderCapabilityService](/Users/Projects/WritingShedPro/WrtingShedPro/Writing Shed Pro/Services/FolderCapabilityService.swift)

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2025-10-21 | AI Assistant | Initial draft - blank projects only |
| 2.0 | 2025-10-25 | AI Assistant | Complete revamp - all project types, TextEditor, simplified approach |