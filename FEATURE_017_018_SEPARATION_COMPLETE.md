# Feature 017 & 018: Scope Separation Complete

## Summary
Successfully separated the original ambitious Feature 017 requirements into two manageable features:

### Feature 017: Footnotes (Simplified)
**Scope**: Basic footnote functionality with simple sequential numbering
- Sequential numbering: 1, 2, 3...
- Superscript markers with button styling
- Document-level footnote/endnote mode toggle
- Standard separator (1.5-inch line, 10pt space above)
- Professional overflow rules (min 2 lines body text, continuation indicators)
- Toolbar button with `number.circle` icon
- "Footnotes..." menu item for list view

**Status**: Specification complete, ready for implementation
**Estimate**: 16-23 hours

### Feature 018: Automatic Paragraph Numbering (New)
**Scope**: Comprehensive automatic numbering system for all paragraph styles
- Hierarchical numbering (1, 1.1, 1.2, 2, 2.1)
- Multiple formats: Numeric, Alphabetic (upper/lower), Roman (upper/lower), Bullets
- Format adornments: Plain, Period, Parentheses, Right Paren, Dashes, Custom
- Per-style numbering configuration
- Nested numbering within parent styles
- Bulleted and numbered list support
- Auto-increment, auto-reset, reordering updates

**Status**: Complete specification created
**Estimate**: 44-58 hours

## What Changed

### Original Feature 017
Initially contained requirements for a full auto-numbering system:
- All numbering formats (numeric, alphabetic, roman, bullets)
- All adornments (period, parentheses, dashes, custom)
- Per-style configuration
- Hierarchical numbering
- List support

### Simplified Feature 017
Now focused only on basic footnotes:
- Simple sequential numbering only (1, 2, 3...)
- Footnote/endnote mode
- Pagination display
- Professional overflow handling

### New Feature 018
Contains all the advanced numbering capabilities:
- All complex numbering formats
- Style sheet integration
- Full hierarchical support
- List management
- Counter tracking system

## Files Created

### Feature 018 Specification
✅ `/specs/018-auto-numbering/spec.md` - Complete feature specification
✅ `/specs/018-auto-numbering/data-model.md` - Data structures and models
✅ `/specs/018-auto-numbering/plan.md` - 7-phase implementation plan (44-58 hours)
✅ `/specs/018-auto-numbering/research.md` - Industry standards and technical research
✅ `/specs/018-auto-numbering/tasks.md` - Detailed development backlog
✅ `/specs/018-auto-numbering/quickstart.md` - Quick reference for users and developers

### Feature 017 Updates
✅ Updated `/specs/017-footnotes/spec.md` - Simplified overview, added comprehensive sections
- Added "Deferred to Feature 018" note
- Added 8 user stories
- Added technical requirements
- Added UI/UX requirements
- Added testing requirements
- Added 10 questions (5 resolved, 5 open)

## Key Decisions

### 1. Feature Split Rationale
**Question**: Should we implement full auto-numbering or just basic footnotes?
**Answer**: Split into two features
**Reason**: Full auto-numbering affects entire architecture (all paragraph styles, style sheets, document structure), while basic footnotes are self-contained

### 2. Endnote Mode
**Question**: Document-level or paragraph-level setting?
**Answer**: Document-level setting
**Reason**: Simpler user experience, clearer mental model, sufficient for first version

### 3. Marker Display
**Question**: How to display footnote markers?
**Answer**: Superscript numbers inline with button styling
**Reason**: Industry standard, familiar to users, clear visual distinction

### 4. Overflow Rules
**Question**: How to handle footnotes filling a page?
**Answer**: Professional typesetting standards
**Reason**: Best user experience, matches professional publishing expectations

### 5. Separator Style
**Question**: Standard or customizable?
**Answer**: Industry standard (1.5-inch line, 10pt space above)
**Reason**: Professional appearance, sufficient for first version

### 6. Bulleted Lists
**Question**: Include in Feature 017 or 018?
**Answer**: Feature 018
**Reason**: Requires full numbering system infrastructure

### 7. Default Format
**Question**: What format for first version?
**Answer**: Simple sequential numbering (1, 2, 3...)
**Reason**: Most common use case, simplest to implement

### 8. Implementation Priority
**Question**: Which features in first version?
**Answer**: Just priorities 1, 2, 3:
1. Basic footnote insertion and display
2. Footnote/endnote mode toggle
3. Pagination display with professional overflow
**Reason**: Core functionality first, advanced features later

## Open Questions for Feature 017

