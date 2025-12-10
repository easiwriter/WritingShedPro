# Phase 006: Image Support Specification

## Overview
Add support for inline images within text documents, allowing users to insert images alongside their text content. Images will use styles defined in the project's stylesheet, with image properties (scale, alignment, captions) controlled through tapping on images.

Images can have captions. These are controlled by the existing image properties where the user can turn captions on and off. If the user turns captions on (show Caption) then they can insert the caption. The selected caption style controls its format. Note that the style's text alignment should be interpreted as being relative to the image bounds.

## Feature Priority
**HIGH** - Requesxt and choose the caption styled by user as next feature after text formatting

## Change Log
- **2025-11-03**: Updated to use Insert menu for images and other content types
- **2025-11-03**: Changed to use stylesheet-based image styles instead of inline style editor
- **2025-11-03**: Image properties edited by tapping on images
- **2025-12-09**: support for captions added

## User Stories

### US-001: Insert Image via Menu
**As a** writer  
**I want to** insert images from an Insert menu  
**So that** I can add illustrations, photos, or diagrams to my text

**Acceptance Criteria:**
- Toolbar has "Insert" button that shows menu
- Menu contains: Image, List, Footnote, Endnote, Comment, Index Item
- Selecting "Image" opens file picker
- File picker supports common image formats (PNG, JPEG, HEIC, GIF)
- Image appears inline at cursor position using default image style from stylesheet
- Image can be inserted in any paragraph
- Undo/redo works for image insertion

### US-002: Edit Image Properties
**As a** writer  
**I want to** tap on an image to edit its properties  
**So that** I can adjust scale, alignment, and captions

**Acceptance Criteria:**
- Tap image to show image property editor
- Can change scale (10% to 200%)
- Can change alignment (left, center, right, inline)
- Can toggle caption on/off
- Can edit caption text
- Can select caption style from available styles
- Changes apply immediately
- Undo/redo works for all property changes

### US-003: Image Styles in Stylesheet
**As a** writer  
**I want to** define image styles in my project's stylesheet  
**So that** all images have consistent formatting

**Acceptance Criteria:**
- Stylesheet contains "Image Styles" section
- Default image style includes: scale, alignment, caption style, has caption
- Can create multiple image styles (e.g., "Figure", "Photo", "Diagram")
- Tapping image shows current style
- Can change image to different style from stylesheet
- All images using a style update when style is changed
- Image style persists with document

### US-004: Image Persistence
**As a** writer  
**I want to** save and reload documents with images  
**So that** my images are preserved across sessions

**Acceptance Criteria:**
- Images saved with document
- Images restored when document opens
- Image quality preserved
- Large images optimized for storage
- Images work with undo/redo system

### US-005: Delete Images
**As a** writer  
**I want to** delete images from my document  
**So that** I can remove unwanted or outdated images

**Acceptance Criteria:**
- Select image and press Delete/Backspace
- Delete via context menu
- Undo/redo works for deletion
- Storage cleaned up when image deleted

### US-006: Image Captions
**As a** writer  
**I want to** add captions to my images  
**So that** I can provide context and descriptions

**Acceptance Criteria:**
- Image style can specify if captions are shown by default
- Option to enable/disable caption for individual images
- Caption text editable inline below image
- Caption styles from stylesheet (like text styles)
- Multiple caption styles available (caption1, caption2, etc.)
- Captions persist with document
- Undo/redo works for caption changes

### US-007: Insert Menu for Content Types
**As a** writer  
**I want to** access an Insert menu for various content types  
**So that** I can add structured content to my documents

**Acceptance Criteria:**
- Toolbar "Insert" button opens menu
- Menu items:
  - Image (implemented)
  - List (future)
  - Footnote (future)
  - Endnote (future)
  - Comment (future)
  - Index Item (future)
- Only implemented items are enabled
- Menu closes after selection
- Menu can be dismissed without selection

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│               FileEditView.swift                │
│  - Insert menu button in toolbar               │
│  - Menu: Image, List, Footnote, etc.           │
│  - Image selection opens file picker            │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│          FormattedTextEditor.swift              │
│  - UITextView with NSTextAttachment support     │
│  - Tap image to show property editor            │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│         ImageAttachment.swift                   │
│  - Custom NSTextAttachment subclass             │
│  - Properties: imageData, scale, alignment      │
│  - Caption text and style                       │
│  - Reference to image style name                │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│           StyleSheet Model                      │
│  - Text styles (existing)                       │
│  - Image styles (new)                           │
│    * Default scale, alignment                   │
│    * Default caption settings                   │
│    * Caption style reference                    │
└─────────────────────────────────────────────────┘
```
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│           ImageAttachment.swift                 │
│  - Custom NSTextAttachment subclass             │
│  - Image storage and retrieval                  │
│  - Size and alignment properties                │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│       AttributedStringSerializer.swift          │
│  - Encode/decode images with text               │
│  - Image data compression                       │
│  - Format: base64 embedded in JSON              │
└─────────────────────────────────────────────────┘
```

