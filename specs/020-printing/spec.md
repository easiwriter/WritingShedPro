# Feature 020: Printing Support

## Overview

Enable printing of text files from the Writing Shed Pro app on both iOS and macOS. Users can print individual files or entire collections/submissions, with proper pagination, formatting, and footnote support.

**Key Features:**
- Print single text files
- Print collections (multiple files combined)
- Print submissions (multiple files combined)
- Respect pagination view layout
- Include all formatting (bold, italic, styles, etc.)
- Include footnotes with proper positioning
- Support page setup preferences (margins, size, etc.)
- Native print dialog integration
- Print preview before printing

---

## User Stories

### US1: Print Single File
**As a** writer  
**I want to** print a single text file  
**So that** I can review my work on paper or share a physical copy

**Acceptance Criteria:**
- Print button accessible from file edit view
- Print button accessible from pagination view
- Uses current page setup (margins, paper size)
- Includes all formatting (bold, italic, colors, etc.)
- Includes all footnotes with proper positioning
- Shows native print dialog with preview
- Supports both portrait and landscape orientations
- Works on both iOS and macOS

### US2: Print Collection
**As a** writer  
**I want to** print an entire collection  
**So that** I can have a complete physical copy of related files

**Acceptance Criteria:**
- Print button accessible from collection detail view
- Files print in the order they appear in the collection
- No page breaks between files (continuous flow)
- Each file's content flows naturally into the next
- All formatting and footnotes preserved
- Uses current page setup preferences
- Shows preview of combined output

### US3: Print Submission
**As a** writer  
**I want to** print an entire submission  
**So that** I can submit physical copies to publishers or agents

**Acceptance Criteria:**
- Print button accessible from submission detail view
- Files print in the order they appear in the submission
- No page breaks between files (continuous flow)
- All formatting and footnotes preserved
- Uses current page setup preferences
- Professional layout suitable for submission

---

## Technical Requirements

### TR1: Print Architecture
- Use `UIPrintInteractionController` on iOS
- Use `NSPrintOperation` on macOS via Mac Catalyst
- Reuse existing `PaginatedTextLayoutManager` for layout
- Generate print-ready `NSAttributedString` with proper formatting
- Support page range selection in print dialog

### TR2: Content Preparation
- For single files: Use `Version.attributedContent`
- For collections/submissions: Combine multiple files' `attributedContent`
- Apply platform scaling removal (use print sizes, not edit sizes)
- Include all attachments (footnotes, images - images in future phase)
- Maintain paragraph styles and formatting

### TR3: Footnote Handling
- Footnotes render at bottom of pages where referenced
- Use existing `FootnoteManager` for positioning
- Maintain footnote numbering across multiple files
- Ensure footnotes don't overflow page boundaries

### TR4: Page Setup Integration
- Use global `PageSetupPreferences` settings
- Support custom margins, paper size, orientation
- Apply header/footer if configured (future enhancement)
- Respect line spacing and paragraph spacing

### TR5: Platform Compatibility
- iOS: Full UIPrintInteractionController support
- Mac Catalyst: NSPrintOperation through UIKit bridge
- Handle differences in print dialog presentation
- Support AirPrint on iOS
- Support system printers on Mac

---

## Implementation Plan

### Phase 1: Core Print Infrastructure (Priority 1)
**Goal:** Enable printing a single file with basic formatting

**Tasks:**
1. Create `PrintService.swift` - Core printing coordination
2. Create `PrintFormatter.swift` - Format content for printing
3. Implement print action in `FileEditView`
4. Implement print action in `PaginatedDocumentView`
5. Add print button to toolbars
6. Basic UIPrintInteractionController integration

**Deliverables:**
- Single file printing works on iOS
- Uses existing page setup
- Shows native print dialog

### Phase 2: Mac Catalyst Support (Priority 1)
**Goal:** Enable printing on Mac

**Tasks:**
1. Mac Catalyst print dialog integration
2. Handle NSPrintOperation compatibility
3. Test print preview on Mac
4. Verify printer selection works

