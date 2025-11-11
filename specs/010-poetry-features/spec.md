# Feature Specification: Poetry-Specific Features

**Feature ID**: 009  
**Created**: 9 November 2025  
**Status**: Planning / Future Enhancement  
**Priority**: Medium  
**Dependencies**: Core text editing features

---

## Overview

Specialized features and tools designed specifically for poetry writing, including formatting, structure, and poetry-specific metadata.

---

## Goals

- Provide tools that understand poetic form and structure
- Support common poetry formats (haiku, sonnet, free verse, etc.)
- Enable line-level editing and formatting
- Track poetry-specific metadata (form type, line count, stanza structure)
- Support poetry submissions with form requirements

---

## Potential Features

### 1. Poetry Forms & Templates

**Description**: Pre-configured templates for common poetry forms

**Examples**:
- Haiku (5-7-5 syllable pattern)
- Sonnet (14 lines with rhyme scheme)
- Villanelle (19 lines, specific repetition pattern)
- Limerick (5 lines, AABBA rhyme scheme)
- Free verse (no constraints)

**Implementation Ideas**:
- Form selector when creating new poem
- Automatic line counting and validation
- Syllable counter for forms with syllable requirements
- Rhyme scheme highlighting
- Structure validation warnings

### 2. Line Break Preservation

**Description**: Maintain exact line breaks and spacing as entered by user

**Considerations**:
- Line breaks are semantic in poetry (not just wrapping)
- Preserve indentation for visual structure
- Export line breaks correctly to different formats
- Display line breaks consistently across devices

**Technical Notes**:
- May need special paragraph/line break handling in NSAttributedString
- Consider using explicit line break markers vs. paragraph breaks
- Ensure CloudKit sync preserves line structure

### 3. Syllable Counter

**Description**: Count syllables per line for forms with syllable requirements

**Features**:
- Real-time syllable counting as user types
- Visual indicator showing current count vs. target
- Highlight lines that don't match required syllable count
- Support for different syllable counting rules (English, other languages)

**UI Example**:
```
The old pond—                    [4/5] ⚠️
A frog jumps in,                 [4/7] ⚠️
Splash! Silence again.           [5/5] ✓
```

### 4. Stanza Management

**Description**: Tools for organizing and restructuring stanzas

**Features**:
- Visual stanza separators
- Drag-to-reorder stanzas
- Stanza templates (couplet, tercet, quatrain, etc.)
- Automatic stanza numbering
- Stanza-level notes

### 5. Rhyme Scheme Analyzer

**Description**: Detect and visualize rhyme patterns

**Features**:
- Automatic rhyme detection
- Label lines with rhyme scheme (ABAB, AABB, etc.)
- Highlight rhyming words
- Suggest alternate rhymes
- Custom rhyme dictionaries

### 6. Meter & Rhythm Tools

**Description**: Tools for working with poetic meter

**Features**:
- Stress pattern visualization
- Meter type detection (iambic, trochaic, etc.)
- Beat counter
- Rhythm consistency checker
- Audio reading with emphasis on stressed syllables

### 7. Poetry-Specific Metadata

**Description**: Additional metadata fields relevant to poetry

**Fields**:
- Form type (haiku, sonnet, free verse, etc.)
- Line count
- Stanza count
- Rhyme scheme
- Meter type
- Theme/subject tags
- Occasion (competition, publication, personal)

**Storage**:
- Extend TextFile model with poetry-specific fields
- Make fields optional (only for poetry projects)
- Include in search/filter capabilities

### 8. Line Numbering

**Description**: Optional line numbers for reference and discussion

**Features**:
- Toggle line numbering on/off
- Start numbering from specific line
- Skip blank lines in numbering
- Include line numbers in exports
- Reference specific lines in notes

### 9. Performance/Reading View

**Description**: Special view optimized for reading poetry aloud

**Features**:
- Large text display
- High contrast mode
- Scroll/page through lines at controlled pace
- Highlight current line being read
- Breathing/pause indicators
- Reading time estimator