### Data Model

### Data Models

#### ImageAttachment (NSTextAttachment subclass)
```swift
class ImageAttachment: NSTextAttachment {
    var imageData: Data
    var scale: CGFloat = 1.0          // 0.1 to 2.0
    var alignment: ImageAlignment = .center
    var captionText: String?
    var captionStyle: String = "caption1"
    var hasCaption: Bool = false
    var imageStyleName: String = "default" // References stylesheet
    
    enum ImageAlignment: String, Codable {
        case left, center, right, inline
    }
}
```

#### ImageStyle (in StyleSheet)
```swift
struct ImageStyle: Codable, Identifiable {
    var id: UUID
    var name: String              // e.g., "Figure", "Photo", "Diagram"
    var defaultScale: CGFloat     // Default: 1.0
    var defaultAlignment: ImageAlignment  // Default: .center
    var hasCaptionByDefault: Bool // Default: false
    var defaultCaptionStyle: String // Default: "caption1"
}
```

#### StyleSheet (extended)
```swift
class StyleSheet {
    // Existing
    var textStyles: [TextStyle]
    
    // New
    var imageStyles: [ImageStyle]
    
    func defaultImageStyle() -> ImageStyle {
        return imageStyles.first ?? ImageStyle.defaultStyle()
    }
}
```

#### Serialization Format
Images will be embedded in the attributed string JSON format:

```json
{
  "text": "Here is my image:\n[IMAGE]\n[CAPTION]More text",
  "attributes": [
    {
      "type": "textAttachment",
      "location": 17,
      "length": 1,
      "imageID": "UUID-HERE",
      "imageData": "base64-encoded-data",
      "scale": 0.95,
      "alignment": "center",
      "hasCaption": true,
      "captionText": "My image caption",
      "captionStyle": "caption1"
    }
  ]
}
```

### UI Components

#### Toolbar Insert Button
- Icon: SF Symbol "plus" or "plus.circle"
- Position: After formatting buttons
- Action: Opens Insert menu

#### Insert Menu
- **Trigger**: Toolbar "Insert" button
- **Menu Items**:
  1. Image (icon: photo, enabled)
  2. List (icon: list.bullet, disabled - future)
  3. Footnote (icon: text.append, disabled - future)
  4. Endnote (icon: text.append, disabled - future)
  5. Comment (icon: text.bubble, disabled - future)
  6. Index Item (icon: tag, disabled - future)
- **Behavior**:
  - Menu opens as popover (iPad/Mac) or action sheet (iPhone)
  - Selecting "Image" opens file picker
  - Disabled items show as grayed out
  - Menu dismisses after selection

#### File Picker
- Supports: .png, .jpg, .jpeg, .heic, .gif
- macOS: NSOpenPanel
- iOS: UIDocumentPickerViewController
- Single selection only

#### Image Property Editor Sheet
Presented when user taps on an image:
- **Title**: "Image Properties"
- **Sections**:
  1. **Preview**: Shows the image at current scale
  2. **Style** (if multiple styles available):
     - Picker showing available image styles from stylesheet
     - Shows current style with checkmark
     - Changing style applies all properties from that style
  3. **Scale**:
     - Slider or stepper (10% to 200%)
     - Text field showing current percentage
     - +/- buttons for 10% increments
  4. **Alignment**:
     - Button row: Left, Center, Right, Inline
     - Current selection highlighted
  5. **Caption**:
     - Toggle: "Show Caption"
     - Text field: Caption text (if enabled)
     - Picker: Caption style (if enabled)
- **Navigation**:
  - "Cancel" button (left) - discards changes
  - "Apply" button (right) - saves changes via undo command

#### Image Tap Interaction
- Single tap on image: Show property editor
- Double tap on caption: Edit caption text inline
- Long press: Context menu (Edit Properties, Copy, Delete)
- **Scale Control**:
  - Label: "Scale" with icon
  - +/- buttons for increment/decrement
  - Percentage display (e.g., "95.00 %")
  - Range: 10% to 200%
- **Alignment Control**:
  - Three visual buttons with alignment icons
  - Left, Center, Right
  - Highlight current selection
- **Caption Styles**:
  - Label: "Caption Styles:" with icon
  - List of available caption styles:
    - "noCaption" (default - no caption shown)
    - "caption1" (stylesheet-defined style)
    - "caption2" (stylesheet-defined style)
    - More styles can be added to stylesheet
  - Checkmark shows current selection
