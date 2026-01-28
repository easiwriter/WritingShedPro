# Text Formatting

Writing Shed Pro provides rich text formatting to make your documents look professional. This guide covers all the formatting options available.

## Character Formatting

Character formatting applies to individual words or characters within a paragraph.

### Bold
Make text **bold** to add emphasis.
- Select text, tap **B** in the toolbar
- Keyboard: ⌘B

### Italic
Make text *italic* for titles, foreign words, or subtle emphasis.
- Select text, tap *I* in the toolbar
- Keyboard: ⌘I

### Underline
<u>Underline</u> text when needed (use sparingly).
- Select text, tap **U** in the toolbar
- Keyboard: ⌘U

### Strikethrough
Show ~~deleted~~ or removed text.
- Select text, tap **S̶** in the toolbar

### Combining Formats
You can combine formats:
- ***Bold italic***
- **Bold with ~~strikethrough~~**
- Any combination you need

## Paragraph Formatting

Paragraph formatting applies to entire paragraphs. Tap the **¶** button to see paragraph styles.

### Available Paragraph Styles

| Style | Use For |
|-------|---------|
| **Body** | Regular text (default) |
| **Heading 1** | Main chapter or section titles |
| **Heading 2** | Subsection titles |
| **Heading 3** | Sub-subsection titles |
| **Subheadline** | Secondary titles or leads |
| **Caption** | Image captions, small notes |
| **Footnote** | Footnote text (automatic) |
| **Large Title** | Very prominent titles |

### Applying Paragraph Styles
1. Place cursor in the paragraph
2. Tap the **¶** button
3. Select the desired style
4. The entire paragraph updates

### Custom Styles
You can create and modify styles in the Stylesheet Editor. See [Stylesheet Editor](../08-advanced-features/02-stylesheet-editor.md).

## Text Alignment

Control how text aligns within the paragraph:

| Alignment | Description |
|-----------|-------------|
| **Left** | Text aligns to left margin (default) |
| **Center** | Text centers between margins |
| **Right** | Text aligns to right margin |
| **Justify** | Text stretches to fill line |

### Setting Alignment
1. Tap in a paragraph
2. Open the style editor (via Edit Style)
3. Choose the alignment option
4. Or: Create a style with the desired alignment

## Indentation

Control paragraph indentation:

### First Line Indent
The first line of a paragraph can be indented. Common in fiction:
- Set in paragraph style
- Typically 0.5 inches or 12 points

### Block Indent
Indent the entire paragraph from left and/or right margins:
- Used for block quotes
- Set in paragraph style

## Line and Paragraph Spacing

### Line Spacing
Space between lines within a paragraph:
- Single spacing (1.0)
- 1.5 spacing
- Double spacing (2.0)
- Custom values

### Paragraph Spacing
Space before and after paragraphs:
- Space Before: Gap above the paragraph
- Space After: Gap below the paragraph

These are set in paragraph styles.

## Text Color

Change text color for emphasis or special purposes:

1. Select text
2. Open Edit Style (from selection menu)
3. Choose Text Color
4. Select from the color picker

**Note**: Use color sparingly in most writing. It may not export to all formats.

## Lists

Create bulleted or numbered lists to organize information clearly.

### Creating Lists

To start a list:
1. Place your cursor on a blank line
2. Tap the **¶** (paragraph style) button in the toolbar
3. Select **Numbered List** or **Bullet List**

The list marker (number or bullet) appears automatically. Each time you press Return, a new list item is created with the next number or bullet.

### Bulleted Lists
- Item one
- Item two  
- Item three

Use bullets for unordered items where sequence doesn't matter.

### Numbered Lists
1. First item
2. Second item
3. Third item

Use numbers when order or sequence is important. Numbers update automatically as you add, remove, or reorder items.

### Nested Lists (Multi-Level Lists)

Create sub-lists to organize hierarchical information. Sub-lists can be indented up to three levels deep.

#### Creating Sub-Lists

**Using the Toolbar (iPhone/iPad):**
1. Place cursor in a list item
2. Tap the **Increase Indent** button (→|) to create a sub-list
3. Tap the **Decrease Indent** button (|←) to promote an item back up

**Using Keyboard Shortcuts (External Keyboard):**
- Press **Tab** to increase indent level (create sub-list)
- Press **Shift+Tab** to decrease indent level (promote item)

#### How Numbering Works

Each sub-list level uses a different numbering style:

| Level | Numbered Style | Bullet Style |
|-------|----------------|--------------|
| 1 | 1. 2. 3. | • (bullet) |
| 2 | a. b. c. | ◦ (circle) |
| 3 | i. ii. iii. | ▪ (square) |

**Important**: Sub-list numbering restarts when you return to a higher level. For example:

```
1. First main item
   a. Sub-item under first
   b. Another sub-item
2. Second main item
   a. Sub-item starts at 'a' again
   b. Because we're under a new parent
```

#### Example Multi-Level List

```
1. Planning Phase
   a. Define objectives
   b. Identify stakeholders
      i. Internal team
      ii. External clients
   c. Set timeline
2. Execution Phase
   a. Assign tasks
   b. Monitor progress
```

### Exiting a List

To stop the list and return to normal body text:

**Method 1 - Decrease Indent:**
- When at Level 1, press **Shift+Tab** (or tap Decrease Indent)
- This applies the Body style

**Method 2 - Change Style:**
- Tap the **¶** button
- Select **Body** or another non-list style

**Method 3 - Empty Line:**
- Press **Return** twice on an empty list item
- The second Return may exit the list (behavior varies)

### List Tips

- **Start typing immediately** after the list marker appears
- **Empty lines** within lists may cause numbering to restart
- **Undo** (⌘Z) works if you accidentally change indent levels
- **Copy/paste** list items preserves their formatting

## Block Quotes

Format quotations as block quotes:
- Apply the Block Quote style
- Text is indented from both margins
- May have different font or styling

## Formatting Tips

### Consistency is Key
Use paragraph styles consistently. If all your chapter headings use "Heading 1," you can change their appearance globally by editing the style.

### Less is More
Resist over-formatting. Clean, simple formatting often reads better than heavily styled text.

### Format Last
Write first, format later. Getting your ideas down is more important than how they look initially.

### Think About Export
Consider how your formatting will appear in exported formats:
- PDF preserves most formatting
- RTF may simplify some features
- Plain text removes all formatting

## Clearing Formatting

To remove character formatting:
1. Select the formatted text
2. Remove individual formats (⌘B to toggle off bold, etc.)

To reset to default style:
1. Select the paragraph
2. Apply the Body style

## Accessibility Considerations

When formatting:
- Don't rely on color alone to convey meaning
- Use heading styles properly (they help screen readers)
- Ensure sufficient contrast
- Keep text readable (not too small)

## See Also
- [Headings and Styles](03-headings-and-styles.md)
- [Stylesheet Editor](../08-advanced-features/02-stylesheet-editor.md)
- [The Editor](01-the-editor.md)
