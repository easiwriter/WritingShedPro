# Feature 028: Markdown Import

**Status**: Draft  
**Priority**: Medium  
**Estimated Effort**: TBD  
**Dependencies**: 001-project-management-ios-macos, 024-hyperlinks  
**Created**: 2026-01-10

## Overview

Add the ability to import Markdown (.md) files and folder structures into WSP projects. This enables users to bring existing content from other tools, version-controlled documentation, and simplifies manual creation (027) by allowing Markdown source files to be converted to WSP format.

## Strategic Value

1. **Content Migration**: Users can bring existing work from other apps
2. **Developer Workflow**: Writers using git/GitHub can author in Markdown, import to WSP for polish
3. **Manual Creation**: Write WSP manual in Markdown (version-controlled), import for distribution
4. **Interoperability**: Positions WSP as welcoming, not a walled garden

## Requirements

### 1. Import Modes

#### 1.1 Single File Import
- Select one `.md` file
- Creates one WSP File in current folder
- File name from Markdown filename (minus extension)

#### 1.2 Multiple File Import
- Select multiple `.md` files
- Creates multiple WSP Files in current folder
- Preserves alphabetical or selection order

#### 1.3 Folder Import
- Select a folder containing `.md` files
- Recreates folder structure in WSP
- Subfolders become WSP Folders
- `.md` files become WSP Files
- Non-markdown files: ignore or import images

### 2. Markdown Parsing

#### 2.1 Supported Markdown Syntax

| Markdown | WSP Equivalent |
|----------|----------------|
| `# Heading 1` | Heading 1 style |
| `## Heading 2` | Heading 2 style |
| `### Heading 3` | Heading 3 style |
| `**bold**` | Bold |
| `*italic*` | Italic |
| `***bold italic***` | Bold + Italic |
| `~~strikethrough~~` | Strikethrough |
| `[text](url)` | Hyperlink (external) |
| `[text](#anchor)` | Internal link (same file) |
| `[text](file.md)` | Cross-file link |
| `[text](file.md#anchor)` | Cross-file link with anchor |
| `![alt](image.png)` | Embedded image |
| `> blockquote` | Block quote style |
| `- list item` | Bulleted list |
| `1. list item` | Numbered list |
| `` `inline code` `` | Monospace/code style |
| ```` ``` code block ``` ```` | Code block style |
| `---` | Horizontal rule / section break |
| `footnote[^1]` | Footnote (if supported) |

#### 2.2 Extended Markdown (Optional)

Consider supporting common extensions:
- Tables (GFM)
- Task lists `- [ ]` and `- [x]`
- Definition lists
- Footnotes `[^1]`

#### 2.3 Unsupported/Ignored

- HTML tags (strip or ignore)
- Custom HTML classes
- Front matter (YAML header) - or extract title from it?

### 3. Link Conversion

#### 3.1 External Links
```markdown
[Apple](https://apple.com)
```
→ WSP external hyperlink (straightforward)

#### 3.2 Internal Anchor Links
```markdown
[See Installation](#installation)
```
→ WSP internal link to heading "Installation" in same file

#### 3.3 Cross-File Links
```markdown
[See Getting Started](getting-started.md)
```
→ WSP cross-file link to imported file "Getting Started"

**Challenge**: File must be imported in same batch, or link marked as broken

#### 3.4 Cross-File Anchor Links
```markdown
[Installation Guide](setup.md#installation)
```
→ WSP cross-file link to heading "Installation" in file "Setup"

#### 3.5 Relative Path Links
```markdown
[Features](../features/editing.md)
```
→ Resolve relative path within imported structure

### 4. Image Handling

#### 4.1 Local Images
```markdown
![Screenshot](images/screenshot.png)
```
- Locate image relative to `.md` file
- Copy image into WSP project
- Create image reference in converted text

#### 4.2 Remote Images
```markdown
![Logo](https://example.com/logo.png)
```
Options:
- Download and embed (preferred)
- Keep as remote reference (may break)
- Skip with warning

#### 4.3 Image Folder Structure
- Create `images` folder in WSP project?
- Or embed images directly in files?
- Follow existing WSP image handling conventions

### 5. Import UI

#### 5.1 Access Points

**From Settings > Import:**
- "Import from File..." shows file types including `.md`

**From Project/Folder Context Menu:**
- "Import Markdown..." option
- Imports into selected location

**Drag and Drop (macOS):**
- Drag `.md` file onto folder → import dialog
- Drag folder → folder import dialog

#### 5.2 Import Dialog