- **Navigation**:
  - "Cancel" button (left)
  - "Done" button (right)

#### File Picker
- Supports: .png, .jpg, .jpeg, .heic, .gif
- macOS: NSOpenPanel
- iOS: UIDocumentPickerViewController or PHPickerViewController

#### Image Selection UI
- Tap/click image to show style editor
- Selected image highlighted with border
- Context menu: Edit Style, Copy, Delete

#### Caption UI
- Caption appears below image (if enabled)
- Editable inline (tap to edit)
- Uses stylesheet formatting (like body text)
- Can be toggled on/off via style editor

### Image Storage Strategy

#### Option 1: Embedded in JSON (CHOSEN)
**Pros:**
- Single file contains everything
- Easy backup/sharing
- No broken links
- Works with current serialization

**Cons:**
- Larger file sizes
- Need compression for large images

**Implementation:**
- Store base64-encoded image data in JSON
- Compress images > 1MB
- Max width: 2048px (downscale if larger)
- JPEG quality: 85% for photos, PNG for graphics

#### Option 2: External Files (Future consideration)
- Store images in document package/folder
- JSON contains only image references
- Better for very large documents

### Undo/Redo Integration

#### InsertImageCommand
```swift
struct InsertImageCommand: UndoableCommand {
    let imageData: Data
    let location: Int
    let scale: CGFloat
    let alignment: ImageAlignment
    
    func execute(on file: File) { /* insert */ }
    func undo(on file: File) { /* remove */ }
}
```

#### ScaleImageCommand
```swift
struct ScaleImageCommand: UndoableCommand {
    let imageID: UUID
    let oldScale: CGFloat
    let newScale: CGFloat
    
    func execute(on file: File) { /* scale */ }
    func undo(on file: File) { /* restore scale */ }
}
```

#### AlignImageCommand
```swift
struct AlignImageCommand: UndoableCommand {
    let imageID: UUID
    let oldAlignment: ImageAlignment
    let newAlignment: ImageAlignment
    
    func execute(on file: File) { /* align */ }
    func undo(on file: File) { /* restore alignment */ }
}
```

#### SetCaptionCommand
```swift
struct SetCaptionCommand: UndoableCommand {
    let imageID: UUID
    let oldCaptionText: String?
    let newCaptionText: String?
    let oldCaptionStyle: String?
    let newCaptionStyle: String?
    let oldHasCaption: Bool
    let newHasCaption: Bool
    
    func execute(on file: File) { /* set caption */ }
    func undo(on file: File) { /* restore caption */ }
}
```

#### DeleteImageCommand
```swift
struct DeleteImageCommand: UndoableCommand {
    let imageData: Data
    let location: Int
    let scale: CGFloat
    let alignment: ImageAlignment
    let captionText: String?
    let captionStyle: String?
    let hasCaption: Bool
    
    func execute(on file: File) { /* delete */ }
    func undo(on file: File) { /* restore */ }
}
```

### Performance Considerations

#### Image Loading
- Lazy load images when document opens
- Cache decoded images in memory
- Limit cache to 10 images or 50MB
- LRU eviction policy

#### Image Compression
- Downscale images > 2048px width
- Use JPEG compression for photos (85% quality)
- Use PNG for graphics/screenshots
- Compress on background queue

#### Rendering
- Use UIImageView for static display
- GPU-accelerated rendering
- Avoid layout thrashing during resize

### Edge Cases

1. **Very Large Images**
   - Downscale to max 2048px width
   - Show warning if original > 10MB
   - Compress to JPEG

2. **Animated GIFs**
   - Display first frame only (Phase 1)
   - Full animation support in future phase

3. **Unsupported Formats**
   - Show error message
4. **Copy/Paste**
   - Support pasting images from clipboard
   - Support copying images to clipboard
   - Handle copying text+images together
   - Caption text copies with image

5. **Multiple Images**
   - No limit on number of images per document
   - Warn if total document size > 100MB
   - Each image has unique ID

6. **Image Selection**
   - Clicking image shows style editor
   - Tapping caption text makes it editable
   - Delete key removes selected image
   - Caption deletion separate from image deletion

7. **Caption Styles**
   - Caption styles come from project stylesheet
   - If caption style doesn't exist, use body style
   - Caption styles support all text formatting (font, color, size)
   - "noCaption" is not a style, just a flag to hide caption

## Implementation Plan

### Phase 1: Insert Menu & Basic Image Insertion (Days 1-2)
1. Replace toolbar image button with "Insert" button
2. Create Insert menu with all items (Image enabled, others disabled)
3. Create ImageAttachment class with basic properties
4. Insert image at cursor position with default style from stylesheet
5. Basic image display in text view
6. Undo/redo for insertion

