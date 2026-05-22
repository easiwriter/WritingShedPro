# Tutorial: Organizing a Large Prose Project

This tutorial walks you through managing a large Prose project in Writing Shed Pro — using sections, search and replace, and manuscript assembly to keep a complex work organized and export-ready.

**Time**: 30–40 minutes  
**Project Type**: Prose  
**Difficulty**: Intermediate  
**Best for**: User guides, essay collections, multi-part articles, research projects, memoirs

## What You'll Learn

- Creating a Prose project for multi-part writing
- Using sections to group related files
- Viewing files grouped by section
- Using search and replace across the project
- Assembling a manuscript from sections
- Exporting the complete document

## Step 1: Create a Prose Project

1. From the project list, tap **+**
2. Name it **"Field Guide to Urban Trees"**
3. Select **Prose** as the project type
4. Tap **Create**

The project opens with the Prose folder structure: Manuscript, Sections, Prose, Collections, Submissions, Research, and more.

For this tutorial, we're writing a reference guide with multiple parts and many files. Prose mode's sections and organization tools are designed for exactly this.

## Step 2: Plan Your Sections

Sections in Prose projects work like chapters in fiction — they group related files into logical units. Plan your structure before writing:

| Section | Contents | Files |
|---------|----------|-------|
| Introduction | Overview, how to use this guide | 2–3 files |
| Broadleaf Trees | Oak, beech, birch, etc. | 8–10 files |
| Coniferous Trees | Pine, spruce, cedar, etc. | 6–8 files |
| Ornamental Trees | Cherry, magnolia, etc. | 5–7 files |
| Appendices | Glossary, further reading | 2–3 files |

### Create Sections
1. Open the **Sections** folder
2. Tap **+**
3. Name it: **"Introduction"**
4. Add a synopsis: *"Overview of urban trees and how to use this guide"*
5. Tap **Create**

Repeat for each section: Broadleaf Trees, Coniferous Trees, Ornamental Trees, and Appendices.

### Reorder Sections
1. In the Sections folder, tap **Edit**
2. Drag sections into your preferred order
3. Tap **Done**

This order determines how sections appear in the file list and (later) in the manuscript.

## Step 3: Create Files and Assign to Sections

### Create Your Files
1. Open the **Prose** folder (your main writing area)
2. Tap **+** to create files:
   - "How to Use This Guide"
   - "English Oak"
   - "Silver Birch"
   - "Scots Pine"
   - "Japanese Cherry"
   - (and more as needed)

### Assign Files to Sections
1. Tap **Edit** in the Prose file list
2. Select one or more files
3. Tap **Assign to Section**
4. Choose the appropriate section

For example:
- "How to Use This Guide" → **Introduction**
- "English Oak" → **Broadleaf Trees**
- "Scots Pine" → **Coniferous Trees**
- "Japanese Cherry" → **Ornamental Trees**

### Batch Assignment
To assign multiple files at once:
1. Tap **Edit** in the file list
2. Select multiple files (e.g., all the broadleaf tree entries)
3. Tap **Assign to Section**
4. Select **Broadleaf Trees**

## Step 4: View Files Grouped by Section

In the main Prose file list, files appear grouped under their section headings:

```
▼ Introduction
    How to Use This Guide
    About Urban Trees
▼ Broadleaf Trees
    English Oak
    Silver Birch
    Common Beech
    Horse Chestnut
▼ Coniferous Trees
    Scots Pine
    Norway Spruce
▼ Ornamental Trees
    Japanese Cherry
    Star Magnolia
▶ Appendices (collapsed)
  Unassigned
    (files not yet assigned to a section)
```

- Tap a section header to **collapse** or **expand** it
- Unassigned files appear at the bottom
- This view gives you an overview of the project's structure

## Step 5: Write Your Content

Now write! Open any file and start. A few tips for large projects:

### Use Consistent Structure
For a reference guide, each tree entry might follow a template:

```
# English Oak

## Identification
- **Height**: 20–40 meters
- **Leaves**: Lobed, 10–12 cm long
- **Bark**: Grey-brown, deeply fissured

## Where to Find It
Common in parks, streets, and gardens throughout the UK...

## Interesting Facts
The English oak can live for over 1,000 years...
```

Consistent structure makes the final document feel cohesive.

