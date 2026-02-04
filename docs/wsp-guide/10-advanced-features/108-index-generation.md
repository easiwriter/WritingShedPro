# Index Generation

The Index feature in Writing Shed Pro allows you to create professional book indexes that automatically calculate page numbers based on your manuscript pagination.

## Overview

An index is an alphabetical list of terms with page numbers showing where each term appears in your document. Writing Shed Pro's index system supports:

- **Invisible markers** - Index markers don't clutter your text
- **Hierarchical entries** - Up to 3 levels of sub-entries
- **Cross-references** - "See" and "See also" references
- **Primary references** - Bold page numbers for main discussions
- **Automatic page ranges** - Consecutive pages shown as "45-47"

## Creating Index Entries

### From Selected Text

1. Select the word or phrase you want to index
2. Right-click and choose **Add to Index**, or press **⌘⇧X**
3. In the dialog:
   - The keyword is pre-filled from your selection
   - Optionally choose a parent entry for hierarchical indexing
   - Toggle **Primary Reference** if this is a main discussion of the topic
4. Click **Save**

An invisible marker is inserted at the cursor position. The marker won't affect your document's appearance.

### Without Selection

1. Place your cursor where you want the index reference
2. Use **Insert → Add Index Entry** or press **⌘⇧X**
3. Type the keyword
4. Configure options and click **Save**

## Managing Index Entries

Access the Index panel from **Insert → Index** or **View → Index List**.

### Viewing Entries

- Entries are grouped alphabetically by first letter
- Each entry shows its reference count and any sub-entries
- Use the search bar to filter entries
- Sort by: Alphabetical, Date Added, Date Modified, or Most Used

### Editing Entries

1. Tap the **⋯** button on an entry
2. Choose **Edit**
3. Modify the keyword, parent, or cross-references
4. Click **Save**

Changes apply to all references in your document.

### Navigating to References

1. Tap an entry to see its reference locations
2. Use **Jump to Reference** to navigate to that location
3. The cursor moves to the index marker in your text

### Merging Entries

To combine duplicate entries:

1. Tap **⋯** on the entry to merge from
2. Choose **Merge Into...**
3. Select the target entry
4. All references transfer to the target entry

### Deleting Entries

1. Tap **⋯** on the entry
2. Choose **Delete**
3. Confirm deletion

All markers for that entry are removed from your document.

## Hierarchical Index

Create up to 3 levels of nested entries:

```
Animals
  Dogs
    Puppies
  Cats
```

### Creating Sub-entries

1. When adding an entry, select a **Parent Entry** from the picker
2. The new entry appears indented under its parent in the index

### Depth Limits

- Level 1: Top-level entries (e.g., "Animals")
- Level 2: First-level sub-entries (e.g., "Dogs")
- Level 3: Second-level sub-entries (e.g., "Puppies")

Entries at level 3 cannot have children.

## Cross-References

### "See" References

Redirect readers from one term to another:
- "Dogs. See Animals"
- No page numbers shown for the redirecting entry

To add a "See" reference:
1. Edit the entry
2. In the **See Reference** field, enter the term to redirect to

### "See Also" References

Point readers to related terms:
- "Dogs, 12, 45. See also Cats, Puppies"

To add "See Also" references:
1. Edit the entry
2. In the **See Also** section, select related entries

## Primary References

Mark important page references as "primary" to display them in **bold**:

- "Dogs, 12, **45-47**, 89"

The bold pages indicate the main discussion of the topic.

To mark a primary reference:
1. When adding a reference, toggle **Primary Reference**
2. The page number(s) for that marker appear bold in the generated index

## Index in Back Matter

The index appears automatically in your manuscript's back matter when exporting:

### PDF Export
- Full alphabetical index with page numbers
- Sub-entries properly indented
- Primary references in bold
- Page ranges formatted (e.g., "45-47")

### RTF/Word Export
- Index included as appendix section
- Page numbers preserved

### HTML Export
- Index with clickable links to each reference location

### Plain Text Export
- Index with chapter/section references

## Settings

Enable or configure the Index from project settings:
1. Go to **Project Settings → Back Matter**
2. Toggle **Index** on or off
3. The index appears in exports when enabled

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Add Index Entry | ⌘⇧X |
| View Index List | Via Insert menu |

## Tips

- **Be consistent** - Use the same keyword format throughout
- **Use autocomplete** - Start typing to see matching existing entries
- **Group related terms** - Use sub-entries for topics with multiple aspects
- **Mark primary discussions** - Readers can quickly find main content
- **Review before export** - Check the Index panel for orphaned entries
