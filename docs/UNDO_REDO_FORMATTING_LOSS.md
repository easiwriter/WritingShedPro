# Undo/Redo Formatting Loss Issue

**Date**: November 27, 2025  
**Issue**: Undo/redo loses formatting  
**Status**: 🔴 CRITICAL - Formatting destroyed on undo/redo

## The Problem

When you:
1. Paste formatted text (with different fonts/sizes)
2. Undo
3. Redo

The text comes back but **loses all formatting** - everything becomes body style.

## Root Cause

**The undo/redo system was designed for plain text (Phase 004) but is now being used with rich text (Phase 005), and they're incompatible.**

###  The Mismatch

**When text is pasted:**
```swift
// handleAttributedTextChange() receives FULL attributed text
func handleAttributedTextChange(_ newAttributedText: NSAttributedString) {
    let newContent = newAttributedText.string  // ← Extract PLAIN text only
    
    // Create undo command from PLAIN text diff
    if let change = TextDiffService.diff(from: previousContent, to: newContent) {
        let command = TextDiffService.createCommand(from: change, file: file)
        undoManager.execute(command)  // ← Command stores PLAIN text only
    }
    
    // Save FULL attributed text to model
    file.currentVersion?.attributedContent = newAttributedText  // ← Formatting saved HERE
}
```

**When undo is performed:**
```swift
func performUndo() {
    undoManager.undo()  // ← Command restores PLAIN text only via updateContent()
    
    // Try to reload from model
    let newAttributedContent = file.currentVersion?.attributedContent
    // But this returns the AFTER-paste content, not BEFORE-paste!
}
```

## The Flow

### 1. Initial State
- Model has content: `"Hello"`
- Both `content` and `attributedContent` are in sync

### 2. User Pastes Formatted Text
- Text view receives: `"Hello [FORMATTED TEXT]"` with rich formatting
- `handleAttributedTextChange()` is called with full `NSAttributedString`
- **Undo command created**: Stores only plain text `"Hello"` → `"Hello [TEXT]"`
- **Model updated**: `attributedContent` = full formatted version
- **Model updated**: `content` = plain text only

### 3. User Undos
- `undoManager.undo()` calls `TextInsertCommand.undo()`
- Command calls `file.currentVersion?.updateContent("Hello")`
- `updateContent()` sets `content = "Hello"` (plain text)
- `performUndo()` tries to reload `attributedContent` from model
- **Problem**: Model still has POST-paste `attributedContent`!
- The undo command only updated `content`, not `attributedContent`

### 4. User Redos  
- `undoManager.redo()` calls `TextInsertCommand.execute()`
- Command calls `file.currentVersion?.updateContent("Hello [TEXT]")`
- `updateContent()` sets `content = "Hello [TEXT]"` (plain text)
- `performRedo()` tries to reload `attributedContent` from model
- **Problem**: Model's `attributedContent` is out of sync with `content`
- When `attributedContent` getter sees `content` changed, it returns plain text version

## Why My Recent Fix Made It Worse

Before my fix:
- `updateContent()` only updated `content`
- `attributedContent` was never updated
- Undo would fail completely (return empty)

After my fix:
- `updateContent()` updates both `content` AND `attributedContent`
- But it creates PLAIN `attributedContent` from the plain text
- **Result**: All formatting is lost!

## The Real Solution

The undo/redo command system needs to be upgraded to store and restore `NSAttributedString`, not just plain `String`.

### Required Changes

#### 1. Update Command Classes

**Currently:**
```swift
final class TextInsertCommand: UndoableCommand {
    let text: String  // Plain text only
    
    func execute() {
        file.currentVersion?.updateContent(newContent)  // Plain text
    }
}
```

**Should be:**
```swift
final class TextInsertCommand: UndoableCommand {
    let text: String  // Keep for compatibility
    let attributedText: NSAttributedString?  // NEW: Store formatting
    
    func execute() {
        if let attributed = attributedText {
            file.currentVersion?.attributedContent = attributed
        } else {
            file.currentVersion?.updateContent(newContent)
        }
    }
}
```

#### 2. Update TextDiffService

**Currently:**
```swift
static func diff(from: String, to: String) -> TextChange?
static func createCommand(from: TextChange, file: TextFile) -> UndoableCommand
```

**Should be:**
```swift
static func diff(
    from: NSAttributedString,
    to: NSAttributedString
) -> AttributedTextChange?

static func createCommand(
    from: AttributedTextChange,
    file: TextFile
) -> UndoableCommand
```

#### 3. Update handleAttributedTextChange

**Currently:**
```swift
let newContent = newAttributedText.string  // Lose formatting HERE
if let change = TextDiffService.diff(from: previousContent, to: newContent) {
```

**Should be:**
```swift
// Keep previous attributed content, not just string
if let change = TextDiffService.diff(
    from: previousAttributedContent,
    to: newAttributedText
) {
```

## Temporary Workaround

The current `updateContent()` implementation:
```swift
func updateContent(_ newContent: String) {
    self.content = newContent
    // Does NOT update attributedContent - keeps model in inconsistent state
}
```

This is the "least bad" option until proper fix is implemented:
- Undo will restore plain text
- User can see the text came back
- But formatting is lost
- Better than redo being completely broken

## Impact

**What Works:**
- ✅ Typing with formatting
- ✅ Applying bold/italic/underline
- ✅ Pasting formatted text (initially)

**What's Broken:**
- ❌ Undo after pasting formatted text → loses formatting
- ❌ Redo after undo → loses formatting
- ❌ Any undo/redo involving formatted text

## Timeline

- **Phase 003**: Plain text only - undo/redo works fine
- **Phase 004**: Undo/redo implemented for plain text
- **Phase 005**: Rich text added, but undo/redo NOT updated
- **November 27, 2025**: Bug discovered - redo completely broken
- **Today**: Fixed redo to work, but formatting lost

## Next Steps

### Option 1: Full Fix (Recommended but Major Work)
- Upgrade all undo/redo commands to work with `NSAttributedString`
- Update `TextDiffService` to diff attributed strings
- Preserve formatting through undo/redo operations
- **Effort**: Several hours, affects multiple files
- **Risk**: Medium - complex changes to core system

### Option 2: Hybrid Approach (Faster)
- Keep commands as plain text
- Store "snapshots" of `attributedContent` before each change
- On undo/redo, restore from snapshot instead of rebuilding
- **Effort**: 1-2 hours
- **Risk**: Low - isolated changes

### Option 3: Document Limitation (Quick)
- Leave as-is with formatting loss
- Document that undo/redo doesn't preserve formatting
- Add to known issues
- **Effort**: 10 minutes
- **Risk**: None - but users lose formatting

## Recommendation

**Option 2 (Hybrid Approach)** is recommended:
1. Add `@State private var attributedContentHistory: [NSAttributedString]`
2. Save snapshot before each change
3. On undo/redo, restore from snapshot
4. This preserves formatting without rewriting command system
5. Can be done in 1-2 hours with low risk

Would you like me to implement Option 2?
