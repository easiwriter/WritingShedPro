# Stylesheet Editor

Every project in Writing Shed Pro has a stylesheet that defines how text looks. The Stylesheet Editor lets you customize fonts, sizes, colors, and more.

## Understanding Stylesheets

A stylesheet contains:
- **Paragraph styles**: How each type of paragraph looks (Body, Headings, etc.)
- **Character styles**: Formatting like bold and italic
- **Image styles**: How images are sized and positioned

Instead of formatting each paragraph manually, you apply a style. Change the style definition, and all text using that style updates.

## Accessing the Stylesheet Editor

1. Open your project
2. Go to **Project Settings**
3. Select **Stylesheet**
4. The Stylesheet Editor opens

## Viewing Styles

The editor shows all available styles:

### Paragraph Styles
- Body
- Heading 1, 2, 3
- Subheadline
- Caption
- Footnote
- Block Quote
- And any custom styles you've created

### How Styles Are Displayed
Each style shows:
- Name
- Preview of appearance
- Font and size summary

Tap any style to edit it.

## Editing a Style

Tap a style to modify it:

### Font Settings
- **Default Font**: New styles use Helvetica Neue Regular
- **Font Family**: Choose an installed font family from the first menu
- **Font Face**: Choose a specific family face, such as Regular, Light, Bold, Italic, or Bold Italic
- **Font Size**: Use the point-size control beside the face menu
- **Bold, Italic, Underline, and Strikethrough**: Use the grouped buttons below the font menus. Active buttons have a filled highlight.

The font face and the **B** and *I* buttons stay synchronized:

- Choosing a Bold, Italic, or Bold Italic face activates the corresponding buttons.
- Choosing a face such as Regular or Light deactivates **B** and *I* when that face does not contain those traits.
- Tapping **B** or *I* selects the matching installed face from the current family when one is available.
- If the family does not provide the requested face, Writing Shed Pro applies the bold or italic trait to the selected face.

### Text Appearance
- **Text Color**: Choose a color
- **Underline** and **Strikethrough**: Set with the grouped font buttons

### Paragraph Settings
- **Alignment**: Left, Center, Right, Justified
- **First Line Indent**: Indent the first line
- **Left Margin**: Space from left edge
- **Right Margin**: Space from right edge

### Spacing
- **Line Spacing**: Space between lines (1.0, 1.5, 2.0, etc.)
- **Space Before**: Gap above paragraph
- **Space After**: Gap below paragraph

### Numbering
- **Enable Numbering**: Toggle on to display automatic numbers before paragraphs using this style
- **Number Format**: Decimal, Roman (upper/lower), Letter (upper/lower)
- **Adornment**: Plain, Period, Parentheses, Right Paren, or Dash variants
- **Parent Style**: Select a numbered parent style for hierarchical numbering (e.g., `1.a`, `1.1.1`)

See [Headings and Styles](../5-writing/43-headings-and-styles.md) for details on heading numbering and lists.

### Save
Tap **Save** or **Done** to apply changes.

## Creating a Custom Style

1. In the Stylesheet Editor, tap **+** or **Add Style**
2. Enter a name for your style
3. Optionally base it on an existing style
4. Configure all settings
5. Save

Your new style appears in the style picker when editing.

## Deleting a Style

1. Select the style
2. Tap **Delete** or swipe left
3. Confirm deletion

**Note**: You cannot delete built-in styles. If text uses a deleted style, it reverts to Body.

## Style Inheritance

Styles can be based on other styles:

### How It Works
- Create "My Body" based on "Body"
- "My Body" inherits all Body settings
- Override only what you want different
- Changes to Body affect "My Body" (except overridden settings)

### Benefits
- Consistency across related styles
- Easy to make global changes
- Reduces redundant configuration

## Common Style Customizations

### Manuscript Format
For standard manuscript submission:
- **Body**: 12pt Courier or Times, double-spaced
- **Heading 1**: Bold, slightly larger, no indent

### Poetry
- **Body**: Comfortable font, single or 1.5 spacing
- **Heading 1**: For poem titles

### Scripts (Drama)
Specific margin and formatting requirements—see DML documentation.

## Resetting Styles

To return a style to defaults:
1. Open the style
2. Tap **Reset to Default** (if available)
3. Confirm

This removes all customizations.

## Exporting Stylesheets

Your stylesheet travels with your project:
- Exports include style definitions
- Other devices see the same formatting
- Share projects with formatting intact

## Best Practices

### Use Styles Consistently
Apply styles through the style picker, not manual formatting. This ensures consistency.

### Keep It Simple
A few well-defined styles work better than many similar ones.

### Test Before Committing
Preview styled text before finalizing style changes.

### Document Your Choices
If you create complex custom styles, note why for future reference.

### Match Requirements
For submissions, check guidelines and configure styles to match.

## Troubleshooting

### Style Not Applying
- Ensure cursor is in correct paragraph
- Text may have manual overrides
- Reapply the style to clear overrides

### Wrong Font Appearing
- Font may not be available on this device
- A similar font was substituted
- Choose a universally available font

### Changes Not Showing
- Save the style changes
- Changes apply to existing text using that style
- New text will also use updated style

## See Also
- [Text Formatting](../5-writing/42-text-formatting.md)
- [Headings and Styles](../5-writing/43-headings-and-styles.md)
- [Page Setup](103-page-setup.md)

---
