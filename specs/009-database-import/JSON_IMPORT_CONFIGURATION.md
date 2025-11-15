# JSON Import Configuration Guide

**Date:** November 15, 2025  
**Feature:** JSON Import from Writing Shed v1

## Overview

The Import button on the toolbar has been wired up to allow users to select and import JSON files exported from Writing Shed v1. This guide shows how to configure the document types in Xcode.

## Implementation Summary

### Code Changes

**ContentView.swift:**
- Added `@State` variables for file picker and error handling
- Import button now triggers `.fileImporter()` 
- `handleJSONImport()` method processes selected files
- Alert displays any import errors

### How It Works

1. User taps Import button (arrow.down.doc icon)
2. File picker opens, filtered to `.json` files
3. User selects a Writing Shed v1 export JSON file
4. `JSONImportService` imports the project
5. New project appears in the project list
6. Warnings logged to console if any

## Xcode Document Type Configuration

### Step 1: Open Project Settings

1. In Xcode, select the project in the Navigator (top item)
2. Select the **"Writing Shed Pro"** target (not the project)
3. Click the **"Info"** tab

### Step 2: Add Document Types

Scroll down to the **"Document Types"** section. If it doesn't exist, you'll need to add it to the Info.plist.

### Step 3: Configure JSON Import Type

Add a new document type with these settings:

| Property | Value |
|----------|-------|
| **Name** | Writing Shed Export |
| **Identifier** | com.writingshed.export |
| **Icon** | (optional) |
| **Types** | public.json |
| **Role** | Viewer |
| **Handler Rank** | Alternate |

### Alternative: Edit Info.plist Directly

If you prefer to edit the Info.plist directly, add this entry:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Writing Shed Export</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.json</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
    </dict>
</array>
```

### Step 4: Build and Test

1. Build and run the app (Cmd+R)
2. Tap the Import button
3. File picker should appear
4. Select a `.json` file
5. Project should import and appear in the list

## UTType Configuration (Modern Approach)

For iOS 14+ and modern SwiftUI, you can also declare imported types:

### In Xcode:

1. Go to Target → Info → Imported Type Identifiers
2. Add: `public.json`

### Or in Info.plist:

```xml
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>public.json</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
            <string>public.content</string>
        </array>
        <key>UTTypeDescription</key>
        <string>JSON Document</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>json</string>
            </array>
            <key>public.mime-type</key>
            <array>
                <string>application/json</string>
            </array>
        </dict>
    </dict>
</array>
```

## Code Reference

### ContentView Integration

```swift
// State variables
@State private var showingJSONImportPicker = false
@State private var showImportError = false
@State private var importErrorMessage = ""

// Import button
Button(action: { showingJSONImportPicker = true }) {
    Label(NSLocalizedString("contentView.import", comment: ""), 
          systemImage: "arrow.down.doc")
}

// File picker
.fileImporter(
    isPresented: $showingJSONImportPicker,
    allowedContentTypes: [.json],
    allowsMultipleSelection: false
) { result in
    handleJSONImport(result)
}

// Error alert
.alert("Import Error", isPresented: $showImportError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(importErrorMessage)
}
```

### Import Handler

```swift
private func handleJSONImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
        guard let fileURL = urls.first else { return }
        
        Task {
            do {
                let errorHandler = ImportErrorHandler()
                let jsonImporter = JSONImportService(
                    modelContext: modelContext,
                    errorHandler: errorHandler
                )
                
                let project = try jsonImporter.importFromJSON(fileURL: fileURL)
                // Success - project now in database
                
            } catch ImportError.missingContent {
                importErrorMessage = "The selected file is empty or corrupt."
                showImportError = true
            } catch {
                importErrorMessage = "Failed to import: \(error.localizedDescription)"
                showImportError = true
            }
        }
        
    case .failure(let error):
        importErrorMessage = "Failed to select file: \(error.localizedDescription)"
        showImportError = true
    }
}
```

## Testing

### Test File Structure

A valid Writing Shed v1 export JSON has this structure:

```json
{
  "projectModel": "novel",
  "projectName": "My Novel",
  "project": "...base64...",
  "textFileDatas": [...],
  "sceneComponentDatas": [],
  "collectionComponentDatas": []
}
```

### Test Scenarios

1. **Valid JSON Export**
   - Select a Writing Shed v1 export
   - Should import successfully
   - Project appears in list

2. **Invalid JSON**
   - Select a random .json file
   - Should show error alert
   - Error: "The selected file is empty or corrupt"

3. **Corrupt Data**
   - Select malformed JSON
   - Should show error alert
   - Error message explains the issue

4. **Cancel Import**
   - Open file picker
   - Cancel without selecting
   - Nothing happens (expected)

## File Picker Behavior

### iOS/iPadOS
- Opens Files app picker
- Shows JSON files
- Can browse iCloud Drive, local files
- Supports file providers (Dropbox, etc.)

### Mac Catalyst
- Opens macOS file picker
- Shows JSON files
- Can browse Finder locations
- Standard macOS file selection

## Troubleshooting

### File Picker Doesn't Show JSON Files

**Cause:** Document types not configured  
**Fix:** Follow the Xcode configuration steps above

### Import Button Does Nothing

**Cause:** `showingJSONImportPicker` not wired correctly  
**Fix:** Verify the button action and `.fileImporter()` binding

### Import Fails Silently

**Cause:** No error handling  
**Fix:** Check console logs for error messages

### "Access Denied" Error

**Cause:** File access permissions  
**Fix:** Ensure the file is accessible (not in protected directory)

## Security Considerations

### File Access

The app uses SwiftUI's `.fileImporter()` which:
- Provides security-scoped access to selected files
- Automatically handles sandbox permissions
- Only accesses files user explicitly selects
- No persistent file access needed

### Data Validation

The JSONImportService validates:
- JSON structure matches expected schema
- Required fields are present
- Data types are correct
- Graceful handling of missing optional fields

## Future Enhancements

Potential improvements:

1. **Import Preview**
   - Show project details before importing
   - Display text file count, publications, etc.
   - Confirm before import

2. **Duplicate Handling**
   - Check if project name already exists
   - Offer to rename or skip import

3. **Progress Indicator**
   - Show progress for large imports
   - Cancel option during import

4. **Batch Import**
   - Allow multiple selection
   - Import multiple projects at once

5. **Import History**
   - Track imported projects
   - Show import date/source

## Related Documentation

- `JSON_IMPORT.md` - JSONImportService documentation
- `JSONImportService.swift` - Implementation code
- `/ImportExport` - Original Writing Shed v1 code reference

## Summary

The Import button is now fully functional:

✅ Button wired to file picker  
✅ File picker filters to JSON files  
✅ JSONImportService handles import  
✅ Error handling with user alerts  
✅ Projects appear in list after import  

**Action Required:**
Configure document types in Xcode as described above to enable JSON file filtering in the file picker.
