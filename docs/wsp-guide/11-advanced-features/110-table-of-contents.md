# Table of Contents

Writing Shed Pro can automatically generate a Table of Contents (TOC) based on your manuscript structure, showing chapters, sections, and their page numbers.

## Overview

A Table of Contents provides readers with a navigational overview of your manuscript. Writing Shed Pro generates the TOC from your document hierarchy:

- **Automatic generation** - Built from your manuscript folder structure
- **Hierarchical entries** - Shows folders and files
- **Page numbers** - Calculated from actual pagination
- **Customizable display** - Control which levels and items appear

## How the TOC Works

The Table of Contents is generated based on your project structure:

1. **Front Matter** folder contents (if included)
2. **Manuscript** folder structure:
   - Part folders (top-level folders in Manuscript)
   - Chapter folders (subfolders)
   - Individual files (scenes/sections)
3. **Back Matter** folder contents (if included)

### Hierarchical Structure Example

```
PART ONE: THE BEGINNING
    Chapter 1: Discovery .............. 3
        The Letter .................... 3
        First Steps .................. 12
    Chapter 2: The Journey ........... 23
PART TWO: THE MIDDLE
    Chapter 3: Complications ......... 45
```

## Enabling the Table of Contents

### Method 1: Front Matter Item

1. Create or open your **Front Matter** folder
2. Add a **Table of Contents** item via the **+** button or settings
3. The TOC will appear in your front matter, after title pages

### Method 2: Export Settings

1. Go to **Export** settings
2. Enable **Generate Table of Contents**
3. Configure which levels to include

## Configuring Table of Contents

Access TOC settings through the settings gear in the Table of Contents view or through export options.

### Entry Selection

Control which items appear in the TOC:

- **Include Front Matter**: Show front matter items before the main content
- **Include Back Matter**: Show back matter items after the main content
- **Include Parts**: Show top-level manuscript folders (parts/sections)
- **Include Chapters**: Show chapter-level folders
- **Include Scenes**: Show individual files within chapters

### Title Options

- **TOC Title**: The heading text (default: "Contents" or "Table of Contents")
- **Title Style**: Text style from your stylesheet for the heading

### Entry Styles

Different styles can be applied to different hierarchical levels:

- **Part Style**: For top-level divisions (Part One, Part Two)
- **Chapter Style**: For chapter headings
- **Section Style**: For individual scenes or sections

### Page Numbers

- **Show Page Numbers**: Toggle page numbers on or off
- **Dot Leaders**: Use dots or other characters to connect titles to page numbers
- **Page Number Position**: Set the tab stop for alignment

## Manual vs. Automatic TOC

Writing Shed Pro supports two approaches:

### Automatic TOC

- Generated from your folder/file structure
- Updates automatically when you reorganize
- Page numbers recalculate with each export
- **Recommended** for most projects

### Manual TOC

If you need complete control:

1. Create a text file in Front Matter named "Contents" or "Table of Contents"
2. Type your entries manually
3. Mark the file as "Manual" in its settings
4. Update it manually when your manuscript changes

**Note**: Manual TOC entries won't have automatic page numbers.

## Page Number Calculation

TOC page numbers are calculated using the same pagination engine as your manuscript:

1. Based on your **Page Setup** settings (margins, page size, etc.)
2. Reflects actual page breaks in your document
3. Accounts for chapter start rules (e.g., "Start on right page")
4. Updates when you edit content or change settings

### Why Page Numbers May Differ

Page numbers in the TOC preview might differ from your expectations if:

- Your Page Setup hasn't been configured
- Chapter start rules are forcing page breaks
- The manuscript is still being paginated (look for progress indicator)

## Best Practices

### Organize for Clear TOC

Structure your manuscript so the TOC makes sense:

- Use **folders** for chapters (they become TOC entries)
- Name folders clearly ("Chapter 1: The Beginning")
- Use consistent naming conventions

### Managing Long TOC

For manuscripts with many chapters:

- Consider hiding scene-level entries (show only chapters)
- Group chapters into Parts for cleaner organization
- Evaluate if every section truly needs a TOC entry

### Finalizing for Publication

Before final export:

1. Review the TOC preview for accuracy
2. Check that page numbers have finished calculating
3. Verify all chapter names are as you want them displayed
4. Ensure the TOC itself isn't paginating onto multiple pages (adjust content if needed)

## TOC in Different Export Formats

### PDF Export

- Full page layout with proper pagination
- Dot leaders and alignment preserved
- Page numbers link to actual pages in the PDF

### EPUB Export

- Converted to navigational TOC
- May include both inline TOC and navigation TOC
- Page numbers may be adjusted for reflowable format

### Print-Ready Export

- Positioned correctly in front matter
- Roman numerals for front matter pages (if configured)
- Arabic numerals for main content

## Troubleshooting

### TOC Not Showing All Entries

- Check that folders/files aren't marked as "Excluded"
- Verify your entry selection settings (Parts, Chapters, Scenes)
- Ensure items aren't in the Trash

### Page Numbers Missing or Wrong

- Wait for pagination to complete (check for progress indicator)
- Verify Page Setup is configured
- Force refresh by reopening the TOC file

### TOC Appearing in Wrong Location

- Check which matter folder contains the TOC file
- Front Matter → appears before manuscript
- Use export settings to control exact positioning

## Related Topics

- [Manuscript Structure](../4-projects/36-manuscript-structure.md)
- [Page Setup](103-page-setup.md)
- [Exporting Your Work](../9-exporting/91-exporting-overview.md)
- [List of Figures](109-list-of-figures.md)
