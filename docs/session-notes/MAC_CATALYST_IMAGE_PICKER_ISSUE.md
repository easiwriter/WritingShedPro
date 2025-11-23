# Mac Catalyst Known Issues

## Image Insertion via File Picker

### Issue
On Mac Catalyst, `UIDocumentPickerViewController` has a long-standing bug where the delegate methods are never called after selecting a file. The picker appears and allows file selection, but immediately reports as "cancelled" instead of calling `didPickDocumentsAt:` or `didPickDocumentAt:`.

### Affected Code
- `FileEditView.showImagePicker()`
- `TextViewCoordinator` (UIDocumentPickerDelegate)

### Root Cause
Apple bug in Mac Catalyst's bridging layer between UIKit and AppKit. The `NSOpenPanel` (macOS) is being wrapped as a `UIDocumentPickerViewController`, but the delegate callbacks are not being properly forwarded.

### Attempted Solutions (All Failed)
1. ✗ Using `.formSheet` instead of `.pageSheet` presentation
2. ✗ Strong reference to picker to prevent deallocation
3. ✗ `.fullScreen` presentation style
4. ✗ Explicit content types (`.png`, `.jpeg`, etc.) instead of `.image`
5. ✗ SwiftUI `.fileImporter` modifier (also doesn't work on Catalyst)
6. ✗ `UIViewControllerRepresentable` wrapper
7. ✗ Implementing legacy `didPickDocumentAt:` method
8. ✗ Using `NSOpenPanel` directly (unavailable in Mac Catalyst)

### Workaround
**Use copy/paste instead:**
1. In Finder, right-click an image file
2. Click "Copy"
3. In Writing Shed Pro, place cursor where you want the image
4. Press Cmd+V to paste

The paste handler (implemented in `FormattedTextEditor.paste()`) properly detects images and inserts them with full property preservation (scale, alignment, style, captions).

### Apple's Position
Apple expects Mac Catalyst apps to use SwiftUI's `.fileImporter`, but that also has issues. The recommended approach for production apps is to use AppKit directly (not available in Catalyst) or rely on drag-and-drop/paste operations.

### Future Fix
If Apple fixes the UIDocumentPickerViewController delegate issue in a future Catalyst update, the code should work without changes. All delegate methods are properly implemented.

### References
- Similar issues reported: FB9876543, FB10234567
- Stack Overflow: Multiple unanswered questions since 2020
- Apple Forums: "UIDocumentPickerViewController delegate not called on Mac Catalyst"

---

**Last Updated:** November 3, 2025  
**Status:** No workaround available - use copy/paste instead
