# JSON Import Feature

**Feature 009 Extension: Import from Writing Shed v1 JSON Export**  
**Created:** November 15, 2025

## Overview

Writing Shed Pro can now import projects that were exported from Writing Shed v1 (iOS) as JSON files. This provides a migration path for users who want to move their existing work to the new app.

## How It Works

### Writing Shed v1 Export Format

The original Writing Shed app had export functionality that creates a JSON file containing:
- Project metadata (name, type)
- Text files and their folder structure
- Versions (drafts) with formatted content
- Publications (magazines, competitions)
- Collections (grouped submissions)
- Submission links (which texts were submitted to which publications)

### Writing Shed Pro Import Process

The `JSONImportService` reads these JSON files and maps the data to the new SwiftData models:

**Mapping:**
- **Project** → Project (with type mapping)
- **TextFile** → TextFile + Versions
- **Submission** (old) → Publication
- **Collection** → Submission (with SubmittedFile records)
- **CollectionSubmission** → Links Submission to Publication

## Key Features

### 1. Dark Mode Fix Applied
- All imported text has adaptive colors stripped
- Text will correctly adapt between light and dark modes
- User-selected colors (red, blue, etc.) are preserved

### 2. Relationship Preservation
- Folder structure maintained
- Text files linked to correct folders
- Versions preserved with content and notes
- Publications imported with notes
- Submissions linked to publications
- Version locking applied to submitted versions

### 3. Metadata Preservation
- Project names cleaned (timestamp metadata removed)
- Creation dates preserved where available
- Notes and comments maintained
- Formatted content preserved (bold, italic, etc.)

## Usage

### Programmatic Import

```swift
// In your view or service
let modelContext = modelContainer.mainContext
let errorHandler = ImportErrorHandler()
let jsonImporter = JSONImportService(
    modelContext: modelContext,
    errorHandler: errorHandler
)

do {
    let fileURL = // URL to JSON export file
    let project = try jsonImporter.importFromJSON(fileURL: fileURL)
    print("Successfully imported project: \(project.name)")
    
    // Check for warnings
    if !errorHandler.warnings.isEmpty {
        print("Import completed with warnings:")
        errorHandler.warnings.forEach { print("  - \($0)") }
    }
} catch {
    print("Import failed: \(error)")
}
```

### Integration with ContentView

To add a "Import JSON" button to the project list:

```swift
// In ContentView.swift toolbar
ToolbarItem(placement: .navigationBarTrailing) {
    Button("Import JSON") {
        showingJSONImportPicker = true
    }
}

// Document picker
.fileImporter(
    isPresented: $showingJSONImportPicker,
    allowedContentTypes: [.json],
    allowsMultipleSelection: false
) { result in
    handleJSONImport(result)
}

// Handler
private func handleJSONImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
        guard let url = urls.first else { return }
        
        Task {
            let errorHandler = ImportErrorHandler()
            let jsonImporter = JSONImportService(
                modelContext: modelContext,
                errorHandler: errorHandler
            )
            
            do {
                let project = try jsonImporter.importFromJSON(fileURL: url)
                // Refresh UI
            } catch {
                // Show error alert
            }
        }
        
    case .failure(let error):
        // Show error alert
    }
}
```

## Data Structure Mapping

### Text Files & Versions

**Writing Shed v1:**
```
TextFile
  └── Draft 1
  └── Draft 2
  └── Draft 3
```

**Writing Shed Pro:**
```
TextFile
  └── Version 1
  └── Version 2
  └── Version 3
```

### Publications & Submissions

**Writing Shed v1:**
```
Submission (Publication)
  └── Collection (Grouped texts)
      └── CollectionSubmission (Links to texts)
```

**Writing Shed Pro:**
```
Publication
  └── Submission
      └── SubmittedFile (Links to TextFile + Version)
```

## Technical Details

### Decoding Process

1. **JSON Deserialization**: Parse JSON into `WritingShedData` struct
2. **Project Creation**: Map project type, clean name
3. **Text Import**: Create TextFile records, preserve folder structure
4. **Version Import**: 
   - Decode NSAttributedString from archived Data
   - Apply `stripAdaptiveColors()` for dark mode support
   - Convert to RTF for storage
5. **Publication Import**: Map submission entities to Publication records
6. **Collection Import**: Map collections to Submission records with SubmittedFile links
7. **Relationship Linking**: Connect submissions to publications

