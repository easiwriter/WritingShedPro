# Project Settings

Every project has settings that control its behavior and appearance. This guide explains what you can configure and how.

## Accessing Project Settings

Open project settings via the **⋯ (ellipsis) button** in the toolbar when a project is open.

## Available Settings

### Project Name

Change the project's display name. Changes sync immediately across devices.

### Author Name

Set the author name for the project. This is used in page headers and footers via the `{{Author}}` placeholder in your page setup template.

### Project Details

Add a description or notes about the project, such as:

- Synopsis or pitch
- Notes to yourself
- Project goals or deadlines

### Date Information (Read-Only)

- **Created**: When the project was first created
- **Modified**: When any content was last changed

## Project Type (Read-Only)

The project type is shown but cannot be changed after creation. This includes:

- Project type (Prose, Poetry, Fiction, Drama)
- Fiction class (Novel, Verse Novel, or Short Fiction) for fiction projects

If you need a different project type, create a new project and move your content.

## Story Structure (Fiction and Drama)

For Fiction and Drama projects, you can change the story structure at any time:

1. Tap **⋯**
2. Tap **Story Structure**
3. Choose from:
   - **Freeform**: No predefined stages
   - **Three-Act**: 3 stages (Setup, Confrontation, Resolution)
   - **Monomyth (Vogler)**: 12 stages from *The Writer's Journey*

### Changing Structure

When you change the structure:

- Existing plot elements keep their stage assignments if the stage exists in the new structure
- Plot elements assigned to stages that don't exist in the new structure are moved to "Unassigned"
- Scene content is not affected

## Script Format (Drama Only)

For Drama projects, choose how scripts are formatted:

1. Tap **⋯**
2. Tap **Script Format**
3. Choose:
   - **Film/Screenplay**: Industry-standard screenplay format
   - **Stage Play**: Traditional stage script format

This affects how Drama Markup Language (DML) is rendered, not how you write it.

## Stylesheet

Each project has a stylesheet that defines text formatting.

1. Tap **⋯**
2. Tap **Stylesheet**

See [Stylesheet Editor](../10-advanced-features/102-stylesheet-editor.md) for details.

## Page Setup

Configure how pages are formatted for export and printing.

1. Tap **⋯**
2. Tap **Page Setup**

See [Page Setup](../10-advanced-features/103-page-setup.md) for details.

## Exporting a Project

To export a project as a `.wsp` file:

1. Tap **⋯**
2. Tap **Export**
3. Choose a save location

The file is saved as `ProjectName.wsp`.

## Duplicating a Project

To make a full copy of a project:

1. Tap **⋯** next to the project in the project list
2. Tap **Duplicate Project**

Writing Shed Pro creates a complete duplicate with a new internal ID, so the copy is independent of the original.

If a project with the same name already exists, the duplicate is automatically renamed with a number suffix.

## Danger Zone

Some settings can cause data loss if used incorrectly.

### Delete Project

- Permanently removes the project and all its contents
- Cannot be undone
- Consider exporting first

### Clear Trash

- Permanently deletes all items in the project's Trash folder
- Cannot be undone

## Settings That Sync

All project settings sync across your devices via iCloud:

- Project name and details
- Story structure
- Script format
- Stylesheet
- Page setup

## See Also

- [Project Types Overview](31-project-types-overview.md)
- [Stylesheet Editor](../10-advanced-features/102-stylesheet-editor.md)
- [Page Setup](../10-advanced-features/103-page-setup.md)

---
