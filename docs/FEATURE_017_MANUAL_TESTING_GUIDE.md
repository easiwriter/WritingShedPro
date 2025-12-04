# Feature 017: Manual Testing Guide
## In-Editor Search & Replace - Phase 1

**Date**: 4 December 2025  
**Version**: Phase 1 Complete  
**Status**: Ready for Testing  

---

## Pre-Testing Checklist

Before starting manual tests:
- [ ] Build succeeds (`⌘+B`)
- [ ] All 88 unit tests pass (`⌘+U`)
- [ ] No compilation errors
- [ ] App launches successfully (`⌘+R`)
- [ ] Can open a text file in FileEditView
- [ ] Text file has some content to search

---

## Quick Start Test (5 minutes)

**Goal**: Verify basic functionality works end-to-end

1. **Open Search Bar**
   - Press `⌘F` in FileEditView
   - ✓ Search bar appears below version toolbar
   - ✓ Search field is focused (cursor blinking)
   - ✓ Magnifying glass icon in toolbar is filled

2. **Basic Search**
   - Type "the" in search field
   - ✓ Wait 300ms for debounce
   - ✓ Matches highlighted in yellow
   - ✓ Current match highlighted in orange
   - ✓ Counter shows "1 of X" (where X is total matches)

3. **Navigate Matches**
   - Press `⌘G` to go to next match
   - ✓ Counter updates to "2 of X"
   - ✓ Orange highlight moves to next match
   - ✓ Text scrolls to show current match

4. **Replace**
   - Click chevron button to expand replace mode
   - ✓ Replace row slides down smoothly
   - ✓ Replace text field appears
   - Type "THE" in replace field
   - Click "Replace" button
   - ✓ Current match replaced with "THE"
   - ✓ Search updates, counter shows new total

5. **Close Search**
   - Press `⎋` (Escape)
   - ✓ Search bar slides up and disappears
   - ✓ Highlights removed from text
   - ✓ Toolbar icon returns to unfilled state

**If all ✓ checks pass**: Basic functionality works! 🎉  
**If any fail**: Note the issue and test other scenarios before debugging.

---

## Detailed Test Scenarios

### Test 1: Search Edge Cases

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **Empty Search** | Open search, leave field empty | No matches, counter hidden |
| **Single Character** | Search for "a" | Finds all "a" characters |
| **No Matches** | Search for "zzzzz" | "No results" shown, counter hidden |
| **Unicode** | Search for "café" | Finds "café" with accent |
| **Emoji** | Search for "😀" | Finds emoji character |
| **Special Chars** | Search for "$100" | Finds dollar amounts |
| **Newlines** | Search for text spanning lines | Context shows with spaces |
| **Long Text** | Search 10+ word phrase | Finds complete phrase |
| **Whitespace** | Search for "  " (two spaces) | Finds double spaces |

### Test 2: Navigation Edge Cases

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **First Match** | Search, verify on match 1 | Counter shows "1 of X" |
| **Next from Last** | Navigate to last match, press ⌘G | Wraps to first match (circular) |
| **Previous from First** | On first match, press ⌘⇧G | Wraps to last match |
| **Single Match** | Search term with only 1 result | Counter shows "1 of 1", nav still works |
| **No Matches Nav** | No results, try navigation | Buttons disabled, no action |
| **Rapid Navigation** | Press ⌘G multiple times quickly | Smooth transitions, no lag |
| **Scroll Position** | Navigate to match outside viewport | Auto-scrolls to show match |

### Test 3: Search Options

#### Case Sensitivity
| Test Case | Case Option | Search | Should Find | Should NOT Find |
|-----------|-------------|--------|-------------|-----------------|
| Insensitive (default) | OFF | "the" | "The", "THE", "the" | n/a |
| Sensitive | ON | "the" | "the" | "The", "THE" |
| Sensitive | ON | "The" | "The" | "the", "THE" |

#### Whole Word
| Test Case | Word Option | Search | Should Find | Should NOT Find |
|-----------|-------------|--------|-------------|-----------------|
| Partial (default) | OFF | "car" | "car", "cars", "scar" | n/a |
| Whole Word | ON | "car" | "car" (standalone) | "cars", "scar" |
| Whole Word | ON | "it" | "it" (standalone) | "item", "with" |
| Punctuation | ON | "word" | "word.", "word!" | "words" |

#### Regular Expression
| Test Case | Regex | Expected Matches | Notes |
|-----------|-------|------------------|-------|
| **Simple Pattern** | `the` | All "the" | Same as plain text |
| **Character Class** | `[0-9]+` | All numbers | "123", "45" |
| **Email Pattern** | `\w+@\w+\.\w+` | Email addresses | "user@example.com" |
| **Start of Line** | `^The` | Lines starting with "The" | Only at line start |
| **End of Line** | `end$` | Lines ending with "end" | Only at line end |
| **Invalid Pattern** | `[unclosed` | Error message shown | Orange warning icon |
| **Capture Groups** | `(\w+)@(\w+)` | Email parts for replace | Used in replace with $1, $2 |

