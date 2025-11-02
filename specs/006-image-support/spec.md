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

### US-002: Resize Images
**As a** writer  
**I want to** resize images in my document  
**So that** I can control their visual impact and layout

**Acceptance Criteria:**
- Click image to select it
- Drag handles to resize proportionally
- Option to set exact dimensions (width/height)
- Undo/redo works for resizing
- Images maintain aspect ratio by default

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
    var displaySize: CGSize        // Current display size
    var alignment: ImageAlignment  // Left/Center/Right
    var imageID: UUID              // Unique identifier
    
    enum ImageAlignment {
        case left
        case center
        case right
        case inline
    }
    
    // Methods
    func resize(to size: CGSize)
    func setAlignment(_ alignment: ImageAlignment)
    func getOptimizedImage() -> UIImage?
}
```

#### Serialization Format
Images will be embedded in the attributed string JSON format:

```json
{
  "text": "Here is my image:\n[IMAGE]\nMore text",
  "attributes": [
    {
      "type": "textAttachment",
      "location": 17,
      "length": 1,
      "imageID": "UUID-HERE",
      "imageData": "base64-encoded-data",
      "width": 300.0,
      "height": 200.0,
      "alignment": "center"
    }
  ]
}
```

### UI Components

#### Toolbar Button
- Icon: SF Symbol "photo" or "photo.badge.plus"
- Position: After color picker button
- Action: Opens file picker

#### File Picker
- Supports: .png, .jpg, .jpeg, .heic, .gif
- macOS: NSOpenPanel
- iOS: UIDocumentPickerViewController or PHPickerViewController

#### Image Selection UI
- Selected image shows resize handles (macOS)
- Selected image shows toolbar with resize/align/delete options (iOS)
- Context menu: Copy, Delete, Resize, Align

#### Resize UI (macOS)
- 8 resize handles around selected image
- Maintain aspect ratio by default
- Hold Shift to ignore aspect ratio
- Display current dimensions tooltip

#### Alignment UI
- Toolbar buttons: Left/Center/Right/Inline
- Keyboard shortcuts: Cmd+L, Cmd+E, Cmd+R

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
    let displaySize: CGSize
    
    func execute(on file: File) { /* insert */ }
    func undo(on file: File) { /* remove */ }
}
```

#### ResizeImageCommand
```swift
struct ResizeImageCommand: UndoableCommand {
    let imageID: UUID
    let oldSize: CGSize
    let newSize: CGSize
    
    func execute(on file: File) { /* resize */ }
    func undo(on file: File) { /* restore size */ }
}
```

#### DeleteImageCommand
```swift
struct DeleteImageCommand: UndoableCommand {
    let imageData: Data
    let location: Int
    let displaySize: CGSize
    
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
   - List supported formats

4. **Copy/Paste**
   - Support pasting images from clipboard
   - Support copying images to clipboard
   - Handle copying text+images together

5. **Multiple Images**
   - No limit on number of images per document
   - Warn if total document size > 100MB

6. **Image Selection**
   - Clicking image selects it
   - Arrow keys move between images
   - Delete key removes selected image

## Implementation Plan

### Phase 1: Basic Image Insertion (MVP)
1. Create ImageAttachment class
2. Add toolbar button and file picker
3. Insert image at cursor position
4. Basic serialization (embed in JSON)
5. Undo/redo for insertion

### Phase 2: Resize and Alignment
1. Add resize handles (macOS)
2. Add resize gesture (iOS)
3. Implement alignment options
4. Undo/redo for resize/align

### Phase 3: Image Management
1. Delete images
2. Copy/paste images
3. Image compression
4. Performance optimization

### Phase 4: Polish
1. Context menu actions
2. Keyboard shortcuts
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
- Resize image and verify size change
- Delete image and verify removal
- Save/load document with images

### UI Tests
- Click insert button, select image, verify display
- Select image, resize, verify new size
- Delete image via keyboard
- Undo/redo image operations

### Manual Testing
- Test with various image formats (PNG, JPEG, HEIC)
- Test with very large images (> 10MB)
- Test with many images (> 20 in one document)
- Test copy/paste from other apps

## Success Metrics
- ✅ Can insert images via file picker
- ✅ Images display inline with text
- ✅ Can resize images maintaining aspect ratio
- ✅ Can align images (left/center/right)
- ✅ Images persist across app restarts
- ✅ Undo/redo works for all image operations
- ✅ No performance degradation with 10+ images
- ✅ All existing tests still pass

## Dependencies
- **Phase 004**: Undo/redo system
- **Phase 005**: Text formatting and serialization

## Future Enhancements (Post-MVP)
- Drag and drop image insertion
- Image captions
- Image rotation
- Image filters/effects
- Animated GIF support
- Link images to external URLs
- Image gallery view
- Batch image operations
- Image compression settings UI
- Cloud image storage integration

## Notes
- Images will use NSTextAttachment (native UIKit/AppKit)
- This is well-supported and integrates seamlessly with UITextView
- Alternative (custom rendering) would be more complex
- Base64 encoding increases size by ~33% but simplifies storage
- Consider external file storage if documents routinely exceed 50MB

## Open Questions
1. Should we support image captions in Phase 1? **Decision: No, future phase**
2. Max image size limit? **Decision: 2048px width, downscale larger**
3. Support for SVG images? **Decision: No, raster only for Phase 1**
4. Should images be copyable as files? **Decision: Yes, via context menu**

---
**Status**: Draft  
**Created**: 2025-11-02  
**Last Updated**: 2025-11-02  
**Version**: 1.0
