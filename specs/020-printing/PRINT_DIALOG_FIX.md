# Print Dialog Fix - Using Custom Renderer

## Problem Identified

The print dialog was still using `UISimpleTextPrintFormatter`, not the new `CustomPDFPageRenderer`. This is why the logs showed:

**Paginated View (Working):**
```
🔧 Using FOOTNOTE-AWARE layout with version: B8B52E7D
🔄 Footnote layout iteration 1
🔄 Footnote layout iteration 2
✅ Footnote layout converged after 2 iterations
```

**Print Dialog (Broken):**
```
[No pagination logs]
CGContextClipToRect: invalid context 0x0
✅ [PrintService] Print job completed
```

The PDF **generation** methods were updated, but the **print dialog** method (`presentPrintDialog`) was not.

## Solution

Updated the entire print flow to use `CustomPDFPageRenderer`:

### 1. Updated `printFile()` Method

**Before:**
```swift
static func printFile(
    _ file: TextFile,
    from viewController: UIViewController,
    completion: @escaping (Bool, Error?) -> Void
)
```

**After:**
```swift
static func printFile(
    _ file: TextFile,
    project: Project,
    context: ModelContext,
    from viewController: UIViewController,
    completion: @escaping (Bool, Error?) -> Void
)
```

Now:
- Gets attributed content directly from file's current version
- Removes platform scaling
- Passes project and context to print dialog

### 2. Updated `presentPrintDialog()` Method

**Before (using UISimpleTextPrintFormatter):**
```swift
let formatter = UISimpleTextPrintFormatter(attributedText: content)
formatter.contentInsets = UIEdgeInsets(...)
printController.printFormatter = formatter
```

**After (using CustomPDFPageRenderer):**
```swift
let textStorage = NSTextStorage(attributedString: content)
let layoutManager = PaginatedTextLayoutManager(
    textStorage: textStorage,
    pageSetup: pageSetup
)
let _ = layoutManager.calculateLayout(version: version, context: context)

let renderer = CustomPDFPageRenderer(
    layoutManager: layoutManager,
    pageSetup: pageSetup,
    version: version,
    context: context,
    project: project
)

printController.printPageRenderer = renderer
```

### 3. Updated `PaginatedDocumentView.printDocument()`

**Before:**
```swift
PrintService.printFile(textFile, from: viewController) { ... }
```

**After:**
```swift
PrintService.printFile(
    textFile,
    project: project,
    context: modelContext,
    from: viewController
) { ... }
```

## Expected Behavior

Now when you print, you should see in the logs:

```
🖨️ [PrintService] Printing file: YourFile.txt
🖨️ Print Dialog Setup:
   - Using CustomPDFPageRenderer with footnote support
   - Calculated pages: 1
🔧 Using FOOTNOTE-AWARE layout with version: B8B52E7D
🔄 Footnote layout iteration 1
🔄 Footnote layout iteration 2
✅ Footnote layout converged after 2 iterations
✅ [PrintService] Print job completed
```

The `CGContextClipToRect: invalid context 0x0` error should be gone, and the print preview should match the paginated view exactly.

## Files Modified

1. **`Services/PrintService.swift`**
   - `printFile()` - Added project and context parameters
   - `presentPrintDialog()` - Switched from UISimpleTextPrintFormatter to CustomPDFPageRenderer
   - Now uses `printPageRenderer` instead of `printFormatter`

2. **`Views/PaginatedDocumentView.swift`**
   - `printDocument()` - Pass project and context to PrintService

## Testing

1. Open a document in paginated view
2. Click the print button
3. Check the console logs - should now show pagination calculation
4. Preview should match the paginated view exactly
5. Print or save as PDF - output should be correct

## Note on Collections/Submissions

The `printCollection()` and `printSubmission()` methods still use the old approach because they combine multiple files. These would need additional refactoring to support per-file pagination with footnotes. This is tracked as future work.

## Related Files

- `/Services/PrintService.swift` - Print coordination
- `/Services/CustomPDFPageRenderer.swift` - Custom renderer
- `/Services/PaginatedTextLayoutManager.swift` - Layout engine
- `/Views/PaginatedDocumentView.swift` - Print button integration
