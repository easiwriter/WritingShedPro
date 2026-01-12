# Feature 029: Manuscript Assembly

**Status:** MVP Complete  
**Branch:** 021-smart-poetry-creation  
**Date:** 2025-01-10

## Completed Phases

### Phase 1: Folder Structure
- Added Manuscript folder with subfolders: Front Matter, Body, Back Matter
- Updated FolderCapabilityService for folder permissions
- Updated ProjectTemplateService to create subfolders on project creation
- Added folder icons and navigation in FolderListView

### Phase 2: Assembly Service & Models
- Created ManuscriptModels.swift:
  - `ManuscriptSection` - represents a section in the manuscript
  - `ManuscriptContent` - assembled content with metadata
  - `ManuscriptSettings` - section break style, footnote numbering
  - `ExportFormat`, `ExportOptions` - for future export types
- Created ManuscriptAssemblyService.swift:
  - `getSections()` - gets all sections for manuscript
  - `getBodySections()` - gets body sections by project type
  - `assembleContent()` - assembles NSAttributedString from sections
- Added `includedInManuscript` property to TextFile model
- Added `manuscriptSettingsData` to Project model

### Phase 3: ManuscriptBodyView (Dynamic Page View)
- Displays assembled body content in a dynamic, paginated, read-only view
- **Poetry/Fiction:** Shows a page view of the files/scenes folder (each file/scene starts on a new page)
- **Drama:** Shows a page view of formatted script scenes (each scene is rendered using the drama script formatter, not as raw text)
- Section headers (chapters, etc.)
- File titles with edit navigation links
- Source folder info in toolbar menu
- **Static text container is no longer used.**

### Phase 4: PDF Export
- Added `generatePDF(from: ManuscriptContent)` to PrintService
- Export button in ManuscriptBodyView toolbar
- Async PDF generation with share sheet

### Phase 5: Include/Exclude UI
- Context menu toggle: "Include in Manuscript" / "Exclude from Manuscript"
- Visual indicator (eye.slash icon, dimmed opacity) for excluded files
- Works for all project types with Manuscript folder

## Future Phases (Not Implemented)

### Phase 6: Full Manuscript View (Medium Priority)
Combined preview of all sections:
- Front Matter + Body + Back Matter in single scrollable view
- Section dividers between major sections
- Could replace or supplement ManuscriptBodyView

### Phase 7: Manuscript Settings UI (Low Priority)
Settings sheet for manuscript preferences:
- Section break style (page break, section mark, double space, none)
- Footnote numbering style (per file, continuous, per section)
- Would use `manuscriptSettingsData` already on Project model

### Phase 8: TOC Generation (Low Priority)
Auto-generate table of contents:
- List sections with page numbers
- Clickable navigation in preview
- Include in PDF export

### Phase 9: Print Support (Low Priority)
Direct print functionality:
- Print dialog from ManuscriptBodyView
- Uses existing PrintService infrastructure

## Files Modified/Created

### New Files
- `Models/ManuscriptModels.swift`
- `Services/ManuscriptAssemblyService.swift`
- `Views/Manuscript/ManuscriptBodyView.swift`

### Modified Files
- `Models/BaseModels.swift` - TextFile.includedInManuscript, Project.manuscriptSettings
- `Services/FolderCapabilityService.swift` - folder rules for manuscript subfolders
- `Services/ProjectTemplateService.swift` - createManuscriptSubfolders()
- `Services/PrintService.swift` - generatePDF(from: ManuscriptContent)
- `Views/FolderListView.swift` - navigation and icons
- `Views/Components/FileListView.swift` - include/exclude context menu
- `Resources/en.lproj/Localizable.strings` - all new strings