### Test 4: Option Combinations

| Case | Word | Regex | Search | Result |
|------|------|-------|--------|--------|
| ON | OFF | OFF | "The" | Only "The" (exact case) |
| OFF | ON | OFF | "car" | Only "car" as whole word |
| ON | ON | OFF | "The" | "The" as whole word, exact case |
| OFF | OFF | ON | `\d+` | All number sequences |
| ON | OFF | ON | `The` | "The" with exact case via regex |
| OFF | ON | ON | `\bcar\b` | Whole word via regex boundary |

### Test 5: Replace Operations

#### Single Replace
| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **Replace First** | Search, replace at match 1 | Match 1 replaced, moves to next |
| **Replace Middle** | Navigate to middle match, replace | That match replaced |
| **Replace Last** | Navigate to last, replace | Last replaced, search updates |
| **Replace No Match** | Clear search, click replace | Button disabled, no action |

#### Replace All
| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **Replace 5 Matches** | Search with 5 results, replace all | All 5 replaced, counter shows 0 |
| **Replace 1 Match** | Single result, replace all | That one replaced |
| **Replace 100+ Matches** | Large file, many matches | All replaced in <100ms |
| **No Matches** | No results, click replace all | Button disabled |

#### Regex Replace with Capture Groups
| Test Case | Search Pattern | Replace With | Example Input | Result |
|-----------|----------------|--------------|---------------|--------|
| **Email Swap** | `(\w+)@(\w+)` | `$2@$1` | user@example | example@user |
| **Name Reverse** | `(\w+) (\w+)` | `$2, $1` | John Doe | Doe, John |
| **Add Prefix** | `(\d+)` | `#$1` | 123 | #123 |

### Test 6: Undo/Redo

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| **Undo Single Replace** | Replace one match, press ⌘Z | Original text restored, match reappears |
| **Undo Replace All** | Replace all, press ⌘Z | All original text restored |
| **Redo After Undo** | Undo replace, press ⌘⇧Z | Replacement re-applied |
| **Multiple Undo** | Replace 3 times, undo 3 times | All three undone in reverse order |
| **Undo Non-Replace** | Edit text normally, undo | Normal undo works (not affected) |

### Test 7: Keyboard Shortcuts

| Shortcut | Context | Expected Action |
|----------|---------|-----------------|
| **⌘F** | Edit mode | Open search bar, focus search field |
| **⌘F** | Search open | Close search bar |
| **⌘G** | Search active, has matches | Next match |
| **⌘G** | No matches | No action (disabled) |
| **⌘⇧G** | Search active, has matches | Previous match |
| **⌘⇧G** | No matches | No action (disabled) |
| **⎋** | Search open | Close search bar, clear highlights |
| **⏎** | Search mode | Next match |
| **⏎** | Replace mode, text entered | Replace current match |
| **⇧⏎** | Search active | Previous match |

### Test 8: UI Animations & Transitions

| Test Case | Action | Expected Animation |
|-----------|--------|-------------------|
| **Search Bar Open** | Press ⌘F | Smooth slide down (0.2s) |
| **Search Bar Close** | Press ⎋ | Smooth slide up (0.2s) |
| **Replace Expand** | Click chevron right | Replace row slides down (0.2s) |
| **Replace Collapse** | Click chevron down | Replace row slides up (0.2s) |
| **Match Highlight** | Type search text | Yellow highlights appear smoothly |
| **Current Match** | Navigate | Orange highlight moves smoothly |
| **Scroll to Match** | Navigate to off-screen match | Animated scroll, not jump |
| **Clear Button** | Text appears in field | X button fades in |

### Test 9: Focus Management

| Test Case | Action | Expected Focus |
|-----------|--------|----------------|
| **Open Search** | Press ⌘F | Search field focused, cursor blinking |
| **Expand Replace** | Click chevron | Replace field focused |
| **Navigate Match** | Press ⌘G | Focus stays in search field |
| **Replace Match** | Click replace | Focus stays in search field |
| **Close Search** | Press ⎋ | Focus returns to text editor |

### Test 10: Visual Feedback

| Element | State | Expected Visual |
|---------|-------|-----------------|
| **Toolbar Button** | Search closed | Outlined magnifying glass |
| **Toolbar Button** | Search open | Filled magnifying glass |
| **Option Toggle** | Inactive | Gray icon, no background |
| **Option Toggle** | Active | Accent color icon + background |
| **Nav Button** | Enabled | Normal opacity |
| **Nav Button** | Disabled | Reduced opacity, no action |
| **Match Counter** | Has matches | "3 of 12" in secondary color |
| **Match Counter** | No matches | "No results" in secondary color |
| **Regex Error** | Invalid pattern | Orange warning + error text |

