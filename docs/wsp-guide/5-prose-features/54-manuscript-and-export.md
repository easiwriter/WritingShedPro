# Manuscript and Export (Prose)

This guide covers how Writing Shed Pro assembles Prose project content into a manuscript for export.

## How Prose Manuscripts Are Assembled

Prose manuscripts use a **section-based** assembly model:

1. **Front Matter** is placed first (Title Page, Copyright, etc.)
2. **Body content** is assembled section by section
3. **Back Matter** is appended (Endnotes, Glossary, Bibliography, Index)

### Section Ordering

If your project uses sections, body content is assembled in this order:
1. Each section is processed in **section order** (as arranged in the Sections folder)
2. Within each section, files appear in **file order** (as arranged within the section)
3. Files not assigned to any section are appended at the end

If your project has no sections, all files are assembled in their list order.

### What Gets Included

By default, all files in the project are included. You can exclude individual files:
1. Open the file's context menu
2. Toggle **Include in Manuscript** off
3. The file stays in your project but is skipped during assembly

This is useful for notes, research files, or alternate drafts you want to keep but not export.

## Previewing the Manuscript

Before exporting:
1. Open the **Manuscript** view
2. Review the assembled content
3. Check that sections appear in the correct order
4. Verify file ordering within sections
5. Confirm no unwanted files are included

## Section Breaks

Control how sections are separated in the manuscript:

| Break Style | Appearance |
|-------------|------------|
| **Page Break** | Each section starts on a new page |
| **Section Mark** | Centered mark (e.g., * * *) between sections |
| **Double Space** | Extra blank line between sections |
| **None** | Sections flow together continuously |

### Setting Section Break Style
1. Open **Export Options** or **Project Settings**
2. Find **Section Break Style**
3. Choose your preferred option

## Section Headings and File Titles

You can control whether structural headings appear in the output:

- **Include Section Headings**: Show the section name as a heading before its files
- **Include File Titles**: Show each file's title as a heading

These settings are in Export Options.

## Export Formats

Prose manuscripts can be exported in all available formats:

| Format | Best For |
|--------|----------|
| **PDF** | Final presentation, sharing, printing |
| **RTF** | Editable by recipients, Word-compatible |
| **HTML** | Web publishing, online sharing |
| **Markdown** | Plain text with formatting, version control |

### Exporting
1. Open the Manuscript view
2. Tap the export/share button
3. Choose your format
4. Configure options (page setup, back matter toggles)
5. Save or share

## Footnote Numbering

Choose how footnotes are numbered across the manuscript:

- **Per File**: Numbering restarts in each file
- **Continuous**: Sequential numbering across the entire manuscript

## Tips

### Organize Before Exporting
Assign files to sections and set their order before generating the manuscript. The assembly follows your section and file ordering exactly.

### Use Sections for Major Divisions
Sections map to major parts of your document. For example, a user guide might use sections for "Introduction", "Getting Started", "Reference", and "Appendix".

### Exclude Work-in-Progress Files
Use the **Include in Manuscript** toggle to keep draft files visible in your project without including them in exports.

### Preview First
Always check the manuscript preview before exporting. It's easier to fix ordering issues in the project than to rearrange an exported document.

## See Also
- [Prose Mode Overview](51-prose-mode-overview.md)
- [Working with Sections](52-working-with-sections.md)
- [Manuscript Structure](../3-projects/36-manuscript-structure.md)
- [Export Options](../9-publishing/91-export-options.md)
- [PDF Export](../9-publishing/92-pdf-export.md)

---
