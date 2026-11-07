# Creating Projects

This guide covers everything you need to know about creating new projects in Writing Shed Pro.

## Creating a New Project

### From the Project List

1. Open Writing Shed Pro to the project list
2. Tap the **+** button in the toolbar
3. Fill in the project details (see below)
4. Tap **Create**

### Project Details

#### Project Name

Enter a descriptive name for your project. Examples:

- "2026 Poetry Collection"
- "The Garden Novel"
- "Murder at Midnight - Screenplay"

You can rename the project later if needed.

#### Project Type

Choose from:

- **Prose**: General writing
- **Poetry**: Poems and verse
- **Fiction**: Novels, verse novels, and short stories
- **Drama**: Scripts and plays

See [Project Types Overview](31-project-types-overview.md) for details on each type.

#### Fiction Class (Fiction Only)

When creating a Fiction project, also select:

- **Novel**: For long-form fiction with chapters
- **Short Fiction**: For stories without chapter structure
- **Verse Novel**: For novel-length verse with a book and episode structure

#### Story Structure (Fiction and Drama)

Optionally select a story structure:

- **Freeform**: No predefined structure (default)
- **Three-Act**: Setup, Confrontation, Resolution
- **Monomyth (Vogler)**: 12-stage Hero's Journey

> **Further Reading**: *The Writer's Journey* by Christopher Vogler.

You can change the structure later in Project Settings.

## After Creating a Project

Your new project opens automatically, showing its folder structure. Depending on the project type, you'll see different folders ready for your content.

### What to Do First

1. **Explore the folders**: Understand the organization structure
2. **Create your first file**: Tap a folder, then tap **+**
3. **Start writing**: Open the file and begin

## Project Naming Best Practices

### Be Descriptive

Good names help you find projects quickly:

- ✓ "Spring 2026 Sonnets"
- ✓ "The Lighthouse Keeper Novel"
- ✗ "Untitled"
- ✗ "Project 1"

### Include Context

Add year, genre, or status when helpful:

- "NaNoWriMo 2026"
- "Horror Short Stories"
- "Competition Entry - Flash Fiction"

### Keep It Concise

Long names may be truncated in the project list:

- ✓ "Murder Mystery Novel"
- ✗ "My Amazing Super Long Title That Goes On Forever"

## Project Limits

Writing Shed Pro has no hard limit on the number of projects you can create. However:

- Each project uses iCloud storage
- Very large projects (many images) may sync slowly
- Keep projects focused rather than one massive project

### Recommended Organization

- **Poetry**: One project per year or collection
- **Fiction**: One project per novel or story collection
- **Drama**: One project per screenplay or play

## Importing Projects

You can import `.wsp` project archives and Scrivener `.scriv` project packages into Writing Shed Pro.

### How to Import

1. Choose **Import** from the project list or Settings
2. Select a `.wsp` file or Scrivener `.scriv` package from your device or iCloud Drive
3. The project is imported and appears in your project list

### Importing a Scrivener Project

The importer supports Scrivener 2 packages with numeric document files in `Files/Docs` and Scrivener 3 packages with UUID-based files in `Files/Data`. Scrivener 1 projects using `binder.scrivproj` are not supported directly; convert a copy to Scrivener 3 format in Scrivener before importing. Keep the original project as a backup.

Select the whole `.scriv` folder or package, not the `.scrivx` binder file inside it. On Mac, if the picker shows the project as a folder, select that folder and click **Import** without opening it. Keep the complete project together: document text is stored alongside the binder in `Files/Data`.

Before importing, review the detected project name and binder contents, then choose whether to create a Prose, Fiction, Poetry, or Drama project. Fiction projects also ask for a fiction structure; Drama projects ask for a script format.

The new project has the standard folders for the selected project type. Original Scrivener folders and their nesting are preserved under **Scrivener Binder**, not added as special folders at the project root. For example, a source folder named Characters remains ordinary binder content in a Prose project. Loose documents are kept directly in Scrivener Binder; no extra Imported Documents folder is created.

Top-level binder folders are also mapped to Prose sections, Poetry collections, Fiction chapters/books, or Drama acts, as appropriate. Loose documents share an Imported Documents section or equivalent group. In Prose projects, imported documents are available through both **Prose** and **Sections**; in Poetry projects, they are available through **Poems** and **Collections**, without duplicating the documents. A text document that has child documents is preserved as a folder containing its own text followed by its children. Scrivener documents excluded from Compile remain excluded from the Writing Shed Pro manuscript. These mappings apply to new imports; existing imported projects are not changed automatically.

Research and Trash are optional and are skipped by default. If imported, their files are kept in corresponding folders and excluded from manuscript assembly. Scrivener item types that Writing Shed Pro cannot import are identified in the review sheet and preserved as empty folders.

### Sample Scrivener Projects

To try the importer, download a Scrivener 3 `.scriv` package from the [PRONOM Research sample collection](https://github.com/digital-preservation/PRONOM_Research/tree/main/Submissions/Scrivener/Samples), such as `Scrivener3-s01.scriv`. The [Scrivener Starter project](https://github.com/carsomyr/scrivener_starter) is another reference, but uses an older content layout that the importer does not currently support. These are third-party examples; project layouts and Scrivener versions may differ.

### What's Included in a WSP File

A `.wsp` file contains your complete project:

- All files with their content and formatting
- All file versions, comments, and footnotes
- Folder structure
- Project settings and metadata
- Publications, submissions, and poetry collections
- Fiction structure (books, chapters, acts, scenes, characters, locations)

### What's Not Included

- **Stylesheets**: Projects use the device's stylesheets after import
- **Reference entries**: Notes, glossary terms, index entries, and other references are regenerated from markers in your text
- **Trash contents**: Excluded from export

### Importing Duplicates

Importing a project with the same name as an existing project creates a separate copy with a number appended to the name (e.g. "My Project 2"). Projects are never overwritten or merged during import.

## Exporting Projects

To export a project as a `.wsp` file, see [Project Settings](33-project-settings.md).

See [Export Options](../10-publishing/91-export-options.md) for details on all export formats including WSP.

## See Also

- [Project Types Overview](31-project-types-overview.md)
- [Project Settings](33-project-settings.md)
- [Folders and Files](34-folders-and-files.md)
- [Export Options](../10-publishing/91-export-options.md)

---