### Use Heading Styles
Apply heading styles (Heading 1, Heading 2, Heading 3) consistently:
- **Heading 1**: Tree name (generates TOC entries)
- **Heading 2**: Section within each entry
- **Heading 3**: Sub-sections if needed

These headings matter for the auto-generated table of contents.

## Step 6: Search and Replace Across the Project

When writing a large project, you'll often need to make consistent changes across many files. For example, you realize you've been inconsistently writing "metres" and "meters".

### Open Search and Replace
1. Tap the **Search** icon in the toolbar (🔍)
2. Enter your search term: `meters`
3. Enter the replacement: `metres`

### Search Across All Files
1. Ensure **Search in Project** is selected (not just the current file)
2. Tap **Find All**
3. See all occurrences across every file, grouped by file name
4. Review each match in context

### Replace Carefully
- **Replace one at a time**: Tap **Replace** for each match to review it
- **Replace All**: Use with caution — preview results first
- **Case-sensitive search**: Enable if you need to match exact capitalization

### Other Search Use Cases
- Find all mentions of a topic across your guide
- Locate inconsistent spelling or terminology
- Find placeholder text you need to fill in (search for "TODO" or "TBD")

## Step 7: Reorder Files Within Sections

Control the reading order within each section:

1. Open the **Sections** folder
2. Tap a section (e.g., **Broadleaf Trees**)
3. See the files assigned to it
4. Tap **Edit**
5. Drag files into your preferred order (e.g., alphabetical, or by importance)
6. Tap **Done**

This order determines the manuscript reading order within each section.

## Step 8: Assemble the Manuscript

Now bring everything together for export:

### Add Sections to Body Matter
1. Open **Manuscript** → **Body Matter**
2. Tap **+**
3. Add sections in reading order:
   - Introduction
   - Broadleaf Trees
   - Coniferous Trees
   - Ornamental Trees
   - Appendices
4. Each section expands to show its files

### Exclude Work-in-Progress Files
If some files aren't ready for the manuscript:
1. Open the file's context menu
2. Toggle **Include in Manuscript** off
3. The file is skipped during assembly but remains in your project

### Set Up Front Matter
1. Open **Manuscript** → **Front Matter**
2. Add content to:
   - **Title Page**: Book title, author name
   - **Table of Contents**: Mark as TOC file for auto-generation
   - **Introduction or Preface**: If separate from the main Introduction section

### Set Up Back Matter
1. Open **Manuscript** → **Back Matter**
2. Useful for a guide:
   - **Glossary**: Define terms
   - **Index**: Add index markers to your content, then enable auto-generation
   - **References**: Cite sources

## Step 9: Export the Complete Document

1. Open **Export Options**
2. Select **PDF**
3. Configure:
   - **Include Table of Contents**: Yes (auto-generated from headings)
   - **Include Index**: If you've added index markers
   - **Page numbers**: Yes
4. Preview the output — check:
   - Sections appear in correct order
   - Files within sections are properly ordered
   - TOC is accurate
   - Page numbering is correct
5. Export

For an editable version, also export as **RTF**.

## What You've Learned

- Creating a Prose project for large, multi-part writing
- Using sections to organize files into logical groups
- Assigning files to sections individually or in batches
- Viewing files grouped by section for structural overview
- Searching and replacing across the entire project
- Reordering files within sections
- Assembling body matter from sections
- Exporting a complete, structured document

## Tips for Large Projects

- **Consistent naming**: Use clear, descriptive file names — you'll have many files
- **Section synopses**: Add synopses to sections to remind yourself what goes where
- **Regular organization**: Assign files to sections as you create them, not all at the end
- **Use the grouped view**: The section-grouped file list is your project dashboard
- **Search is your friend**: In a 50+ file project, Search and Replace keeps consistency manageable
- **Exclude generously**: Keep reference notes and drafts in the project but out of the manuscript

## What's Next

- **[Working with Sections](../6-prose-features/52-working-with-sections.md)** — Full sections reference
- **[Manuscript Structure](../4-projects/36-manuscript-structure.md)** — Body matter details
- **[Search and Replace](../11-advanced-features/101-search-and-replace.md)** — Advanced search features
- **[Tutorial: Formatting a Professional Manuscript](138-tutorial-professional-manuscript.md)** — Advanced export settings

---
