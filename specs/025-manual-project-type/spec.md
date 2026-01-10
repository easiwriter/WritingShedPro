# Feature 025: Manual Project Type

**Status**: Draft  
**Priority**: Medium  
**Estimated Effort**: TBD  
**Dependencies**: 001-project-management-ios-macos, 024-hyperlinks  
**Created**: 2026-01-10

## Overview

Add a "Manual" project type that leverages existing WSP project structure (folders = sections, files = chapters) with enhanced navigation and reading experience. This enables creation of documentation, user guides, and reference materials using WSP itself.

## Requirements

### 1. Project Type Extension

#### 1.1 Add Manual Type
Extend existing project type enumeration:
```swift
enum ProjectType {
    case shortFiction
    case longFiction
    case poetry
    case drama
    case manual      // NEW
}
```

#### 1.2 Manual Project Characteristics
- Uses standard folder/file structure
- Folders act as sections/parts
- Files act as chapters/pages
- File order defines reading sequence
- Supports all existing text formatting
- Hyperlinks (024) essential for cross-references

### 2. Structure Mapping

| Manual Concept | WSP Structure |
|----------------|---------------|
| Manual title | Project name |
| Part/Section | Folder |
| Chapter/Page | File |
| Page order | File sort order |
| Sub-sections | Headings within file |

Example structure:
```
My App Manual (Project)
├── Getting Started (Folder)
│   ├── Introduction (File)
│   ├── Installation (File)
│   └── Quick Start (File)
├── Features (Folder)
│   ├── Writing Tools (File)
│   ├── Formatting (File)
│   └── Export Options (File)
└── Reference (Folder)
    ├── Keyboard Shortcuts (File)
    └── Troubleshooting (File)
```

### 3. Table of Contents (TOC)

#### 3.1 Auto-Generated TOC
- Built from project structure automatically
- Folders = top-level entries
- Files = second-level entries
- Headings within files = third-level entries (optional depth)

#### 3.2 TOC Display
**Sidebar/Panel** (preferred):
- Collapsible tree view
- Always visible during reading
- Current location highlighted
- Tap to navigate

**Alternative: TOC Page**
- Generated as first page of exported manual
- Clickable entries (using hyperlinks)

#### 3.3 TOC Options
- Include/exclude headings from files
- Heading depth (H1 only, H1-H2, H1-H2-H3)
- Show page numbers (for print/PDF)

### 4. Navigation Enhancements

#### 4.1 Previous/Next Navigation
- "Previous Chapter" / "Next Chapter" buttons
- Follows file order within project
- Wraps between folders (end of folder → first file of next folder)

#### 4.2 Breadcrumb Trail
Show current location:
```
Manual Name > Section > Chapter
```
Each element clickable to navigate up.

#### 4.3 Quick Jump
- Keyboard shortcut to show TOC overlay (Cmd+G or similar)
- Search within TOC
- Recent locations history?

### 5. Reading Mode

#### 5.1 Manual Presentation
When viewing a Manual project (especially in WSP Reader):
- TOC sidebar visible by default
- Navigation controls prominent
- Edit controls hidden (in Reader) or de-emphasized (in main app)

#### 5.2 Page-by-Page vs Scroll
**Option A: Single-File View**
- One chapter visible at a time
- prev/next to move between
- Cleaner, book-like experience

**Option B: Continuous Scroll**
- All files concatenated
- Section headers as visual breaks
- More like a web page

**Recommendation**: Start with Option A, consider Option B as setting

### 6. Manual-Specific Features

#### 6.1 Index Generation (Future)
- Mark terms for inclusion in index
- Auto-generate alphabetical index
- Links back to term locations

#### 6.2 Glossary Support (Future)
- Dedicated glossary file/section
- Auto-link terms in text to glossary definitions

#### 6.3 Version/Revision Tracking
- Manual version number (stored in project metadata)
- "Last Updated" date
- Revision history page?

### 7. Export Considerations

#### 7.1 WSP Export
- Standard .wsp export (Reader will detect Manual type)
- Include project type flag in export metadata

#### 7.2 PDF Export
- Generate TOC page at start
- Include page numbers
- PDF bookmarks matching TOC structure
- Optional: Running headers showing section/chapter

#### 7.3 HTML Export (Future)
- Multi-page HTML with navigation
- Single-page HTML option
- CSS customization

### 8. Creating a Manual Project

#### 8.1 New Project Flow
When creating new project:
- Project type selector includes "Manual" option
- Initial template structure:
  ```
  New Manual (Project)
  ├── Introduction (File)
  └── Chapter 1 (File)
  ```

#### 8.2 Converting Existing Project
- Allow changing project type to Manual
- Existing structure becomes TOC structure
- No data loss, just presentation change

## Implementation Notes

### Phase 1: Core Manual Type
1. Add `manual` to ProjectType enum
2. Add project type selector to project creation
3. Persist project type in SwiftData model

### Phase 2: Table of Contents
1. Create TOC generation logic
2. Build TOC sidebar view
3. Wire up navigation on tap

### Phase 3: Navigation
1. Previous/Next chapter buttons
2. Breadcrumb component
3. Keyboard navigation

### Phase 4: Reading Experience
1. Reading mode layout
2. TOC always-visible option
3. Polish transitions and animations

### Phase 5: Export Enhancements
1. TOC in PDF export
2. PDF bookmarks
3. Running headers (optional)

## UI Mockups

### Manual View - iPad/Mac
```
┌─────────────────────────────────────────────────────────────┐
│ ☰ My App Manual                          < Prev  Next >    │
├──────────────────┬──────────────────────────────────────────┤
│ ▼ Getting Started│                                          │
│   • Introduction │  # Installation                          │
│   • Installation │                                          │
│   • Quick Start  │  To install Writing Shed Pro...          │
│                  │                                          │
│ ▶ Features       │  ## Requirements                         │
│                  │                                          │
│ ▶ Reference      │  - iOS 17+ or macOS 14+                  │
│                  │  - 50MB free space                       │
│                  │                                          │
│                  │  ## Download                              │
│                  │                                          │
│                  │  1. Open App Store                       │
│                  │  2. Search for "Writing Shed Pro"        │
│                  │                                          │
└──────────────────┴──────────────────────────────────────────┘
```

### Manual View - iPhone
```
┌─────────────────────────┐
│ ☰ Installation    < >   │
├─────────────────────────┤
│                         │
│ # Installation          │
│                         │
│ To install Writing      │
│ Shed Pro...             │
│                         │
│ ## Requirements         │
│                         │
│ - iOS 17+               │
│ - 50MB free space       │
│                         │
│ ## Download             │
│                         │
│ 1. Open App Store       │
│                         │
└─────────────────────────┘
(☰ toggles TOC overlay)
```

## Open Questions

1. Should headings within files appear in TOC automatically, or require opt-in?
2. TOC sidebar: always visible on iPad/Mac, or collapsible?
3. Should manual projects support folders-within-folders for deeper hierarchy?
4. How to handle very long files (chapters) - lazy loading?
5. Should "Reading Mode" be available for non-Manual projects too?

## Relationship to Other Projects

This feature builds foundation for:
- **026-wsp-reader**: Reader app displays Manual projects with this navigation
- **027-wsp-manual**: The WSP user manual will use this project type

Also benefits:
- Novel projects (TOC for long fiction)
- Non-fiction writing (textbooks, guides)
