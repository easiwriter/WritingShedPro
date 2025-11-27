# PDF Generation Fix - Using Custom Page Renderer

## Problem

The PDF generation was producing incorrect output compared to the paginated view preview. The issue manifested as:
- Incorrect pagination breaks
- Missing or misplaced footnotes
- Text overflow and layout issues
- `CGContextClipToRect: invalid context` errors

### Root Cause

The PDF generation code was using `UISimpleTextPrintFormatter` which:
- Does NOT support custom text layout calculations
- Does NOT support footnotes
- Does NOT use the same pagination logic as the paginated view
- Has no awareness of `PaginatedTextLayoutManager` or `FootnoteAwareLayoutManager`

This caused PDFs to render completely differently from the preview.

## Solution

Created a custom `UIPrintPageRenderer` subclass (`CustomPDFPageRenderer`) that:
1. Uses the same `PaginatedTextLayoutManager` as the paginated view
2. Respects footnote-aware layout calculations
3. Renders text with proper container sizing
4. Positions footnotes correctly at the bottom of pages
5. Processes attachments (footnote markers, comments) identically to the view

### Architecture

```
PaginatedDocumentView          PrintService
        |                           |
        v                           v
PaginatedTextLayoutManager <- CustomPDFPageRenderer
        |                           |
        v                           v
FootnoteAwareLayoutManager     PDF Context
```

Both the preview and PDF generation now use the **exact same layout engine**.

## Implementation Details

### CustomPDFPageRenderer.swift

New class that:
- Takes a `PaginatedTextLayoutManager` instance
- Overrides `numberOfPages` to return the layout manager's page count
- Overrides `drawPage(at:in:)` to render each page

For each page:
1. Gets page info from layout manager (character range, container size)
2. Queries footnotes for that page
3. Extracts text for the page's character range
4. Processes attachments (footnotes → superscript numbers, comments → removed)
5. Draws text in the proper rect with proper insets
6. Renders footnotes at the bottom if present

### PrintService.swift Changes

Updated PDF generation methods:
```swift
// OLD: Simple formatter approach
private static func createPDF(from content: NSAttributedString, ...) -> Data? {
    let formatter = UISimpleTextPrintFormatter(attributedText: content)
    let renderer = UIPrintPageRenderer()
    renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
    // ...
}

// NEW: Custom renderer with layout manager
private static func createPDF(
    from content: NSAttributedString,
    pageSetup: PageSetup,
    title: String,
    version: Version?,
    project: Project,
    context: ModelContext
) -> Data? {
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
    // ...
}
```

### Method Signature Changes

`generatePDF` methods now require additional parameters:
- `project: Project` - For stylesheet (footnote formatting)
- `context: ModelContext` - For footnote queries

```swift
// Single file
static func generatePDF(
    from file: TextFile,
    pageSetup: PageSetup? = nil,
    project: Project,
    context: ModelContext
) -> Data?

// Multiple files
static func generatePDF(
    from files: [TextFile],
    title: String,
    pageSetup: PageSetup? = nil,
    project: Project,
    context: ModelContext
) -> Data?
```

## Benefits

✅ **Consistent Layout** - PDFs match the preview exactly  
✅ **Footnote Support** - Footnotes render correctly in PDFs  
✅ **Proper Pagination** - Page breaks happen at the right places  
✅ **Attachment Handling** - Footnote markers and comments processed correctly  
✅ **Font Scaling** - Mac Catalyst 1.3x scaling properly removed for print  

## Testing

To test the fix:

1. Open a document with footnotes in the paginated view
2. Note the page breaks and footnote positions
3. Generate a PDF from that document
4. Verify the PDF matches the preview exactly:
   - Same page breaks
   - Same footnote positions
   - Same text layout

## Known Limitations

- **Multi-file PDFs**: Currently don't support footnotes (because there's no single `Version` context for combined files)
- **Performance**: PDF generation is now slightly slower because it uses the full pagination system (acceptable trade-off for correctness)

## Future Improvements

1. Support footnotes in multi-file PDFs by tracking version per section
2. Optimize layout calculation for PDF-only scenarios
3. Add page headers/footers in PDF rendering
4. Support for embedded images in PDFs

## Related Files

- `/Services/CustomPDFPageRenderer.swift` - New custom renderer
- `/Services/PrintService.swift` - Updated PDF generation methods
- `/Services/PaginatedTextLayoutManager.swift` - Shared layout engine
- `/Views/PaginatedDocumentView.swift` - Preview uses same engine
- `/Views/VirtualPageScrollView.swift` - Page rendering reference

## Commit Message

```
Fix PDF generation to match paginated view preview

- Create CustomPDFPageRenderer using PaginatedTextLayoutManager
- Replace UISimpleTextPrintFormatter with custom renderer
- Support footnote-aware layout in PDF generation
- Process attachments (footnote markers, comments) correctly
- Update PrintService.generatePDF() signatures to include project and context
- Remove platform font scaling for accurate print sizes

Resolves: Inconsistent PDF rendering vs preview
Resolves: Missing footnotes in PDFs
Resolves: CGContextClipToRect invalid context errors
```
