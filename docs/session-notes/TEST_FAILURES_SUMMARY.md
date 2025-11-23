# Test Failures Summary - November 2, 2025

## Overview
After fixing compilation errors in all test suites, we now have runtime test failures across 3 test files.

---

## FormattingUndoRedoTests.swift - 8 Failures

### Issue: Commands not applying formatting before undo manager registration

**Root Cause:** Tests were calling `undoManager.execute(command)` expecting it to apply the formatting, but `TextFileUndoManager.execute()` does NOT call `command.execute()` - it only records the command for undo. The pattern is:
1. Apply change to document FIRST
2. Create command with before/after state
3. Register command with undo manager

**Failures:**
1. Line 77: `testBoldFormatUndoRedo()` - Bold not applied before undo check
2. Line 170: `testPartialFormatRemoval()` - Format removal not applied
3. Line 212: `testColorChangeUndoRedo()` - Color change not applied  
4. Line 220: `testColorChangeUndoRedo()` - Color undo check
5. Line 263: `testParagraphStyleUndoRedo()` - Paragraph style not applied
6. Line 317: `testUnderlineStrikethroughUndo()` - Underline not applied
7. Line 318: `testUnderlineStrikethroughUndo()` - Strikethrough not applied
8. Line 371: `testMixedTextAndFormattingUndo()` - Text addition not applied

**Fix Applied:** Added `version.attributedContent = textN` BEFORE calling `undoManager.execute(command)` for all 8 test cases.

**Status:** ✅ FIXED - All instances updated with proper sequencing

---

## TextFormatterComprehensiveTests.swift - 5 Failures

### Issue: Partial selection formatting behavior

**Failures:**
1. Line 85: `testToggleBoldPartialSelection()` - "World should not be bold"
2. Line 275: `testMixedFormattingInSameText()` - Unexpected bold on "Normal"
3. Line 364: `testFormattingAtEndOfText()` - "Hello" unexpectedly bold
4. Line 413: `testFormattingSingleLineInMultiline()` - Line 1 incorrectly bold
5. Line 415: `testFormattingSingleLineInMultiline()` - Line 3 incorrectly bold

**Pattern:** When toggling bold on a partial selection (e.g., "Hello" in "Hello World"), text outside the range is getting formatted.

**Suspected Cause:** 
- TextFormatter might be applying formatting beyond the specified range
- OR tests are checking the wrong attributed string (original vs result)
- OR text without explicit font attributes is being affected

**Investigation Needed:**
1. Check if TextFormatter.toggleBold() respects range boundaries
2. Verify tests are checking the `result` not the original `text`
3. Check behavior when text has no explicit font attributes

**Status:** ⚠️ NEEDS INVESTIGATION

---

## StyleReapplicationTests.swift - 8 Failures

### Issue: Style name attribute and font size updates not working

**Failures:**

#### Style Name Attribute (2 failures):
1. Line 106: `testGenerateAttributesWithAllProperties()` - textStyleName nil instead of "test-style"
2. Line 227: `testApplyStyleWithModelBasedFormatting()` - textStyle nil instead of "UICTFontTextStyleBody"

**Issue:** Custom `.textStyleName` attribute not being set when generating or applying styles

#### Font Size Updates (2 failures):
3. Line 381: `testMultipleStylesInDocument()` - Title font 28.0 instead of 32.0
4. Line 387: `testMultipleStylesInDocument()` - Body font 17.0 instead of 18.0

**Issue:** Style sheet font size changes not being reapplied to document

#### Style Enumeration (4 failures):
5. Line 511: `testEnumerateTextStyleAttributeInDocument()` - Found 0 styles instead of 3
6. Line 512: `testEnumerateTextStyleAttributeInDocument()` - Title style XCTAssertNotNil failed
7. Line 513: `testEnumerateTextStyleAttributeInDocument()` - Body style XCTAssertNotNil failed  
8. Line 514: `testEnumerateTextStyleAttributeInDocument()` - Caption style XCTAssertNotNil failed

**Issue:** Custom `.textStyleName` attribute not found when enumerating document

**Root Cause:** The `.textStyleName` attribute key is not being used/stored correctly in the formatting code.

**Status:** ⚠️ NEEDS INVESTIGATION - Likely missing implementation in TextFormatter or style application code

---

## Summary Statistics

- **Total Test Failures:** 21
- **FormattingUndoRedoTests:** 8 failures ✅ FIXED
- **TextFormatterComprehensiveTests:** 5 failures ⚠️ INVESTIGATING  
- **StyleReapplicationTests:** 8 failures ⚠️ INVESTIGATING

## Next Steps

1. ✅ Run tests again to confirm FormattingUndoRedoTests fixes
2. ⚠️ Investigate TextFormatterComprehensiveTests partial selection issues
3. ⚠️ Investigate StyleReapplicationTests missing .textStyleName attribute
4. Update this document with findings and solutions

---

**Last Updated:** November 2, 2025