### Base64 Encoded Metadata

The JSON export uses base64-encoded property lists for entity metadata. The importer decodes these using:

```swift
guard let data = Data(base64Encoded: encodedString),
      let dict = try? PropertyListSerialization.propertyList(
          from: data, 
          format: nil
      ) as? [String: Any] else {
    throw ImportError.missingContent
}
```

### NSAttributedString Handling

Formatted text is stored as archived NSAttributedString:

```swift
let attributedString = try NSKeyedUnarchiver.unarchivedObject(
    ofClass: NSAttributedString.self,
    from: data
)
```

Then cleaned and converted:

```swift
let cleaned = AttributedStringSerializer.stripAdaptiveColors(from: attributedString)
let rtfData = try cleaned.data(
    from: NSRange(location: 0, length: cleaned.length),
    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
)
```

## Error Handling

The importer uses the existing `ImportErrorHandler` to track warnings:

- **Warnings**: Non-fatal issues (e.g., missing metadata, decode failures)
- **Errors**: Fatal issues that stop import (e.g., corrupt JSON, missing files)

Common warnings:
- "Failed to decode text file metadata" - Uses defaults (Untitled, Drafts folder)
- "Failed to decode publication metadata" - Uses defaults (Untitled Publication)
- "Failed to decode collection metadata" - Skips that collection

## Testing

### Test JSON File Structure

A minimal valid JSON export:

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

### Test Cases

1. **Simple Project**: Text files only, no publications
2. **With Publications**: Magazines and competitions with submissions
3. **With Collections**: Multiple texts submitted together
4. **Empty Project**: No text files (should succeed)
5. **Corrupt Data**: Invalid JSON (should fail gracefully)

## Future Enhancements

Potential improvements:

1. **UI Integration**: Add "Import from JSON" option in project list
2. **Progress Reporting**: Show progress during large imports
3. **Preview**: Show project contents before importing
4. **Conflict Resolution**: Handle duplicate project names
5. **Selective Import**: Choose which elements to import
6. **Validation**: Pre-import validation of JSON structure

## Comparison with Legacy Database Import

| Feature | Legacy DB Import | JSON Import |
|---------|-----------------|-------------|
| Source | CoreData .sqlite file | JSON export file |
| Scope | All projects | Single project |
| Access | Direct database queries | Structured JSON parsing |
| Speed | Slower (database queries) | Faster (in-memory) |
| Portability | Requires CoreData | Portable JSON format |
| User Flow | App-to-app | File-based |

## Files

- **JSONImportService.swift**: Main import service
- **structs.swift**: Original data structures (reference)
- **ImportExport/Importer/**: Original Writing Shed v1 code (reference)

## Related Features

- **Feature 009**: Legacy Database Import (direct CoreData import)
- **Appearance Mode Fix**: Applied to all imported text
- **Publications Management**: Imported publications use Feature 008b models
- **Version Locking**: Submitted versions are automatically locked

## Notes for Developers

### Why JSON Import?

While Writing Shed Pro has direct legacy database import, JSON import provides:

1. **User Control**: Users can export specific projects
2. **Portability**: JSON files can be shared, backed up, archived
3. **Safety**: No direct database access required
4. **Future-Proofing**: JSON format easier to maintain than CoreData queries
5. **Debugging**: JSON files human-readable for troubleshooting

### Entity Type Constants

The original code used constants like `kSubmissionEntity`. These are string literals in the JSON:

- `"WS_Submission_Entity"` - Publications (magazines, competitions)
- `"WS_Collection_Entity"` - Collections (grouped submissions)
- `"WS_TextCollection_Entity"` - Text collection links
- `"WS_CollectionSubmission_Entity"` - Submission links
- `"WS_Version_Entity"` - Text versions
- `"WS_TextString_Entity"` - Text content

### Preservation of Original Code

The `/ImportExport` directory contains the original Writing Shed v1 import/export code for reference. This code is NOT used by Writing Shed Pro but serves as documentation of the JSON structure and original implementation approach.

## See Also

- `LEGACY_COLLECTIONS_STRUCTURE.md` - Legacy database structure documentation
- `APPEARANCE_MODE_FIX_COMPLETE.md` - Dark mode color adaptation
- `specs/009-database-import/` - Feature 009 specifications
