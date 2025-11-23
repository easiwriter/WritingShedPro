# Feature 015: Footnotes - Quick Start

## Quick Overview

Add footnote support to text documents with inline superscript markers and detailed footnote text.

## Key Components

1. **FootnoteModel** - SwiftData model storing footnote content
2. **FootnoteAttachment** - NSTextAttachment for superscript markers
3. **FootnoteManager** - Business logic for CRUD operations
4. **FootnoteDetailView** - View/edit single footnote
5. **FootnotesListView** - View all footnotes in document

## User Flow

1. User positions cursor in text
2. User taps "Add Footnote" button
3. User enters footnote text in dialog
4. Superscript number appears at cursor position
5. Tapping number shows footnote detail
6. Footnotes auto-renumber when added/deleted

## Technical Approach

- Similar architecture to Feature 014 (Comments)
- Use NSTextAttachment for inline markers
- Store content in SwiftData
- Serialize attachments with document
- Auto-renumber on changes

## Visual Design

```
Main text with footnote¹ continues here...

[Tap superscript ¹]
↓
┌─────────────────────────┐
│ Footnote 1              │
│                         │
│ This is the footnote    │
│ text content.           │
│                         │
│ [Edit] [Delete]         │
└─────────────────────────┘
```

## Key Differences from Comments

| Aspect | Comments | Footnotes |
|--------|----------|-----------|
| Marker | Blue bubble icon | Superscript number |
| Purpose | Review/feedback | Reference/citation |
| Display | Inline icon | Superscript text |
| Numbering | None | Auto-numbered |
| Export | Optional | Always included |

## Next Steps

1. Complete `spec.md` with user requirements
2. Implement Phase 1 (Data Model)
3. Implement Phase 2 (Manager)
4. Build UI components
5. Integrate with FileEditView
6. Add export support
