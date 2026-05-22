# Tutorial: Formatting a Professional Manuscript

This tutorial walks you through preparing a complete, professionally formatted manuscript in Writing Shed Pro — covering page layout, paragraph styles, footnotes, table of contents, front and back matter, and PDF export.

**Time**: 40–50 minutes  
**Project Type**: Any (examples use Prose and Fiction)  
**Difficulty**: Advanced  
**Prerequisites**: A project with written content ready for export

## What You'll Learn

- Setting up page layout (margins, paper size, headers, footers)
- Configuring paragraph styles with the Stylesheet Editor
- Working with footnotes
- Building a table of contents
- Assembling front matter and back matter
- Exporting to PDF with professional pagination

## Step 1: Set Up Page Layout

Start with the physical page dimensions and margins.

### Open Page Setup
1. Open **Project Settings** (⚙️)
2. Select **Page Setup**

### Choose Paper Size
Select a standard size for your manuscript type:

| Manuscript Type | Recommended Size |
|----------------|-----------------|
| Standard submission | US Letter (8.5" × 11") or A4 |
| Novel (trade paperback) | 6" × 9" |
| Poetry chapbook | 5.5" × 8.5" (Digest) |
| Academic paper | A4 or US Letter |

### Set Margins
Standard manuscript margins:
- **Top**: 1 inch (2.54 cm)
- **Bottom**: 1 inch
- **Left**: 1.25 inches (slightly wider for binding)
- **Right**: 1 inch

Adjust as needed for your target publication's guidelines.

### Configure Headers and Footers
1. In Page Setup, find **Headers & Footers**
2. Common configurations:
   - **Header**: Author surname / Title (left), Page number (right)
   - **Footer**: Empty (or page number centered)
3. Set header/footer margins (typically 0.5 inches from edge)

**Tip**: Front matter pages typically use Roman numeral page numbers (i, ii, iii...) while body matter uses Arabic numerals (1, 2, 3...). Writing Shed Pro handles this automatically when you use the Manuscript folder structure.

## Step 2: Configure Paragraph Styles

The Stylesheet Editor controls how every paragraph type looks in your exported document.

### Open the Stylesheet Editor
1. Open **Project Settings**
2. Select **Stylesheet**

### Key Styles to Configure

#### Body Text
- **Font**: Times New Roman 12pt (standard submission) or your preferred book font
- **Line spacing**: Double (submissions) or 1.5 (book)
- **First-line indent**: 0.5 inches (standard for prose)
- **Space after**: Minimal for prose; more for non-fiction

#### Heading 1 (Chapter Titles)
- **Font**: Same family or complementary, 18–24pt
- **Alignment**: Centered
- **Space before**: Start new page (page break)
- **Space after**: 2–3 lines

#### Heading 2 (Section Headings)
- **Font**: Same family, 14–16pt
- **Alignment**: Left or centered
- **Space before**: 1–2 lines
- **Space after**: 1 line

#### Block Quote
- **Left indent**: 0.5 inches
- **Right indent**: 0.5 inches
- **Font size**: Same or slightly smaller than body
- **Italic**: Optional

### Save Your Stylesheet
Changes save automatically. The stylesheet applies to all files in the project — edit once, format everywhere.

## Step 3: Add Footnotes

Footnotes are valuable for academic writing, historical fiction, and annotated editions.

### Insert a Footnote
1. Place your cursor where the footnote marker should appear
2. Tap the **Insert Note** button (📝) in the formatting toolbar
3. Select **Footnote**
4. A numbered marker appears in the text
5. Type the footnote content in the footnote panel

### Footnote Tips
- Footnotes are numbered automatically and renumber if you add or remove them
- During PDF export, footnotes appear at the bottom of the page where they're referenced
- Keep footnotes concise — save lengthy discussions for endnotes

### Endnotes
For endnotes (all notes collected at the end):
- Write your footnotes as normal
- In **Export Options**, select **Endnotes** instead of Footnotes
- They'll be collected into the Back Matter automatically

## Step 4: Build a Table of Contents

A Table of Contents (TOC) helps readers navigate longer works.

### Automatic TOC
Writing Shed Pro can generate a TOC from your heading styles:

1. Open **Manuscript** → **Front Matter**
2. Open the **Table of Contents** file
3. Mark it as a TOC file (if not already set)
4. Configure TOC settings:
   - **Depth**: How many heading levels to include (1 = chapters only, 2 = chapters + sections)
   - **Style**: Dotted leaders, page numbers right-aligned

The TOC generates automatically during PDF export, pulling chapter titles and page numbers from your body matter.

### Manual TOC
For complete control, write your own TOC:
1. Open the Table of Contents file
2. Type chapter titles and placeholder page numbers
3. Update page numbers after a test export

## Step 5: Set Up Front Matter

