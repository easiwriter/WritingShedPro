# Recent Features Testing Guide
## Collections/Submissions Fix, Version Notes, & Text View Enhancements

**Date**: 13 December 2025  
**Status**: Ready for Testing  
**Platform**: iOS (Notes: Pinch zoom and drag scroll are iOS-only)

---

## Features Covered

1. **Collections/Submissions Folder Separation** (Legacy Import Fix)
2. **Version Notes** (New Feature)
3. **Pinch Zoom** (iOS Text View Enhancement)
4. **Two-Finger Drag Scroll** (iOS Text View Enhancement)

---

## Pre-Testing Checklist

Before starting manual tests:
- [ ] Build succeeds (`⌘+B`)
- [ ] No compilation errors
- [ ] App launches successfully (`⌘+R`)
- [ ] Have a Writing Shed v1 JSON export file ready (for import testing)
- [ ] Can open a text file in FileEditView

---

## Feature 1: Collections/Submissions Folder Separation

### Background
**Issue**: After legacy import, Collections folder was showing all items (54 total) instead of only collections (5), and Submissions folder was empty instead of showing submissions (49).

**Root Cause**: Import logic was checking wrong attributes and not properly decoding the `collectionSubmissionIds` plist data.

**Fix**: Now correctly decodes the plist and checks if the array is empty:
- Collections: Items with empty or missing `collectionSubmissionIds`
- Submissions: Items with non-empty `collectionSubmissionIds`

### Test Steps

#### Test 1.1: Fresh Import (Recommended)
1. **Prepare Test Data**
   - Use a Writing Shed v1 JSON export that contains both collections and submissions
   - Note the expected counts from the legacy app

2. **Delete Existing Data** (to test clean import)
   - Delete the app from simulator/device
   - Or: Settings → Reset all data

3. **Import Legacy Data**
   - Launch app
   - Go to Settings → Import
   - Select your Writing Shed v1 JSON export
   - Wait for import to complete

4. **Verify Collections Folder**
   - Navigate to Files → Collections
   - ✓ Should show only collections (expected: 5 items in test case)
   - ✓ Items should NOT have submission markers/indicators
   - ✓ List sorted alphabetically (case-insensitive)

5. **Verify Submissions Folder**
   - Navigate to Files → Submissions  
   - ✓ Should show only submissions (expected: 49 items in test case)
   - ✓ Items may have collection/group metadata
   - ✓ List sorted alphabetically (case-insensitive)

6. **Verify Total Count**
   - Collections count + Submissions count = Total legacy items
   - ✓ All items accounted for
   - ✓ No duplicates
   - ✓ No missing items

#### Test 1.2: Sorting Verification
1. **Check Collections Sort Order**
   - Open Collections folder
   - Note the item names
   - ✓ Items sorted A-Z
   - ✓ Case-insensitive (e.g., "apple" comes before "Banana")
   - ✓ Uses localized comparison (handles accents, special chars)

2. **Check Submissions Sort Order**
   - Open Submissions folder
   - Note the item names
   - ✓ Items sorted A-Z
   - ✓ Case-insensitive
   - ✓ Uses localized comparison

#### Expected Results
| Folder | Expected Count (your data may vary) | Notes |
|--------|--------------------------------------|-------|
| Collections | 5 | No `collectionSubmissionIds` or empty array |
| Submissions | 49 | Non-empty `collectionSubmissionIds` array |
| **Total** | **54** | All items from legacy import |

### Troubleshooting
- **Collections folder empty**: Check if items have `collectionSubmissionIds` set
- **All items in Submissions**: Verify legacy JSON structure
- **Wrong counts**: Check console logs for import errors
- **Unsorted lists**: Verify `localizedCaseInsensitiveCompare` is working

---

## Feature 2: Version Notes

### Background
**Feature**: Added ability to attach notes to text file versions. Notes are stored in the Version model (not TextFile) and imported from `WS_Version_Entity.notes` field.

### UI Elements
- **Toolbar Button**: "list.clipboard" icon between "Image Properties" and "Bold"
- **Notes Editor**: Sheet with TextEditor for multi-line notes
- **Storage**: Notes saved with Version, persisted to SwiftData/CloudKit

