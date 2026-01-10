# Feature 029: Manuscript Assembly - Implementation Plan

**Created**: 2026-01-10  
**Estimated Total Effort**: 4-5 weeks

## Phase Overview

| Phase | Focus | Effort | Dependencies |
|-------|-------|--------|--------------|
| **Phase 1** | Folder Structure & Navigation | 2-3 days | None |
| **Phase 2** | Body Assembly View | 3-4 days | Phase 1 |
| **Phase 3** | Front/Back Matter | 2-3 days | Phase 1 |
| **Phase 4** | Preview & Print | 3-4 days | Phase 2, 3 |
| **Phase 5** | Export | 3-4 days | Phase 4 |
| **Phase 6** | Include/Exclude & Polish | 2-3 days | Phase 2 |
| **Phase 7** | Table of Contents Generation | 3-4 days | Phase 2, 4 |

---

## Phase 1: Folder Structure & Navigation

**Goal**: Create the three-subfolder structure inside Manuscript and handle navigation

### Tasks

1. **Update ProjectTemplateService** to create Manuscript subfolders
   - Create "Front Matter", "Body", "Back Matter" subfolders inside Manuscript
   - Set appropriate userOrder for display ordering
   - Update for all project types

2. **Update FolderCapabilityService** for new folders
   - Front Matter: allows files only (no subfolders)
   - Body: read-only (assembled view, no manual additions)
   - Back Matter: allows files only (no subfolders)

3. **Update FolderListView** display order
   - Add Manuscript subfolders to the ordering logic
   - Ensure they display in correct order: Front Matter, Body, Back Matter

4. **Handle Manuscript folder tap**
   - Tapping Manuscript shows its three subfolders
   - Navigation to subfolders works correctly

### Files to Modify
- `Services/ProjectTemplateService.swift`
- `Services/FolderCapabilityService.swift`
- `Views/FolderListView.swift`

### Acceptance Criteria
- [ ] New projects have Manuscript with three subfolders
- [ ] Subfolders display in correct order
- [ ] Front/Back Matter allow file creation
- [ ] Body shows "assembled view" (placeholder for Phase 2)

---

## Phase 2: Body Assembly View

**Goal**: Display assembled content from source folders in the Body view

### Tasks

1. **Create ManuscriptSection model**
   ```swift
   struct ManuscriptSection: Identifiable {
       let id: UUID
       let title: String?
       let level: Int  // 0=top, 1=chapter/act, 2=scene
       let items: [TextFile]
   }
   ```

2. **Create ManuscriptAssemblyService**
   - Compute assembled content based on project type
   - General Purpose: Sections folder files in userOrder
   - Poetry: Poems folder files in userOrder
   - Fiction (Novel): Chapters → Scenes hierarchy
   - Fiction (Short): Scenes in userOrder
   - Drama: Acts → Scenes hierarchy

3. **Create ManuscriptBodyView**
   - Display assembled sections with appropriate headers
   - Show section/chapter/scene dividers
   - Read-only scrollable view of all content
   - Tap on section to navigate to source file

4. **Handle Body folder tap**
   - Tapping Body opens ManuscriptBodyView instead of file list
   - Add visual indicator that this is an assembled view

### Files to Create
- `Models/ManuscriptSection.swift`
- `Services/ManuscriptAssemblyService.swift`
- `Views/Manuscript/ManuscriptBodyView.swift`

### Files to Modify
- `Views/FolderListView.swift` (navigation handling)

### Acceptance Criteria
- [ ] Body view shows assembled content for each project type
- [ ] Correct hierarchy (chapters/acts contain scenes)
- [ ] Section headers are displayed
- [ ] Content appears in correct order
- [ ] Tapping content navigates to source file

---

## Phase 3: Front/Back Matter

**Goal**: Enable file creation and management in Front/Back Matter folders

### Tasks

1. **Enable file creation in Front/Back Matter**
   - Add file capability already set in Phase 1
   - Verify AddFileSheet works correctly

2. **Create matter-specific templates** (optional)
   - Title Page template
   - Table of Contents placeholder
   - Acknowledgements template
   - Bibliography template

3. **Create FrontBackMatterView** (if different from standard folder view)
   - List of files with reordering
   - Standard file editing when tapped

