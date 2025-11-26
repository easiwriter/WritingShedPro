# Style Editor Save Options

## Changes Made
When editing an existing style from the style picker, the user is now presented with two clear options:

### New Workflow
1. User selects a style and taps the "Edit Style" button (slider icon)
2. User makes changes to the style properties
3. User taps Save
4. **Alert appears with two options**:
   - **"Update Existing Style"**: Updates the style definition, changes apply automatically to all documents in the project
   - **"Create New Style"**: Creates a new style with the edited properties, adds asterisk (*) suffix to name

### Previous Workflow (Removed)
- ~~After editing, alert asked "Apply now or on reopen"~~
- ~~User had to manually choose when to apply changes~~
- ~~Confusing because changes weren't automatically applied~~

## Implementation Details

### TextStyleEditorView Changes

#### Added State Variable
```swift
@State private var showingSaveOptionsAlert = false
```

#### Modified Save Button Logic
```swift
Button("button.save") {
    if isNewStyle {
        // For new styles, just save directly
        saveChanges()
        dismiss()
    } else {
        // For existing styles, show options alert
        showingSaveOptionsAlert = true
    }
}
```

#### Added Alert
```swift
.alert("textStyleEditor.saveOptions.title", isPresented: $showingSaveOptionsAlert) {
    Button("textStyleEditor.saveOptions.updateStyle") {
        // Update the existing style - changes apply automatically
        saveChanges()
        dismiss()
    }
    Button("textStyleEditor.saveOptions.createNewStyle") {
        // Create a new style with asterisk suffix
        createNewStyleFromChanges()
        dismiss()
    }
    Button("button.cancel", role: .cancel) { }
}
```

#### Added createNewStyleFromChanges() Method
Creates a duplicate of the current style with:
- Name: `originalName + "*"`
- Display name: `originalDisplayName + "*"`
- All current edited properties copied
- Adds to stylesheet at the end of the list
- Posts `StyleSheetModified` notification

### StylePickerSheet Simplification

#### Removed
- `stylesWereModified` state variable
- `showingApplyChangesAlert` state variable  
- `handleDismiss()` method that checked for modifications
- Alert asking "Apply now or on reopen"

#### Why This Works
- When user chooses "Update Existing Style", the `StyleSheetModified` notification is posted
- `FileEditView` listens to this notification
- `reapplyAllStyles()` is called automatically
- All open documents update immediately
- No manual "apply now/later" decision needed

### Localized Strings Added
```
"textStyleEditor.saveOptions.title" = "Save Style Changes";
"textStyleEditor.saveOptions.message" = "Do you want to update the existing style (changes will apply to all documents) or create a new style with these attributes?";
"textStyleEditor.saveOptions.updateStyle" = "Update Existing Style";
"textStyleEditor.saveOptions.createNewStyle" = "Create New Style";
```

## User Experience Flow

### Option 1: Update Existing Style
1. Edit style properties
2. Tap Save
3. Alert: "Update Existing Style" or "Create New Style"
4. Choose "Update Existing Style"
5. ✅ Style updated in database
6. ✅ `StyleSheetModified` notification posted
7. ✅ All open documents automatically reapply the style
8. ✅ Changes visible immediately in all documents

### Option 2: Create New Style
1. Edit style properties (e.g., change Body from 17pt to 20pt)
2. Tap Save
3. Alert: "Update Existing Style" or "Create New Style"
4. Choose "Create New Style"
5. ✅ New style "Body*" created with 20pt size
6. ✅ Original "Body" style unchanged
7. ✅ New style appears in style picker
8. ✅ `StyleSheetModified` notification posted
9. ✅ User can now apply "Body*" to text

## Benefits

1. **Clear Intent**: User explicitly chooses to update vs. create new
2. **Automatic Application**: No "apply now vs later" confusion
3. **Safe Experimentation**: Can create variations without modifying originals
4. **Naming Convention**: Asterisk suffix clearly indicates derived style
5. **Immediate Feedback**: Changes apply automatically when updating

## Technical Notes

- New styles are created with `displayOrder = maxOrder + 1` so they appear at the end
- All style properties are copied (font, size, color, alignment, spacing, etc.)
- The `StyleSheetModified` notification ensures all documents stay in sync
- Creating a new style doesn't affect existing text using the original style

## Files Modified
- **TextStyleEditorView.swift**: Added save options alert and createNewStyleFromChanges() method
- **StylePickerSheet.swift**: Removed old "apply changes" alert logic
- **Localizable.strings**: Added new alert strings
