# Phase 2 Manual Testing Checklist

**Date**: 2025-10-27  
**Tester**: _____________  
**Device**: _____________  

## Test B: Undo/Redo Refresh (T2.16)

### Setup
1. Open Writing Shed Pro
2. Navigate to any project → any folder → any file
3. Clear all existing text

### Test Cases

#### TC-B1: Basic Undo/Redo
- [ ] Type "Hello World"
- [ ] Wait 3 seconds (for typing coalescing)
- [ ] Tap Undo button
- [ ] **Expected**: Text clears AND text view updates immediately
- [ ] **Actual**: ___________________________
- [ ] Tap Redo button
- [ ] **Expected**: "Hello World" reappears AND text view updates immediately
- [ ] **Actual**: ___________________________

#### TC-B2: Multiple Undo/Redo
- [ ] Type "Line 1" + Return
- [ ] Type "Line 2" + Return
- [ ] Type "Line 3"
- [ ] Wait 3 seconds
- [ ] Tap Undo button 3 times
- [ ] **Expected**: Each undo removes one line AND updates text view
- [ ] **Actual**: ___________________________
- [ ] Tap Redo button 3 times
- [ ] **Expected**: Each redo restores one line AND updates text view
- [ ] **Actual**: ___________________________

#### TC-B3: Undo After Editing
- [ ] Type some text
- [ ] Move cursor to middle
- [ ] Delete some characters
- [ ] Type new characters
- [ ] Tap Undo multiple times
- [ ] **Expected**: Each undo step reverses correctly with immediate visual update
- [ ] **Actual**: ___________________________

#### TC-B4: Button States
- [ ] Clear all text
- [ ] **Expected**: Undo button disabled
- [ ] Type "Test"
- [ ] Wait 3 seconds
- [ ] **Expected**: Undo button enabled, Redo button disabled
- [ ] Tap Undo
- [ ] **Expected**: Undo button disabled, Redo button enabled
- [ ] **Actual**: ___________________________

**Test B Result**: ✅ Pass / ❌ Fail  
**Notes**:
```

```

---

## Test C: Cursor Positioning (T2.17)

### Setup
1. Open Writing Shed Pro
2. Navigate to any file
3. Type or paste this text:
```
The quick brown fox jumps over the lazy dog.
Pack my box with five dozen liquor jugs.
How vexingly quick daft zebras jump!
```

### Test Cases

#### TC-C1: Tap to Position Cursor
- [ ] Tap between "quick" and "brown" on line 1
- [ ] **Expected**: Cursor appears between the two words
- [ ] **Actual**: Cursor position: ___________________________
- [ ] Tap at the beginning of line 2
- [ ] **Expected**: Cursor at start of "Pack"
- [ ] **Actual**: Cursor position: ___________________________
- [ ] Tap at the end of line 3
- [ ] **Expected**: Cursor at end of "jump!"
- [ ] **Actual**: Cursor position: ___________________________

#### TC-C2: Arrow Key Navigation
- [ ] Place cursor at start of line 1
- [ ] Press right arrow 4 times
- [ ] **Expected**: Cursor after "The "
- [ ] **Actual**: Cursor position: ___________________________
- [ ] Press down arrow once
- [ ] **Expected**: Cursor moves to line 2, approximately same column
- [ ] **Actual**: Cursor position: ___________________________
- [ ] Press left arrow 2 times
- [ ] **Expected**: Cursor moves back 2 characters
- [ ] **Actual**: ___________________________

#### TC-C3: Cursor + Tap Combination
- [ ] Use arrow keys to position cursor mid-line
- [ ] Tap elsewhere in the text
- [ ] **Expected**: Cursor moves to tap location smoothly
- [ ] **Actual**: ___________________________
- [ ] Check if any characters were inserted
- [ ] **Expected**: No unwanted spaces or characters
- [ ] **Actual**: ___________________________

#### TC-C4: Tap at Different Locations
Test each of these tap locations and record where cursor actually appears:

| Intended Tap Location | Expected Result | Actual Result | Pass/Fail |
|----------------------|-----------------|---------------|-----------|
| Start of line 1 | Before "The" | | |
| Middle of "brown" | In "brown" | | |
| End of line 1 | After "dog." | | |
| Between "my" and "box" | Between words | | |
| Start of line 3 | Before "How" | | |
| End of line 3 | After "jump!" | | |

#### TC-C5: Long Press and Double Tap
- [ ] Long press on a word
- [ ] **Expected**: Context menu appears (Paste, Select, etc.)
- [ ] **Actual**: ___________________________
- [ ] Dismiss menu
- [ ] Double tap on a word
- [ ] **Expected**: Word is selected
- [ ] **Actual**: ___________________________
- [ ] Tap elsewhere
- [ ] **Expected**: Selection clears, cursor at new position
- [ ] **Actual**: ___________________________

#### TC-C6: Cursor Position Accuracy Map
Draw or mark where taps actually position the cursor:

```
Line 1: The quick brown fox jumps over the lazy dog.
        ↑   ↑     ↑     ↑   ↑     ↑    ↑   ↑    ↑   ↑
Mark:   [_] [_]   [_]   [_] [_]   [_]  [_] [_]  [_] [_]
```

For each ↑, tap and record if cursor goes to correct position (✓) or wrong position (✗ + where it went)

**Test C Result**: ✅ Pass / ❌ Fail / ⚠️ Partial  
**Notes**:
```

```

---

## Additional Observations

### Unwanted Character Insertion
- [ ] Did you observe any spaces being inserted? Yes / No
- [ ] If yes, when did it happen? ___________________________
- [ ] Did you observe any other characters inserted? Yes / No
- [ ] If yes, which characters? ___________________________

### Text View Behavior
- [ ] Does text view scroll smoothly? Yes / No
- [ ] Does selection highlight correctly? Yes / No
- [ ] Does copy/paste work correctly? Yes / No

### Performance
- [ ] Is typing responsive? Yes / No
- [ ] Are there any delays when moving cursor? Yes / No
- [ ] Are there any visual glitches? Yes / No
- [ ] If yes, describe: ___________________________

---

## Debug Logs

If running in Xcode, check the console for debug output:
- Look for lines starting with "📝 shouldChange"
- Look for lines starting with "🎹 Keyboard"

Paste relevant log output here:
```

```

---

## Conclusion

### Test B (Undo/Redo): ✅ Pass / ❌ Fail
**Summary**: 

### Test C (Cursor Positioning): ✅ Pass / ❌ Fail / ⚠️ Partial
**Summary**: 

### Overall Phase 2 Status: ✅ Ready for Phase 3 / ⚠️ Needs Work / ❌ Blocking Issues

### Recommendations:
- [ ] Proceed to Phase 3
- [ ] Fix cursor positioning before Phase 3
- [ ] Other: ___________________________

---

## Tester Sign-off

**Name**: _____________  
**Date**: _____________  
**Signature**: _____________