### Test Steps

#### Test 2.1: Create Notes on New Version
1. **Open a Text File**
   - Navigate to Files → select any text file
   - File opens in FileEditView

2. **Locate Notes Button**
   - Look at formatting toolbar (above keyboard)
   - ✓ Find "list.clipboard" icon button
   - ✓ Button positioned between image properties and Bold button
   - ✓ Button is enabled and tappable

3. **Open Notes Editor**
   - Tap the notes button
   - ✓ Sheet slides up from bottom
   - ✓ Shows "Notes" title
   - ✓ TextEditor field visible
   - ✓ "Done" button in top-right

4. **Add Notes**
   - Type some text: "This is a test note for version 1"
   - Add multiple lines
   - Try emoji: "📝 Important reminder"
   - ✓ Text appears in editor
   - ✓ Multi-line support works
   - ✓ Emoji displays correctly

5. **Save Notes**
   - Tap "Done" button
   - ✓ Sheet dismisses
   - ✓ Back in FileEditView
   - Notes saved automatically

6. **Verify Persistence**
   - Close the file (navigate away)
   - Reopen the same file
   - Tap notes button
   - ✓ Notes still present
   - ✓ All content preserved including emoji

#### Test 2.2: Edit Existing Notes
1. **Open File with Notes**
   - Open a file that has notes (from Test 2.1)
   - Tap notes button

2. **Modify Notes**
   - Add more text to existing notes
   - Delete some lines
   - Change content
   - Tap "Done"

3. **Verify Changes**
   - Close and reopen file
   - Tap notes button
   - ✓ Changes persisted
   - ✓ No data loss

#### Test 2.3: Clear Notes
1. **Open Notes Editor**
   - Open file with notes
   - Tap notes button

2. **Delete All Content**
   - Select all text (long press → Select All)
   - Delete
   - ✓ TextEditor now empty
   - Tap "Done"

3. **Verify Empty State**
   - Close and reopen file
   - Tap notes button
   - ✓ Notes still empty
   - ✓ No residual content

#### Test 2.4: Import Legacy Notes
1. **Prepare Import**
   - Use Writing Shed v1 export that contains versions with notes
   - Verify in legacy app which versions have notes

2. **Import Data**
   - Delete app data (fresh start)
   - Import the JSON file
   - Wait for completion

3. **Check Imported Notes**
   - Navigate to files that had notes in legacy app
   - Open each file
   - Tap notes button
   - ✓ Notes imported correctly
   - ✓ Content matches legacy app
   - ✓ No truncation or corruption

#### Test 2.5: Version Switching
1. **Create Multiple Versions**
   - Open a file
   - Add notes: "Version 1 notes"
   - Close file
   - Create a new version
   - Add different notes: "Version 2 notes"

2. **Switch Between Versions**
   - Use version toolbar to switch to Version 1
   - Tap notes button
   - ✓ Shows "Version 1 notes"
   - Switch to Version 2
   - Tap notes button
   - ✓ Shows "Version 2 notes"
   - ✓ Each version has its own notes

### Expected Results
| Test | Expected Outcome |
|------|------------------|
| Create notes | Notes saved with version |
| Edit notes | Changes persisted |
| Clear notes | Empty notes state saved |
| Import notes | Legacy notes imported to correct version |
| Version switching | Each version has independent notes |

### Troubleshooting
- **Button not visible**: Check toolbar initialization in FormattingToolbarView
- **Sheet doesn't open**: Verify `showNotesEditor` state binding
- **Notes not saving**: Check Version model has `notes: String?` property
- **Import fails**: Verify `WS_Version_Entity.notes` field mapping

---

## Feature 3: Pinch Zoom (iOS Only)

### Background
**Feature**: Pinch-to-zoom gesture for text views with persistent zoom factor across all text files.

**Technical Details**:
- Uses `UIPinchGestureRecognizer` with `CGAffineTransform`
- Zoom range: 0.5x (50%) to 3.0x (300%)
- Stored in UserDefaults: `textViewZoomFactor`
- Applied to all text views on creation