### Resolved
1. ✅ Numbering formats: Deferred to Feature 018
2. ✅ Endnote mode: Document-level setting
3. ✅ Marker style: Inline superscript with button styling
4. ✅ Overflow handling: Professional typesetting standards
5. ✅ Separator: Industry standard (1.5" line, 10pt space)

### Still Open
6. ⚠️ Should footnote content support rich text formatting (bold, italic)?
7. ⚠️ Maximum length for footnote text?
8. ⚠️ Should footnotes support images or only text?
9. ⚠️ Keyboard shortcut for inserting footnote?
10. ⚠️ Should deleted footnotes go to "trash" or permanent delete?

## Implementation Sequence

### Recommended Order
1. **Feature 017**: Footnotes (16-23 hours)
   - Self-contained feature
   - Builds on proven patterns (Feature 014 Comments)
   - Delivers immediate user value
   
2. **Feature 018**: Auto-Numbering (44-58 hours)
   - More complex, affects multiple systems
   - Can benefit from footnote experience
   - Foundation for future features (Table of Contents, Outlining)

### Dependencies
- **Feature 017** depends on:
  - Feature 014 (Comments) - proven patterns
  - Feature 005 (Text Formatting) - text system
  - AttributedStringSerializer - existing serialization
  
- **Feature 018** depends on:
  - Feature 005 (Text Formatting) - paragraph styles
  - Feature 003 (Text File Creation) - document structure
  - Feature 017 (Footnotes) - consumer of basic numbering

## Architecture Notes

### Feature 017: Footnotes
```
FootnoteModel (SwiftData)
├── Simple int counter (1, 2, 3...)
├── Character position tracking
└── Content storage

FootnoteAttachment (NSTextAttachment)
├── Superscript rendering
└── Button styling

FootnoteManager
├── CRUD operations
├── Auto-renumbering
└── Position tracking

UI Components
├── DetailView (edit single footnote)
├── ListView (browse all footnotes)
└── Toolbar button
```

### Feature 018: Auto-Numbering
```
NumberingManager (Singleton)
├── DocumentNumberingState (SwiftData)
│   └── Counter tracking per style/level
├── Format Converters
│   ├── toNumeric()
│   ├── toAlphabetic()
│   ├── toRoman()
│   └── bulletForLevel()
└── Adornment Formatter

ParagraphStyle Extension
├── NumberingSettings
│   ├── Format (numeric, alphabetic, roman, bullet)
│   ├── Adornment (plain, period, parentheses, etc.)
│   ├── Starting number
│   ├── Reset behavior
│   └── Custom prefix/suffix
└── Hierarchical relationships

UI Components
├── Style Editor (numbering configuration)
├── Toolbar buttons (list creation)
└── Number preview
```

## Benefits of Separation

### 1. Reduced Complexity
- Each feature has clear, focused scope
- Easier to understand, implement, and test
- Less risk of bugs

### 2. Incremental Delivery
- Users get footnotes sooner
- Can gather feedback before auto-numbering
- Adjust Feature 018 based on Feature 017 experience

### 3. Better Testing
- Smaller test surface per feature
- Easier to isolate issues
- More thorough coverage

### 4. Clearer Architecture
- Each feature has distinct responsibility
- Minimal coupling between features
- Easier to maintain

### 5. Flexible Scheduling
- Can prioritize based on user needs
- Can defer Feature 018 if needed
- Independent release cycles

## Next Steps

### Immediate
1. Answer 5 open questions for Feature 017
2. Review and approve specifications
3. Commit Feature 018 specification to repository

### Feature 017 Implementation
1. Phase 1: Core Data Model (4-6 hours)
2. Phase 2: Footnote Manager (4-6 hours)
3. Phase 3: UI Components (3-4 hours)
4. Phase 4: FileEditView Integration (2-3 hours)
5. Phase 5: Footnote Management (2-3 hours)
6. Phase 6: Export Support (3-4 hours)
7. Testing & Polish (2-3 hours)

### Feature 018 Planning
1. Review specification with stakeholders
2. Prioritize phases (can we defer some?)
3. Identify any missing requirements
4. Plan integration with other features
5. Schedule implementation

## Timeline

**Feature 017**: 16-23 hours (~2-3 weeks)
**Feature 018**: 44-58 hours (~6-8 weeks)

**Total**: 60-81 hours (~8-11 weeks)

vs. Original Combined Feature: Would have been ~80-100 hours with higher risk and complexity.

## Success Metrics

### Feature 017
- ✅ Specifications complete and reviewed
- ✅ Scope clearly defined
- ✅ Open questions identified
- ⏳ Implementation ready to start

### Feature 18
- ✅ Complete specification created
- ✅ Architecture designed
- ✅ Implementation plan detailed
- ✅ Research completed
- ⏳ Ready for review and approval

## Conclusion

Successfully decomposed an overly ambitious feature into two manageable, well-scoped features:
- **Feature 017**: Basic footnotes (ready to implement)
- **Feature 018**: Comprehensive auto-numbering (fully planned)

Each feature now has:
- Clear scope and boundaries
- Complete specification
- Detailed implementation plan
- Realistic time estimates
- Identified dependencies
- Success criteria

Both features follow proven patterns from existing codebase (Feature 014 Comments, Feature 005 Text Formatting) and maintain architectural consistency.

**Status**: Ready to proceed with Feature 017 implementation or answer open questions.
