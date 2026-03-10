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
├── Body Matter/
│   └── (your writing organized by type)
└── Back Matter/
    ├── Endnotes (auto-generated)
    ├── Glossary (auto-generated)
    ├── References/Bibliography (auto-generated)
    ├── Index (auto-generated)
    └── Contributors (user-created)
```

The body folder is always called **Body Matter** for all project types. You manage its contents through the Body Matter view, where you can add, remove, and reorder items for manuscript assembly.

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
| **Prose** | Body Matter | Sections → Files | Section order, then file order within each section |
| **Poetry** | Body Matter | Collections and/or poems | Body matter order (collections and individual poems) |
| **Novel** | Body Matter | Chapters → Scenes | Chapter order, then scene order within each chapter |
| **Verse Novel** | Body Matter | Books → Episodes | Book order, then episode order within each book |
| **Short Fiction** | Body Matter | Flat (scenes only) | Scene order |
| **Drama** | Body Matter | Acts → Scenes (or flat) | Act order, then scene order; standalone scenes appended |

### Including Files in the Manuscript

Files are included in manuscript assembly by adding their parent container to **Body Matter**. For example:
- In a Novel, add a chapter to Body Matter to include all its scenes
- In Poetry, add a collection or individual poem to Body Matter
- In Prose, add a section to Body Matter to include all its files

To exclude a file from the manuscript, remove it from its container or move it to a container that is not included in Body Matter.
### Type-Specific Assembly Details

Each project type has unique assembly features documented in its own guide:

- [Prose Manuscript and Export](../5-prose-features/54-manuscript-and-export.md) — section-based assembly, ordering
- [Poetry Manuscript and Export](../6-poetry-features/66-manuscript-and-export.md) — poem ordering, formatting preservation
- [Fiction Manuscript Formatting](../7-fiction-features/74-manuscript-formatting.md) — chapter headings, scene breaks, industry format
- [Drama Manuscript and Export](../8-drama-features/85-manuscript-and-export.md) — act/scene grouping, DML rendering, script formats

## Back Matter

Back matter appears at the end of your manuscript. Some sections are **auto-generated** from references in your text, while others are **user-created**.

### Enabling Back Matter Sections

Back matter sections must be enabled before they appear in export:

1. Open your project's **Manuscript** folder
2. Open **Back Matter**
3. Tap the settings icon to manage which sections are included
4. Toggle sections on or off

Only enabled sections with actual content appear in the exported manuscript.

### Auto-Generated Back Matter

These sections are created automatically based on content you've added to your files using the **Insert menu** (⊕) in the editor toolbar. Each reference type creates an inline marker in your text and a corresponding entry in the back matter.

#### Endnotes

If you use footnotes in endnotes mode, they appear here:
- Collected from all files in order
- Numbered sequentially across the manuscript
- Preserves all footnote formatting

**Note**: Footnotes vs. endnotes is a display setting — your footnote content can appear either at page bottoms (footnotes) or collected at the end (endnotes).

See [Footnotes](../4-writing/45-footnotes.md) for details on adding footnotes.

#### Glossary

Terms you've marked for the glossary appear here:
- Alphabetically sorted, grouped by first letter
- Each entry shows the term and its definition
- Terms appear as styled inline markers in the text
- Only terms actually referenced in your text are included

To add a glossary entry:
1. Place the cursor where you want the term to appear
2. Tap **⊕** → **Glossary Term**
3. Enter the term and its definition
4. The term appears as an inline marker in your text

You can also select text and use the context menu's **Add to Glossary** action.

#### References / Bibliography

Bibliographic citations appear here:
- Formatted in citation style (author/date)
- Only referenced works are included
- Sorted alphabetically by author
- Each reference shows author, publication date, and details

To add a reference:
1. Place the cursor at the citation point
2. Tap **⊕** → **Reference**
3. Enter the author, publication date, and details — or select an existing reference
4. A marker like `[Author, 2026]` appears in your text

References support full academic citation fields including title, source, URL, DOI, volume, issue, pages, and more.

#### Table of Figures

Figure references placed in your text are collected into a table of figures:
- Listed in document order
- Each entry shows the figure number and caption
- Numbered sequentially across the manuscript

To add a figure reference, use **⊕** → **Figure Reference** in the editor toolbar.

#### Index

Index entries with page numbers appear here:
- Alphabetically sorted main entries
- Sub-entries indented under parents (up to 3 levels of hierarchy)
- Page numbers calculated from pagination, with ranges (e.g., "1, 3, 5–7, 12")
- Cross-references ("See" and "See also")
- Primary references shown in bold

To add an index entry:
1. Place the cursor at the relevant location
2. Tap **⊕** → **Index Entry**
3. Enter the keyword
4. Optionally set a parent entry for sub-entries
5. Mark as a primary reference if desired

See [Index Generation](../10-advanced-features/108-index-generation.md) for details on creating index entries.

**Note**: Index with page numbers is only available in PDF export, since other formats don't have fixed page numbers.

#### How Reference Markers Appear

All reference types insert inline markers in your text:
- **In the editor**: Markers appear as coloured inline elements
- **In PDF export**: Markers are rendered in the appropriate format for the reference type
- **In plain text export**: Markers are converted to readable text (e.g., "see Note 1", "see Glossary")

Markers are stored as metadata — they don't alter your text content. Deleting a marker removes the reference without affecting surrounding text.

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
   - ☑️ Include Table of Figures
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
