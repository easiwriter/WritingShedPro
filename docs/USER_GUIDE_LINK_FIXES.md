# User Guide Link Fixes

**Date:** 4 February 2026

## Summary

Updated all internal links in the Writing Shed Pro User Guide to match the new file naming convention. The guide files were renamed from `0X-folder/0Y-file.md` format to `X-folder/XY-file.md` format.

## Files Updated

### TOC and Index Files
- `00-toc.md` - Fixed link to `96-markdown-features.md`
- `index.md` - Completely regenerated with correct paths

### 1-welcome
- `11-introduction.md`
- `12-whats-new.md`
- `13-quick-start-guide.md`

### 2-getting-started
- `21-installation.md`
- `22-creating-your-first-project.md`
- `23-the-interface-tour.md`
- `24-icloud-sync.md`

### 3-projects
- `31-project-types-overview.md`
- `32-creating-projects.md`
- `33-project-settings.md`
- `34-folders-and-files.md`
- `35-organizing-your-work.md`

### 4-writing
- `41-the-editor.md`
- `42-text-formatting.md`
- `43-headings-and-styles.md`
- `44-images.md`
- `45-footnotes.md` - Also removed broken pagination link
- `46-comments.md`
- `47-word-count-and-statistics.md`

### 5-prose-features
- `51-prose-mode-overview.md`
- `52-working-with-sections.md`
- `53-file-organization.md`

### 7-fiction-features
- `74-manuscript-formatting.md`

### 8-drama-features
- `82-script-formatting.md`
- `83-film-vs-stage-formats.md`
- `84-dml-reference.md`

### 9-publishing
- `91-export-options.md`
- `92-pdf-export.md`
- `94-printing.md`
- `95-submission-tracking.md`
- `96-markdown-features.md`

### 10-advanced-features
- `101-search-and-replace.md`
- `102-stylesheet-editor.md`
- `103-page-setup.md`
- `104-collections.md`
- `105-keyboard-shortcuts.md`
- `106-tips-and-tricks.md`

### 11-reference
- `111-keyboard-shortcut-list.md`
- `112-dml-quick-reference.md`
- `113-troubleshooting.md`
- `114-faq.md`

### 12-appendices
- `121-version-history.md`
- `122-credits.md`
- `123-legal.md`

## Link Format Changes

### Cross-folder links (relative paths)
Old format: `../0X-folder/0Y-file.md`
New format: `../X-folder/XY-file.md`

Examples:
- `../01-welcome/02-whats-new.md` → `../1-welcome/12-whats-new.md`
- `../08-advanced-features/02-stylesheet-editor.md` → `../10-advanced-features/102-stylesheet-editor.md`
- `../09-reference/01-keyboard-shortcut-list.md` → `../11-reference/111-keyboard-shortcut-list.md`

### Same-folder links
Old format: `(0Y-file.md)`
New format: `(XY-file.md)`

Examples:
- `(01-introduction.md)` → `(11-introduction.md)`
- `(02-creating-projects.md)` → `(32-creating-projects.md)`

## Folder Mapping

| Old Prefix | New Prefix | Folder Name |
|------------|------------|-------------|
| 01- | 1- | welcome |
| 02- | 2- | getting-started |
| 03- | 3- | projects |
| 04- | 4- | writing |
| 05- | 5- | prose-features |
| 06- | 6- | poetry-features |
| 07- | 7- | fiction-features |
| 08- | 8- | drama-features |
| 07-publishing or 09-publishing | 9- | publishing |
| 08-advanced-features | 10- | advanced-features |
| 09-reference | 11- | reference |
| 10-appendices | 12- | appendices |

## File Number Mapping

Files within each folder use a two-digit prefix where:
- First digit = folder number
- Second digit = file order within folder

Example for folder 4-writing:
- 41-the-editor.md (1st file)
- 42-text-formatting.md (2nd file)
- 43-headings-and-styles.md (3rd file)
- etc.

---
