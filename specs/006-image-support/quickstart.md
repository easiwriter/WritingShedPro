# Phase 006: Image Support - Quick Start Guide

## 🎯 Goal
Add inline image support to text documents with insert, resize, align, and persist functionality.

## 📋 Implementation Checklist

### Step 1: Create ImageAttachment Model (1-2 hours)
- [ ] Create `ImageAttachment.swift` in Models folder
- [ ] Subclass `NSTextAttachment`
- [ ] Add properties: `imageID`, `displaySize`, `alignment`, `imageData`
- [ ] Implement `ImageAlignment` enum (left, center, right, inline)
- [ ] Add `resize(to:)` and `setAlignment(_:)` methods
- [ ] Write unit tests for ImageAttachment

### Step 2: Update AttributedStringSerializer (2-3 hours)
- [ ] Add image encoding in `encode()` method
  - Detect NSTextAttachment in attributed string
  - Extract image data
  - Convert to base64
  - Store in JSON with position and properties
- [ ] Add image decoding in `decode()` method
  - Parse image data from JSON
  - Create ImageAttachment instances
  - Insert into attributed string at correct positions
- [ ] Write tests for image serialization round-trip

### Step 3: Add File Picker UI (1-2 hours)
- [ ] Add image toolbar button to `FileEditView.swift`
  - SF Symbol: "photo.badge.plus"
  - Position after color picker
- [ ] Implement file picker presentation
  - macOS: NSOpenPanel
  - iOS: PHPickerViewController
- [ ] Filter for image types: PNG, JPEG, HEIC, GIF
- [ ] Handle file selection callback

### Step 4: Implement Image Insertion (2-3 hours)
- [ ] Add `insertImage()` method to `FormattedTextEditor`
- [ ] Load image from selected file
- [ ] Create ImageAttachment
- [ ] Set initial display size (fit to width, max 600px)
- [ ] Insert at cursor position
- [ ] Update attributed string
- [ ] Trigger undo command creation

### Step 5: Add Undo/Redo for Images (1-2 hours)
- [ ] Create `InsertImageCommand.swift`
- [ ] Create `DeleteImageCommand.swift`
- [ ] Create `ResizeImageCommand.swift`
- [ ] Integrate with existing undo manager
- [ ] Write tests for image undo/redo

### Step 6: Image Selection and Deletion (2-3 hours)
- [ ] Detect image tap/click in FormattedTextEditor
- [ ] Show selection state (border or highlight)
- [ ] Handle Delete/Backspace key when image selected
- [ ] Remove image from attributed string
- [ ] Create undo command

### Step 7: Image Resizing (3-4 hours)
- [ ] Add resize handles on macOS (8 handles)
- [ ] Add pinch gesture on iOS
- [ ] Maintain aspect ratio by default
- [ ] Update ImageAttachment size
- [ ] Refresh display
- [ ] Create undo command

### Step 8: Image Alignment (1-2 hours)
- [ ] Add alignment buttons to toolbar
- [ ] Implement left/center/right alignment
- [ ] Update paragraph style for alignment
- [ ] Create undo command

### Step 9: Testing (2-3 hours)
- [ ] Unit tests for ImageAttachment
- [ ] Unit tests for serialization
- [ ] Integration tests for insert/resize/delete
- [ ] UI tests for toolbar interaction
- [ ] Manual testing with various image formats
- [ ] Performance testing with 10+ images

### Step 10: Polish (1-2 hours)
- [ ] Add image compression for large files
- [ ] Add loading indicator for large images
- [ ] Error handling for unsupported formats
- [ ] Accessibility labels
- [ ] Documentation

## 🚀 Quick Implementation Path (MVP)

If you need a minimal working version quickly:

### Minimum Viable Feature (4-6 hours)
1. **Basic ImageAttachment** (30 min)
   - Simple NSTextAttachment subclass with imageData property
   
2. **Toolbar Button + File Picker** (1 hour)
   - Add button, open file picker, get image file
   
3. **Insert Image** (1 hour)
   - Load image, create attachment, insert at cursor
   
4. **Basic Serialization** (1.5 hours)
   - Save image as base64 in JSON
   - Restore on load
   
5. **Delete Image** (30 min)
   - Select and delete with backspace
   
6. **Basic Undo** (1 hour)
   - InsertImageCommand and DeleteImageCommand

## 📦 File Structure

```
Models/
  ImageAttachment.swift           (NEW)
  
Services/
  AttributedStringSerializer.swift (MODIFY - add image support)
  
Views/
  FileEditView.swift              (MODIFY - add toolbar button)
  Components/
    FormattedTextEditor.swift     (MODIFY - image insertion/selection)
    
Models/Commands/
  InsertImageCommand.swift        (NEW)
  DeleteImageCommand.swift        (NEW)
  ResizeImageCommand.swift        (NEW)

Tests/
  ImageAttachmentTests.swift      (NEW)
  ImageSerializationTests.swift   (NEW)
  ImageInsertionTests.swift       (NEW)
```

## 🔑 Key Code Patterns

### Insert Image
```swift
func insertImage(from imageData: Data) {
    let attachment = ImageAttachment()
    attachment.imageData = imageData
    attachment.image = UIImage(data: imageData)
    attachment.displaySize = calculateDisplaySize(for: attachment.image!)
    
    let attachmentString = NSAttributedString(attachment: attachment)
    textView.textStorage.insert(attachmentString, at: textView.selectedRange.location)
    
    // Create undo command
    let command = InsertImageCommand(imageData: imageData, location: textView.selectedRange.location)
    file.addCommand(command)
}
```

### Serialize Images
```swift
// In encode()
if let attachment = attrs[.attachment] as? ImageAttachment,
   let imageData = attachment.imageData {
    attributes.append([
        "type": "image",
        "location": i,
        "imageData": imageData.base64EncodedString(),
        "width": attachment.displaySize.width,
        "height": attachment.displaySize.height
    ])
}
```

### Deserialize Images
```swift
// In decode()
if attrDict["type"] == "image",
   let imageDataString = attrDict["imageData"] as? String,
   let imageData = Data(base64Encoded: imageDataString) {
    let attachment = ImageAttachment()
    attachment.imageData = imageData
    attachment.image = UIImage(data: imageData)
    attachment.displaySize = CGSize(width: width, height: height)
    
    result.addAttribute(.attachment, value: attachment, range: range)
}
```

## ⚠️ Common Pitfalls

1. **Large Images**: Always compress/downscale images > 2048px
2. **Base64 Overhead**: Base64 increases size by 33%, plan accordingly
3. **Memory Management**: Don't keep all images decoded in memory
4. **Undo Stack**: Image data in undo commands can be large
5. **Thread Safety**: Load/compress images on background thread
6. **Selection State**: Track which image is selected separately from text selection

## 📊 Estimated Timeline

- **Minimum Viable Product**: 4-6 hours
- **Full Feature Set**: 18-25 hours
- **Testing & Polish**: 3-5 hours
- **Total**: 21-30 hours

## 🎯 Success Criteria

- ✅ Can insert PNG/JPEG images via toolbar
- ✅ Images display inline with text
- ✅ Images persist when saving/loading
- ✅ Can delete images with backspace
- ✅ Undo/redo works for image operations
- ✅ No crashes with 10+ images in document

---
**Ready to start?** Begin with Step 1: Create ImageAttachment Model