**Deliverables:**
- Single file printing works on Mac
- Native Mac print dialog
- Print preview functional

### Phase 3: Collection/Submission Printing (Priority 2)
**Goal:** Enable printing multiple files

**Tasks:**
1. Implement collection content combining
2. Implement submission content combining
3. Add print button to collection detail view
4. Add print button to submission detail view
5. Handle continuous flow between files
6. Test large multi-file documents

**Deliverables:**
- Collections print as continuous document
- Submissions print as continuous document
- No unwanted page breaks between files
- Footnote numbering continuous across files

### Phase 4: Advanced Features (Priority 3)
**Goal:** Polish and additional capabilities

**Tasks:**
1. Page range selection support
2. Copy count selection
3. Duplex printing options
4. Print quality settings
5. Error handling and user feedback
6. Printing progress indication

**Deliverables:**
- Full print dialog feature support
- Graceful error handling
- User feedback during printing

---

## Data Model

### No New Models Required
Printing uses existing models:
- `TextFile` - Source files
- `Version` - Content to print
- `Collection` - Group of files
- `Submission` - Group of files
- `PageSetupPreferences` - Layout settings
- `FootnoteModel` - Footnote data

### Print Configuration (Transient)
```swift
struct PrintConfiguration {
    let content: NSAttributedString
    let pageSetup: PageSetup
    let includeFootnotes: Bool
    let fileTitle: String?
    
    // For multi-file printing
    let isMultiFile: Bool
    let fileTitles: [String]?
}
```

---

## Service Layer

### PrintService.swift
```swift
class PrintService {
    /// Print a single file
    static func printFile(
        _ file: TextFile,
        from viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    )
    
    /// Print a collection (multiple files)
    static func printCollection(
        _ collection: Collection,
        from viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    )
    
    /// Print a submission (multiple files)
    static func printSubmission(
        _ submission: Submission,
        from viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    )
    
    /// Present print dialog with prepared content
    private static func presentPrintDialog(
        content: NSAttributedString,
        pageSetup: PageSetup,
        title: String,
        from viewController: UIViewController,
        completion: @escaping (Bool) -> Void
    )
}
```

### PrintFormatter.swift
```swift
class PrintFormatter {
    /// Prepare single file content for printing
    static func formatFile(_ file: TextFile) -> NSAttributedString
    
    /// Combine multiple files for printing
    static func formatMultipleFiles(_ files: [TextFile]) -> NSAttributedString
    
    /// Remove platform scaling for print-accurate sizes
    static func removePlatformScaling(from: NSAttributedString) -> NSAttributedString
    
    /// Apply page setup to attributed string
    static func applyPageSetup(to: NSAttributedString, pageSetup: PageSetup) -> NSAttributedString
}
```

---

## UI Integration

### FileEditView
```swift
// Add to toolbar
Button {
    showPrintDialog = true
} label: {
    Label("Print", systemImage: "printer")
}

// Add print handling
.sheet(isPresented: $showPrintDialog) {
    if let viewController = UIApplication.shared.windows.first?.rootViewController {
        PrintService.printFile(file, from: viewController) { success in
            showPrintDialog = false
        }
    }
}
```

### PaginatedDocumentView
```swift
// Add print button to toolbar
Button {
    showPrintDialog = true
} label: {
    Image(systemName: "printer")
}
```

### Collection/Submission Detail Views
```swift
// Add to toolbar/menu
Button {
    printCollection()
} label: {
    Label("Print Collection", systemImage: "printer")
}

private func printCollection() {
    // Get files from collection
    // Call PrintService.printCollection
}
```

---

## Platform Considerations

### iOS Specific
- Use `UIPrintInteractionController` for native print dialog
- Support AirPrint for wireless printing
- Handle print preview in modal presentation
- Show print progress for large documents
- Handle print cancellation gracefully

