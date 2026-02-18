# What's New

This section highlights the latest features and improvements in Writing Shed Pro.

## Version 1.0

Welcome to the first release of Writing Shed Pro! Here's everything you can do:

### Core Features
- Create and manage writing projects
- Organize work in folders with drag-to-reorder support
- Rich text editing with bold, italic, underline, and strikethrough
- Customizable paragraph styles with stylesheet editor
- iCloud sync across all your devices

### Poetry Tools
- Smart poetry templates for 30+ traditional forms
- Real-time syllable counting
- Stress pattern analysis for metered verse
- Rhyme scheme visualization
- Form reference panel while writing

### Fiction Tools
- Novel and short fiction project types
- Scene and chapter management
- Plot element tracking with story structure templates
- Character and location management
- Monomyth (Hero's Journey) support

### Drama Tools
- Drama Markup Language (DML) for easy script writing
- Film and stage play format output
- Automatic dialogue formatting
- Scene headings and transitions

### Publishing
- PDF and RTF export
- Professional pagination
- Footnotes with page positioning
- Printing support on iOS and macOS
- Collection and submission tracking

### Search and Replace
- Find text in files, collections, or entire projects
- Case-sensitive and whole-word options
- Regular expression support
- Replace across multiple files

## Version 1.1

### Poetry Collections
- **Poetry Collections are now first-class entities** — dedicated PoetryCollection model with their own names, synopses, and file links
- **Collections folder** is now exclusive to Poetry projects (removed from Fiction and Short Fiction)
- Collections can be added to the manuscript body matter for assembly and export
- Old submission-based collections are automatically migrated to the new model

### Verse Novel
- **New fiction class: Verse Novel** — a novel written in verse, organized by Books and Episodes
- Each episode uses the poetry editor for verse writing
- Full manuscript assembly with poetry formatting
- Books and episodes support body matter ordering

### Body Matter
- **Unified "Body Matter" folder** — all project types now use a single "Body Matter" subfolder inside Manuscript (replaces the old type-specific names like "All Poems", "All Chapters", etc.)
- **Body Matter view** — add, remove, and reorder items in your manuscript body with a dedicated management interface
- Poetry collections and fiction books can be included in body matter for manuscript assembly
- Legacy folder names are automatically renamed during migration

### Scene Grouping
- **Fiction scenes grouped by chapter** — when viewing all scenes, they appear in collapsible sections organized by chapter with expand/collapse controls
- **Drama scenes grouped by act** — same collapsible grouping for drama projects, with scenes organized under their assigned acts
- Unassigned scenes appear in a separate section
- Expand/collapse all button in the toolbar for quick navigation

### Notification Reminders
- **Submission reminders** — set a date-based reminder for any submission to receive a notification
- **Deadline reminders** — set reminders for publication deadlines (magazines and competitions)
- Reminders use the system notification center with alert and sound
- Manage reminders from submission and publication detail views

### Other Improvements
- Improved manuscript assembly for all project types
- Migration service ensures smooth upgrades from version 1.0
- CloudKit-safe migration (idempotent, no data loss)

## Coming Soon

We're continually improving Writing Shed Pro. Features in development include:

- Markdown import and export
- WSP Reader companion app
- Enhanced collaboration tools
- Additional export formats

## See Also
- [Introduction](11-introduction.md)
- [Quick Start Guide](13-quick-start-guide.md)

---
