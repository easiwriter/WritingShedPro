# Style Replacement and Edit Application Fix

## Problem
When replacing or editing a style:
1. **Style Replacement**: Deleting a style and selecting a replacement would update the `.textStyle` attribute (style name) but not apply the replacement style's formatting
2. **Style Editing**: Editing a style's properties (font, size, color, etc.) would not apply the changes to existing text using that style

## Root Cause
### Replacement Issue
The `replaceStyleInFile` method only changed the `.textStyle` attribute value but didn't apply the new style's formatting attributes (font, color, paragraph style, etc.).

### Edit Issue  
When a style was edited, the `StyleSheetModified` notification was posted, but `FileEditView` wasn't listening to it, so files using that style never got updated.

## Solution

### 1. Enhanced `replaceStyleInFile` to Apply Formatting
Updated `StyleSheetService.replaceStyleInFile` to:
1. Look up the new style definition
2. Generate its formatting attributes
3. Apply those attributes to all text with the old style name
4. Preserve character-level traits (bold, italic) within paragraphs

```swift
private static func replaceStyleInFile(
    _ file: TextFile,
    oldStyleName: String,
    newStyleName: String
) {
    guard let currentVersion = file.currentVersion,
          let attributedString = currentVersion.attributedContent,
          let project = file.project,
          let newStyle = resolveStyle(named: newStyleName, for: project, context: nil) else {
        return
    }
    
    let mutableString = NSMutableAttributedString(attributedString: attributedString)
    let newStyleAttributes = newStyle.generateAttributes()
    
    // For each range with the old style...
    mutableString.enumerateAttribute(.textStyle, ...) { value, range, _ in
        if styleValue == oldStyleName {
            // Update style name
            mutableString.addAttribute(.textStyle, value: newStyleName, range: range)
            
            // Apply new formatting while preserving character traits
            mutableString.enumerateAttributes(in: range, ...) { attributes, subrange, _ in
                var newAttributes = newStyleAttributes
                
                // Preserve existing bold/italic
                let existingFont = attributes[.font] as? UIFont ?? newFont
                let existingTraits = existingFont.fontDescriptor.symbolicTraits
                
                if !existingTraits.isEmpty {
                    if let descriptor = newFont.fontDescriptor.withSymbolicTraits(existingTraits) {
                        newAttributes[.font] = UIFont(descriptor: descriptor, size: 0)
                    }
                }
                
                mutableString.setAttributes(newAttributes, range: subrange)
            }
        }
    }
    
    currentVersion.attributedContent = mutableString
}
```

### 2. Added StyleSheetModified Notification Handler
Added listener in `FileEditView` to respond when a style is edited:

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StyleSheetModified"))) { notification in
    handleStyleSheetModified(notification)
}

private func handleStyleSheetModified(_ notification: Notification) {
    guard let notifiedStyleSheetID = notification.userInfo?["stylesheetID"] as? UUID,
          let ourStyleSheetID = file.project?.styleSheet?.id,
          notifiedStyleSheetID == ourStyleSheetID else {
        return
    }
    
    // Reapply all styles to get the updated formatting
    if attributedContent.length > 0 {
        reapplyAllStyles()
    }
}
```

## How It Works

### Style Replacement Flow
1. User deletes a style and selects replacement
2. `StyleSheetService.replaceStyleInProject` calls `replaceStyleInFile` for each file
3. For each file:
   - Finds all ranges with old style name
   - Updates `.textStyle` attribute to new style name
   - **Looks up new style definition**
   - **Applies new style's formatting** (font, size, color, alignment, etc.)
   - Preserves character-level formatting (bold, italic)
4. File now displays with replacement style's formatting

### Style Edit Flow
1. User edits style properties in `TextStyleEditorView`
2. Saves changes → `StyleSheetModified` notification posted
3. All open `FileEditView` instances receive notification
4. Each checks if notification is for their stylesheet
5. If yes, calls `reapplyAllStyles()`:
   - Walks through document
   - Finds all `.textStyle` attributes
   - **Looks up current style definition** (now has edited properties)
   - **Applies updated formatting** to each range
6. File now displays with updated style formatting

## Files Modified
- **StyleSheetService.swift**:
  - Enhanced `replaceStyleInFile` to apply formatting, not just update style name
  - Added style lookup and attribute application logic
  - Preserves character-level traits during replacement

- **FileEditView.swift**:
  - Added `.onReceive` for `StyleSheetModified` notification
  - Added `handleStyleSheetModified()` method
  - Triggers `reapplyAllStyles()` when stylesheet is modified

## Testing
### Style Replacement:
1. Apply a custom style to text
2. Delete that style, selecting Body as replacement
3. **Expected**: Text immediately changes to Body style formatting (font, size, color)
4. Style picker should show "Body" selected
5. Formatting should match Body style exactly

### Style Editing:
1. Apply a custom style to text
2. Open style editor, change font/size/color
3. Save changes
4. **Expected**: Text in document immediately updates with new formatting
5. No need to reselect or reapply the style

## Related Code
- **TextFormatter.applyStyle**: Applies style formatting and sets `.textStyle` attribute
- **FileEditView.reapplyAllStyles**: Walks document and reapplies all styles from current definitions
- **TextStyleEditorView.saveChanges**: Posts `StyleSheetModified` notification after save
- **Version.attributedContent**: Properly serializes/deserializes `.textStyle` attribute

## Key Insight
The `.textStyle` attribute is just a **name tag** that says "this paragraph is using style X". To actually see the formatting, we must:
1. Look up the style definition in the database
2. Generate its attributes
3. Apply those attributes to the text

When replacing or editing styles, updating the name tag isn't enough - we must also apply the new/updated formatting.
