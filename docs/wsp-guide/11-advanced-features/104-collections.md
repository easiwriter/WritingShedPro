# Poetry Collections

Poetry Collections let you group related poems together as first-class entities in your Poetry project. Each collection has its own name, synopsis, and list of linked poems, and can be included in your manuscript's body matter for export.

## What Are Poetry Collections?

A Poetry Collection is a dedicated grouping of poems for a specific purpose:
- Poems for a chapbook
- A submission package
- A themed reading set
- Any curated grouping you need

### Collections vs Folders
| Folders | Poetry Collections |
|---------|-------------------|
| Poems live in one folder | Poems can belong to multiple collections |
| Moving poems changes location | Adding to a collection doesn't move the poem |
| Physical organization | Virtual grouping with metadata |
| Hierarchical | Flat (each collection is independent) |

## Where Collections Appear

Collections are available **only in Poetry projects**. Access them through the dedicated **Collections** folder in the project sidebar.

**Note**: Fiction and Drama projects use chapters, books, or acts to organize their content. The Collections folder is not available in those project types.

## Creating a Collection

### From the Collections Folder
1. Open the **Collections** folder
2. Tap **+**
3. Enter a collection name
4. Optionally add a synopsis
5. Tap **Create**

### When Adding Poems
1. Select poems in the Poems folder
2. Choose **Add to Collection...**
3. Select **Create New Collection**
4. Enter a name

## Adding Poems to Collections

### From the Poems Folder (Multiple Poems)
1. Tap **Edit** in the Poems folder
2. Select multiple poems
3. Tap **Add to Collection**
4. Choose the collection

### Drag and Drop (iPad/Mac)
- Drag poems to the Collections folder
- Drop on a specific collection

## Viewing Collection Contents

1. Open the Collections folder
2. Tap a collection
3. See all poems in the collection

### What You See
- Poem titles
- Word counts
- Last modified date

## Removing Poems from Collections

1. Open the collection
2. Select the poem(s) to remove
3. Tap **Remove from Collection**

The poem isn't deleted—it just leaves this collection.

## Renaming Collections

1. Open the Collections folder
2. Tap **Edit**
3. Select the collection
4. Tap **Rename**
5. Enter the new name
6. Tap **Rename**

## Deleting Collections

1. Swipe left on the collection
2. Tap **Delete**
3. Confirm

**Note**: Deleting a collection doesn't delete the poems. They remain in the Poems folder.

## Body Matter Integration

Poetry Collections can be included in your manuscript's body matter for export and assembly:

### Adding to Body Matter
1. Open the **Manuscript** folder
2. Navigate to **Body Matter**
3. Add collections (and/or individual poems) to body matter
4. Reorder items as needed

### How Assembly Works
- Collections in body matter are assembled in their body matter order
- Within each collection, poems are assembled in their collection order
- Individual poems not in any collection can also be added to body matter
- This gives you full control over the manuscript structure

### Why This Matters
- Organize a chapbook with themed sections (each section is a collection)
- Control the exact reading order for export
- Mix collections and standalone poems in your manuscript

## Using Collections for Submissions

Collections integrate with the submission system:

### Workflow
1. Create a collection for your submission
2. Add the poems you want to submit
3. Review and organize
4. Submit the collection to a publication
5. Track the submission status

### Benefits
- Clear record of what was submitted
- Easy to submit the same group elsewhere
- Collections maintain their poem list independently

## Collection Best Practices

### Naming
Use clear, descriptive names:
- "Spring 2026 Contest Entry"
- "Nature Poems Chapbook"
- "Anthology Submission"

### Regular Review
- Remove poems no longer relevant
- Delete obsolete collections
- Update collection synopses

### Avoid Duplication
Instead of copying poems:
- Add the same poem to multiple collections
- Each collection references the poem
- Edits to the poem appear everywhere

## Common Use Cases

### Poetry Chapbook
Collect poems for a chapbook, add the collection to body matter, arrange in reading order, and export as a complete manuscript.

### Contest Entry
Group poems meeting contest criteria. Submit the collection and track the submission status.

### Reading Selection
Assemble poems for a live reading. Order them for performance flow.

### Themed Group
Collect all poems about nature, all sonnets, all work from a particular period, etc.

## Migration from Version 1.0

If you're upgrading from version 1.0, your existing collections are automatically migrated to the new Poetry Collection model. The migration:
- Converts old submission-based collections to dedicated PoetryCollection entities
- Preserves all poem links
- Removes the Collections folder from non-Poetry projects (Fiction, Short Fiction)

## Troubleshooting

### Poem Not Showing in Collection
- Verify the poem was added
- Check if the poem was deleted (it might be in Trash)
- Restore from Trash if needed

### Can't Find Collections Folder
- Collections are only available in Poetry projects
- If you're in a Fiction or Drama project, use chapters, books, or acts instead

### Can't Add to Collection
- Ensure the poem exists in the Poems folder
- Check that the collection exists

## See Also
- [Organizing Your Work](../4-projects/35-organizing-your-work.md)
- [Submission Tracking](../10-publishing/95-submission-tracking.md)
- [Folders and Files](../4-projects/34-folders-and-files.md)
- [Poetry Mode Overview](../7-poetry-features/61-poetry-mode-overview.md)
- [Manuscript Structure](../4-projects/36-manuscript-structure.md)

---
