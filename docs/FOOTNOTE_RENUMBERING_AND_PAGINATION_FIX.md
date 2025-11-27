# Footnote Issues Fixed

**Date:** 25 November 2025  
**Issues Fixed:**
1. Footnote markers not renumbering when inserting earlier footnote
2. Text on page 2 appearing underneath where footnotes would be positioned

---

## Issue 1: Footnote Markers Not Updating After Insertion

### Problem
When inserting a footnote earlier in the document (e.g., at position 176), the existing footnote marker at position 679 still showed "1" instead of being renumbered to "2".

**Console Evidence:**
```
📝📖 DECODE footnote at 176: id=81CBB142..., number=1
📝📖 DECODE footnote at 679: id=C4ED7FB8..., number=1  ← Should be 2!
```

### Root Cause
The `FootnoteManager.renumberFootnotes()` method correctly updated the FootnoteModel numbers in the SwiftData database, but the `FootnoteAttachment` objects embedded in the NSAttributedString were not being refreshed. The text view displayed cached attachment images with old numbers.

### Solution

#### 1. Added Notification System
**File:** `FootnoteManager.swift`

Added notification name:
```swift
extension Notification.Name {
    static let footnoteNumbersDidChange = Notification.Name("footnoteNumbersDidChange")
}
```

Post notification after renumbering (3 locations):
- After `createFootnote()` → renumber → **post notification**
- After `moveFootnoteToTrash()` → renumber → **post notification**  
- After `restoreFootnote()` → renumber → **post notification**

```swift
// Post notification so views can update footnote attachment numbers
NotificationCenter.default.post(
    name: .footnoteNumbersDidChange,
    object: nil,
    userInfo: ["versionID": version.id.uuidString]
)
```

#### 2. Added Notification Handler in FileEditView
**File:** `FileEditView.swift`

Listen for notification:
```swift
.onReceive(NotificationCenter.default.publisher(for: .footnoteNumbersDidChange)) { notification in
    handleFootnoteNumbersChanged(notification)
}
```

Handler implementation:
```swift
private func handleFootnoteNumbersChanged(_ notification: Notification) {
    guard let versionIDString = notification.userInfo?["versionID"] as? String,
          let notifiedVersionID = UUID(uuidString: versionIDString),
          let currentVersion = file.currentVersion,
          notifiedVersionID == currentVersion.id else {
        return
    }
    
    print("🔢 Updating footnote attachment numbers for our version")
    updateFootnoteAttachmentNumbers()
}
```

Update attachment numbers:
```swift
private func updateFootnoteAttachmentNumbers() {
    let mutableContent = NSMutableAttributedString(attributedString: attributedContent)
    var needsUpdate = false
    
    // Enumerate all footnote attachments
    mutableContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableContent.length)) { value, range, stop in
        guard let attachment = value as? FootnoteAttachment else { return }
        
        // Look up current number from database
        if let footnote = FootnoteManager.shared.getFootnote(id: attachment.footnoteID, context: modelContext) {
            if attachment.number != footnote.number {
                print("🔢 Updating attachment \(attachment.footnoteID) from \(attachment.number) to \(footnote.number)")
                attachment.number = footnote.number  // Triggers image cache clear
                needsUpdate = true
            }
        }
    }
    
    if needsUpdate {
        attributedContent = mutableContent  // Trigger view refresh
    }
}
```

### How It Works
1. User inserts footnote at position 176 (before existing footnote at 679)
2. FootnoteManager creates footnote, saves, calls `renumberFootnotes()`
3. Database updated: position 176 = number 1, position 679 = number 2
4. FootnoteManager posts `footnoteNumbersDidChange` notification
5. FileEditView receives notification, checks version ID matches
6. `updateFootnoteAttachmentNumbers()` enumerates all FootnoteAttachment objects
7. For each attachment, looks up current number from database
8. If number changed, updates `attachment.number` (clears cached image)
9. Updates `attributedContent` to trigger view refresh
10. FootnoteAttachment regenerates images with correct numbers

---

## Issue 2: Text Overlapping Footnote Area on Page 2

### Problem
Looking at the screenshots:
- **Page 1:** Text ends correctly, footnotes at bottom ✅
- **Page 2:** Overflow text appears, but some text is **underneath** where footnotes would be positioned ❌

The pagination was reserving space for footnotes on **every page in the look-ahead range**, not just pages where footnotes actually appear.

### Root Cause
The `calculateFootnoteAwareLayout()` method used a "look-ahead" approach:

```swift
// BEFORE: Too conservative
let expectedPageLength = Int(containerSize.height * 1.5)
let lookAheadRange = NSRange(location: characterIndex, length: min(expectedPageLength, ...))

let hasFootnotesInRange = allFootnotes.contains { footnote in
    NSLocationInRange(footnote.characterPosition, lookAheadRange)
}
```

This checked if footnotes existed **anywhere in the next ~1.5 pages**, not specifically on the current page being laid out. So:
- Page 0: Has footnotes at 176 and 679 → reserves 250pt ✅
- Page 1: Look-ahead detects footnotes from page 0 → **reserves 250pt unnecessarily** ❌
- Result: Page 1 has reduced text area but no footnotes → text overlaps footnote space

### Solution

Changed to a **two-pass iterative approach**:

**File:** `PaginatedTextLayoutManager.swift`