---

## Platform-Specific Tests

### Mac Catalyst Only

| Test Case | Expected Behavior |
|-----------|-------------------|
| **Window Resize** | Search bar adjusts width |
| **Keyboard Shortcuts** | All shortcuts work natively |
| **Mouse Hover** | Tooltips appear on buttons |
| **Right Click** | Context menu (if applicable) |
| **Menu Integration** | Edit → Find (⌘F) works |

### iOS Specific

| Test Case | Expected Behavior |
|-----------|-------------------|
| **Portrait/Landscape** | Search bar adapts layout |
| **Keyboard Appearance** | Keyboard pushes view up |
| **Touch Targets** | All buttons are 44pt+ tap targets |
| **Accessibility** | VoiceOver reads all elements |
| **Split View** | Works in iPad split view |

---

## Performance Tests

| Test Case | File Size | Expected Performance |
|-----------|-----------|---------------------|
| **Small File** | <1k words | Search completes <10ms |
| **Medium File** | 1-10k words | Search completes <50ms |
| **Large File** | >10k words | Search completes <200ms |
| **Rapid Typing** | Any size | No lag (debounced) |
| **Replace All** | 100 matches | Completes <100ms |
| **Memory Usage** | Large file | No memory spikes |

---

## Bug Reporting Template

If you find a bug, document it with:

```markdown
### Bug: [Short Description]

**Severity**: Critical / High / Medium / Low

**Steps to Reproduce**:
1. Step one
2. Step two
3. Step three

**Expected Behavior**:
What should happen

**Actual Behavior**:
What actually happened

**Environment**:
- Device: iPad Pro / iPhone 15 / Mac Catalyst
- iOS Version: 17.x
- File Size: X words
- Search Term: "example"

**Screenshots/Video**:
[Attach if applicable]

**Console Output**:
[Any error messages from console]
```

---

## Test Results Tracking

### Quick Start Test
- [ ] Basic search works
- [ ] Navigation works
- [ ] Replace works
- [ ] Close works

### Edge Cases
- [ ] Empty search
- [ ] Unicode/emoji
- [ ] No matches
- [ ] Single match

### Options
- [ ] Case sensitivity
- [ ] Whole word
- [ ] Regular expression
- [ ] Combinations

### Replace
- [ ] Single replace
- [ ] Replace all
- [ ] Regex with capture groups
- [ ] Undo/redo

### Keyboard Shortcuts
- [ ] ⌘F (open/close)
- [ ] ⌘G (next)
- [ ] ⌘⇧G (previous)
- [ ] ⎋ (close)
- [ ] ⏎ (next/replace)

### UI/UX
- [ ] Animations smooth
- [ ] Focus management correct
- [ ] Visual feedback clear
- [ ] No visual glitches

### Performance
- [ ] No lag while typing
- [ ] Search completes quickly
- [ ] Replace all is fast
- [ ] No memory issues

### Platform
- [ ] iOS works
- [ ] Mac Catalyst works
- [ ] Keyboard shortcuts work on both

---

## Known Issues to Watch For

Based on implementation, these are potential issues to watch for:

1. **Debouncing Edge Case**: If you type very fast, search might not trigger until you stop
   - Expected: 300ms delay is intentional
   
2. **Replace All Performance**: Very large files (50k+ words) with 1000+ matches might be slow
   - Expected: Phase 1 is single-file focused, this is acceptable
   
3. **Regex Complexity**: Very complex regex patterns might take longer
   - Expected: User responsibility to use reasonable patterns

4. **Keyboard Focus**: On iOS, keyboard appearing might shift layout
   - Expected: Standard iOS behavior

5. **Mac Catalyst Menu**: Edit → Find menu item doesn't exist yet
   - Expected: Phase 1 limitation, use ⌘F directly

---

## Success Criteria

All tests pass if:
- ✅ No crashes or hangs
- ✅ All keyboard shortcuts work
- ✅ Search finds correct matches
- ✅ Replace works correctly
- ✅ Undo/redo works
- ✅ Animations are smooth
- ✅ Performance is acceptable (<200ms)
- ✅ No visual glitches
- ✅ Works on both iOS and Mac Catalyst

---

## After Testing

1. **Document Results**
   - Note any bugs found
   - Rate severity of each
   - Prioritize fixes

2. **Update Status**
   - Mark todos as complete
   - Create bug fix tasks if needed

3. **Decide Next Steps**
   - If no critical bugs: Ready for Phase 2
   - If bugs found: Fix before proceeding

---

**Testing Duration Estimate**: 30-60 minutes for thorough testing  
**Priority Tests**: Quick Start + Keyboard Shortcuts + Replace Operations  
**Optional Tests**: Platform-specific, performance edge cases

Good luck with testing! 🧪✨