### Test Steps

#### Test 3.1: Basic Pinch Zoom
1. **Open a Text File**
   - Navigate to any text file
   - File opens in FileEditView with text visible

2. **Test Zoom In**
   - Place two fingers on text view
   - Pinch outward (spread fingers)
   - ✓ Text scales larger
   - ✓ Zoom is smooth and responsive
   - ✓ Images scale with text
   - ✓ Layout remains readable

3. **Test Zoom Out**
   - Place two fingers on text view
   - Pinch inward (bring fingers together)
   - ✓ Text scales smaller
   - ✓ Can see more content at once
   - ✓ Layout remains readable

4. **Test Zoom Limits**
   - Pinch out to maximum
   - ✓ Stops at 3.0x (text very large)
   - ✓ Cannot zoom beyond maximum
   - Pinch in to minimum
   - ✓ Stops at 0.5x (text smaller than normal)
   - ✓ Cannot zoom beyond minimum

#### Test 3.2: Zoom Persistence
1. **Set a Zoom Level**
   - Open a text file
   - Pinch to zoom to ~1.5x (moderately larger)
   - Note the text size

2. **Close and Reopen File**
   - Navigate away from file
   - Return to same file
   - ✓ Zoom level preserved
   - ✓ Text appears at same size

3. **Open Different File**
   - Navigate to a different text file
   - ✓ New file opens with same zoom level
   - ✓ Zoom factor applies globally

4. **Test After App Restart**
   - Close app completely
   - Relaunch app
   - Open any text file
   - ✓ Zoom level preserved after restart
   - ✓ UserDefaults storage working

#### Test 3.3: Zoom Reset
1. **Find Default Zoom**
   - Pinch zoom to various levels
   - Try to return to 1.0x (normal size)
   - Note: No explicit reset button yet

2. **Manual Reset** (if needed)
   - Zoom carefully to approximate 1.0x
   - Or: Delete app and reinstall for true reset

#### Test 3.4: Interaction with Other Features
1. **Zoom + Text Selection**
   - Zoom text to 1.5x
   - Try selecting text with tap/drag
   - ✓ Selection works normally
   - ✓ Cursor placement accurate
   - ✓ Selection handles visible

2. **Zoom + Image Tapping**
   - Zoom text to 2.0x
   - Tap on an image attachment
   - ✓ Image selection works
   - ✓ Blue border appears correctly
   - ✓ Image properties accessible

3. **Zoom + Formatting**
   - Zoom text to 1.5x
   - Select text and apply bold
   - ✓ Formatting applies correctly
   - ✓ Text remains at zoom level

4. **Zoom + Search**
   - Zoom text to 2.0x
   - Press ⌘F to open search
   - Search for text
   - ✓ Matches highlighted correctly
   - ✓ Navigation works
   - ✓ Zoom doesn't interfere

### Expected Results
| Zoom Level | Text Appearance | Use Case |
|------------|----------------|----------|
| 0.5x | Smaller than normal | See more content |
| 1.0x | Normal size | Default |
| 1.5x | 50% larger | Comfortable reading |
| 2.0x | Double size | High visibility |
| 3.0x | Triple size | Maximum zoom |

### Troubleshooting
- **Pinch doesn't work**: Verify on iOS device (not macOS)
- **Zoom doesn't persist**: Check UserDefaults key `textViewZoomFactor`
- **Zoom resets**: Verify transform applied in `makeUIView`
- **Layout broken**: Check `CGAffineTransform` scaling

---

## Feature 4: Two-Finger Drag Scroll (iOS Only)

### Background
**Feature**: Two-finger pan gesture for scrolling text views without interfering with text selection or tapping.

**Technical Details**:
- Uses `UIPanGestureRecognizer` requiring exactly 2 fingers
- Scrolls content vertically
- Doesn't interfere with single-finger text editing gestures
- Includes bounds checking

### Test Steps

#### Test 4.1: Basic Drag Scroll
1. **Open Long Text File**
   - Open a file with multiple pages of content
   - Text should extend beyond visible screen

