# Style Usage Detection Fix

## Problem
When attempting to delete a custom style that was in use, the system would not detect the usage and allow deletion without warning.

## Root Cause
The `fileUsesStyle` method in `StyleSheetService.swift` was deserializing `formattedContent` using RTF deserialization:

```swift
guard let attributedString = try? NSAttributedString(
    data: formattedData,
    options: [.documentType: NSAttributedString.DocumentType.rtf],
    documentAttributes: nil
) else {
    return false
}
```

However, `formattedContent` is **not stored as RTF**. It's stored as a PropertyList (JSON) format using `AttributedStringSerializer.encode`.

### Why This Failed
1. RTF doesn't understand custom NSAttributedString keys like `.textStyle`
2. When deserializing as RTF, all custom attributes are lost
3. The `.textStyle` attribute that marks which style is applied to each paragraph was not being read
4. `fileUsesStyle` would enumerate `.textStyle` attributes but find none, returning false even when the style was in use

## The Data Flow

### Writing Styles (CORRECT)
1. **TextFormatter.applyStyle** adds `.textStyle` attribute to NSAttributedString (line 618)
2. **Version.attributedContent setter** calls `AttributedStringSerializer.encode` (line 230 in BaseModels.swift)
3. **AttributedStringSerializer.encode** saves `.textStyle` to PropertyList format (line 289)
4. Data stored in `Version.formattedContent` as PropertyList, NOT RTF

### Reading Styles (WAS BROKEN, NOW FIXED)
1. **Version.attributedContent getter** uses `AttributedStringSerializer.decode` to restore custom attributes (line 194 in BaseModels.swift)
2. **StyleSheetService.fileUsesStyle** was trying to deserialize as RTF ❌
3. Now uses `currentVersion.attributedContent` which properly deserializes ✅

## Solution
Changed both `fileUsesStyle` and `replaceStyleInFile` to use the `Version.attributedContent` getter instead of manually deserializing:

```swift
// BEFORE (WRONG)
guard let formattedData = currentVersion.formattedContent,
      let attributedString = try? NSAttributedString(
        data: formattedData,
        options: [.documentType: NSAttributedString.DocumentType.rtf],
        documentAttributes: nil
      ) else {
    return false
}

// AFTER (CORRECT)
guard let currentVersion = file.currentVersion,
      let attributedString = currentVersion.attributedContent else {
    return false
}
// attributedString is now properly unwrapped and ready to use
```

## Why Version.attributedContent Works
The `Version` model's `attributedContent` getter handles the deserialization correctly:
1. Tries legacy RTF format first (for imports from Writing Shed 1.0)
2. Falls back to `AttributedStringSerializer.decode` for current format
3. This preserves **all custom attributes** including `.textStyle`

## Files Modified
- **StyleSheetService.swift**:
  - `fileUsesStyle`: Now uses `currentVersion.attributedContent` instead of RTF deserialization
  - `replaceStyleInFile`: Now uses `currentVersion.attributedContent` for reading and the setter for writing

## Testing
To verify the fix:
1. Apply a custom style to text in a file
2. Go to Style Sheet editor
3. Try to delete that custom style
4. Should now show alert: "Style '[name]' is used by X file(s)"
5. Replacement picker should appear
6. Console should show debug logs starting with 🔍 showing the style was found

## Related Code
- **TextFormatter.swift** line 618: Adds `.textStyle` attribute when applying styles
- **AttributedStringSerializer.swift** lines 287-289: Encodes `.textStyle` attribute
- **AttributedStringSerializer.swift** lines 402-404: Decodes `.textStyle` attribute
- **BaseModels.swift** lines 165-221: Version.attributedContent getter/setter

## Lesson Learned
Always use the model's computed properties for serialization/deserialization instead of manually handling the raw data. The `Version.attributedContent` property already has the correct logic for handling both legacy RTF imports and the current PropertyList format.
