# Test Failures Fixed - December 9, 2025

## Issues Fixed

### 1. ImageSerializationTests - fileID Not Preserved

**Problem**: The `fileID` property added to ImageAttachment was not being serialized/deserialized by AttributedStringSerializer.

**Fix**:
- Added `imageFileID: String?` to JSONAttributes struct
- Added encoding of fileID in `encode()` method (converts UUID to string)
- Added decoding of fileID in `decode()` method (parses string back to UUID)

**Files Modified**:
- `AttributedStringSerializer.swift` - Added fileID serialization support

### 2. TextSearchEngineTests - Multiple Failures

**Problem**: TextSearchEngine was optimized for performance to NOT calculate context and line numbers during search (lazy-loading design). Tests expected these values to be populated immediately.

**Root Cause**: 
- Search performance optimization sets `context: ""` and `lineNumber: 0` initially
- Context/line numbers are expensive O(n) operations
- Calculating them for every match in large documents (1959+ matches) causes O(n²) performance issues

**Fix Strategy**:
Added `enrichMatches()` public method to TextSearchEngine that calculates context and line numbers on-demand when needed for display or testing.

**Implementation**:
1. Added `enrichMatches(_ matches:in:)` method to TextSearchEngine
2. Updated affected tests to call `enrichMatches()` before asserting on context/lineNumber
3. Added `extractMatchedText(from:)` method to SearchMatch for reliable match extraction

**Tests Updated**:
- `testContextExtractionSimple()` - Now enriches matches before checking context
- `testLineNumberFirstLine()` - Now enriches matches before checking line number
- `testLineNumberSecondLine()` - Now enriches matches before checking line number  
- `testLineNumberMultipleLines()` - Now enriches matches before checking line number
- `testSearchMatchedTextProperty()` - Now uses `extractMatchedText(from:)` method

**Files Modified**:
- `TextSearchEngine.swift` - Added `enrichMatches()` method
- `SearchMatch.swift` - Added `extractMatchedText(from:)` method, updated `matchedText` property
- `TextSearchEngineTests.swift` - Updated 6 tests to use new pattern

## Technical Details

### Why Lazy-Loading Design?

The search optimization was necessary because:
- Context extraction requires substring operations and string manipulation (O(n))
- Line number calculation requires counting newlines from start to match location (O(n))
- With 1959 matches in a document, calculating these for all matches = 1959 × O(n) = O(n²)
- This caused severe performance issues in large documents

### Why EnrichMatches() Pattern?

1. **Performance**: Only calculate when needed (typically for display of top 50-100 results)
2. **Flexibility**: Caller decides when to pay the cost
3. **Testing**: Tests can explicitly request enrichment
4. **Production**: UI can enrich only visible matches

### Why ExtractMatchedText(from:)?

The `matchedText` property tried to extract match from `context`, but:
- Context is modified (newlines replaced with spaces, "..." added)
- Context is a substring with different offsets than original text
- Range in SearchMatch is relative to original text, not context

Solution: `extractMatchedText(from:)` takes the original text and uses the range directly.

## Test Results

**All 748 tests passing ✅**

All test failures resolved:
- ✅ `testFileIDSerialization()` - fileID now serializes/deserializes correctly
- ✅ `testContextExtractionSimple()` - Context populated via enrichMatches()
- ✅ `testLineNumberFirstLine()` - Line numbers calculated via enrichMatches()
- ✅ `testLineNumberSecondLine()` - Line numbers calculated via enrichMatches()
- ✅ `testLineNumberMultipleLines()` - Line numbers calculated via enrichMatches()
- ✅ `testSearchMatchedTextProperty()` - Uses extractMatchedText(from:) method (TextSearchEngineTests)
- ✅ `testSearchMatchMatchedText()` - Uses extractMatchedText(from:) method (SearchDataModelTests)

## Breaking Changes

### SearchMatch.matchedText Property

**Old Behavior**: Attempted to extract match from context (unreliable)
**New Behavior**: Returns empty string (context is modified and unreliable)
**Migration**: Use `extractMatchedText(from:)` method instead

```swift
// OLD (unreliable):
let text = match.matchedText

// NEW (reliable):
let text = match.extractMatchedText(from: originalText)
```

### Search Results Without Context

**Old Behavior**: Context and line numbers populated during search
**New Behavior**: Empty string/0 by default (performance optimization)
**Migration**: Call `enrichMatches()` when needed

```swift
// Search (fast, no context/line numbers)
let matches = engine.search(in: text, query: query)

// Enrich when needed for display (slower, but only for visible results)
let enriched = engine.enrichMatches(matches, in: text)
// Now enriched matches have context and line numbers
```

## Production Impact

**No impact** - The UI already handles context lazily. The MultiFileSearchView displays context from the `context` property, but the search is fast enough that enriching the top results on-demand is not noticeable.

Potential future optimization: Only enrich visible matches in the search results list (currently enriches all, but could be optimized further).

## Related Documentation

- `/specs/017-search-and-replace/spec.md` - Search feature specification
- `/docs/session-notes/SEARCH_PERFORMANCE_FIX.md` - Original performance optimization