### Phase 2: Stylesheet Image Styles (Days 3-4)
1. Add ImageStyle struct to StyleSheet model
2. Add image styles section to stylesheet editor
3. Create default image style for projects
4. Store imageStyleName in ImageAttachment
5. Apply style properties when inserting images
6. Serialization of image styles with stylesheet

### Phase 3: Image Property Editor (Days 5-6)
1. Detect taps on images in text view
2. Create ImagePropertyEditorView (SwiftUI sheet)
3. Show current image properties
4. Allow editing: scale, alignment, caption toggle
5. Apply changes via undo commands
6. Update image display after changes

### Phase 4: Caption Support (Days 7-8)
1. Add caption rendering below images
2. Caption text editable inline
3. Caption style from stylesheet
4. Toggle caption on/off in property editor
5. Serialization of caption data
6. Undo/redo for caption changes

### Phase 5: Polish & Testing (Day 9)
1. Context menu for images
2. Error handling and validation
3. Performance optimization
4. Comprehensive testing
5. Documentation updates

## Testing Strategy

### Unit Tests
- ImageAttachment creation and properties
- Image serialization/deserialization
- Image compression and optimization
- Undo/redo commands

### Integration Tests
- Insert image and verify in attributed string
- Scale image and verify scale change
- Align image and verify alignment
- Add caption and verify caption display
- Delete image and verify removal (with caption)
- Save/load document with images and captions

### UI Tests
- Click insert button, open style editor, select image, verify display
- Select image, change scale, verify new size
- Select image, change alignment, verify position
- Select image, enable caption, verify caption appears
- Edit caption text, verify changes persist
- Delete image via keyboard
- Undo/redo image operations

### Manual Testing
- Test with various image formats (PNG, JPEG, HEIC)
- Test with very large images (> 10MB)
- Test with many images (> 20 in one document)
- Test caption editing and formatting
- Test copy/paste from other apps
- Test appearance mode with captions

## Success Metrics
- ✅ Can insert images via Insert menu
- ✅ Insert menu shows all planned content types
- ✅ Images use default style from stylesheet
- ✅ Can tap image to edit properties
- ✅ Can change image scale (10% to 200%)
- ✅ Can change image alignment (left/center/right)
- ✅ Can add/edit/remove captions
- ✅ Caption styles from stylesheet work correctly
- ✅ Image styles defined in stylesheet
- ✅ All images using a style update when style changes
- ✅ Images + captions persist across app restarts
- ✅ Undo/redo works for all image operations
- ✅ No performance degradation with 10+ images
- ✅ All existing tests still pass

## Dependencies
- **Phase 004**: Undo/redo system
- **Phase 005**: Text formatting and serialization
- **Existing**: Stylesheet system for caption styles

## Future Enhancements (Post-MVP)
- Drag and drop image insertion
- Image rotation
- Image filters/effects
- Animated GIF support
- Link images to external URLs
- Image gallery view
- Batch image operations
- Image compression settings UI
- Cloud image storage integration
- More caption style options (numbered, lettered)

## Notes
- Images will use NSTextAttachment (native UIKit/AppKit)
- This is well-supported and integrates seamlessly with UITextView
- Base64 encoding increases size by ~33% but simplifies storage
- Consider external file storage if documents routinely exceed 50MB
- **Insert menu pattern**: Follows standard word processor pattern (Word, Pages)
- **Stylesheet integration**: Image styles work like text styles for consistency
- **Tap to edit**: Intuitive interaction - tap image to modify properties
- **Caption integration**: Captions are part of the attachment, not separate text runs
- **Scale vs Resize**: Using percentage scale instead of pixel dimensions
- **Future insert items**: List, Footnote, Endnote, Comment, Index Item planned

## Open Questions
1. ~~Should we support image captions in Phase 1?~~ **Decision: Yes, captions are core feature**
2. ~~Max image size limit?~~ **Decision: 2048px width, downscale larger**
3. ~~Support for SVG images?~~ **Decision: No, raster only for Phase 1**
4. ~~Should images be copyable as files?~~ **Decision: Yes, via context menu**
5. ~~How to handle caption text selection vs image selection?~~ **Decision: Tap image for property editor, double-tap caption for editing**
6. ~~Should caption styles be editable per-image or only via stylesheet?~~ **Decision: Via stylesheet only for consistency**
7. ~~Should we use a style editor or properties per image?~~ **Decision: Both - styles in stylesheet, tap image to override**
8. Should all Insert menu items be visible but disabled, or hidden? **Decision: Visible but disabled to show roadmap**

---
**Status**: Updated  
**Created**: 2025-11-02  
**Last Updated**: 2025-11-03  
**Version**: 2.0
