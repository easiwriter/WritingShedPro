# Index Generation

The Index feature in Writing Shed Pro allows you to create professional book indexes that automatically calculate page numbers based on your manuscript pagination.

## Overview

An index is an alphabetical list of terms with page numbers showing where each term appears in your document. Writing Shed Pro's index system supports:

- **Invisible markers** - Index markers don't clutter your text
- **Hierarchical entries** - Up to 3 levels of sub-entries
- **Cross-references** - "See" and "See also" references
- **Primary references** - Bold page numbers for main discussions
- **Automatic page ranges** - Consecutive pages shown as "45–47"
- **Find Occurrences** - Search and mark multiple mentions of a term

## Creating Index Entries

When Index is enabled in your Back Matter settings, an index button (![index icon](list.bullet.indent)) appears in the formatting toolbar.

### From Selected Text

1. Select the word or phrase you want to index
2. Tap the **Index** button in the formatting toolbar, or press **⇧⌘X**
3. In the dialog:
   - The keyword is pre-filled from your selection
   - Optionally choose a parent entry for hierarchical indexing
   - Toggle **Primary Reference** if this is a main discussion of the topic
4. Click **Save**

An invisible marker is inserted at the cursor position. The marker won't affect your document's appearance.

### Without Selection

1. Place your cursor where you want the index reference
2. Tap the **Index** button in the toolbar, or press **⇧⌘X**
3. Type the keyword
4. Configure options and click **Save**

## Viewing the Index

Navigate to your project's **Back Matter** folder and tap the **Index** file. This displays a live preview of your index with:

- Entries grouped alphabetically by first letter
- Hierarchical display with sub-entries indented
- Real page numbers calculated from your manuscript's pagination
- Cross-references displayed inline ("see" and "see also")

### Page Number Display

Page numbers are calculated using the same pagination engine as your manuscript export:

- Numbers reflect actual page positions based on your Page Setup settings
- Consecutive pages collapse into ranges (e.g., "23–25")
- While page numbers are calculating, a reference count icon shows how many markers exist

## Managing Index Entries

From the Index back matter view, tap the **⋯** button on any entry to access:

### Edit

Modify the entry's keyword, parent assignment, or cross-references. Changes apply to all references throughout your document.

### Find Occurrences

Search your entire manuscript for additional mentions of the keyword:

1. Tap **⋯** → **Find Occurrences**
2. The app searches all body files for matching text (case-insensitive)
3. Review the list of found occurrences, each showing:
   - The file name
   - Context snippet with the match highlighted
   - Whether it's already marked
4. Use checkboxes to select which occurrences to mark
5. Tap **Mark Selected** to insert index markers at all selected locations

This is particularly useful for names, places, or technical terms that appear multiple times—you can review each occurrence in context and decide which are significant enough to index.

**Note:** Already-marked occurrences appear in orange and cannot be selected again.

### Delete

Remove the entry and all its markers from your document. A confirmation dialog shows how many references will be removed.

## Hierarchical Index

Create up to 3 levels of nested entries:

```
Animals
    Dogs
        Puppies
    Cats
```

### Creating Sub-entries

1. When adding or editing an entry, select a **Parent Entry** from the picker
2. The entry appears indented under its parent in the index view

### Depth Limits

- **Level 1**: Top-level entries (e.g., "Animals")
- **Level 2**: Sub-entries (e.g., "Dogs") — can have children
- **Level 3**: Sub-sub-entries (e.g., "Puppies") — cannot have children

The parent picker only shows entries that can accept children (levels 1 and 2).

## Cross-References

### "See" References

Redirect readers from one term to another:

> Dogs. *See* Animals

When an entry has a "see" reference, no page numbers are shown—the reader is directed to look up the other term instead.

To add a "See" reference:
1. Edit the entry
2. In the **See Reference** field, select the target entry

### "See Also" References

Point readers to related terms while still showing page numbers:

> Dogs, 12, 45. *See also* Cats, Puppies

To add "See Also" references:
1. Edit the entry
2. In the **See Also** section, select one or more related entries

Cross-references appear in purple in the index preview.

## Primary References

Mark important page references as "primary" to indicate the main discussion of a topic. In traditional print indexes, primary references appear in **bold**:

> Dogs, 12, **45–47**, 89

To mark a primary reference:
1. When adding a new reference, toggle **Primary Reference** on
2. That marker's page number will be emphasised in the generated index

## Index in Back Matter

The index is automatically included in your manuscript exports when enabled in Back Matter settings.

### Viewing Before Export

The Back Matter Index file shows a live preview with calculated page numbers, letting you verify your index is complete and correctly structured before exporting.

### PDF Export

- Full alphabetical index with accurate page numbers
- Sub-entries properly indented
- Primary references in bold
- Consecutive pages shown as ranges (e.g., "45–47")

### Other Export Formats

- **RTF/Word**: Index included as appendix section
- **HTML**: Index with internal links to reference locations
- **Plain Text**: Index with section references

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Add Index Entry | ⇧⌘X |

## Best Practices

### Be Consistent
Use the same keyword format throughout. "United Kingdom" and "UK" create separate entries—pick one and stick with it, or use cross-references.

### Use Hierarchical Entries
Group related terms under parent entries. Instead of separate entries for "border collie", "labrador", and "poodle", create them as sub-entries under "Dogs".

### Mark Primary Discussions
When a topic has multiple page references, mark the main discussion as primary so readers can quickly find substantive content.

### Review with Find Occurrences
After creating an entry, use **Find Occurrences** to locate other mentions. Not every mention needs indexing—a passing reference may not warrant inclusion—but this ensures you don't miss significant discussions.

### Check Before Export
Review the Index back matter view before exporting. Look for:
- Entries with zero references (may need markers added)
- Inconsistent capitalisation or spelling
- Missing cross-references for related terms

---