### 10. Poetry Submissions Enhancements

**Description**: Extend Feature 008b for poetry-specific submission needs

**Features**:
- Track which form types each publication accepts
- Submission requirements by form (e.g., "Max 40 lines for sonnets")
- Line count validation before submission
- Form type filtering when selecting files to submit
- Publication preferences for specific poetry forms

---

## User Stories (Draft)

### US-009-001: Create Poem from Template

**As a** poet  
**I want to** start a new sonnet from a template  
**So that** I have the correct structure and line count

**Acceptance Criteria**:
- Template provides 14 numbered lines
- Shows rhyme scheme guide (ABAB CDCD EFEF GG)
- Validates line count as I write
- Prevents adding more than 14 lines

### US-009-002: Count Syllables for Haiku

**As a** poet  
**I want to** see syllable counts for each line of my haiku  
**So that** I can ensure it follows 5-7-5 pattern

**Acceptance Criteria**:
- Real-time syllable counting
- Visual indicator (✓ or ⚠️) for each line
- Total syllable count shown
- Adjusts dynamically as I edit

### US-009-003: Preserve Line Breaks

**As a** poet  
**I want to** my line breaks to stay exactly as I entered them  
**So that** the visual structure of my poem is maintained

**Acceptance Criteria**:
- Line breaks don't change when viewing on different devices
- Exporting preserves exact line structure
- Copy/paste maintains line breaks
- Indentation preserved

### US-009-004: Reorder Stanzas

**As a** poet  
**I want to** drag stanzas to reorder them  
**So that** I can experiment with poem structure

**Acceptance Criteria**:
- Visual handles to grab stanzas
- Smooth drag-and-drop interaction
- Undo/redo support for reordering
- Works on both iOS and macOS

---

## Technical Considerations

### Text Storage
- NSAttributedString for rich text with line breaks
- Custom paragraph styles for poetry line spacing
- Preserve whitespace and indentation
- Handle line breaks differently from paragraph breaks

### Syllable Counting
- NLTagger for word tokenization
- CMU Pronouncing Dictionary or similar for syllable lookup
- Fallback heuristics for unknown words
- Cache syllable counts for performance

### Form Validation
- Rule engine for different poetry forms
- Extensible system for adding new forms
- User-defined custom forms
- Validation without being overly restrictive

### CloudKit Sync
- Ensure line breaks sync correctly
- Handle poetry metadata in sync
- Version control respects line-level changes

### Performance
- Real-time syllable counting must be fast
- Rhyme detection can be background process
- Don't block typing with heavy analysis

---

## Data Model Extensions

### Poetry-Specific Fields (Optional, Project-Type Dependent)

```swift
// Extension to TextFile for poetry projects
extension TextFile {
    var poetryForm: PoetryForm?        // haiku, sonnet, free_verse, etc.
    var lineCount: Int                 // Computed from content
    var stanzaCount: Int               // Computed from content
    var rhymeScheme: String?           // e.g., "ABAB CDCD EFEF GG"
    var meterType: MeterType?          // iambic, trochaic, etc.
    var syllableTarget: Int?           // Expected syllables (e.g., 17 for haiku)
}

enum PoetryForm: String, Codable {
    case haiku
    case sonnet
    case villanelle
    case limerick
    case freeVerse
    case custom
}

enum MeterType: String, Codable {
    case iambic
    case trochaic
    case anapestic
    case dactylic
    case free
}
```

---

## UI Mockups (Conceptual)

### Poetry Form Selector
```
┌─────────────────────────────────────┐
│ Choose Poetry Form                  │
├─────────────────────────────────────┤
│ ⚪ Free Verse                       │
│ ⚫ Haiku (5-7-5)                    │
│ ⚪ Sonnet (14 lines)                │
│ ⚪ Limerick (5 lines)               │
│ ⚪ Custom                           │
│                                     │
│ [Cancel]               [Create]     │
└─────────────────────────────────────┘
```

