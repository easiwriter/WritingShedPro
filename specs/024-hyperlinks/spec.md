# Feature 024: Hyperlinks

**Status**: Draft  
**Priority**: Medium  
**Estimated Effort**: TBD  
**Dependencies**: 001-project-management-ios-macos, 005-text-formatting  
**Created**: 2026-01-10

## Overview

Add hyperlink support to WSP documents, enabling both internal links (within a document or project) and external links (URLs opening in browser). This feature is foundational for manual-style projects and enhances regular documents with cross-referencing capabilities.

## Requirements

### 1. Link Types

#### 1.1 External Links
- Link to any valid URL (http://, https://, mailto:)
- Tapping/clicking opens in system browser or mail client
- Visual indicator: underlined, distinct color (configurable in stylesheet?)

#### 1.2 Internal Links (Within Document)
- Link to headings within the same file
- Link to bookmarks/anchors (user-defined markers)
- Tapping scrolls to the target location

#### 1.3 Internal Links (Cross-File)
- Link to another file within the same project
- Link to a specific heading/bookmark in another file
- Tapping navigates to that file (and scrolls to target if specified)

### 2. User Interface

#### 2.1 Creating Links

**Option A: Toolbar Button**
- Add link icon to formatting toolbar
- Select text → tap link button → enter URL or choose internal target

**Option B: Context Menu**
- Select text → right-click/long-press → "Add Link..."

**Recommended**: Implement both for discoverability

#### 2.2 Link Dialog

```
┌─────────────────────────────────────┐
│ Add Link                            │
├─────────────────────────────────────┤
│ Display Text: [selected text     ]  │
│                                     │
│ Link Type: ○ External URL           │
│            ○ This Document          │
│            ○ Another File           │
├─────────────────────────────────────┤
│ [External URL field or picker]      │
│                                     │
│ OR                                  │
│                                     │
│ [Heading/file picker for internal]  │
├─────────────────────────────────────┤
│         [Cancel]    [Add Link]      │
└─────────────────────────────────────┘
```

#### 2.3 Editing/Removing Links
- Tap on linked text to show popover with:
  - Link destination (display)
  - "Edit Link" button
  - "Remove Link" button
  - "Open Link" button (for external)

#### 2.4 Visual Appearance
- Linked text: underlined, blue (or stylesheet-defined)
- Should be visually distinct but not distracting
- Color/style may be defined in stylesheet editor

### 3. Data Model

#### 3.1 Storage in AttributedString
Links stored as attributes on text ranges:
- `.link` attribute for external URLs (standard)
- Custom attribute for internal links with file/heading identifiers

#### 3.2 Internal Link Format
```swift
enum InternalLinkTarget {
    case heading(headingText: String)           // Within same file
    case bookmark(id: String)                   // User-defined anchor
    case file(fileID: UUID)                     // Another file in project
    case fileHeading(fileID: UUID, heading: String)  // Heading in another file
}
```

#### 3.3 Bookmark/Anchor System
- Users can insert named bookmarks at any point in text
- Bookmarks are invisible markers (or show small icon?)
- Can be targeted by internal links
- Useful for linking to specific paragraphs, not just headings

### 4. Link Navigation

#### 4.1 External Links
- iOS: Open in Safari (or in-app SFSafariViewController?)
- macOS: Open in default browser

#### 4.2 Internal Links - Same File
- Smooth scroll to target heading/bookmark
- Briefly highlight target (pulse/flash)

#### 4.3 Internal Links - Other File
- Navigate to target file in editor
- Scroll to heading/bookmark if specified
- Consider back navigation (how to return?)

### 5. Import/Export Considerations

#### 5.1 WSP Format
- Links must be preserved in .wsp export
- Internal links use file UUIDs - need resolution on import

#### 5.2 RTF Export
- External links: Preserve as standard RTF hyperlinks
- Internal links: Convert to external (file://) or strip?

#### 5.3 PDF Export
- External links: Embed as clickable PDF links
- Internal links (same file): PDF internal links (page/destination)
- Internal links (cross-file): May not be possible, strip or leave as text

#### 5.4 Plain Text Export
- Strip all link formatting
- Optionally append URL in brackets: `text [https://...]`

### 6. Edge Cases

#### 6.1 Broken Internal Links
- File deleted or heading changed
- Visual indicator for broken links (red underline? strikethrough?)
- "Broken Links" report in project tools?

#### 6.2 Link Text Editing
- Editing text within a link should preserve the link
- Deleting all link text removes the link

#### 6.3 Overlapping Links
- Prevent overlapping link ranges (link within a link)

### 7. Accessibility

- Links must be keyboard navigable
- VoiceOver should announce "link" and destination
- Focus indicators for keyboard navigation

## Implementation Notes

### Phase 1: External Links
1. Add link attribute support to text system
2. Toolbar button and context menu option
3. Link dialog (URL only initially)
4. Tap handling to open URLs
5. Visual styling

### Phase 2: Internal Links - Same File
1. Heading detection/indexing
2. Bookmark system (insert/delete/rename)
3. Link dialog with heading picker
4. Scroll-to-target navigation

### Phase 3: Internal Links - Cross-File
1. File picker in link dialog
2. Cross-file heading indexing
3. Navigation between files
4. Back button/history?

### Phase 4: Polish
1. Broken link detection
2. Link reports/management
3. Export support for all formats
4. Stylesheet integration

## Open Questions

1. Should bookmarks be visible in the document? (Small icon, hidden, toggleable?)
2. How to handle back navigation after following internal links?
3. Should there be a "Links" panel showing all links in document/project?
4. Link styling: hardcoded or stylesheet-configurable?
5. Should internal links work across projects? (Probably not initially)

## Future Considerations

- Bidirectional links (show what links TO this heading)
- Link autocomplete (type `[[` to search for headings)
- Wiki-style links `[[Heading Name]]` auto-converted to links
