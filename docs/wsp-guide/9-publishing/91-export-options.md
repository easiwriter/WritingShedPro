# Export Options

Writing Shed Pro offers multiple ways to export your work for sharing, submission, and printing. This guide provides an overview of export options.

## Available Export Formats

| Format | Best For | Features Preserved |
|--------|----------|-------------------|
| **PDF** | Submissions, sharing, print | All formatting, pagination, footnotes |
| **RTF** | Editor collaboration | Most formatting, editable |
| **Markdown** | Plain text with structure | Headings, bold, italic, links |
| **Plain Text** | Maximum compatibility | Text only, no formatting |
| **WSP** | Backup, sharing, device transfer | Complete project archive |
| **Print** | Physical copies | All formatting via printing |

## Accessing Export

### From a Single File
1. Open the file
2. Tap the share/export button (or menu)
3. Select your format
4. Configure options
5. Export

### From a Collection
1. Open the collection
2. Tap the share/export button
3. All files in the collection export together
4. Choose format and options

### From a Submission
1. Open the submission
2. Export includes all submitted files
3. Same format options apply

### Manuscript Export (Fiction)
1. From your fiction project, access Manuscript
2. Export the assembled manuscript
3. All chapters/scenes combined

## Manuscript Export by Project Type

All project types support manuscript export — the process of assembling your files into a single document. How files are combined differs by type:

| Project Type | Assembly Model | Details |
|-------------|----------------|---------|
| **Prose** | Section-based | Files ordered by section, then by file order within each section |
| **Poetry** | Flat | Poems in display order, formatting preserved |
| **Fiction** | Chapter-based | Chapters → Scenes (Novel/Verse Novel) or flat scenes (Short Fiction) |
| **Drama** | Act-based | Acts → Scenes, with DML rendered to script format |

For type-specific details:
- [Prose Manuscript and Export](../5-prose-features/54-manuscript-and-export.md)
- [Poetry Manuscript and Export](../6-poetry-features/66-manuscript-and-export.md)
- [Fiction Manuscript Formatting](../7-fiction-features/74-manuscript-formatting.md)
- [Drama Manuscript and Export](../8-drama-features/85-manuscript-and-export.md)

For the overall manuscript structure (front matter, back matter), see [Manuscript Structure](../3-projects/36-manuscript-structure.md).

## Export Workflow

### 1. Prepare Your Content
- Review and proofread
- Check pagination view
- Verify formatting

### 2. Check Page Setup
- Paper size
- Margins
- Headers/footers
- Orientation

### 3. Choose Format
- PDF for fixed appearance
- RTF for editability
- Print for paper copies

### 4. Configure Options
- Page range (all or selection)
- Include footnotes
- Include comments (usually no)

### 5. Export
- Save to Files
- Share via email, AirDrop, etc.
- Print directly

## What Gets Exported

### Always Included
- Text content
- Paragraph styles
- Character formatting (bold, italic, etc.)
- Images
- Footnotes

### Optional
- Comments (usually excluded)
- Track changes (if applicable)
- Bookmarks/links

### Never Included
- Internal notes
- Draft metadata
- Version history

## Export Best Practices

### For Submissions
1. Check submission guidelines
2. Use PDF unless RTF requested
3. Verify word count
4. Review the exported file

### For Collaboration
1. RTF allows editing
2. Include comments if reviewing
3. Communicate format expectations

### For Printing
1. Preview before printing
2. Check paper size matches page setup
3. Consider paper and ink quality

### For Backup
1. Export regularly
2. Keep copies of important work
3. Multiple formats for redundancy

## WSP Project Export and Import

The `.wsp` format is Writing Shed Pro's native project archive — a single JSON file containing your entire project.

### What's Included

| Data | Included |
|------|----------|
| All files and their content | ✅ |
| All file versions | ✅ |
| Formatted text (rich text) | ✅ |
| Comments and footnotes | ✅ |
| Folder structure | ✅ |
| Project settings and metadata | ✅ |
| Publications and submissions | ✅ |
| Poetry collections | ✅ |
| Fiction structure (books, chapters, acts, scenes) | ✅ |
| Characters and locations | ✅ |
| Prose sections | ✅ |
| Workflow status for each file | ✅ |

### What's Not Included

| Data | Reason |
|------|--------|
| Stylesheets | Projects use the device's stylesheets |
| Reference entries (notes, glossary, index, etc.) | Regenerated from in-text markers |
| Trash contents | Excluded from export |
| Undo history | Session-only data |

### Exporting a Project

1. From the project list, long-press (or right-click) the project
2. Select **Export**
3. A save dialog appears with the filename `ProjectName.wsp`
4. Choose a destination (Files, iCloud Drive, etc.)
5. Tap **Save**

### Importing a WSP File

1. Open **Settings** (gear icon on the project list)
2. Tap **Import**
3. Select the `.wsp` file from your device or iCloud Drive
4. The project is added to your project list

Importing a project with the same name as an existing project creates a separate copy — it does not overwrite or merge.

See [Creating Projects](../3-projects/32-creating-projects.md) for more about importing.

## Troubleshooting Export

### Export Takes Too Long
- Large files with many images
- Complex formatting
- Try reducing image quality/count

### Formatting Looks Wrong
- Check page setup settings
- Review in pagination view first
- Verify font availability

### File Won't Open Elsewhere
- PDF should open anywhere
- RTF may need Word-compatible app
- Check file isn't corrupted

## See Also
- [PDF Export](92-pdf-export.md)
- [RTF Export](93-rtf-export.md)
- [Markdown Import and Export](96-markdown-import-export.md)
- [Printing](94-printing.md)
- [Page Setup](../10-advanced-features/103-page-setup.md)
- [Creating Projects](../3-projects/32-creating-projects.md) — importing WSP files

---
