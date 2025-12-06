# Word Document Import/Export

**Feature:** RTF (Rich Text Format) import and export for Word compatibility  
**Date:** 6 December 2025  
**Status:** Implemented

## Overview

Writing Shed Pro supports importing and exporting RTF (Rich Text Format) files, which are fully compatible with Microsoft Word, Pages, and other word processors. RTF provides excellent formatting preservation for manuscripts and documents.

**Platform Notes:**
- **All Platforms:** RTF import and export fully supported
- **Word Compatibility:** RTF files can be opened, edited, and saved in Microsoft Word
- **.docx Note:** .docx format is not reliably supported on iOS/macOS. Use RTF instead for best results

## What's Preserved

### ✅ Fully Preserved
- Plain text content (100%)
- Bold, italic, underline, strikethrough
- Font family (common fonts)
- Font size
- Text color
- Text background color (highlights)
- Basic paragraph alignment (left, right, center, justified)
- Basic lists (bulleted and numbered)
- Line spacing and paragraph spacing

### ⚠️ Partially Preserved
- Uncommon fonts (may be substituted)
- Complex list formatting
- Basic tables (may lose structure)

### ❌ Not Preserved
- Headers and footers
- Page numbers
- Sections and page breaks
- Columns
- Table of contents
- Comments and track changes
- Embedded images
- Drawing objects and shapes
- Text boxes
- Footnotes/endnotes (appear as inline text)

## Usage

### Importing a Word Document

```swift
import WordDocumentService

// Option 1: Import from file picker
func importWordDocument(url: URL) {
    do {
        let (plainText, rtfData, filename) = try WordDocumentService.importWordDocument(from: url)
        
        // Create a new TextFile with the imported content
        let file = TextFile(name: filename, folder: currentFolder)
        let version = Version()
        version.content = plainText
        version.formattedContent = rtfData
        version.textFile = file
        
        modelContext.insert(file)
        try modelContext.save()
        
    } catch {
        showAlert("Import Failed", error.localizedDescription)
    }
}
```

### Exporting as Word Document

```swift
// Export current file as .docx
func exportAsWordDocument() {
    guard let file = currentFile,
          let version = file.currentVersion,
          let attributedString = version.attributedContent else {
        return
    }
    
    // Option 1: Share via system share sheet
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootViewController = windowScene.windows.first?.rootViewController {
        WordDocumentService.shareAsWordDocument(
            attributedString,
            filename: file.name,
            from: rootViewController
        )
    }
    
    // Option 2: Save directly (advanced)
    do {
        let docxData = try WordDocumentService.exportToWordDocument(
            attributedString,
            filename: file.name
        )
        // Save docxData to desired location
    } catch {
        showAlert("Export Failed", error.localizedDescription)
    }
}
```

### Exporting as RTF

RTF is simpler and more compatible - Word can open RTF files.

```swift
func exportAsRTF() {
    guard let file = currentFile,
          let version = file.currentVersion,
          let attributedString = version.attributedContent else {
        return
    }
    
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootViewController = windowScene.windows.first?.rootViewController {
        WordDocumentService.shareAsRTF(
            attributedString,
            filename: file.name,
            from: rootViewController
        )
    }
}
```

## UI Integration Examples

### Add Import Button to Toolbar

```swift
// In FileListView or similar
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button(action: showImportPicker) {
            Image(systemName: "square.and.arrow.down")
        }
    }
}

// File picker state
@State private var showingImportPicker = false

var body: some View {
    // ... existing view ...
    .fileImporter(
        isPresented: $showingImportPicker,
        allowedContentTypes: [.init(filenameExtension: "docx")!],
        allowsMultipleSelection: false
    ) { result in
        switch result {
        case .success(let urls):
            if let url = urls.first {
                importWordDocument(url)
            }
        case .failure(let error):
            print("Import error: \(error)")
        }
    }
}
```

### Add Export Menu to FileEditView