4. **Add common front matter quick-add options**
   - "Add Title Page" button
   - "Add Table of Contents" button
   - "Add Dedication" button
   - These create pre-formatted files

### Files to Create
- `Views/Manuscript/FrontMatterView.swift` (optional, may reuse FolderFilesView)
- `Views/Manuscript/BackMatterView.swift` (optional)
- `Services/MatterTemplateService.swift`

### Acceptance Criteria
- [ ] Can create files in Front Matter folder
- [ ] Can create files in Back Matter folder
- [ ] Files can be reordered
- [ ] Quick-add templates available

---

## Phase 4: Preview & Print

**Goal**: Unified preview of complete manuscript with pagination and print support

### Tasks

1. **Create ManuscriptPreviewView**
   - Combines Front Matter + Body + Back Matter
   - Shows paginated view with page numbers
   - Respects page setup settings

2. **Add Preview button to Manuscript folder**
   - Toolbar button or action in Manuscript view
   - Opens full manuscript preview

3. **Integrate with existing pagination system**
   - Reuse pagination logic from Feature 010
   - Apply page breaks between major sections
   - Generate page numbers

4. **Add Print functionality**
   - Print button in preview view
   - Uses existing PrintService
   - Prints complete assembled manuscript

### Files to Create
- `Views/Manuscript/ManuscriptPreviewView.swift`

### Files to Modify
- `Views/FolderListView.swift` (add preview action)
- `Services/PrintService.swift` (if needed for multi-file printing)

### Acceptance Criteria
- [ ] Preview shows complete manuscript (front + body + back)
- [ ] Pagination is accurate
- [ ] Page numbers displayed
- [ ] Print produces correct output

---

## Phase 5: Export

**Goal**: Export complete manuscript to various formats

### Tasks

1. **Create ManuscriptExportSheet**
   - Format selection: PDF, RTF, Plain Text, Word (.docx)
   - Options: include title page, include TOC
   - Export progress indicator

2. **Create ManuscriptExportService**
   - Assemble complete content (front + body + back)
   - Generate each format
   - Handle large manuscripts with background processing

3. **PDF Export**
   - Use existing PDF generation (from print/pagination)
   - Apply page setup settings

4. **RTF Export**
   - Combine RTF content from source files
   - Preserve formatting

5. **Plain Text Export**
   - Strip formatting
   - Add section dividers

6. **Word (.docx) Export**
   - Use existing WordDocumentService
   - Combine multiple files into single document

### Files to Create
- `Views/Manuscript/ManuscriptExportSheet.swift`
- `Services/ManuscriptExportService.swift`

### Files to Modify
- `Services/WordDocumentService.swift` (multi-file support)

### Acceptance Criteria
- [ ] Export to PDF works
- [ ] Export to RTF works
- [ ] Export to Plain Text works
- [ ] Export to Word works
- [ ] Formatting preserved where applicable
- [ ] Progress shown for large manuscripts

---

## Phase 6: Include/Exclude & Polish

**Goal**: Fine-tune manuscript assembly with include/exclude toggles

### Tasks

1. **Add includeInManuscript property to TextFile**
   - Boolean property, default true
   - CloudKit compatible (has default)

2. **Update ManuscriptAssemblyService**
   - Filter out excluded files
   - Respect include flag in all project types

3. **Add include/exclude toggle in source views**
   - Toggle in file info/detail view
   - Visual indicator for excluded files (dimmed or badge)

4. **Add ManuscriptSettingsView**
   - List all source files with include toggles
   - Quick select/deselect all
   - Show excluded count

5. **Polish and edge cases**
   - Empty manuscript handling
   - Very large manuscript performance
   - Error states and recovery

### Files to Modify
- `Models/TextFile.swift` (add property)
- `Services/ManuscriptAssemblyService.swift`
- `Views/FileEditView.swift` or info views

### Files to Create
- `Views/Manuscript/ManuscriptSettingsView.swift`

### Acceptance Criteria
- [ ] Files can be excluded from manuscript
- [ ] Excluded files don't appear in Body view
- [ ] Excluded files don't appear in preview/export
- [ ] Toggle accessible from file views
- [ ] Settings view shows all files with toggles

