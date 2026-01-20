# Copy/Paste References - Known Limitation

**Status:** Known Limitation / Feature Request  
**Date Identified:** 2025-01-19  
**Severity:** Medium (affects workflow but doesn't corrupt data)

## Issue Description

When copying text containing reference attachments (endnotes, citations, glossary entries, etc.) and pasting it into another document within the same project, the reference metadata is lost. The U+FFFC placeholder characters are pasted, but the underlying `ReferenceAttachment` objects are not preserved.

### Current Behavior
1. User selects text containing 1+ references
2. User copies selection (Cmd+C)
3. User opens another document and pastes (Cmd+V)
4. Pasted text shows U+FFFC characters but references are missing
5. Reference IDs, types, and metadata not transferred

### Expected Behavior
1. Copy should preserve reference metadata in pasteboard
2. Paste should reconstruct ReferenceAttachments from metadata
3. References should be fully functional in destination document with updated reference counts

## Root Cause

UITextView's default copy/paste behavior:
- Copies U+FFFC (object replacement character) placeholder
- Does not serialize custom NSTextAttachment subclass objects
- ReferenceAttachment Swift objects are not stored in pasteboard
- Pasted text has no metadata to reconstruct the references

## Implementation Required

### Step 1: Custom Pasteboard Type
- Create custom UIPasteboard type: `"com.writingshedpro.references"`
- Store serialized reference metadata (UUIDs, types, tags/numbers)

### Step 2: Override Copy
- Intercept `copy(_:)` in CustomTextView
- Extract all ReferenceAttachments in selected range
- Store metadata in custom pasteboard type alongside standard RTF

### Step 3: Override Paste
- Intercept `paste(_:)` in CustomTextView
- Detect pasted U+FFFC characters
- Look up reference metadata from custom pasteboard type
- Reconstruct ReferenceAttachments with proper type/ID information
- Increment reference counts for pasted references

### Step 4: Cross-Document Handling
- When pasting into different document, ensure reference counts incremented
- May need to create ReferenceDeleteCommand companions for pasted references

## Complexity Estimate
- Medium (2-3 hours of implementation + testing)
- Involves: pasteboard handling, attachment reconstruction, reference counting

## Affected Components
- `FormattedTextEditor.swift` - CustomTextView class
- `ReferenceAttachment.swift` - May need Codable/serialization support
- `FileEditView.swift` - Reference count management

## Workaround
- Currently: none (references are lost on paste)
- Users must re-create references or manually adjust reference counts

## Related Issues
- None currently identified

## Notes
- Images already handle this correctly via RTFD format
- Footnotes/Comments may have similar limitation (investigate)
- Should test inter-app paste (paste into Notes, other text editors) - expected to not work
