# Headings and Styles

Headings structure your document, making it easier to navigate and understand. Styles ensure consistent formatting throughout your work. This guide covers both.

## Understanding Headings

Headings create a hierarchy in your document:

```
Heading 1: Main Title
├── Heading 2: Section
│   ├── Heading 3: Subsection
│   └── Heading 3: Subsection
└── Heading 2: Section
```

### When to Use Each Level

| Level | Use For | Examples |
|-------|---------|----------|
| **Heading 1** | Main title, chapter titles | "Chapter 1", "Introduction" |
| **Heading 2** | Major sections | "Background", "Methods" |
| **Heading 3** | Subsections | "Data Collection", "Analysis" |

### Applying Headings

1. Place cursor in the paragraph you want as a heading
2. Tap the **¶** button in the toolbar
3. Select Heading 1, 2, or 3
4. The paragraph reformats as a heading

### Heading Best Practices

- Use headings in order (don't skip from H1 to H3)
- Keep heading text concise
- Use sentence case or title case consistently
- Don't end headings with periods

## Understanding Styles

A style is a saved set of formatting attributes. Instead of manually formatting each paragraph, you apply a style.

### Benefits of Styles

1. **Consistency**: All same-style paragraphs look identical
2. **Efficiency**: One tap applies multiple formats
3. **Flexibility**: Change a style to update all instances
4. **Export-friendly**: Styles translate well to other formats

### Built-in Styles

Writing Shed Pro includes these default styles:

| Style | Purpose |
|-------|---------|
| Body | Regular paragraph text |
| Heading 1 | Primary headings |
| Heading 2 | Secondary headings |
| Heading 3 | Tertiary headings |
| Subheadline | Subtitle or lead text |
| Caption | Image captions, notes |
| Footnote | Footnote content |
| Block Quote | Quotations |

### Applying Styles

1. **Single paragraph**: Tap in paragraph, select style
2. **Multiple paragraphs**: Select text spanning paragraphs, select style

## Working with the Style Picker

Tap **¶** to open the style picker:

- Styles are listed by name
- Current style is highlighted
- Tap any style to apply it
- Changes take effect immediately

## Customizing Styles

You can modify any style to match your preferences:

1. Select text with the style you want to edit
2. Tap **Edit Style** from the selection menu
3. Adjust settings:
   - Font family and size
   - Bold, italic, underline
   - Text color
   - Alignment
   - Spacing
4. Save your changes

Changes apply to all paragraphs using that style.

See [Stylesheet Editor](../08-advanced-features/02-stylesheet-editor.md) for complete details.

## Creating New Styles

If the built-in styles don't meet your needs:

1. Open the Stylesheet Editor
2. Tap **Add Style** (or + button)
3. Name your new style
4. Configure all attributes
5. Save

Your custom style appears in the style picker.

## Style Hierarchy

Styles can inherit from other styles:

- A style based on Body shares Body's attributes
- Override only what's different
- Changes to the parent affect children (unless overridden)

This makes it easy to maintain consistent base formatting while varying specific elements.

## Document Structure with Headings

Well-structured documents are easier to:
- Navigate
- Understand
- Export to other formats
- Convert to table of contents

### Example Structure

```
The Garden Novel
├── Part One: Spring
│   ├── Chapter 1: First Bloom
│   ├── Chapter 2: Growing Pains
│   └── Chapter 3: Unexpected Frost
└── Part Two: Summer
    ├── Chapter 4: Long Days
    └── Chapter 5: Heat Wave
```

Each part title might be Heading 1, each chapter Heading 2.

## Styles for Different Project Types

### Poetry
- Minimal heading use
- Consistent body style
- Perhaps a title style for poem titles

### Fiction
- Chapter titles as Heading 1
- Scene breaks with consistent styling
- Body text for narrative

### Drama
- Act/Scene headings
- Character names (may be a custom style)
- Dialogue formatting

### Academic/Non-Fiction
- Multiple heading levels
- Block quotes for citations
- Footnotes for references

## Troubleshooting Styles

### Style Not Applying
- Ensure cursor is in the correct paragraph
- Check if text has manual overrides

### Inconsistent Appearance
- Some text may have manual formatting
- Select and reapply the style

### Want to Reset a Style
- In Stylesheet Editor, you can reset to defaults
- Or manually adjust to desired settings

## See Also
- [Text Formatting](02-text-formatting.md)
- [Stylesheet Editor](../08-advanced-features/02-stylesheet-editor.md)
- [The Editor](01-the-editor.md)