#### Pass 1: Initial Layout (Full Height)
```swift
// Calculate initial pagination without footnote adjustment
var initialPageInfos: [PageInfo] = []

while characterIndex < totalCharacters || initialPageInfos.isEmpty {
    let container = NSTextContainer(size: containerSize)  // Full height
    // ... calculate page breaks
    initialPageInfos.append(pageInfo)
}
```

This determines **approximate page breaks** using full page height.

#### Pass 2: Refine Pages With Footnotes
```swift
// Recalculate pages that have footnotes with reduced container height
var finalPageInfos: [PageInfo] = []

for initialPage in initialPageInfos {
    // Check if THIS SPECIFIC PAGE has footnotes
    let footnotesOnPage = allFootnotes.filter { footnote in
        NSLocationInRange(footnote.characterPosition, initialPage.characterRange)
    }
    
    // Determine container size for THIS page
    let pageContainerSize: CGSize
    if !footnotesOnPage.isEmpty {
        // Page has footnotes - reduce height
        pageContainerSize = CGSize(
            width: containerSize.width,
            height: containerSize.height - maxFootnoteReserve  // 250pt
        )
    } else {
        // No footnotes - use full height
        pageContainerSize = containerSize
    }
    
    // Recalculate with adjusted size
    let container = NSTextContainer(size: pageContainerSize)
    // ... calculate final page breaks
}
```

### How It Works Now

**Example: Document with 2 footnotes on page 1**

#### Pass 1: Initial Layout (Full Height = 648pt)
```
Page 0: chars 0-1200   (footnotes at 176, 679 detected)
Page 1: chars 1200-2400 (no footnotes)
Page 2: chars 2400-3000 (no footnotes)
```

#### Pass 2: Refine with Footnote Awareness
```
Page 0: 
  - Has 2 footnotes → reduce height to 398pt (648 - 250)
  - Recalculate: chars 0-900 (less text fits)
  
Page 1:
  - No footnotes → full height 648pt
  - Recalculate: chars 900-2100 (more text fits)
  
Page 2:
  - No footnotes → full height 648pt  
  - Recalculate: chars 2100-3000
```

**Result:**
- Page 0: Text ends at 900, footnotes at bottom (250pt reserved) ✅
- Page 1: Text continues from 900-2100, **no space reserved** ✅
- Page 2: Text continues from 2100, **no space reserved** ✅

### Debug Output
```
📐 Page 0: Found 2 footnotes, reducing container height by 250.0pt
📐 Page 1: No footnotes, using full container height
📐 Page 2: No footnotes, using full container height
```

---

## Testing

### Test Case 1: Footnote Renumbering
1. Create document with footnote at position 500
2. Insert second footnote at position 200 (before first)
3. **Expected:** First footnote shows "1", second shows "2"
4. **Verify:** Console shows `🔢 Updating attachment ... from 1 to 2`

### Test Case 2: Pagination Accuracy  
1. Create document with 2 footnotes on first page
2. Add enough text to flow to second page
3. **Expected:**
   - Page 1: Text ends early, footnotes at bottom
   - Page 2: Overflow text uses **full page height**, no wasted space
4. **Verify:** Console shows `📐 Page 1: No footnotes, using full container height`

### Test Case 3: Multiple Pages with Footnotes
1. Create document with footnotes on pages 1, 3, and 5
2. **Expected:**
   - Pages 1, 3, 5: Reduced text area
   - Pages 2, 4, 6: Full text area
3. **Verify:** Each page only reserves space if it has footnotes

---

## Files Modified

### FootnoteManager.swift
- Added `Notification.Name.footnoteNumbersDidChange`
- Post notification after `createFootnote()`, `moveFootnoteToTrash()`, `restoreFootnote()`

### FileEditView.swift
- Added `.onReceive()` listener for `footnoteNumbersDidChange`
- Added `handleFootnoteNumbersChanged()` handler
- Added `updateFootnoteAttachmentNumbers()` to sync attachment numbers with database

### PaginatedTextLayoutManager.swift
- Rewrote `calculateFootnoteAwareLayout()` with two-pass approach
- Pass 1: Calculate initial page breaks (full height)
- Pass 2: Recalculate only pages with footnotes (reduced height)
- Added debug logging for footnote detection per page

---

## Compilation Status
✅ **No errors** - Ready for testing

---

## Next Steps

1. **Test footnote renumbering**
   - Insert footnotes in different orders
   - Delete footnotes and verify renumbering
   - Restore from trash and verify renumbering

2. **Test pagination accuracy**
   - Create documents with varying footnote distributions
   - Verify no overlap on any page
   - Verify efficient space usage on pages without footnotes

3. **Edge cases (Task 6)**
   - Footnotes exceeding 250pt reserved space
   - Very long footnotes spanning multiple pages
   - Page with many small footnotes

4. **Continue with Task 4**
   - Implement endnote mode
   - Add display mode toggle UI

---

## Summary

**Issue 1 - Footnote Renumbering:**
Fixed by adding a notification system that alerts FileEditView when footnote numbers change, triggering an update of the FootnoteAttachment objects in the attributed string.

**Issue 2 - Pagination Overlap:**
Fixed by changing from a look-ahead approach to a precise two-pass layout calculation that only reserves space on pages where footnotes actually appear, ensuring pages without footnotes use their full height.

Both fixes maintain the integrity of the footnote system while ensuring professional typesetting standards are met.
