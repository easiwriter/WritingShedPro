# Feature 029: Reference Metadata Persistence System

## Problem Statement

RTF format doesn't preserve custom NSTextAttachment subclasses. When a file is saved to RTF and then deserialized, custom `ReferenceAttachment` instances are lost, becoming generic attachments. This prevented reliable deletion of note references across all files in a project.

### Root Cause
- RTF serialization: Only preserves basic attachment metadata, not custom subclass data
- Deserialization: RTF is restored as generic `NSTextAttachment`, losing `ReferenceAttachment` properties (entryID, referenceType, etc.)
- Result: Deletion logic couldn't find and remove references from saved files

## Solution Architecture

### 1. Metadata Persistence (`BaseModels.swift`)
- Added `referenceMetadataData: Data?` field to `Version` model
- Stores reference metadata as JSON (survives RTF serialization)
- Encoded/decoded using the new `ReferenceMetadata` structure

### 2. Reference Metadata Structures (`ReferenceModels.swift`)

**ReferenceEntry (Codable)**
- Stores individual reference information:
  - `type: ReferenceType` - Type of reference (note, endnote, citation, etc.)
  - `entryID: UUID` - ID of the referenced entry (NoteEntry, CitationEntry, etc.)
  - `displayText: String` - Display text shown in marker
  - `displayNumber: Int` - Display number for notes/endnotes

**ReferenceMetadata (Codable)**
- Contains `var references: [ReferenceEntry]`
- Methods:
  - `add(_ entry: ReferenceEntry)` - Add a new reference
  - `removeReferences(to entryID: UUID)` - Remove all references to an entry
  - `encode() -> Data?` - Encode to JSON for storage
  - `decode(_ data: Data) -> ReferenceMetadata?` - Decode from JSON

### 3. Save-Time Extraction (`FileEditView.swift`)

**extractReferenceMetadata(from:) -> ReferenceMetadata**
- Enumerates all `ReferenceAttachment` instances in attributed string
- Creates `ReferenceEntry` for each attachment
- Returns complete `ReferenceMetadata` structure
- Called in `saveChanges()` for both textView and direct content paths

Result: When saving, metadata is extracted and stored alongside RTF content

### 4. Load-Time Restoration (`FileEditView.swift`)

**restoreReferenceAttachments(in:from:) -> NSAttributedString**
- Called after file content is loaded in `onAppear`
- Deserializes `ReferenceMetadata` from `referenceMetadataData`
- Enumerates attachments in loaded content
- Replaces generic attachments with properly typed `ReferenceAttachment` instances
- Uses metadata to set all properties: entryID, referenceType, displayText, displayNumber

Result: When opening a saved file, reference attachments are recreated from metadata

### 5. Deletion System (`NotesListView.swift`)

**deleteNote(_:)**
- Uses `referencingFileIDs` array already tracked by NoteEntry
- For each file containing references:
  - Iterates through all versions
  - Deserializes `referenceMetadataData`
  - Removes entries referencing the deleted note
  - Re-encodes metadata and saves
- Ensures deletion works across all files even when closed
- Notifies open file to remove markers in real-time

Result: Deleting a note removes its references from ALL project files permanently

## Key Benefits

1. **Reliable Deletion**: References removed across entire project, not just current file
2. **Persistent Storage**: Metadata survives RTF serialization/deserialization
3. **No Data Loss**: Even closed files have references properly removed
4. **App Store Compliant**: Users won't see orphaned markers after deletion or when reopening files

## Testing Checklist

- [ ] Create a note in File A and File B
- [ ] Close both files
- [ ] Delete the note from Notes list
- [ ] Reopen File A - markers should be gone
- [ ] Reopen File B - markers should be gone
- [ ] Create new note, reference it, save, close, reopen - markers still present
- [ ] Test with different reference types (endnotes, citations, etc.)
- [ ] Verify metadata is properly encoded/decoded in debug output

## Files Modified

1. **BaseModels.swift** - Added `referenceMetadataData: Data?` to Version
2. **ReferenceModels.swift** - Added ReferenceEntry and ReferenceMetadata structures
3. **FileEditView.swift** - Added extraction and restoration functions
4. **NotesListView.swift** - Updated deleteNote() to remove from all file metadata

## Related Issues Resolved

- Note deletion now works across all project files
- Orphaned reference markers eliminated
- Persistence of references across save/load cycles
- Foundation for other back matter reference types (citations, glossary, etc.)

## Design Principles Applied

- **Separation of Concerns**: Metadata stored separately from content (RTF)
- **Transitive Tracking**: referencingFileIDs enables efficient traversal
- **Graceful Degradation**: Old files without metadata work (no restoration, but no crashes)
- **Production Quality**: Proper serialization, not workarounds