```
┌─────────────────────────────────────────┐
│ Import Markdown                         │
├─────────────────────────────────────────┤
│ Source: ~/Documents/manual/             │
│                                         │
│ Found:                                  │
│   📁 getting-started/ (3 files)         │
│   📁 features/ (5 files)                │
│   📁 reference/ (2 files)               │
│   📄 introduction.md                    │
│                                         │
│ Options:                                │
│   ☑ Preserve folder structure           │
│   ☑ Convert links to internal links     │
│   ☑ Import images                       │
│   ☐ Download remote images              │
│                                         │
│ Import to: [Current Project ▼]          │
│                                         │
├─────────────────────────────────────────┤
│            [Cancel]  [Import]           │
└─────────────────────────────────────────┘
```

#### 5.3 Progress & Results

For large imports:
- Progress indicator
- "Importing file X of Y..."
- Summary on completion:
  - Files imported: 15
  - Images copied: 8
  - Links converted: 42
  - Warnings: 2 (broken links)

### 6. Project Type Detection

When importing a folder structure:
- Detect if it looks like documentation/manual
- Offer to set project type to Manual (025)
- Look for signals: `README.md`, numbered folders, docs structure

### 7. Conflict Handling

#### 7.1 Naming Conflicts
If file/folder name already exists:
- Option A: Append number (`file-1`, `file-2`)
- Option B: Skip with warning
- Option C: Ask user (may be tedious for bulk)

#### 7.2 Format Conflicts
If Markdown contains unsupported syntax:
- Best-effort conversion
- Log warnings for manual review
- Don't fail entire import

### 8. Edge Cases

#### 8.1 Empty Files
- Import as empty WSP file
- Or skip with warning?

#### 8.2 Very Large Files
- May need chunking or streaming
- Test with large documentation sets

#### 8.3 Non-UTF8 Encoding
- Detect encoding
- Convert to UTF-8
- Warn if lossy conversion

#### 8.4 Mixed Content Folders
- Ignore non-`.md` files (except images)
- Or offer to import `.txt` as plain text?

## Implementation Notes

### Phase 1: Basic Single-File Import
1. Add Markdown parser (or use library like swift-markdown)
2. Convert basic syntax (headings, bold, italic)
3. Create WSP File from result
4. Simple file picker integration

### Phase 2: Full Syntax Support
1. Lists (bulleted, numbered)
2. Code blocks
3. Block quotes
4. Horizontal rules
5. Tables (if WSP supports)

### Phase 3: Links & Images
1. External link conversion
2. Image copying and embedding
3. Internal anchor links
4. Cross-file link tracking

### Phase 4: Folder Import
1. Folder structure recursion
2. Batch file processing
3. Link resolution across files
4. Progress UI

### Phase 5: Polish
1. Import options dialog
2. Conflict handling
3. Error reporting
4. Project type suggestion

## Technical Considerations

### Markdown Parser
Options:
1. **Apple's swift-markdown** - Official, well-maintained
2. **cmark** - C library, very fast
3. **Custom parser** - More control, more work

Recommendation: Start with swift-markdown (Swift Package)

### Link Resolution Strategy
1. First pass: Parse all files, build map of filename → WSP File ID
2. Second pass: Convert links using map
3. Mark unresolved links as broken

### Testing
- Test with various Markdown sources:
  - GitHub READMEs
  - Documentation sites (exported)
  - Obsidian vaults
  - Bear notes export
  - iA Writer documents

## Use Cases

### Use Case 1: Import Existing Notes
User has years of Markdown notes in Obsidian. Wants to move to WSP.
- Folder import with link conversion
- Obsidian `[[wiki-links]]` - consider supporting?

### Use Case 2: Create WSP Manual
Developer writes manual in Markdown (for git versioning).
- Import folder as Manual project
- Cross-file links become TOC navigation

### Use Case 3: Import GitHub README
User wants to include project README in WSP.
- Single file import
- External links preserved

### Use Case 4: Blog Post Migration
Writer has blog posts as Markdown.
- Bulk import into project
- Each post becomes a file

## Open Questions

1. Support wiki-style links `[[Page Name]]`? (Obsidian, Notion exports)
2. Handle YAML front matter? (Extract title, date, tags?)
3. Should there be a Markdown *export* too? (Round-trip capability)
4. Support CommonMark strictly, or accept broader syntax?
5. Handle nested lists (indentation levels)?
6. What about Markdown comments `<!-- comment -->`?

## Future Considerations

### Markdown Export
- Export WSP file as `.md`
- Export project as folder of `.md` files
- Enables round-trip workflow

### Live Sync (Advanced)
- Link WSP project to folder of `.md` files
- Auto-import changes
- Two-way sync?
- Very complex, probably not worth it

### Import from Other Formats
This spec establishes patterns for:
- DOCX import (future)
- HTML import (future)
- OPML import (outlines)
