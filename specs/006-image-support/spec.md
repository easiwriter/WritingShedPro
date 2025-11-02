# Phase 006: Image Support Specification

## Overview
Add support for inline images within text documents, allowing users to insert, resize, and align images alongside their text content. Images will be stored efficiently and persist across sessions.

## Feature Priority
**HIGH** - Requested by user as next feature after text formatting

## User Stories

### US-001: Insert Image
**As a** writer  
**I want to** insert images into my documents  
**So that** I can include illustrations, photos, or diagrams with my text

**Acceptance Criteria:**
- Toolbar button for inserting images
- File picker supports common image formats (PNG, JPEG, HEIC, GIF)
- Image appears inline at cursor position
- Image can be inserted in any paragraph
- Undo/redo works for image insertion

### US-002: Scale Images
**As a** writer  
**I want to** scale images in my document  
**So that** I can control their visual impact and layout

**Acceptance Criteria:**
- Click image to show style editor
- Scale control with +/- buttons and percentage display
- Scale from 10% to 200%
- Undo/redo works for scaling
- Images maintain aspect ratio automatically

### US-003: Image Alignment
**As a** writer  
**I want to** align images within the text  
**So that** I can control layout and text flow

**Acceptance Criteria:**
- Left-align (default)
- Center-align
- Right-align
- Inline with text baseline
- Undo/redo works for alignment changes

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
- Option to enable/disable caption for each image
- Caption text editable inline below image
- Caption styles from stylesheet (like text styles)
- Multiple caption styles available (caption1, caption2, etc.)
- "noCaption" option to hide caption
- Captions persist with document
- Undo/redo works for caption changes

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│               FileEditView.swift                │
│  - Toolbar button for image insertion          │
│  - File picker integration                      │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│          FormattedTextEditor.swift              │
│  - UITextView with NSTextAttachment support     │
│  - Image selection and interaction              │
└────────────────┬────────────────────────────────┘
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

#### ImageAttachment Class
```swift
class ImageAttachment: NSTextAttachment {
    // Properties
    var imageData: Data?           // Original image data
    var scale: CGFloat = 1.0       // Scale percentage (0.1 to 2.0 = 10% to 200%)
    var alignment: ImageAlignment  // Left/Center/Right
    var imageID: UUID              // Unique identifier
    var captionText: String?       // Optional caption text
    var captionStyle: String?      // Caption style name (from stylesheet)
    var hasCaption: Bool = false   // Whether to show caption
    
    enum ImageAlignment: String {
        case left
        case center
        case right
        case inline
    }
    
    // Computed properties
    var displaySize: CGSize {
        // Calculate from original image size * scale
    }
    
    // Methods
    func setScale(_ scale: CGFloat)
    func setAlignment(_ alignment: ImageAlignment)
    func setCaption(_ text: String?, style: String?)
    func getOptimizedImage() -> UIImage?
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

#### Toolbar Button
- Icon: SF Symbol "photo" or "photo.on.rectangle"
- Position: After color picker button
- Action: Opens image style sheet (like text formatting)

#### Image Style Editor (Sheet/Popover)
Based on user's reference implementation:
- **Title**: Shows current image name or "Image Settings"
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

### Phase 1: Basic Image Insertion (MVP - Days 1-3)
1. Create ImageAttachment class with scale and alignment
2. Add toolbar button (opens style editor, not file picker directly)
3. Implement image style editor sheet
4. Insert image at cursor position with default settings
5. Basic serialization (embed in JSON with scale/alignment)
6. Undo/redo for insertion

### Phase 2: Image Style Editor (Days 4-5)
1. Create ImageStyleEditorView (SwiftUI sheet)
2. Add scale control (+/- buttons, percentage display)
3. Add alignment control (three button selector)
4. Implement file picker within style editor
5. Update image on style changes
6. Undo/redo for scale and alignment

### Phase 3: Caption Support (Days 6-7)
1. Add caption properties to ImageAttachment
2. Add caption style selector to style editor
3. Implement caption rendering below image
4. Make caption text editable inline
5. Load caption styles from stylesheet
6. Undo/redo for caption changes

### Phase 4: Image Management (Day 8)
1. Delete images
2. Copy/paste images with captions
3. Image compression
4. Performance optimization

### Phase 5: Polish (Day 9)
1. Context menu actions
2. Error handling
3. Accessibility support
4. Comprehensive testing

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
- ✅ Can insert images via style editor + file picker
- ✅ Images display inline with text
- ✅ Can scale images from 10% to 200%
- ✅ Can align images (left/center/right)
- ✅ Can add/edit/remove captions
- ✅ Caption styles from stylesheet work correctly
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
- Alternative (custom rendering) would be more complex
- Base64 encoding increases size by ~33% but simplifies storage
- Consider external file storage if documents routinely exceed 50MB
- **Caption integration**: Captions are separate text runs with special formatting
- **Style editor pattern**: Following user's reference design with sheet/popover UI
- **Scale vs Resize**: Using percentage scale (like reference) instead of pixel dimensions
- **Caption styles**: Reusing existing stylesheet system, no new style infrastructure needed

## Open Questions
1. ~~Should we support image captions in Phase 1?~~ **Decision: Yes, captions are core feature**
2. ~~Max image size limit?~~ **Decision: 2048px width, downscale larger**
3. ~~Support for SVG images?~~ **Decision: No, raster only for Phase 1**
4. ~~Should images be copyable as files?~~ **Decision: Yes, via context menu**
5. How to handle caption text selection vs image selection? **Decision: Tap image for style editor, tap caption for text editing**
6. Should caption styles be editable per-image or only via stylesheet? **Decision: Via stylesheet only, keeps consistency**

---
**Status**: Draft  
**Created**: 2025-11-02  
**Last Updated**: 2025-11-02  
**Version**: 1.0
