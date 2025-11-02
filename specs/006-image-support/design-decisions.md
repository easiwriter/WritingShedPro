# Phase 006: Image Support - Design Decisions

## Based on Reference Screenshots

### Screenshot Analysis

#### Image 1: Image Style Editor
Shows a comprehensive style editor with:
- **Title**: "largeImage" (current image name)
- **Scale Control**: +/- buttons with "95.00 %" display
- **Alignment**: Three visual buttons (left, center, right with icons)
- **Caption Styles**: List with "noCaption" (checked), "caption1", "caption2"
- **Navigation**: Cancel/Done buttons

#### Image 2: Image Chooser Menu
Shows a popover menu with:
- **Image Selection**: List of available images (largeImage, mediumImage, smallImage)
- **Style Editors**: "Edit Image Styles" and "Edit Caption Styles" options
- **Context**: Appears over document text ("Test")

## Key Design Decisions

### 1. Captions are Core Feature (Not Post-MVP)
**Decision**: Include caption support in Phase 1  
**Rationale**: Your reference design shows captions as integral to image styling  
**Impact**: 
- Add ~2 days to implementation timeline (now 9 days vs 7 days)
- Captions use existing stylesheet system (no new infrastructure)
- Better UX consistency with your existing app design

### 2. Scale (Percentage) vs Resize (Pixels)
**Decision**: Use percentage-based scaling (10% - 200%)  
**Rationale**: Matches your reference UI with +/- buttons and percentage display  
**Benefits**:
- Simpler mental model for users
- Easier to make images uniformly sized
- More responsive (adapts to different screen sizes)
- Maintains aspect ratio automatically

### 3. Style Editor Sheet (Not Inline Handles)
**Decision**: Use sheet/popover UI for all image properties  
**Rationale**: Your reference shows unified style editor approach  
**Benefits**:
- Consistent with text formatting UI pattern
- Less cluttered document view
- All controls in one place
- Works better on small screens (iOS)
- Matches your existing app design language

### 4. Caption Styles from Stylesheet
**Decision**: Reuse existing text style system for captions  
**Rationale**: Your reference shows "caption1", "caption2" styles  
**Benefits**:
- No new style infrastructure needed
- Consistent styling across document
- Project-level style control
- Same editor as text styles ("Edit Caption Styles")

### 5. "noCaption" Option
**Decision**: Use flag + option (not just missing caption)  
**Rationale**: Your reference explicitly shows "noCaption" as a choice  
**Benefits**:
- Clear user intent (hide vs empty)
- Preserves caption text if user toggles off/on
- Better for templates (images can have caption slot)

## Implementation Approach

### Phase Structure (9 days total)

**Phase 1: Foundation (Days 1-3)**
- ImageAttachment model with scale, alignment, caption properties
- Basic insertion workflow
- Serialization with all properties

**Phase 2: Style Editor UI (Days 4-5)**
- Create ImageStyleEditorView (SwiftUI sheet)
- Scale control (+/- buttons, percentage display)
- Alignment selector (three visual buttons)
- File picker integration
- Real-time preview

**Phase 3: Caption Support (Days 6-7)**
- Caption style picker (loads from stylesheet)
- Caption rendering below image
- Inline caption editing
- noCaption/caption1/caption2 options
- Caption formatting from stylesheet

**Phase 4: Management (Day 8)**
- Delete functionality
- Copy/paste with captions
- Image compression
- Performance optimization

**Phase 5: Polish (Day 9)**
- Error handling
- Accessibility
- Testing
- Documentation

## UI Component Specifications

### Image Style Editor Sheet
```
┌─────────────────────────────────────┐
│  Cancel      largeImage        Done │
├─────────────────────────────────────┤
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │  ≡  │ │  ≡  │ │  ≡  │  Alignment│
│  │     │ │     │ │     │          │
│  └─────┘ └─────┘ └─────┘          │
│                                     │
│  ⚡ Scale                           │
│     ┌───┐      95.00 %     ┌───┐  │
│     │ - │                   │ + │  │
│     └───┘                   └───┘  │
│                                     │
│  💬 Caption Styles:                │
│     ✓ noCaption                    │
│       caption1                     │
│       caption2                     │
│                                     │
└─────────────────────────────────────┘
```

### Image in Document View
```
┌─────────────────────────────┐
│                             │
│        [IMAGE CONTENT]      │  ← Image at specified scale
│                             │
└─────────────────────────────┘
  Caption text in caption1 style  ← Optional caption (if enabled)
```

## Data Structure

### ImageAttachment Properties
```swift
class ImageAttachment: NSTextAttachment {
    var imageID: UUID                    // Unique identifier
    var imageData: Data?                 // Original image data
    var scale: CGFloat = 1.0             // 0.1 to 2.0 (10% to 200%)
    var alignment: ImageAlignment        // .left, .center, .right
    var hasCaption: Bool = false         // Show/hide caption
    var captionText: String?             // Optional caption text
    var captionStyle: String?            // Caption style name (from stylesheet)
}
```

### Serialization Format
```json
{
  "type": "image",
  "imageID": "uuid",
  "imageData": "base64...",
  "scale": 0.95,
  "alignment": "center",
  "hasCaption": true,
  "captionText": "My caption",
  "captionStyle": "caption1"
}
```

## Differences from Original Spec

| Original Plan | Updated (Based on Screenshots) |
|---------------|-------------------------------|
| Resize handles (drag) | Scale control (+/- buttons) |
| Pixel dimensions | Percentage scale (10%-200%) |
| Captions in Phase 4+ | Captions in Phase 3 (core) |
| Direct file picker | Style editor → file picker |
| Size in pixels | Scale as percentage |
| Inline controls | Unified sheet/popover UI |

## Benefits of Updated Approach

1. **Consistency**: Matches your existing app design patterns
2. **Simplicity**: Percentage is easier than pixels for users
3. **Completeness**: Captions from start, not bolted on later
4. **Maintainability**: Reuses stylesheet system
5. **User Experience**: Unified style editor is cleaner UI
6. **Flexibility**: Easy to add caption3, caption4, etc. later

## Next Steps

1. Review updated spec and confirm approach
2. Begin implementation with ImageAttachment model
3. Create ImageStyleEditorView (SwiftUI)
4. Implement scale and alignment first
5. Add caption support once scale/align working
6. Test with real images and content

---
**Status**: Ready for Implementation  
**Timeline**: 9 working days  
**Confidence**: High (based on existing patterns)
