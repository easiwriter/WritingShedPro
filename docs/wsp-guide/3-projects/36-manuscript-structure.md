# Manuscript Structure

Writing Shed Pro uses a **Manuscript** folder to organize your work for export and publication. This guide covers the manuscript structure, its subfolders, and the special files for front and back matter.

## Overview

The Manuscript folder provides a structured way to assemble your writing into a complete, publishable document. It contains three main subfolders:

```
Manuscript/
├── Front Matter/
│   ├── Title Page
│   ├── Copyright
│   ├── Dedication
│   ├── Table of Contents
│   └── (other front matter files)
├── [Body Content]/
│   └── (your writing organized by type)
└── Back Matter/
    ├── Endnotes (auto-generated)
    ├── Glossary (auto-generated)
    ├── References/Bibliography (auto-generated)
    ├── Index (auto-generated)
    └── Contributors (user-created)
```

The body folder name varies by project type:
- **Drama**: All Acts
- **Poetry**: All Poems
- **Prose**: All Sections
- **Novel**: All Chapters
- **Short Fiction**: All Stories

## Front Matter

Front matter appears at the beginning of your manuscript, before the main content. Writing Shed Pro provides files for common front matter elements, but **you supply the content**.

### Common Front Matter Files

| File | Purpose | Content to Add |
|------|---------|----------------|
| **Title Page** | Book title and author | Title, subtitle, author name, publisher logo |
| **Copyright** | Legal information | Copyright notice, ISBN, publisher info, rights statements |
| **Dedication** | Personal dedication | To whom you dedicate the book |
| **Acknowledgments** | Thanks | People and organizations to thank |
| **Epigraph** | Introductory quote | A quotation that sets the tone |
| **Table of Contents** | Chapter listing | Auto-generated from headings, or manually created |
| **Foreword** | Introduction by another person | Written by someone other than the author |
| **Preface** | Author's introduction | Why and how you wrote the book |
| **Introduction** | Subject introduction | Background on the subject matter |

### Adding Front Matter Content

1. Open the **Manuscript** folder
2. Open **Front Matter**
3. Tap on any file (e.g., "Title Page")
4. Add your content using the editor
5. Format as desired

### Table of Contents

The Table of Contents (TOC) can be:
- **Auto-generated**: Writing Shed Pro creates it from your heading styles during PDF export
- **Manual**: You write and format it yourself

To enable auto-generated TOC:
1. Go to **Export Options**
2. Enable **Include Table of Contents**
3. The TOC will be generated based on Heading 1, Heading 2, etc. styles in your content

**Note**: Auto-generated TOC requires consistent use of heading paragraph styles.

## Body Content

The middle folder contains your actual writing, organized according to project type. How body content is assembled into the manuscript differs for each type:

| Project Type | Body Folder | Hierarchy | Assembly Order |
|-------------|-------------|-----------|---------------|
| **Prose** | All Sections | Sections → Files | Section order, then file order within each section |
| **Poetry** | All Poems | Flat (all poems) | Display order |
| **Novel** | All Chapters | Chapters → Scenes | Chapter order, then scene order within each chapter |
| **Verse Novel** | All Chapters | Books → Episodes | Book order, then episode order within each book |
| **Short Fiction** | All Stories | Flat (scenes only) | Scene order |
| **Drama** | All Acts | Acts → Scenes (or flat) | Act order, then scene order; standalone scenes appended |

### Excluding Files from the Manuscript

Any file can be excluded from manuscript assembly without deleting it:
1. Open the file's details or context menu
2. Toggle **Include in Manuscript** off
3. The file remains in your project but is skipped during assembly

This is useful for notes, alternate versions, or work-in-progress files you don't want in the current export.

### Type-Specific Assembly Details

Each project type has unique assembly features documented in its own guide:

