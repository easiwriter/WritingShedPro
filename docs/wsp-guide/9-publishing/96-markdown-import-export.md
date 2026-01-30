# Markdown Import and Export

Writing Shed Pro supports Markdown (.md) files for both import and export, making it easy to work with plain text formats while preserving document structure.

## What is Markdown?

Markdown is a lightweight markup language that uses simple symbols to indicate formatting:
- `**bold**` becomes **bold**
- `*italic*` becomes *italic*
- `# Heading` becomes a heading
- `[link](url)` becomes a hyperlink

Markdown files are plain text, readable by any text editor, yet carry formatting information that apps can interpret.

## Exporting to Markdown

### When to Use Markdown Export
- Sharing with collaborators who use plain text editors
- Publishing to platforms that accept Markdown (blogs, GitHub, etc.)
- Creating backup copies in a universal format
- Converting for use in other Markdown-based tools

### How to Export
1. Open the file you want to export
2. Tap the **Share** or **Export** button
3. Select **Export as Markdown**
4. Choose where to save the .md file

### What Gets Exported

| Feature | Markdown Equivalent |
|---------|-------------------|
| Bold | `**text**` |
| Italic | `*text*` |
| Bold + Italic | `***text***` |
| Strikethrough | `~~text~~` |
| Headings (1-6) | `#` to `######` |
| Links | `[text](url)` |
| Code/monospace | `` `code` `` |

### What Doesn't Export
- Complex formatting (fonts, colors, sizes)
- Images (exported as reference links)
- Footnotes (converted to inline notes)
- Page layout and margins

## Importing Markdown

Writing Shed Pro can import .md files and convert them to rich text, applying your project's stylesheet for consistent formatting.

### How to Import
1. Open a folder in your project (Draft, Ready, or any folder)
2. Tap the **Import** button (arrow-into-tray icon)
3. Select a .md or .markdown file
4. The file is imported with formatting applied

### Stylesheet Mapping

When importing Markdown, headings and text are mapped to your project's stylesheet:

| Markdown | Style Applied |
|----------|--------------|
| `# Heading 1` | Title 1 |
| `## Heading 2` | Title 2 |
| `### Heading 3` | Title 3 |
| `#### Heading 4` | Title 4 |
| `##### Heading 5` | Subheadline |
| `###### Heading 6` | Subheadline |
| Regular text | Body |
| `> Blockquote` | Callout |
| Code blocks | Caption 1 |

### What Gets Imported

| Markdown Feature | Result |
|-----------------|--------|
| **Bold** (`**text**`) | Bold formatting |
| *Italic* (`*text*`) | Italic formatting |
| ~~Strikethrough~~ | Strikethrough formatting |
| [Links](url) | Clickable hyperlinks |
| `Code` | Monospace font |
| Headings | Styled headings per stylesheet |
| Lists | Formatted lists |
| Blockquotes | Callout style |

### Import Best Practices

**Prepare your Markdown file**:
- Use standard Markdown syntax
- Ensure headings use `#` notation
- Check that links are properly formatted

**After importing**:
- Review the applied styles
- Adjust any formatting as needed
- The imported file becomes a new text file in the folder

## Round-Trip Workflow

You can export to Markdown, edit externally, and reimport:

1. Export your file to Markdown
2. Edit in your preferred Markdown editor
3. Import the updated file
4. Styles are reapplied from your stylesheet

**Note**: Some formatting may change in the round trip. Complex styling not supported by Markdown will be simplified on export and cannot be automatically restored on import.

## Markdown and Other Formats

### Markdown vs RTF
| Aspect | Markdown | RTF |
|--------|----------|-----|
| File size | Smaller | Larger |
| Human readable | Yes | No |
| Formatting | Basic | Rich |
| Universal | Very | Mostly |
| Editability | Any text editor | Word processors |

### Markdown vs PDF
| Aspect | Markdown | PDF |
|--------|----------|-----|
| Editable | Yes | No |
| Formatting | Basic | Full |
| File size | Smaller | Larger |
| Universal | Yes | Yes |

## Troubleshooting

### Import Not Recognizing Formatting
- Ensure proper Markdown syntax (e.g., `**bold**` not `** bold **`)
- Check for invisible characters from other editors
- Some extended Markdown features may not be supported

### Export Missing Features
- Markdown is intentionally limited in features
- Complex formatting will be simplified
- Consider RTF or PDF for full formatting

### Headings Not Styled Correctly
- Verify your project has a stylesheet with the mapped styles
- Check that headings use `#` syntax, not underlines
- Import applies the default stylesheet mapping

## See Also
- [Export Options](01-export-options.md)
- [RTF Export](03-rtf-export.md)
- [Stylesheet Editor](../10-advanced-features/02-stylesheet-editor.md)

---
