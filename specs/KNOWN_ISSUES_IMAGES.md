# Known Issues - Image Support (Feature 006)

## Active Issues

### Issue: Paragraph Alignment Inheritance After Center/Right-Aligned Images

**Severity**: Medium  
**Status**: Open - Deferred  
**Date Discovered**: 11 November 2025

#### Description
When inserting a center or right-aligned image and then pressing Return to create a new paragraph, the new paragraph displays with center/right alignment instead of the expected body text alignment (left/natural).

#### Reproduction Steps
1. Create a new document (empty)
2. Insert an image using Files or Photos
3. Select the image and apply center or right alignment
4. Move cursor to the right of the image (position after the trailing newline)
5. Press Return to create a new paragraph
6. **Expected**: New paragraph should be left-aligned (body text style)
7. **Actual**: New paragraph is center or right-aligned (inherits image alignment)

#### Technical Details
- The paragraph style attributes show `.alignment = .left` (correct)
- But the visual display shows center/right alignment (incorrect)
- This suggests the paragraph style is being applied correctly in the data model, but something in the rendering/display layer is overriding it

#### Root Cause Analysis
The issue is complex because:
1. `InsertImageCommand` correctly creates newlines with `textParagraphStyle.alignment = .left` before and after center/right images
2. These newlines wrap the centered image to isolate its paragraph
3. When cursor is on the trailing newline and Return is pressed, UITextView inserts a new newline
4. The new newline appears to inherit the center/right alignment from the image instead of the left alignment from the current newline

**Possible root causes**:
- UITextView's typing attributes might be reading from the image's paragraph style rather than the newline's
- The newly inserted text might not be inheriting the newline's paragraph style correctly
- Display rendering might be using image alignment for subsequent paragraphs

#### Previous Attempts to Fix
1. Added `syncTypingAttributesForCursorPosition()` in `textViewDidChangeSelection` to reset typing attributes when cursor moves - **FAILED**
   - Timing issue: typing attributes are synced AFTER text is already inserted
   
2. Added `textView:shouldChangeTextIn:replacementText:` delegate to sync before Return is inserted - **FAILED**
   - Method fires but alignment still incorrect

3. Added post-insertion fix in `textViewDidChange` to correct newly inserted newlines - **FAILED**
   - Paragraph style already shows as correct but display is still wrong

#### Files Involved
- `Writing Shed Pro/Models/Commands/InsertImageCommand.swift` - Creates newlines with paragraph styles
- `Writing Shed Pro/Views/Components/FormattedTextEditor.swift` - Text view delegate, typing attribute management
- `Writing Shed Pro/Views/FileEditView.swift` - Main editor view

#### Next Steps to Try
1. **Debug approach**: Add detailed logging of:
   - Paragraph styles at each position in the text
   - UITextView's typing attributes when cursor is at various positions
   - What paragraph style is applied to newly inserted text
   
2. **Possible solutions**:
   - Check if UITextView has a method to explicitly set paragraph style for next input
   - Consider forcing paragraph style application after every insertion
   - Look at whether the zero-width space navigation is interfering
   - Check if text color/font attributes are being copied when they shouldn't be

3. **Alternative approach**:
   - Instead of trying to prevent inheritance, post-process inserted text to correct its paragraph style
   - Fix the alignment immediately after the user finishes typing the paragraph

#### Related Code
- Commit 7b0dd6a: "Fix cursor navigation around images with zero-width space handling" (working version)
- Commits 4c8aadd-4c8aadd: Attempted fixes (reverted)

#### Workaround
Users can manually reapply left alignment after typing a new paragraph following a centered image.