Front matter appears before your main content. Open **Manuscript** → **Front Matter** and populate the files you need:

### Recommended Front Matter (in order)

1. **Title Page**
   - Book title (large, centered)
   - Author name
   - Publisher/imprint (if applicable)

2. **Copyright**
   ```
   © 2026 [Your Name]
   All rights reserved.
   
   Published by [Publisher]
   ISBN: [number]
   
   No part of this publication may be reproduced...
   ```

3. **Dedication** — Brief, personal

4. **Table of Contents** — Auto-generated or manual

5. **Acknowledgments** — Thank contributors, editors, supporters

You don't need all of these — only files with content are included in the export.

## Step 6: Set Up Back Matter

Back matter appears after your main content. Open **Manuscript** → **Back Matter**:

### Auto-Generated Back Matter
Writing Shed Pro can generate these automatically from your content:

- **Endnotes**: Collected from footnotes (if you chose endnotes over footnotes)
- **Glossary**: From glossary entries you've defined
- **Index**: From index markers in your text
- **References/Bibliography**: From reference entries

### Manual Back Matter

- **Contributors**: For multi-author works — add and format contributor bios using the Contributors feature
- **About the Author**: Write a brief author biography
- **Also By**: List your other published works

### Configure Back Matter Order
In the Back Matter folder, reorder items to match your publisher's requirements. Common order:
1. Endnotes
2. Glossary
3. Bibliography/References
4. Index
5. About the Author

## Step 7: Assemble Body Matter

Your main content needs to be in the Body Matter folder:

1. Open **Manuscript** → **Body Matter**
2. Add your content items:
   - **Prose**: Add sections in reading order
   - **Fiction**: Add chapters in reading order
   - **Poetry**: Add collections and/or individual poems
   - **Drama**: Add acts in performance order
3. Reorder as needed

### Exclude Files from Manuscript
If a file shouldn't appear in the manuscript (notes, drafts, alternate versions):
1. Open the file's context menu
2. Toggle **Include in Manuscript** off
3. The file stays in your project but is skipped during assembly

## Step 8: Preview and Adjust

Before the final export, preview everything:

1. Open **Export Options**
2. Tap **Preview**
3. Page through the entire manuscript checking:
   - Title page layout
   - TOC accuracy and formatting
   - Body text formatting consistency
   - Chapter heading appearance
   - Footnote placement
   - Page numbers (Roman in front, Arabic in body)
   - Back matter content and order
   - Overall page count

### Common Adjustments
- **Orphan/widow lines**: Adjust paragraph spacing or rewrite to avoid single lines at page tops/bottoms
- **Chapter starts**: Ensure chapters start on a new page (configured in Heading 1 style)
- **White space**: Check that spacing between elements feels balanced
- **Headers/footers**: Verify they appear correctly and don't show on the title page

## Step 9: Export to PDF

1. Open **Export Options**
2. Select **PDF**
3. Configure final settings:
   - **Include Table of Contents**: Yes/No
   - **Include Endnotes**: If using endnotes
   - **Include Index**: If you've created index entries
   - **Page numbers**: Starting page, format
4. Tap **Export**
5. Choose a save location
6. Review the final PDF in a PDF reader

### Also Export RTF
For submissions that require editable documents:
1. In Export Options, select **RTF**
2. Export alongside your PDF
3. RTF preserves formatting while remaining editable

## What You've Learned

- Setting up page layout for professional output
- Configuring paragraph styles with the Stylesheet Editor
- Adding and managing footnotes
- Building an automatic table of contents
- Assembling front matter, body matter, and back matter
- Previewing the complete manuscript
- Exporting to PDF and RTF

## Professional Manuscript Checklist

Before submitting, verify:

- [ ] Paper size matches publisher requirements
- [ ] Margins are correct (typically 1 inch)
- [ ] Font is readable and standard (Times New Roman 12pt for submissions)
- [ ] Line spacing matches requirements (double for submissions)
- [ ] First-line indent is consistent
- [ ] Chapter headings start on new pages
- [ ] Page numbers are correct (Roman/Arabic)
- [ ] Headers show author/title information
- [ ] Title page is clean and professional
- [ ] Copyright page has correct information
- [ ] TOC page numbers match actual pages
- [ ] Footnotes/endnotes are accurate
- [ ] No orphan/widow lines
- [ ] All intended content is included

## What's Next

- **[Page Setup](../11-advanced-features/103-page-setup.md)** — Full page setup reference
- **[Stylesheet Editor](../11-advanced-features/102-stylesheet-editor.md)** — Complete style configuration
- **[PDF Export](../10-publishing/92-pdf-export.md)** — Detailed PDF export options
- **[RTF Export](../10-publishing/93-rtf-export.md)** — RTF export details
- **[Footnotes](../5-writing/45-footnotes.md)** — Full footnotes reference

---