### Haiku Editor with Syllable Counter
```
┌─────────────────────────────────────┐
│ ← spring-haiku.txt            [✓]   │
├─────────────────────────────────────┤
│ Line 1: [5 syllables] ✓             │
│ Cherry blossoms fall                │
│                                     │
│ Line 2: [7 syllables] ✓             │
│ Petals drift on gentle breeze       │
│                                     │
│ Line 3: [5 syllables] ✓             │
│ Spring whispers goodbye              │
│                                     │
│ Total: 17 syllables ✓              │
└─────────────────────────────────────┘
```

### Stanza Editor
```
┌─────────────────────────────────────┐
│ ← my-poem.txt                       │
├─────────────────────────────────────┤
│ [≡] Stanza 1:                       │
│     Shall I compare thee to a       │
│     summer's day?                   │
│     Thou art more lovely and more   │
│     temperate...                    │
│                                     │
│ [≡] Stanza 2:                       │
│     Rough winds do shake the        │
│     darling buds of May,            │
│     And summer's lease hath all     │
│     too short a date...             │
│                                     │
│ [+ Add Stanza]                      │
└─────────────────────────────────────┘
```

---

## Out of Scope (For Now)

- ❌ AI-generated poetry
- ❌ Rhyming dictionary (may be future enhancement)
- ❌ Thesaurus integration
- ❌ Audio recording of readings
- ❌ Collaborative poetry writing
- ❌ Public poetry sharing/community
- ❌ Poetry contest discovery
- ❌ Automatic translation

---

## Dependencies

- **Feature 003**: Text file creation (foundation)
- **Feature 005**: Text formatting (line breaks, indentation)
- **Feature 008b**: Publication system (for poetry submission enhancements)
- **NaturalLanguage framework**: For syllable counting and analysis
- **Custom syllable dictionary**: CMU or similar

---

## Success Metrics

- Poets can create and format poems without fighting the editor
- Syllable counting is accurate for 95%+ of common English words
- Line breaks are preserved 100% across devices and exports
- Form templates reduce setup time by 80%
- Poetry-specific metadata improves organization and search

---

## Implementation Phases

### Phase 1: Foundation
- Line break preservation
- Basic poetry metadata (form type, line count)
- Form selector for new poems

### Phase 2: Analysis Tools
- Syllable counter
- Line numbering
- Stanza management

### Phase 3: Advanced Features
- Rhyme scheme analyzer
- Meter tools
- Performance/reading view

### Phase 4: Integration
- Poetry-specific submission requirements
- Enhanced search/filtering by poetry attributes
- Export with poetry formatting

---

## Open Questions

1. **Syllable counting accuracy**: Which syllable dictionary/algorithm is most accurate for poetry?
2. **Form extensibility**: Should users be able to define custom poetry forms?
3. **Language support**: Should syllable counting support languages other than English?
4. **Rhyme detection**: How sophisticated should rhyme detection be? (perfect rhymes only, or near rhymes too?)
5. **Performance impact**: How much overhead do real-time analysis tools add?
6. **Free tier limits**: Should poetry-specific features require subscription? Or available to all?

---

## Related Resources

- CMU Pronouncing Dictionary: http://www.speech.cs.cmu.edu/cgi-bin/cmudict
- Poetry Foundation: https://www.poetryfoundation.org/
- Poetic forms reference: https://poets.org/glossary
- NaturalLanguage Framework: Apple Developer Documentation

---

## Notes

- Poetry features should enhance, not restrict, the writing experience
- Validation should guide but not block (allow breaking "rules")
- Consider cultural/stylistic variations in poetry forms
- Keep UI clean - not all poets use all features
- Focus on tools professional poets actually need

---

**Status**: 📋 Specification Draft  
**Next Steps**: User research with poets, prioritize features, prototype syllable counter  
**Estimated Effort**: Large (6-8 weeks for full implementation)
