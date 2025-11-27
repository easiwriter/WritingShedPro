# Feature 020: Printing - Quick Reference

## User Actions

### Print Single File
1. Open file in edit or pagination view
2. Tap printer icon in toolbar
3. Configure print settings in dialog
4. Tap "Print" to print or "Cancel" to cancel

### Print Collection (Coming in Phase 3)
1. Navigate to collection detail view
2. Tap print button
3. Files print continuously without page breaks

### Print Submission (Coming in Phase 3)
1. Navigate to submission detail view
2. Tap print button
3. Files print continuously without page breaks

---

## Developer Quick Reference

### Print a File
```swift
PrintService.printFile(textFile, from: viewController) { success, error in
    if let error = error {
        // Handle error
    } else if success {
        // Print completed
    } else {
        // User cancelled
    }
}
```

### Print a Collection
```swift
PrintService.printCollection(collection, modelContext: context, from: viewController) { success, error in
    // Handle result
}
```

### Check if Printing Available
```swift
if PrintService.isPrintingAvailable() {
    // Show print button
}
```

### Validate File Can Be Printed
```swift
if PrintService.canPrint(file: textFile) {
    // File has printable content
}
```

---

## Architecture

```
User Taps Print Button
         ↓
    printFile() function
         ↓
    saveChanges() (if needed)
         ↓
    PrintService.printFile()
         ↓
    PrintFormatter.formatFile()
         ↓
    removePlatformScaling()
         ↓
    UIPrintInteractionController
         ↓
    Native Print Dialog
         ↓
    Completion Handler
         ↓
    Show Error Alert (if needed)
```

---

## Key Files

### Services
- `PrintService.swift` - Coordinates printing operations
- `PrintFormatter.swift` - Prepares content for printing

### Views with Print Buttons
- `FileEditView.swift` - Edit mode toolbar
- `PaginatedDocumentView.swift` - Pagination zoom controls

### Dependencies
- `PageSetupPreferences` - Page configuration
- `PaginatedTextLayoutManager` - Layout calculation
- `FootnoteManager` - Footnote positioning

---

## Platform Scaling

| Platform | Edit Font | Print Font | Scaling Factor |
|----------|-----------|------------|----------------|
| Mac | 22.1pt | 17pt | ÷1.3 |
| iOS | 17pt | 11.05pt | ×0.65 |

---

## Testing Commands

### iOS Simulator
```bash
# Build and run
xcodebuild -scheme "Writing Shed Pro" -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Mac Catalyst
```bash
# Build for Mac
xcodebuild -scheme "Writing Shed Pro" -destination 'platform=macOS,variant=Mac Catalyst'
```

---

## Common Issues

### Print button disabled
- Check `UIPrintInteractionController.isPrintingAvailable`
- Ensure device/simulator supports printing
- Mac Catalyst always supports printing

### Empty print output
- Verify file has `attributedContent`
- Check `PrintFormatter.formatFile()` returns content
- Ensure platform scaling applied correctly

### Print dialog doesn't appear
- Verify view controller reference is valid
- Check for threading issues (must present on main thread)
- Review console logs for presentation errors

---

## Localization Keys

```swift
"print.error.noContent"
"print.error.notAvailable"
"print.error.cancelled"
"print.error.failed"
"fileEdit.print.accessibility"
"paginatedDocument.print.accessibility"
```

---

## Phase Status

- ✅ Phase 1: Single File Printing - COMPLETE
- ⏸️ Phase 2: Mac Catalyst Support - INCLUDED IN PHASE 1
- ⏸️ Phase 3: Collection/Submission Printing - PENDING
- ⏸️ Phase 4: Advanced Features - FUTURE

---

## Next Steps

1. Test on iOS device
2. Test on Mac
3. Implement Phase 3 (collections/submissions)
4. Add print buttons to collection/submission views
