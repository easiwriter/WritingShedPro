# Feature 029: Manuscript Assembly

**Status**: Not Started  
**Priority**: High  
**Estimated Effort**: TBD  
**Dependencies**: 002-project-folder-creation, 021-smart-poetry-creation, 022-smart-fiction-creation, 023-smart-drama-creation  
**Created**: 2026-01-10  
**Last Updated**: 2026-01-10

## Implementation Status

### Completed
- ✅ Manuscript folder created for all project types

### Not Started
- ⏳ Manuscript view/editor
- ⏳ Content assembly from source folders
- ⏳ Ordering and structure management
- ⏳ Export functionality
- ⏳ Preview mode

## Overview
The purpose of the Manuscript folder is to act as a container for all the contents of the document. In addition to preview there needs to be a print button which could be in the preview screen. The folder contains the following folders:
- front matter
- the body
- back matter

The front matter typically contains some or all of:
- A half-title or title page, sometimes with a verso carrying copyright and publication details.
- A dedication or epigraph, if the work has one.
- A foreword (written by someone other than the author) and/or a preface (written by the author about the work rather than its subject).
- Acknowledgements.
- A table of contents.
- Lists of figures, tables, abbreviations, or symbols, common in academic and technical works.

The back matter typically contains some or all of:
- Appendices or annexes containing material too bulky or tangential for the body.
- Notes or endnotes.
- A bibliography or reference list.
- A glossary.
- An index.
- Colophons or production notes in finely made books.

## Core Concepts

### Manuscript Folder Structure

The Manuscript folder exists in all project types and contains three subfolders:

| Subfolder | Purpose | Typical Contents |
|-----------|---------|------------------|
| **Front Matter** | Introductory material before the main content | Title page, dedication, epigraph, foreword, preface, acknowledgements, table of contents, lists of figures/tables/abbreviations |
| **Body** | The main content of the work | Assembled from source folders (see below) |
| **Back Matter** | Supplementary material after the main content | Appendices, endnotes, bibliography, glossary, index, colophon |

### Body Assembly by Project Type

The Body subfolder assembles content from source folders based on project type:

| Project Type | Source Content | Assembly Logic |
|--------------|----------------|----------------|
| **General Purpose** | Sections folder | User-defined order of files and subfolders |
| **Poetry** | Poems folder | User-defined order of poems, optionally grouped by collection |
| **Fiction (Novel)** | Chapters → Scenes | Chapters in order, scenes within each chapter in order |
| **Fiction (Short)** | Scenes folder | Scenes in user-defined order |
| **Drama** | Acts → Scenes | Acts in order, scenes within each act in order |

### Assembly vs Source

- **Source folders** (Poems, Scenes, Scripts, Sections) contain the individual pieces of content
- **Body subfolder** provides a unified view of the assembled main content
- **Front/Back Matter** subfolders contain standalone files created directly within them
- Changes made in the Manuscript view should reflect back to the source files
- The Body is not a copy but a structured view/compilation

## User Stories

### US1: View Assembled Manuscript (P1)

**As a** writer  
**I want to** view my complete work assembled in the Manuscript folder  
**So that** I can see how all the pieces fit together

**Acceptance Criteria:**
- Tapping the Manuscript folder shows the assembled content
- Content is displayed in the correct order based on project type
- The view is read-only or clearly indicates editing affects source files
- Page breaks or section dividers are shown between pieces

---

### US2: Reorder Manuscript Sections (P1)

**As a** writer  
**I want to** reorder sections within the Manuscript view  
**So that** I can adjust the flow of my work

**Acceptance Criteria:**
- Drag-and-drop reordering is available in edit mode
- Reordering updates the userOrder of source items
- Changes persist after leaving the view
- Undo/redo support for reordering

---

### US3: Include/Exclude Content (P2)

**As a** writer  
**I want to** include or exclude specific pieces from the Manuscript  
**So that** I can control what appears in the final output

**Acceptance Criteria:**
- Each source item has an "include in manuscript" toggle
- Excluded items are visually distinct but still visible in source folders
- Excluded items do not appear in the Manuscript view
- Default is included