- [Prose Manuscript and Export](../5-prose-features/54-manuscript-and-export.md) — section-based assembly, ordering
- [Poetry Manuscript and Export](../6-poetry-features/66-manuscript-and-export.md) — poem ordering, formatting preservation
- [Fiction Manuscript Formatting](../7-fiction-features/74-manuscript-formatting.md) — chapter headings, scene breaks, industry format
- [Drama Manuscript and Export](../8-drama-features/85-manuscript-and-export.md) — act/scene grouping, DML rendering, script formats

## Back Matter

Back matter appears at the end of your manuscript. Some sections are **auto-generated** from references in your text, while others are **user-created**.

### Auto-Generated Back Matter

These sections are created automatically based on content you've added to your files:

#### Endnotes

If you use footnotes in endnotes mode, they appear here:
- Collected from all files in order
- Numbered sequentially across the manuscript
- Preserves all footnote formatting

**Note**: Footnotes vs. endnotes is a display setting—your footnote content can appear either at page bottoms (footnotes) or collected at the end (endnotes).

See [Footnotes](../4-writing/45-footnotes.md) for details on adding footnotes.

#### Glossary

Terms you've marked for the glossary appear here:
- Alphabetically sorted
- Each entry shows the term and its definition
- Terms are highlighted in the text with special formatting

To add glossary entries, use the References menu in the editor toolbar.

#### References / Bibliography

Citations and works cited appear here:
- Formatted according to your chosen citation style
- Includes all works referenced in your text
- Sorted alphabetically by author

To add reference entries, use the References menu in the editor toolbar.

#### Index

Index entries with page numbers appear here:
- Alphabetically sorted main entries
- Sub-entries indented under parents (up to 3 levels)
- Page numbers calculated from pagination
- Cross-references ("See" and "See also")
- Primary references shown in bold

See [Index Generation](../10-advanced-features/108-index-generation.md) for details on creating index entries.

**Note**: Index with page numbers is only available in PDF export, since other formats don't have fixed page numbers.

### User-Created Back Matter

#### Contributors

For anthologies, magazines, and collaborative works:
- Add contributor names and biographies
- Automatically sorted by surname
- Format customizable in export

See [Contributors](../10-advanced-features/107-contributors.md) for details.

#### Other Back Matter Files

You can add additional back matter files for:
- **Appendices**: Supplementary material, data, or documents
- **About the Author**: Your biography
- **Also By**: List of your other works
- **Colophon**: Information about the book's production
- **Reading Group Guide**: Discussion questions

To add a custom back matter file:
1. Open **Back Matter** folder
2. Tap **+** to create a new file
3. Name it appropriately
4. Add your content

## Export Options

When exporting your manuscript, you can control which sections are included:

### Back Matter Settings

1. Open **Export** options
2. Under **Back Matter**, enable or disable:
   - ☑️ Include Endnotes
   - ☑️ Include Glossary
   - ☑️ Include Bibliography
   - ☑️ Include Index
   - ☑️ Include Contributors

### Section Order in Export

The exported manuscript follows this order:
1. Front Matter (in file order)
2. Body Content (in file/chapter order)
3. Back Matter:
   - Endnotes
   - Glossary
   - References/Bibliography
   - Contributors
   - Index
   - (Custom files in order)

## Tips

### Consistent Formatting
Use paragraph styles consistently throughout your manuscript. This ensures:
- Auto-generated TOC works correctly
- Export formatting is uniform
- Professional appearance

### Review Before Export
Always preview your assembled manuscript:
- Check that all sections are included
- Verify page numbering is correct
- Ensure cross-references resolve

### Empty Sections
If a back matter section has no entries (e.g., no glossary terms defined), it won't appear in the export. This prevents empty sections in your final document.

### File Order in Front/Back Matter
Files in Front Matter and Back Matter appear in the order shown in the folder. To reorder:
1. Tap **Edit** in the folder
2. Drag files to the desired order
3. Tap **Done**

## Related Topics

- [Export Options](../9-publishing/91-export-options.md)
- [PDF Export](../9-publishing/92-pdf-export.md)
- [Footnotes](../4-writing/45-footnotes.md)
- [Index Generation](../10-advanced-features/108-index-generation.md)
- [Contributors](../10-advanced-features/107-contributors.md)