### Mac Catalyst Specific
- Bridge to `NSPrintOperation` for native Mac experience
- Support standard Mac print dialog
- Handle printer selection and settings
- Support PDF export from print dialog
- Handle page setup access from print dialog

### Shared Behavior
- Use existing `PaginatedTextLayoutManager` for layout
- Reuse pagination calculation logic
- Apply same page setup as pagination view
- Include footnotes with same positioning logic

---

## Testing Strategy

### Unit Tests
- PrintFormatter content combination
- Platform scaling removal
- Page setup application
- Multi-file content merging

### Integration Tests
- Single file print preparation
- Collection print preparation
- Submission print preparation
- Footnote positioning in print

### Manual Testing
- Print single file on iOS device
- Print single file on Mac
- Print to PDF on both platforms
- Print collection with multiple files
- Print with various page setups
- Verify formatting preservation
- Verify footnote positioning
- Test AirPrint on iOS
- Test various printers on Mac

---

## Dependencies

### Existing Code
- `PaginatedTextLayoutManager` - Layout calculation
- `PageSetupPreferences` - Page configuration
- `FootnoteManager` - Footnote positioning
- `Version.attributedContent` - Content source
- `TextFormatter` - Style application

### New Code Required
- `PrintService.swift` - Printing coordination
- `PrintFormatter.swift` - Content preparation
- UI integration in views
- Mac Catalyst print bridge if needed

---

## Success Criteria

1. ✅ User can print single file from edit view
2. ✅ User can print single file from pagination view
3. ✅ User can print entire collection
4. ✅ User can print entire submission
5. ✅ Printed output matches pagination view
6. ✅ All formatting preserved in print
7. ✅ Footnotes positioned correctly
8. ✅ Works on iOS with AirPrint
9. ✅ Works on Mac with system printers
10. ✅ Print dialog shows proper preview

---

## Future Enhancements

### Phase 5+ (Not in Initial Scope)
- Custom headers and footers
- Page numbering options
- Table of contents generation
- Print to PDF with save location
- Batch printing multiple projects
- Print templates and presets
- Double-sided printing configuration
- Booklet printing (signature layout)

---

## Notes

### Design Decisions

1. **Reuse Pagination Logic**: The pagination view already calculates proper page breaks, so printing should use the same `PaginatedTextLayoutManager` to ensure consistency.

2. **No Page Breaks Between Files**: For collections/submissions, files flow continuously without forced page breaks. This provides maximum flexibility and natural document flow.

3. **Platform Scaling**: Printing must remove any platform-specific scaling (Mac's 1.3x editor scaling) to produce accurate print output at actual point sizes.

4. **Native Print Dialogs**: Use platform-native print dialogs (UIPrintInteractionController on iOS, NSPrintOperation on Mac) for familiar user experience.

5. **Footnote Continuity**: When printing multiple files, footnotes should maintain continuous numbering throughout the document for professional appearance.

### Implementation Notes

- Start with Phase 1 (single file printing) to establish core infrastructure
- Test thoroughly on both iOS and Mac before moving to multi-file printing
- Reuse as much pagination view code as possible
- Consider creating a shared `PrintableContent` protocol for consistency

### Known Limitations

- Image attachments not yet supported (requires Feature 006 completion)
- Headers/footers are future enhancement
- No custom page numbering in initial version
- Print preview on iOS may be limited by UIKit capabilities

---

## Related Features

- **Feature 010**: Pagination System (provides layout foundation)
- **Feature 015**: Footnotes (must be included in print output)
- **Feature 019**: Page Setup Settings (provides print configuration)
- **Feature 006**: Image Support (future - images in print)

---

## Glossary

- **AirPrint**: Apple's wireless printing technology for iOS devices
- **NSPrintOperation**: macOS class for managing print jobs
- **UIPrintInteractionController**: iOS class for presenting print interface
- **Page Setup**: Configuration for paper size, margins, orientation
- **Print Preview**: Visual representation of print output before printing
- **Duplex**: Double-sided printing