---

### US4: Export Manuscript (P2)

**As a** writer  
**I want to** export my assembled Manuscript  
**So that** I can share or submit my work

**Acceptance Criteria:**
- Export options include: PDF, RTF, Plain Text, Word (.docx)
- Export respects page setup settings
- Export includes only included content
- Title page option (project name, author)
- Table of contents option (for novels/drama with chapters/acts)

---

### US5: Preview Manuscript (P2)

**As a** writer  
**I want to** preview my Manuscript with pagination  
**So that** I can see how it will look when printed or exported

**Acceptance Criteria:**
- Preview mode shows paginated view
- Page numbers are displayed
- Headers/footers reflect page setup settings
- Preview matches export output

---

### US6: Poetry Collection Assembly (P2)

**As a** poet  
**I want to** assemble poems into collections within the Manuscript  
**So that** I can organize themed groups of poems

**Acceptance Criteria:**
- Poems can be grouped into named sections
- Section headings appear in the Manuscript
- Poems can appear in multiple collections
- Order within each section is independent

---

## Functional Requirements

### FR1: Manuscript Folder Behavior

- **FR1.1:** Manuscript folder is read-only for manual file additions
- **FR1.2:** Tapping Manuscript folder opens the assembly view, not a file list
- **FR1.3:** Assembly view shows content from source folders in order
- **FR1.4:** Content order is determined by userOrder property on source items

### FR2: Content Assembly

- **FR2.1:** General Purpose: Files from Sections folder, ordered by userOrder
- **FR2.2:** Poetry: Poems from Poems folder, ordered by userOrder
- **FR2.3:** Fiction (Novel): Chapters in order, each containing its scenes in order
- **FR2.4:** Fiction (Short): Scenes in order by userOrder
- **FR2.5:** Drama: Acts in order, each containing its scenes in order

### FR3: Editing in Manuscript View

- **FR3.1:** Inline editing modifies the source file directly
- **FR3.2:** Changes are saved to the source file's current version
- **FR3.3:** Undo/redo operates on the source file's undo manager
- **FR3.4:** Cursor position is tracked across the assembled view

### FR4: Export

- **FR4.1:** Export combines all included content into a single document
- **FR4.2:** Section/chapter breaks are preserved
- **FR4.3:** Formatting from source files is preserved
- **FR4.4:** Export uses page setup settings (margins, paper size)
- **FR4.5:** Optional front matter: title page, table of contents

## Technical Considerations

### Data Model

No new models required. The Manuscript view is a computed assembly of existing content:

```swift
// Computed property on Project
var manuscriptContent: [ManuscriptSection] {
    switch type {
    case .generalPurpose:
        // Sections folder contents in userOrder
    case .poetry:
        // Poems folder contents in userOrder
    case .fiction:
        if fictionClass == .novel {
            // Chapters with their scenes
        } else {
            // Scenes in userOrder
        }
    case .drama:
        // Acts with their scenes
    }
}

struct ManuscriptSection {
    let title: String?
    let items: [TextFile]
    let level: Int  // 0 = top level, 1 = chapter/act, 2 = scene
}
```

### UI Components

- `ManuscriptView`: Main assembly view for reading/editing
- `ManuscriptExportSheet`: Export options and progress
- `ManuscriptPreviewView`: Paginated preview mode
- `ManuscriptSettingsView`: Include/exclude toggles, section management

### Performance

- Lazy loading of content for large manuscripts
- Incremental rendering for preview mode
- Background export with progress indicator

## Open Questions

1. Should the Manuscript support adding introductions/forewords that aren't part of source folders?
2. How should footnotes/endnotes be handled in the assembled view?
3. Should there be a "compile" step or is it always live-assembled?
4. How to handle conflicting formatting between source files?

## Testing Requirements

### Unit Tests
- Content assembly order verification for each project type
- Include/exclude filtering
- Export format generation

### Integration Tests
- End-to-end assembly from source to export
- Editing in Manuscript view updates source
- Reordering persists correctly

### UI Tests
- Manuscript folder navigation
- Export flow completion
- Preview pagination accuracy