```swift
// In FileEditView
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button(action: exportAsWordDocument) {
                Label("Export as Word (.docx)", systemImage: "doc")
            }
            
            Button(action: exportAsRTF) {
                Label("Export as RTF", systemImage: "doc.richtext")
            }
            
            Button(action: exportAsPDF) {
                Label("Export as PDF", systemImage: "doc.fill")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
```

## Info.plist Configuration

To allow importing .docx files (iOS only), add to your Info.plist:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <!-- Existing entries... -->
    <dict>
        <key>CFBundleTypeName</key>
        <string>Microsoft Word Document</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>org.openxmlformats.wordprocessingml.document</string>
        </array>
    </dict>
</array>
```

**Note:** On macOS, .docx import is not supported. Users should convert to RTF first.

For RTF:

```xml
<dict>
    <key>CFBundleTypeName</key>
    <string>Rich Text Format</string>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>LSHandlerRank</key>
    <string>Alternate</string>
    <key>LSItemContentTypes</key>
    <array>
        <string>public.rtf</string>
    </array>
</dict>
```

## Technical Details

### Import Process

1. Read .docx file as `Data`
2. Convert to `NSAttributedString` using `.docx` document type
3. Extract plain text for `Version.content`
4. Convert to RTF data for `Version.formattedContent`
5. Store in SwiftData

### Export Process

1. Load `Version.attributedContent` (RTF → NSAttributedString)
2. Convert to `.docx` document type using `NSAttributedString.data(documentAttributes:)`
3. Save or share the resulting data

### Format Compatibility

- **Import**: .docx → NSAttributedString → RTF (internal format)
- **Export**: RTF (internal format) → NSAttributedString → .docx or .rtf
- **Round-trip**: Generally preserves basic formatting, but not 100% identical

## Error Handling

```swift
do {
    let result = try WordDocumentService.importWordDocument(from: url)
    // Handle success
} catch WordDocumentError.cannotAccessFile {
    // File access permission error
} catch WordDocumentError.importFailed(let reason) {
    // Import failed with specific reason
} catch {
    // Other unexpected errors
}
```

## Testing Checklist

- [ ] Import .docx with bold/italic text
- [ ] Import .docx with different fonts
- [ ] Import .docx with colored text
- [ ] Import .docx with lists
- [ ] Export to .docx preserves formatting
- [ ] Export to RTF preserves formatting
- [ ] Round-trip (import → export → import) maintains content
- [ ] Large documents (10,000+ words) import successfully
- [ ] Share sheet works on iPhone and iPad
- [ ] File picker filters to .docx files
- [ ] Error messages are user-friendly

## Limitations

1. **Platform-specific:** .docx format only available on iOS/iPadOS. macOS users should use RTF format
2. **Not a full Word implementation** - Complex documents will lose features
3. **Images not supported** - Images are stripped during import
4. **Tables are basic** - Complex tables may lose structure
5. **No comments or track changes** - These are Word-specific features
6. **Font substitution** - Uncommon fonts may be replaced
7. **No page layout** - Headers, footers, page numbers not preserved

## Future Enhancements

Possible improvements if needed:

- Batch import multiple .docx files
- Preview before import
- Format conversion options
- Image extraction and storage
- Table preservation improvements
- Custom import/export settings

## Related Files

- `WordDocumentService.swift` - Main service implementation
- `AttributedStringSerializer.swift` - RTF conversion
- `Version` model - Content storage
- `FileEditView` - UI integration point

## Recommendations

**For Best Results:**
- Use this for importing **plain manuscripts** or **simple formatted documents**
- For complex documents with images/tables, consider:
  - Copy/paste from Word (preserves some formatting)
  - Use PDF export instead
  - Keep original .docx files separately

**Export Recommendations:**
- Use **.rtf** for maximum compatibility
- Use **.docx** if recipient specifically needs Word format
- Use **PDF** for final/published versions

---

**Status:** Ready for integration into UI  
**Dependencies:** None (uses iOS native APIs)  
**iOS Version:** Requires iOS 15.0+ for .docx support