2. **Test Two-Finger Scroll Down**
   - Place two fingers on text view
   - Drag downward
   - ✓ Content scrolls up (showing lower content)
   - ✓ Scroll is smooth and follows fingers
   - ✓ No delay or lag

3. **Test Two-Finger Scroll Up**
   - Place two fingers on text view
   - Drag upward
   - ✓ Content scrolls down (showing upper content)
   - ✓ Scroll is smooth

4. **Test Scroll Bounds**
   - Scroll to top of document
   - Try scrolling up further
   - ✓ Stops at top, no over-scroll
   - Scroll to bottom of document
   - Try scrolling down further
   - ✓ Stops at bottom, no over-scroll

#### Test 4.2: No Interference with Tapping
1. **Single Finger Tap**
   - Tap with one finger to place cursor
   - ✓ Cursor moves to tap location
   - ✓ No scrolling occurs
   - ✓ Text selection works normally

2. **Image Tapping**
   - Tap on image attachment with one finger
   - ✓ Image selects
   - ✓ Blue border appears
   - ✓ No scrolling triggered

3. **Text Selection**
   - Tap and drag with one finger to select text
   - ✓ Selection works normally
   - ✓ No scrolling interference
   - ✓ Selection handles appear

#### Test 4.3: Combined Gestures
1. **Zoom + Scroll**
   - Pinch to zoom text to 2.0x
   - Use two fingers to scroll
   - ✓ Scrolling works at zoomed level
   - ✓ Gestures don't conflict

2. **Scroll + Tap**
   - Scroll with two fingers
   - Lift fingers
   - Immediately tap with one finger
   - ✓ Tap registers correctly
   - ✓ No gesture confusion

3. **Scroll + Select**
   - Scroll with two fingers to middle of document
   - Tap and drag with one finger to select
   - ✓ Selection works
   - ✓ No accidental scrolling

#### Test 4.4: Edge Cases
1. **One Finger Only**
   - Try dragging with only one finger
   - ✓ Text selection starts (not scrolling)
   - ✓ No scroll gesture triggered

2. **Three Fingers**
   - Try dragging with three fingers
   - ✓ Behavior defined (either scrolls or ignored)
   - ✓ No crashes

3. **Quick Swipe**
   - Perform quick two-finger swipe
   - ✓ Content scrolls
   - ✓ No momentum/inertia (immediate stop)

4. **Diagonal Scroll**
   - Scroll with slight horizontal component
   - ✓ Only vertical scrolling occurs
   - ✓ No horizontal shift

### Expected Results
| Action | Fingers | Expected Behavior |
|--------|---------|-------------------|
| Tap | 1 | Place cursor, no scroll |
| Drag | 1 | Text selection, no scroll |
| Scroll | 2 | Content scrolls vertically |
| Pinch | 2 | Zoom in/out |
| Image tap | 1 | Image selection |

### Troubleshooting
- **Scroll doesn't work**: Verify exactly 2 fingers used
- **Interferes with selection**: Check `minimumNumberOfTouches = 2`
- **No bounds checking**: Verify `maxOffsetY` calculation
- **Works on macOS**: Feature is iOS-only (UIKit gestures)

---

## Integration Testing

### Test Int-1: All Features Together
1. **Import Legacy Data**
   - Import Writing Shed v1 JSON
   - ✓ Collections/Submissions separated correctly
   - ✓ Notes imported to versions

2. **Open Collection Item**
   - Navigate to Collections folder
   - Open a collection
   - ✓ Opens in FileEditView

3. **Use All Text View Features**
   - Add version notes
   - Pinch zoom to 1.5x
   - Two-finger scroll through content
   - Use search (⌘F)
   - Apply formatting (Bold, Italic)
   - ✓ All features work together
   - ✓ No conflicts or crashes

4. **Switch to Submission**
   - Navigate to Submissions folder
   - Open a submission
   - ✓ Zoom level preserved
   - ✓ Version notes accessible
   - ✓ All gestures work

### Test Int-2: Cross-Version Notes
1. **Create Multiple Versions with Notes**
   - Open file, add notes to Version 1
   - Create Version 2, add different notes
   - Create Version 3, add different notes

