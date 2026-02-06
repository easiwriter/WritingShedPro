# List of Figures (Table of Figures)

The List of Figures feature in Writing Shed Pro creates an automatic catalog of all images in your manuscript, with captions and page numbers.

## Overview

A List of Figures (also called Table of Figures) is a reference list showing every image in your document along with its caption and the page where it appears. This is common in academic papers, technical manuals, and illustrated books. Writing Shed Pro's system supports:

- **Automatic scanning** - Finds all images in your manuscript
- **Caption extraction** - Uses image captions as entry text
- **Page numbers** - Calculated from actual manuscript pagination
- **Numbered prefixes** - Optional "Figure 1:", "Figure 2:" etc.
- **Dot leaders** - Customizable separators between caption and page number
- **Missing caption handling** - Control how uncaptioned images are displayed

## Enabling List of Figures

1. Navigate to your project's **Back Matter** folder
2. Tap the **+** button or go to **Settings**
3. Enable **Table of Figures** in the back matter items
4. A "Table of Figures" file is created in your Back Matter folder

## Viewing the List of Figures

Open the **Table of Figures** file in your Back Matter folder to see a live preview showing:

- All images from your manuscript in document order
- Sequential figure numbers
- Caption text (or "Missing caption" placeholder)
- Calculated page numbers based on your Page Setup settings

### Page Number Display

Page numbers are calculated using the same pagination engine as your manuscript export:

- Numbers reflect actual page positions based on your Page Setup settings
- While page numbers are calculating, a progress indicator appears
- Recalculates automatically when you make changes to your manuscript

## Configuring Settings

Tap the **gear icon** (⚙️) in the navigation bar to open the settings sheet.

### Title Section

- **Title**: The heading displayed at the top (default: "List of Figures")
- **Title style**: Choose a text style from your stylesheet for the title

### Entry Style

Choose which text style from your stylesheet to use for the figure entries.

### Numbering

- **Use caption prefix**: Toggle to show/hide numbered prefixes
- **Prefix text**: The text before each number (default: "Figure")

When enabled, entries appear as:
> Figure 1: Sunrise over the mountains ............. 12

When disabled, entries show only:
> Sunrise over the mountains ............. 12

### Formatting

- **Show page numbers**: Toggle page numbers on or off
- **Separator**: Choose the character between caption and page number (., -, _, space, or none)
- **Use dot leaders**: Repeat the separator to fill the space
- **Page number position**: Adjust the tab stop position (300–600 points)

### Missing Captions

Control how images without captions are handled:

- **Show uncaptioned images** (ON): Displays "Missing caption" as a placeholder
  > Figure 3: Missing caption ............. 45

- **Show uncaptioned images** (OFF): Skips uncaptioned images and shows a summary at the bottom
  > *3 images without captions on pages: 45, 67, 89*

## Adding Captions to Images

For images to appear meaningfully in the List of Figures, they need captions:

1. Select an image in your document
2. In the image settings (tap the image, then the info button):
   - Enable **Show Caption**
   - Enter the caption text
   - Optionally set a caption prefix style
3. The caption appears below the image and in the List of Figures

## Best Practices

### Consistent Captioning

- Add captions to all images you want listed
- Use consistent language and formatting
- Keep captions concise but descriptive

### Numbering Style

Choose a prefix that matches your document type:
- Academic: "Figure 1:", "Figure 2:"
- Technical: "Fig. 1:", "Fig. 2:"
- Art books: Disable prefix, use captions only

### Checking for Missing Captions

Use the **Show uncaptioned images** toggle strategically:
1. During editing, turn it ON to see which images need captions
2. Before publishing, turn it OFF if you want to exclude decorative images
3. Review the summary message to ensure no important images are missing captions

## Export Behavior

The List of Figures is included in your manuscript exports (PDF, EPUB, etc.) when:

- The Table of Figures file exists in Back Matter
- Back Matter is included in your export settings

The page numbers in the exported document will match your actual pagination.

## Related Topics

- [Adding Images](../4-writing/44-images.md)
- [Manuscript Structure](../3-projects/36-manuscript-structure.md)
- [Page Setup](103-page-setup.md)
- [Table of Contents](110-table-of-contents.md)
