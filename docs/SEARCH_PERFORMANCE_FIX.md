# Search Performance Fix - Case Study

**Date:** 5 December 2025  
**Feature:** 017 - In-Editor Search and Replace  
**Issue:** Search taking 14+ seconds for 1959 matches

## The Problem

Searching for common characters like "i" caused a 14-second beach ball, making the feature unusable.

**Console output:**
```
⏱️ search: 14.111s
⏱️ highlightMatches: 0.009s
⏱️ TOTAL: 14.120s
```

## Initial Assumptions (All Wrong!)

We tried multiple "fixes" based on incorrect assumptions:

1. ❌ **Assumed: Immediate search on keystroke**
   - Fixed: Added 300ms debouncing
   - Result: Still 14 seconds (just delayed)

2. ❌ **Assumed: Too many highlights**
   - Fixed: Limited to 500 matches + current
   - Result: Still 14 seconds (just fewer highlights)

3. ❌ **Assumed: Multiple layout passes**
   - Fixed: Single `beginEditing/endEditing` cycle
   - Result: Still 14 seconds

4. ❌ **Assumed: @Published causing view redraws**
   - Fixed: Migrated to @Observable
   - Result: Still 14 seconds

5. ❌ **Assumed: Two separate clear+highlight cycles**
   - Fixed: Integrated into single cycle
   - Result: Still 14 seconds

6. ❌ **Assumed: Old NSString.range(of:) loop**
   - Fixed: Used NSRegularExpression
   - Result: Still 14 seconds!

## The Real Problem (Finally Found!)

The search algorithm was **always fast** (~0.05 seconds). The 13.95 seconds were spent on:

```swift
for regexMatch in regexMatches {  // 1959 iterations
    let context = extractContext(for: nsRange, in: text)      // O(n) per match
    let lineNumber = calculateLineNumber(for: nsRange, in: text)  // O(n) per match
}
```

### calculateLineNumber() - The Silent Killer

```swift
func calculateLineNumber(for location: Int, in text: String) -> Int {
    let nsText = text as NSString
    let substring = nsText.substring(to: location)  // Creates substring
    let lineBreaks = substring.components(separatedBy: .newlines).count
    return lineBreaks
}
```

**For 1959 matches:**
- Match 1: Scan characters 0-100 (find newlines)
- Match 2: Scan characters 0-250 (find newlines)
- Match 3: Scan characters 0-400 (find newlines)
- ...
- Match 1959: Scan characters 0-26130 (find newlines)

**Total complexity: O(n²)**

### extractContext() - Also Expensive

- String manipulation for each match
- Multiple `replacingOccurrences` calls
- While loop collapsing spaces
- All done 1959 times!

## The Fix

**Don't calculate metadata during search:**

```swift
for regexMatch in regexMatches {
    let match = SearchMatch(
        range: regexMatch.range,
        context: "",      // Calculate lazily when needed
        lineNumber: 0     // Calculate lazily when needed
    )
    matches.append(match)
}
```

**Why this works:**
- In-editor highlighting only needs the ranges
- Context and line numbers aren't displayed
- Only calculate them if/when showing a search results panel

## Performance Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Search time | 14.111s | ~0.05s | **280x faster** |
| User experience | Beach ball | Instant | Usable! |
| Complexity | O(n²) | O(n) | Optimal |

## Lessons Learned

### 1. Profile Before Optimizing
We made 6 "optimizations" before finding the real problem. Always measure!

### 2. Don't Trust Assumptions
The search algorithm worked fine. The "helper functions" were the killers.

### 3. Watch for Hidden Complexity
Functions that look O(1) might be O(n):
- `substring(to:)` - looks cheap, actually expensive for large strings
- `components(separatedBy:)` - scans entire string
- Calling these in a loop = O(n²)

### 4. Question Every Loop
```swift
for match in matches {  // 1959 iterations
    doExpensiveThing()  // If this is O(n), you have O(n²)
}
```

### 5. Lazy Evaluation is Your Friend
Don't calculate what you might not need. Calculate on-demand.

### 6. Test with Realistic Data
- 10 matches: Everything looks fast
- 1959 matches: The truth emerges

## Code Commits

1. `3159956` - Added undo/redo search notification
2. `deaff88` - UI display refresh after content changes
3. `861ef13` - Debouncing + 500-match limit
4. `cebc0dc` - NSTextStorage batching
5. `ca571b9` - Tracked range clearing
6. `602b926` - @Observable migration
7. `3cd2752` - Integrated clear+highlight
8. `79a0fab` - Switch to NSRegularExpression
9. `94a77b0` - Fix compilation error
10. `71a9bc8` - **Remove O(n²) calculations - WORKS!**

## Conclusion

Sometimes the solution isn't optimizing the code you're looking at - it's **not running** the code you don't need.

The search was always fast. We just needed to stop doing unnecessary work.

---

**Performance mantra:** Measure, don't guess. The bottleneck is rarely where you think it is.