---

## Phase 7: Table of Contents Generation

**Goal**: Auto-generate table of contents based on project structure

### Tasks

1. **Create TOCGeneratorService**
   - Generate TOC entries from manuscript structure
   - Project-type specific generation logic
   - Support for page number placeholders (resolved during preview/export)

2. **Define TOC structure per project type**

   | Project Type | TOC Entries |
   |--------------|-------------|
   | **General Purpose** | Section names (from Sections folder hierarchy) |
   | **Poetry** | Poem titles, optionally grouped by collection |
   | **Fiction (Novel)** | Part/Chapter titles with page numbers |
   | **Fiction (Short)** | Scene titles (if multi-scene) or single entry |
   | **Drama** | Act titles → Scene titles |

3. **Create TOCEntryModel**
   ```swift
   struct TOCEntry: Identifiable {
       let id: UUID
       let title: String
       let level: Int          // 0=part, 1=chapter/act, 2=scene
       let pageNumber: Int?    // nil until pagination calculated
       let sourceFile: TextFile?
   }
   ```

4. **Create TOCView**
   - Display generated TOC entries
   - Show hierarchy with indentation
   - Tappable entries navigate to source
   - Edit mode for custom title overrides

5. **Add "Generate TOC" action in Front Matter**
   - Button to generate/regenerate TOC
   - Creates or updates TOC file in Front Matter folder
   - Preserves manual customizations option

6. **Integrate TOC with Preview/Export**
   - Calculate actual page numbers during preview
   - Update TOC entries with resolved page numbers
   - Include formatted TOC in export output

7. **TOC formatting options**
   - Include/exclude page numbers
   - Dot leaders (Title ......... 42)
   - Indentation style
   - Font/size settings

### Files to Create
- `Models/TOCEntry.swift`
- `Services/TOCGeneratorService.swift`
- `Views/Manuscript/TOCView.swift`
- `Views/Manuscript/TOCSettingsSheet.swift`

### Files to Modify
- `Views/Manuscript/ManuscriptPreviewView.swift` (page number resolution)
- `Services/ManuscriptExportService.swift` (include TOC in export)

### Acceptance Criteria
- [ ] TOC generates correctly for General Purpose projects
- [ ] TOC generates correctly for Poetry projects
- [ ] TOC generates correctly for Fiction (Novel) projects
- [ ] TOC generates correctly for Fiction (Short) projects
- [ ] TOC generates correctly for Drama projects
- [ ] Page numbers resolve correctly in preview
- [ ] Page numbers appear in exported documents
- [ ] Tapping TOC entry navigates to content
- [ ] Custom title overrides are preserved on regeneration

---

## Migration Considerations

### Existing Projects

Projects created before this feature will need migration:

1. **On app update**: Check if Manuscript folder has subfolders
2. **If not**: Create Front Matter, Body, Back Matter subfolders
3. **Preserve**: Any existing files in Manuscript (move to appropriate subfolder or Body)

### Migration Code Location
- `Services/MigrationService.swift` or similar
- Run on app launch for affected projects

---

## Testing Strategy

### Phase 1 Tests
- Folder creation for each project type
- Capability verification
- Display order verification

### Phase 2 Tests
- Assembly logic for each project type
- Correct ordering
- Hierarchy verification (novel chapters, drama acts)

### Phase 3 Tests
- File creation in front/back matter
- Template generation

### Phase 4 Tests
- Preview content assembly
- Pagination accuracy
- Print output

### Phase 5 Tests
- Each export format
- Large file handling
- Format preservation

### Phase 6 Tests
- Include/exclude filtering
- Toggle persistence
- UI state consistency

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Performance with large manuscripts | Medium | High | Lazy loading, pagination |
| Complex hierarchy assembly | Low | Medium | Thorough testing per project type |
| Export format compatibility | Medium | Medium | Test on multiple platforms |
| Migration of existing projects | Low | High | Non-destructive migration, backup |

---

## Definition of Done

- [ ] All phases complete
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Manual testing on iOS and macOS
- [ ] No regressions in existing functionality
- [ ] Documentation updated
- [ ] Localization strings added