2. **Verify Isolation**
   - Switch between versions
   - ✓ Each version has correct notes
   - ✓ No notes bleeding between versions

3. **Apply Zoom at Different Versions**
   - Switch to Version 1, set zoom to 1.5x
   - Switch to Version 2
   - ✓ Zoom level consistent across versions
   - ✓ Zoom is global, not per-version

---

## Performance Testing

### Test Perf-1: Large Import
1. **Import Large Dataset**
   - Use JSON with 100+ items
   - Time the import process
   - ✓ Import completes without crash
   - ✓ Collections/Submissions separated correctly
   - ✓ Reasonable completion time

### Test Perf-2: Zoom Performance
1. **Zoom with Large Document**
   - Open file with 100+ pages
   - Pinch zoom to 3.0x
   - ✓ Zoom responsive
   - ✓ No lag or stutter
   - ✓ Text remains readable

### Test Perf-3: Scroll Performance
1. **Scroll Long Document**
   - Open file with 100+ pages
   - Two-finger scroll rapidly
   - ✓ Scroll is smooth
   - ✓ No dropped frames
   - ✓ Content loads properly

---

## Known Limitations

### Collections/Submissions
- **One-time fix**: Requires fresh import or data migration
- **Legacy data only**: Applies to imported Writing Shed v1 data

### Version Notes
- **No formatting**: Notes are plain text only
- **No attachments**: Cannot add images to notes
- **Version-specific**: Notes tied to version, not shared across versions

### Pinch Zoom
- **iOS only**: Uses UIKit gestures, not available on macOS
- **Global zoom**: One zoom level for all files (not per-file)
- **No reset button**: Must manually zoom back to 1.0x
- **Transform-based**: Uses CGAffineTransform (visual scaling, not font size)

### Two-Finger Scroll
- **iOS only**: Uses UIKit gestures, not available on macOS
- **2 fingers required**: Won't scroll with 1 or 3+ fingers
- **Vertical only**: No horizontal scrolling
- **No momentum**: Stops immediately when fingers lift

---

## Regression Testing

### Test Reg-1: Text Editing Still Works
- [ ] Typing text
- [ ] Backspace/delete
- [ ] Copy/paste
- [ ] Undo/redo
- [ ] Text selection

### Test Reg-2: Formatting Still Works
- [ ] Bold
- [ ] Italic
- [ ] Underline
- [ ] Paragraph styles
- [ ] Image insertion

### Test Reg-3: Search Still Works
- [ ] Open search (⌘F)
- [ ] Find matches
- [ ] Navigate matches (⌘G)
- [ ] Replace
- [ ] Replace all

### Test Reg-4: Other Features
- [ ] Version management
- [ ] Pagination view
- [ ] PDF export
- [ ] RTF import/export
- [ ] CloudKit sync

---

## Bug Report Template

If you encounter issues, use this template:

```
**Feature**: [Collections/Notes/Zoom/Scroll]
**Platform**: iOS [version] / iPad [model]
**Build**: [commit hash or date]

**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Behavior**:


**Actual Behavior**:


**Screenshots/Video**:
[attach if possible]

**Console Logs**:
[any relevant error messages]

**Frequency**: [Always / Sometimes / Rare]
```

---

## Testing Completion Checklist

- [ ] All Feature 1 tests completed (Collections/Submissions)
- [ ] All Feature 2 tests completed (Version Notes)
- [ ] All Feature 3 tests completed (Pinch Zoom)
- [ ] All Feature 4 tests completed (Two-Finger Scroll)
- [ ] Integration tests completed
- [ ] Performance tests completed
- [ ] Regression tests completed
- [ ] No critical bugs found
- [ ] All bugs documented

---

## Next Steps

After testing:
1. ✅ **If all tests pass**: Features ready for production
2. 🐛 **If bugs found**: Create issues in GitHub
3. 📝 **Update documentation**: Note any unexpected behaviors
4. 🚀 **Plan deployment**: Consider TestFlight for wider testing

---

**Questions or Issues?**
Contact: [Your contact method]
Document Version: 1.0 (13 December 2025)
