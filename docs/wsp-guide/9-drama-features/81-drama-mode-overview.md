# Drama Mode Overview

Drama projects in Writing Shed Pro provide specialized tools for playwrights and screenwriters. This overview explains the features available for writing scripts.

## What Makes Drama Mode Special

Drama mode understands script writing needs:
- **Dialogue formatting**: Character names, dialogue, and directions
- **Industry formats**: Film/screenplay and stage play styles
- **DML markup**: Easy-to-write source that renders professionally
- **Scene structure**: Organize your script logically

## Creating a Drama Project

1. From the project list, tap **+**
2. Enter a project name
3. Select **Drama** as the project type
4. Optionally select a story structure
5. Tap **Create**

## Story Structures

Drama projects support the same story structures as Fiction:

### Freeform

No predefined stages—organize your plot however you like.

### Three-Act Structure

Classic narrative structure:

1. **Act 1 - Setup**: Introduce world and characters, inciting incident
2. **Act 2 - Confrontation**: Rising action, complications
3. **Act 3 - Resolution**: Climax and conclusion

### The Monomyth (Hero's Journey)

Christopher Vogler's 12-stage adaptation of the Hero's Journey from *The Writer's Journey*:

1. Ordinary World
2. Call to Adventure
3. Refusal of the Call
4. Meeting the Mentor
5. Crossing the Threshold
6. Tests, Allies, Enemies
7. Approach to the Inmost Cave
8. Ordeal
9. Reward
10. The Road Back
11. Resurrection
12. Return with the Elixir

You can change the structure at any time in Project Settings.

### Using Structures in Drama

Plot elements in your drama project can be linked to structure stages:

- Create plot elements for key story beats
- Assign each to a monomyth stage or three-act stage
- Connect plot elements to scenes
- Use the structure to track your script's arc

## Drama Project Structure

```
Project
├── Manuscript (Front Matter, Body Matter, Back Matter)
├── Scenes (filtered by workflow status)
├── Acts (group scenes into acts)
├── Plot Elements
├── Characters
├── Locations
├── Submissions
├── Research
├── Publishers / Agents
├── Other
└── Trash
```

Drama projects share structure with Fiction projects, as scripts have similar organizational needs.

## Script Format Options

Choose how your script is rendered:

### Film/Screenplay Format
Industry-standard screenplay format:
- INT./EXT. scene headings
- Centered character names
- Dialogue with specific margins
- Right-aligned transitions

### Stage Play Format
Traditional theatrical format:
- ACT/Scene headings
- Character names in caps
- Italicized stage directions
- Different margin conventions

### Changing Format
1. Open Project Settings
2. Select **Script Format**
3. Choose Film or Stage
4. Your DML source renders in the new format

The same source works for both—only the output changes.

## Drama Markup Language (DML)

DML is a simple markup that lets you write dialogue naturally:

### Basic Example
```
# ACT I, Scene 1
@ LOCATION: Living Room
= Night, raining

> A modest living room. JOHN stands by the window.

JOHN
(hesitantly)
I don't think we should go.

MARY
We don't have a choice.
```

This renders as professional script format based on your settings.

See [DML Reference](84-dml-reference.md) for complete syntax.

## Core Concepts

### Scenes
Like fiction, drama is built from scenes:
- Each scene file contains DML content
- Scenes are organized into acts (chapters)
- Preview shows formatted output

### Acts
The equivalent of chapters:
- Group related scenes
- Organize your script structure
- Traditional theatrical divisions

### Scene Grouping by Act

When viewing all scenes in a Drama project, scenes are automatically grouped under their assigned act in collapsible sections:

- Each section shows a theater masks icon, act name, and scene count
- Tap a section header to expand or collapse it
- Use the expand/collapse all button in the toolbar
- Unassigned scenes appear in a separate "Unassigned" section

This gives you an at-a-glance view of your script structure without navigating into individual acts.

### Characters
Define your dramatis personae:
- Character names
- Descriptions
- Relationships
- Notes

### Locations
Your settings and places:
- Location names
- Descriptions
- Practical notes for production

## Drama Workflow

### 1. Create Characters and Locations
Before writing, define:
- Your main characters
- Key locations
- This helps with consistency

### 2. Write Scenes
- Use DML markup
- Focus on dialogue and action
- Let formatting happen automatically

### 3. Organize
- Group scenes into acts
- Arrange in performance order
- Review the full script

### 4. Export
- Choose film or stage format
- Generate PDF or print
- Share your script

## Live Preview

As you write in DML:
- Preview shows formatted output
- See how dialogue will look
- Check scene headings and transitions

Toggle between:
- Source view (DML markup)
- Preview (formatted script)

## Differences from Fiction

| Aspect | Fiction | Drama |
|--------|---------|-------|
| Content | Prose narrative | Dialogue and directions |
| Markup | Standard text | DML formatting |
| Output | Manuscript | Script format |
| Chapters | Reader divisions | Acts (performance divisions) |

## Getting Started Tips

### Learn DML Basics
Start with simple scenes:
- Scene heading
- A few characters
- Basic dialogue

### Study Script Format
Read professional scripts to understand:
- How dialogue is spaced
- When to use parentheticals
- How to write action lines

### Use Both Formats
Try rendering in both film and stage:
- See how the same content adapts
- Understand the differences
- Choose appropriately for your target

## See Also
- [Script Formatting](82-script-formatting.md)
- [Film vs Stage Formats](83-film-vs-stage-formats.md)
- [DML Reference](84-dml-reference.md)
- [Manuscript and Export](85-manuscript-and-export.md)

---
