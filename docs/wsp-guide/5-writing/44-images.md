# Images

Writing Shed Pro supports inline images in your documents. Add photos, illustrations, diagrams, or any visual content to complement your writing.

## Inserting Images

### From the Insert Menu
1. Place cursor where you want the image
2. Tap the **⊕** (Insert) button in the toolbar
3. Select **Image**
4. Choose an image from:
   - Photo Library
   - Files
   - Take Photo (iOS)
5. The image appears at the cursor position

### Drag and Drop (iPad/Mac)
- Drag an image from Photos, Files, or other apps
- Drop it into your document at the desired location

## Image Properties

Tap an image to select it, then open **Image Properties** from the image controls button in the editor toolbar.

### Image Style
Choose one of the image styles defined in the project's stylesheet. Selecting a style loads that style's settings into the Image Properties form.

- **Reset to Style** discards changes in the form and reloads the selected style's current definition. It does not alter the image until you apply the settings.
- **Apply to Image** applies the displayed settings only to the selected image.
- **Update Style** replaces the selected style's definition with the displayed settings. After confirmation, every image using that style is reformatted. Projects that share the same stylesheet are updated as well.

### Scale
Adjust the image size:

- 10% to 200% of the available text-column width
- Use the minus and plus buttons or type an exact percentage
- Maintains aspect ratio

### Spacing
Set **Space Above** and **Space Below** in points to control the vertical space around the image paragraph.

### Alignment
Control horizontal position:

- **Left**: Image aligns to left margin
- **Center**: Image centers in the text column
- **Right**: Image aligns to right margin

### Border
Choose a rectangular border preset:

- **None**: No border
- **Thin**: 1-point border
- **Medium**: 2-point border
- **Thick**: 4-point border

Use **Border Padding** to set the gap, in points, between the image and its border. The caption remains below and outside the border.

### Caption
Add a caption below the image:

1. Toggle **Show Caption** on
2. Enter caption text
3. Select caption style

## Image Styles

Images can use styles defined in your project's stylesheet:

### Default Image Style
New images use the default style with:

- Centered alignment
- 100% scale
- Configurable spacing and border settings
- Optional caption

### Custom Image Styles
Create styles for different image uses:

- **Figure**: Centered, 80% scale, numbered caption
- **Photo**: Full width, minimal caption
- **Diagram**: Centered, specific scale and border

Create and edit image styles in the **Stylesheet Editor**. An image style controls scale, alignment, spacing, caption defaults, border thickness, and border padding.

Apply a style by selecting an image, opening Image Properties, choosing the style, and tapping **Apply to Image**. Use **Update Style** when you want the current settings to become the style definition and reformat all images assigned to it.

## Working with Captions

Captions help readers understand your images:

### Adding a Caption
1. Tap the image
2. Toggle **Show Caption** on
3. Tap to edit caption text
4. Choose a caption style

### Caption Styles
Caption styles control:

- Font and size
- Alignment (relative to image)
- Numbering (Figure 1, Figure 2, etc.)

## Editing Images

### Move an Image
1. Cut the image (select and Cut)
2. Place cursor at new location
3. Paste

Or drag and drop within the document.

### Resize an Image
1. Tap the image
2. Open Image Properties
3. Use the scale buttons or type an exact percentage
4. Tap **Apply to Image**

### Replace an Image
1. Delete the current image
2. Insert a new image at that location

### Delete an Image
1. Tap the image to select
2. Press Delete/Backspace
3. Or Cut without pasting

## Image Tips

### Resolution
- Use appropriate resolution for your purpose
- High-res images look great but increase file size
- For print, aim for 300 DPI at final size
- For screen only, 150 DPI is often sufficient

### File Size
Large images increase:

- Document file size
- iCloud sync time
- Export time

Writing Shed Pro optimizes images for storage, but starting with reasonably sized images helps.

### Placement
- Place images near related text
- Consider how images will appear in pagination view
- Check appearance in export preview

### Accessibility
- Captions help all readers understand images
- Images export with any available alt text
- Don't convey critical information only in images

## Images in Different Project Types

### Prose
- Illustrations for articles
- Charts and graphs
- Photos for memoirs

### Poetry
- Use sparingly if at all
- Consider whether images enhance or distract

### Fiction
- Cover mockups
- Character inspiration (private use)
- Maps for fantasy/sci-fi

### Drama
- Character/costume reference
- Set diagrams
- Production notes

## Images in Export

When you export your document:

### PDF
- Images embed at full quality
- Appear exactly as in the document
- Captions included

### RTF
RTF export does not include inline images. Writing Shed Pro warns you before export so you can choose a format like PDF when images must be preserved.

### Print
- Images print at available resolution
- Check print preview first

## Troubleshooting

### Image Won't Insert
- Check that the file format is supported (PNG, JPEG, HEIC, GIF)
- Try a different image
- Restart the app if persistent

### Image Appears Blurry
- Original image may be low resolution
- Scale is set too large
- Check the source image quality

### Image Too Large/Small
- Adjust the scale in image properties
- Check default image style settings

### Only One Image Changed
- **Apply to Image** intentionally changes only the selected image
- Use **Update Style** and confirm the update to reformat every image assigned to that style

## See Also
- [The Editor](41-the-editor.md)
- [Stylesheet Editor](../11-advanced-features/102-stylesheet-editor.md)
- [PDF Export](../10-publishing/92-pdf-export.md)

---
