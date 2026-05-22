# Manuscript and Export (Drama)

This guide covers how Writing Shed Pro assembles Drama project content into a manuscript for export.

## How Drama Manuscripts Are Assembled

Drama manuscripts use an **act-and-scene** assembly model:

1. **Front Matter** is placed first (Title Page, Copyright, etc.)
2. **Scenes** are assembled by act, in scene order
3. **Standalone scenes** (not assigned to an act) are appended at the end
4. **Back Matter** is appended (Endnotes, Glossary, Bibliography, Index)

### Act Ordering

If your project uses acts:
1. Each act is processed in **act order** (as arranged in the Chapters/Acts list)
2. Within each act, scenes appear in **scene order**
3. Scenes not assigned to any act are appended after all acts

If your project has no acts, all scenes are assembled in their list order — similar to Short Fiction.

### DML Rendering

Unlike other project types where content is stored as rich text, Drama content is written in **Drama Markup Language (DML)**. During manuscript assembly:
1. Each scene's DML source is parsed
2. The markup is rendered into formatted script output
3. The script format (Film or Stage) determines the visual layout

This means the same source content produces different manuscript output depending on your script format setting.

### What Gets Included

By default, all scenes are included. You can exclude individual scenes:
1. Open the scene's context menu
2. Toggle **Include in Manuscript** off
3. The scene stays in your project but is skipped during assembly

This is useful for deleted scenes you want to keep for reference, or alternate versions.

## Previewing the Manuscript

Before exporting:
1. Open the **Manuscript** view
2. Review the assembled content in your chosen script format
3. Check that acts and scenes are in the correct order
4. Verify DML rendering looks correct
5. Confirm standalone scenes appear where expected

## Script Format in the Manuscript

Your project's script format setting controls how the manuscript renders:

### Film/Screenplay Format
- Scene headings: `INT./EXT. LOCATION - TIME`
- Character names centred above dialogue
- Dialogue with specific margins
- Transitions right-aligned
- Roughly 1 page = 1 minute of screen time

### Stage Play Format
- Act and scene headings
- Character names in caps
- Stage directions in italics or parentheses
- Different margin conventions

### Changing Format
You can switch format before exporting without altering your DML source:
1. Open **Project Settings**
2. Change **Script Format** (Film or Stage)
3. The manuscript re-renders in the new format

## Scene Breaks

Control how scenes are separated within an act:

| Break Style | Appearance |
|-------------|------------|
| **Page Break** | Each scene starts on a new page |
| **Section Mark** | Centred mark between scenes |
| **Double Space** | Extra blank line between scenes |
| **None** | Scenes flow together continuously |

For screenplays, scenes typically flow continuously. For stage plays, a new scene within an act may start with a heading but no page break.

## Act and Scene Headings

You can control whether structural headings appear in the output:
- **Include Section Headings**: Show act names as headings
- **Include File Titles**: Show scene titles as headings

For film scripts, you typically don't use act headings (the scene heading `INT./EXT.` serves as the divider). For stage plays, act and scene headings are traditional.

## Export Formats

Drama manuscripts can be exported in all available formats:

| Format | Best For |
|--------|----------|
| **PDF** | Industry submissions, table reads, archival — preserves exact script layout |
| **RTF** | Collaboration, editable in Word or Final Draft |
| **HTML** | Online sharing, web publication |
| **Markdown** | Plain text archives |

### Why PDF Is Standard for Scripts
Script formatting relies on precise margins and spacing (especially for the 1 page = 1 minute rule in film). PDF preserves this exactly. Other formats may alter margins and spacing.

### Exporting
1. Open the Manuscript view
2. Tap the export/share button
3. Choose your format
4. Configure options (page setup, back matter toggles)
5. Save or share

## Footnote Numbering

Choose how footnotes are numbered across the manuscript:
- **Per File**: Numbering restarts in each scene
- **Continuous**: Sequential numbering across the entire manuscript

## Tips

### Use Acts for Structure
Acts are the natural divisions of a script. Assign scenes to acts to keep your manuscript organised and ensure the correct assembly order.

### Keep DML Clean
Well-structured DML source produces clean manuscript output. See the [DML Reference](84-dml-reference.md) for syntax details.

### Preview Both Formats
If you're considering both film and stage production, preview the manuscript in each format to see how your script translates.

### Standalone Scenes
Unassigned scenes appear at the end of the manuscript. If this isn't what you want, assign them to an act or exclude them from the manuscript.

### Check Page Count (Film)
For screenplays, review the page count in the manuscript preview. The 1 page ≈ 1 minute guideline helps estimate runtime.

## See Also
- [Drama Mode Overview](81-drama-mode-overview.md)
- [Script Formatting](82-script-formatting.md)
- [Film vs Stage Formats](83-film-vs-stage-formats.md)
- [DML Reference](84-dml-reference.md)
- [Manuscript Structure](../4-projects/36-manuscript-structure.md)
- [Export Options](../10-publishing/91-export-options.md)

---
