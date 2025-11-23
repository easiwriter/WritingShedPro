# Test Compilation Fixes

**Date**: 2025-11-20  
**Status**: ✅ FIXED

## Issues Fixed

### CommentAttachmentTests.swift

**Issue 1: CGFloat Optional Comparison**
- **Lines**: 51, 52, 72, 73
- **Error**: `Cannot convert value of type 'CGFloat?' to expected argument type 'CGFloat'`
- **Cause**: XCTAssertEqual expects non-optional values for accuracy comparison
- **Fix**: Changed `image?.size.width` to `image?.size.width ?? 0` to unwrap optional before comparison

**Issue 2: Incorrect attachmentBounds Method Signature**
- **Lines**: 108, 126, 134, 243, 251
- **Error**: Extra argument 'textContainer' in call
- **Cause**: Tests were calling with old signature that had extra `textContainer:` parameter
- **Actual Signature**: `attachmentBounds(for:proposedLineFragment:glyphPosition:characterIndex:)`
- **Fix**: Removed duplicate `textContainer: nil` parameter from all calls

### CommentInsertionHelperTests.swift

**Issue 3: Parameter Order**
- **Lines**: 423, 441
- **Error**: `Argument 'in' must precede argument 'at'`
- **Cause**: Tests used wrong parameter order for `commentAttachment` method
- **Old**: `commentAttachment(at: position, in: text)`
- **New**: `commentAttachment(in: text, at: position)`
- **Fix**: Swapped parameter order to match actual method signature

**Issue 4: Tuple Access**
- **Lines**: 483, 489, 490, 491
- **Error**: `Value of tuple type '(CommentAttachment, Int)' has no member 'attachment'/'position'`
- **Cause**: Tests tried to access tuple elements as named properties
- **Return Type**: `[(CommentAttachment, Int)]` (unnamed tuple)
- **Fix**: 
  - Changed `$0.attachment` to `$0.0` (first tuple element)
  - Changed `allAttachments[i].position` to `allAttachments[i].1` (second tuple element)

## Changes Summary

### File: CommentAttachmentTests.swift
1. **Line 51-52**: Added `?? 0` to unwrap optional CGFloat
2. **Line 72-73**: Added `?? 0` to unwrap optional CGFloat
3. **Line 108**: Removed extra `textContainer: nil` parameter
4. **Line 126**: Removed extra `textContainer: nil` parameter
5. **Line 134**: Removed extra `textContainer: nil` parameter
6. **Line 243**: Removed extra `textContainer: nil` parameter
7. **Line 251**: Removed extra `textContainer: nil` parameter

### File: CommentInsertionHelperTests.swift
1. **Line 423**: Changed `commentAttachment(at: 5, in: withComment)` to `commentAttachment(in: withComment, at: 5)`
2. **Line 441**: Changed `commentAttachment(at: 0, in: withComment)` to `commentAttachment(in: withComment, at: 0)`
3. **Line 483**: Changed `$0.attachment.commentID` to `$0.0.commentID`
4. **Line 489-491**: Changed `allAttachments[i].position` to `allAttachments[i].1`

## Method Signatures Reference

### CommentAttachment
```swift
override func attachmentBounds(
    for textContainer: NSTextContainer?,
    proposedLineFragment lineFrag: CGRect,
    glyphPosition position: CGPoint,
    characterIndex charIndex: Int
) -> CGRect
```

### CommentInsertionHelper
```swift
static func commentAttachment(
    in attributedText: NSAttributedString,
    at position: Int
) -> CommentAttachment?

static func allCommentAttachments(
    in attributedText: NSAttributedString
) -> [(CommentAttachment, Int)]  // Returns unnamed tuple
```

## Testing Verification

All test compilation errors resolved:
✅ CommentAttachmentTests.swift compiles
✅ CommentInsertionHelperTests.swift compiles
✅ No remaining compilation errors in test target
✅ Ready for test execution

## Root Cause Analysis

These errors occurred because:
1. Tests were written against an earlier API design
2. Method signatures were refined during implementation
3. Tests weren't updated to match final signatures
4. Swift's strict type checking caught all mismatches

## Additional Fixes: CommentManagerTests.swift

**Issue 5: Wrong Parameter Label**
- **Lines**: 126, 134, 168, 199, 218, 257, 276, 282, 310, 358, 411, 458, 459, 501, 528, 529
- **Error**: `Incorrect argument label in call (have 'for:context:', expected 'forTextFile:context:')`
- **Cause**: Tests used old parameter name `for:` instead of `forTextFile:`
- **Fix**: Global replacement of `getComments(for:` → `getComments(forTextFile:`
- **Method**: Used sed command for batch replacement

**Issue 6: Missing Method**
- **Lines**: 349, 402, 449, 493
- **Error**: `Value of type 'CommentManager' has no member 'updateCommentPositions'`
- **Cause**: Tests referenced old method name that was renamed
- **Old API**: `updateCommentPositions(for:afterPosition:delta:context:)`
- **New API**: `updatePositionsAfterEdit(textFileID:editPosition:lengthDelta:context:)`
- **Fix**: Updated all 4 calls to use new method signature with correct parameter names

### CommentManager API Reference

```swift
// Query methods
func getComments(forTextFile textFileID: UUID, context: ModelContext) -> [CommentModel]
func getActiveComments(forTextFile textFileID: UUID, context: ModelContext) -> [CommentModel]
func getResolvedComments(forTextFile textFileID: UUID, context: ModelContext) -> [CommentModel]
func getCommentCount(forTextFile textFileID: UUID, includeResolved: Bool, context: ModelContext) -> Int

// Position management
func updatePositionsAfterEdit(
    textFileID: UUID,
    editPosition: Int,
    lengthDelta: Int,
    context: ModelContext
)
```

## Total Fixes Summary

**CommentAttachmentTests.swift**: 8 errors fixed
**CommentInsertionHelperTests.swift**: 6 errors fixed
**CommentManagerTests.swift**: 20 errors fixed

**Total**: 34 compilation errors resolved ✅

## Prevention

To prevent similar issues:
- Run tests frequently during development
- Update tests immediately when changing API signatures
- Use compiler warnings as guidance for test updates
- Consider using test-driven development (TDD) approach
- Use automated tools (sed, scripts) for batch parameter renames
