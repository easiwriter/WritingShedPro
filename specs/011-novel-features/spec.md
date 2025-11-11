# Feature Specification: Novel-Specific Features

**Feature ID**: 010  
**Created**: 9 November 2025  
**Status**: Planning / Future Enhancement  
**Priority**: High  
**Dependencies**: Core project management, file organization

---

## Overview

Specialized features and tools designed for novel writing, including chapter organization, character tracking, plot management, and long-form manuscript tools.

---

## Goals

- Support complex multi-chapter novel structure
- Track characters, locations, plot threads across entire manuscript
- Provide tools for managing timeline and continuity
- Enable quick navigation in long documents
- Support novel-specific export formats (manuscript, ebook)
- Integrate with traditional publishing workflows

---

## Potential Features

### 1. Chapter Management

**Description**: Organize novel as a collection of chapters with special navigation

**Features**:
- Each chapter as separate file (already supported)
- Chapter ordering and numbering
- Automatic chapter renumbering on reorder
- Chapter-level notes and status (draft, revised, final)
- Chapter summary/synopsis
- Target word count per chapter
- Chapter templates (opening, action, conclusion, etc.)

**UI Ideas**:
- Chapter outline view (table of contents)
- Drag-to-reorder chapters
- Quick jump to any chapter
- Chapter progress indicators
- Compile all chapters into single document view

### 2. Manuscript Compilation

**Description**: Combine all chapters into single manuscript for export/review

**Features**:
- Compile chapters in order
- Include/exclude specific chapters (for partial drafts)
- Add front matter (title page, dedication, etc.)
- Add back matter (acknowledgments, author bio)
- Page numbering for entire manuscript
- Insert chapter breaks with formatting
- Export as single PDF/Word document
- Manuscript formatting presets (Standard Manuscript Format)

**Export Formats**:
- PDF (manuscript format)
- DOCX (Word)
- EPUB (ebook)
- Plain text
- RTF

### 3. Character Database

**Description**: Track characters with profiles, relationships, and appearances

**Data Model**:
```swift
@Model
class Character {
    var id: UUID
    var name: String
    var aliases: [String]           // Other names character goes by
    var role: CharacterRole         // protagonist, antagonist, supporting
    var description: String?        // Physical description
    var backstory: String?          // Character history
    var personality: String?        // Traits, motivations
    var relationships: [Relationship]
    var firstAppearance: TextFile?  // Which chapter introduced
    var notes: String?
    var imageURL: String?           // Character portrait
    var project: Project
}

enum CharacterRole {
    case protagonist
    case antagonist
    case supporting
    case minor
}

struct Relationship {
    var character: Character
    var type: String              // "friend", "enemy", "spouse", etc.
    var description: String?
}
```

**Features**:
- Character list with search/filter
- Character profiles with rich details
- Track character appearances by chapter
- Character relationship graph
- Character arc tracking (how they change)
- Export character profiles

### 4. Location Database

**Description**: Track settings and locations in the novel

**Data Model**:
```swift
@Model
class Location {
    var id: UUID
    var name: String
    var type: LocationType          // city, building, room, etc.
    var description: String?
    var parentLocation: Location?   // Nesting (room -> building -> city)
    var notes: String?
    var imageURL: String?           // Location reference image
    var firstAppearance: TextFile?
    var project: Project
}

enum LocationType {
    case world
    case country
    case city
    case building
    case room
    case other
}
```

**Features**:
- Location list with hierarchy
- Location details and descriptions
- Track location appearances
- Location maps (future: integrate with image support)

### 5. Plot Threads / Story Arcs

**Description**: Track multiple plot lines through the novel

**Data Model**:
```swift
@Model
class PlotThread {
    var id: UUID
    var name: String                // "Romance subplot", "Mystery arc"
    var description: String?
    var status: PlotStatus          // introduced, developing, resolved
    var chapters: [TextFile]        // Chapters where this thread appears
    var characters: [Character]     // Characters involved
    var notes: String?
    var color: String?              // Color code for visualization
    var project: Project
}

enum PlotStatus {
    case introduced
    case developing
    case resolved
    case abandoned
}
```

**Features**:
- Plot thread list
- Visual plot thread timeline across chapters
- Mark which threads appear in each chapter
- Track thread resolution
- Warn about dangling plot threads
- Color-coded thread visualization

### 6. Timeline Management

**Description**: Track chronological order of events (may differ from chapter order)

**Features**:
- Event database with dates/times
- Timeline view of all events
- Compare story time vs. chapter order (flashbacks, etc.)
- Detect timeline inconsistencies
- Multiple timelines (for multiple POVs or parallel stories)
- Calendar view for events

**Data Model**:
```swift
@Model
class Event {
    var id: UUID
    var name: String
    var description: String?
    var storyDate: Date?            // When it happens in story
    var chapter: TextFile?          // Where it's described
    var characters: [Character]
    var location: Location?
    var plotThreads: [PlotThread]
    var project: Project
}
```

### 7. Scene Management

**Description**: Break chapters into scenes with metadata

**Features**:
- Scene markers within chapters
- Scene list view
- Scene goals and conflicts
- POV character per scene
- Scene location and time
- Scene word count targets
- Scene status (planned, drafted, revised)

**Technical Note**: Scenes might be markers/annotations within a chapter file rather than separate files

### 8. Continuity Checker

**Description**: Tools to catch continuity errors

**Features**:
- Character name consistency checker (catch typos/variants)
- Timeline inconsistency detector
- Character trait changes (eye color, age, etc.)
- Object permanence (character has item they shouldn't have)
- Location consistency
- Generate continuity report

**Implementation**: Likely uses NLP/search to find mentions and compare

### 9. Outline & Synopsis Views

**Description**: High-level views of novel structure

**Features**:
- Novel outline (hierarchical chapter/scene structure)
- Chapter synopses in order
- Act structure visualization (three-act, five-act, etc.)
- Beat sheet view
- Story arc diagrams
- Export outline as separate document

### 10. Revision Tracking

**Description**: Track drafts and revisions at novel level

**Features**:
- Draft versions (First Draft, Second Draft, etc.)
- Chapter revision status
- Revision notes and goals
- Compare drafts (see what changed)
- Revision history timeline
- Track word count changes across drafts

**Integration**: Builds on Feature 004 (version control) but at novel-wide scope

### 11. Word Count Goals & Progress

**Description**: Novel-wide and chapter-level word count tracking

**Features**:
- Novel target word count
- Chapter target word counts
- Daily writing goals
- Progress tracking (chapters completed)
- Word count history graph
- Estimated completion date
- Writing pace statistics

**UI Example**:
```
Novel Progress:
━━━━━━━━━━━━━━━━━━━━━ 45,000 / 100,000 words (45%)
Chapters: 12 / 30 (40%)
Estimated completion: March 2026 (at current pace)
```

### 12. Research Notes & World Building

**Description**: Dedicated space for research and world-building information

**Features**:
- Research notes separate from manuscript
- Wiki-style linking between notes
- Attach notes to characters, locations, plot threads
- Image/file attachments for research
- Tag and organize research notes
- Quick search research while writing

**Structure**: Could be special folder type or dedicated notes system

### 13. Novel-Specific Export/Publishing

**Description**: Export formats and templates for novel publishing

**Features**:
- Standard Manuscript Format export
- Query letter template
- Synopsis generator (from chapter summaries)
- Ebook formatting (EPUB with proper structure)
- Print-ready PDF (with ISBN, copyright page, etc.)
- Submission package generation

### 14. Writing Session Tracking

**Description**: Track writing sessions and productivity

**Features**:
- Session start/stop timer
- Words written per session
- Session notes/reflections
- Streak tracking (consecutive days)
- Writing time heatmap
- Productivity insights

**Privacy**: All data stays local, no external tracking

---

## User Stories (Draft)

### US-010-001: Reorder Chapters

**As a** novelist  
**I want to** drag chapters to reorder them  
**So that** I can restructure my novel without renaming files

**Acceptance Criteria**:
- Drag-and-drop chapter reordering
- Automatic chapter number updates
- Compile respects new order
- Undo/redo support

### US-010-002: Track Character Appearances

**As a** novelist  
**I want to** see which chapters each character appears in  
**So that** I can ensure consistent character development

**Acceptance Criteria**:
- Character profile shows list of chapters
- Can click chapter to jump to that file
- Search finds all character mentions
- Visual timeline of appearances

### US-010-003: Compile Manuscript

**As a** novelist  
**I want to** export my entire novel as a single Word document  
**So that** I can submit to agents/publishers

**Acceptance Criteria**:
- All chapters combined in order
- Proper page breaks between chapters
- Standard manuscript formatting applied
- Front/back matter included
- Export within 30 seconds for 100k word novel

### US-010-004: Set Word Count Goals

**As a** novelist  
**I want to** set a 80,000 word target for my novel  
**So that** I can track my progress

**Acceptance Criteria**:
- Set overall word count goal
- See visual progress bar
- Get notifications at milestones (25%, 50%, 75%, 100%)
- View estimated completion date

### US-010-005: Manage Plot Threads

**As a** novelist  
**I want to** track my romance subplot across chapters  
**So that** I ensure it's properly developed and resolved

**Acceptance Criteria**:
- Create plot thread with name and description
- Mark chapters where thread appears
- See visual timeline of thread progression
- Set thread status (introduced/developing/resolved)
- Get warning if thread never resolved

---

## Technical Considerations

### Performance
- Large manuscripts (100k+ words across 30+ files)
- Fast search across all chapters
- Efficient character/location mention detection
- Compilation speed for long manuscripts

### Data Model
- Novel-specific models (Character, Location, PlotThread, Event)
- Relationships between models (Character appears in Chapters)
- CloudKit sync for all novel data
- Export model data for backup

### Text Analysis
- NLP for character mention detection
- Name entity recognition for locations
- Timeline analysis from text
- Continuity checking algorithms

### Export
- Proper manuscript formatting (Courier, 12pt, double-spaced, etc.)
- EPUB generation with metadata
- Page numbering and headers
- Chapter break styling

### Organization
- Clear separation of manuscript vs. notes vs. research
- Scalable to very long novels (200k+ words)
- Support for novel series (multiple projects linked?)

---

## Data Model Extensions

### Novel Project Type Extensions

```swift
// Novel-specific project fields
extension Project {
    var targetWordCount: Int?
    var genre: String?
    var targetAudience: String?        // YA, Adult, Middle Grade, etc.
    var seriesName: String?
    var bookNumber: Int?               // If part of series
    var draftVersion: String?          // "First Draft", "Revision 2", etc.
}

// Novel elements
@Model class Character { /* see above */ }
@Model class Location { /* see above */ }
@Model class PlotThread { /* see above */ }
@Model class Event { /* see above */ }

// Scene markers (annotations on TextFile)
@Model
class Scene {
    var id: UUID
    var textFile: TextFile             // Parent chapter
    var startPosition: Int             // Character offset in chapter
    var endPosition: Int
    var title: String?
    var goal: String?                  // What should happen
    var conflict: String?
    var povCharacter: Character?
    var location: Location?
    var timeOfDay: String?
    var notes: String?
}
```

---

## UI Mockups (Conceptual)

### Chapter Outline View
```
┌─────────────────────────────────────┐
│ ← My Novel                 [Compile]│
├─────────────────────────────────────┤
│ Progress: 45,000 / 100,000 words    │
│ ━━━━━━━━━━━━━━━━━━━━ 45%           │
│                                     │
│ [≡] 1. The Beginning                │
│     Status: ✓ Revised               │
│     3,245 words                     │
│                                     │
│ [≡] 2. Discovery                    │
│     Status: ✓ Revised               │
│     2,890 words                     │
│                                     │
│ [≡] 3. The Journey                  │
│     Status: ⏳ Draft                │
│     4,123 words                     │
│                                     │
│ [+ Add Chapter]                     │
└─────────────────────────────────────┘
```

### Character Profile
```
┌─────────────────────────────────────┐
│ ← Characters                    [+] │
├─────────────────────────────────────┤
│ Sarah Chen                          │
│ Role: Protagonist                   │
│                                     │
│ Description:                        │
│ 28 years old, software engineer,    │
│ black hair, brown eyes...           │
│                                     │
│ Relationships:                      │
│ • Marcus (mentor)                   │
│ • David (rival)                     │
│                                     │
│ Appears in:                         │
│ Ch 1, 3, 5, 7, 9, 11... (18 total) │
│                                     │
│ Character Arc:                      │
│ Naive → Experienced → Leader        │
│                                     │
│ [Edit] [View Appearances]           │
└─────────────────────────────────────┘
```

### Plot Thread Timeline
```
┌─────────────────────────────────────┐
│ ← Plot Threads                      │
├─────────────────────────────────────┤
│ Mystery Arc                         │
│ Ch: 1━━━5━━━━━━12━━━15━━━━━━━━30   │
│     Intro  Clue1 Clue2   Resolved   │
│                                     │
│ Romance Subplot                     │
│ Ch: ━━3━━━━8━━━━━━━━━20━━━━━━━30   │
│     Meet  Conflict    Resolved      │
│                                     │
│ Character Growth                    │
│ Ch: 1━━━━━━━━━━━━━━━━━━━━━━━━━30   │
│     Start─────────────────────End   │
│                                     │
└─────────────────────────────────────┘
```

### Compile Settings
```
┌─────────────────────────────────────┐
│ Compile Manuscript                  │
├─────────────────────────────────────┤
│ Format:                             │
│ ⦿ Standard Manuscript Format        │
│ ○ Ebook (EPUB)                      │
│ ○ Print PDF                         │
│                                     │
│ Include:                            │
│ ☑ Title Page                        │
│ ☑ All Chapters (1-30)               │
│ ☑ Chapter Numbers                   │
│ ☐ Chapter Summaries                 │
│                                     │
│ Font: Courier New, 12pt             │
│ Spacing: Double                     │
│ Margins: 1 inch                     │
│                                     │
│ [Cancel]               [Export]     │
└─────────────────────────────────────┘
```

---

## Out of Scope (For Now)

- ❌ AI writing assistance (separate feature)
- ❌ Collaborative novel writing (multiple authors)
- ❌ Public novel sharing platform
- ❌ Direct publishing to Amazon/platforms
- ❌ Cover design tools
- ❌ Marketing materials generation
- ❌ Agent/publisher database
- ❌ Rights management

---

## Dependencies

- **Feature 001**: Project management (novel as project type)
- **Feature 003**: Text file creation (chapters)
- **Feature 004**: Version control (draft tracking)
- **Feature 007**: Word count (novel-wide counts)
- **Feature 008a**: File movement (chapter organization)
- **NaturalLanguage framework**: Text analysis
- **Export libraries**: PDF, EPUB generation

---

## Success Metrics

- Novelists can organize 30+ chapters efficiently
- Character database improves continuity tracking
- Manuscript compilation takes < 30 seconds for 100k words
- Export formatting matches industry standards
- 80% reduction in time spent organizing novel structure

---

## Implementation Phases

### Phase 1: Chapter Organization
- Chapter ordering and numbering
- Chapter-level metadata
- Basic compilation

### Phase 2: Tracking & Continuity
- Character database
- Location database
- Basic continuity checks

### Phase 3: Plot & Structure
- Plot thread tracking
- Timeline management
- Outline views

### Phase 4: Export & Publishing
- Standard manuscript format export
- EPUB generation
- Submission package tools

---

## Open Questions

1. **Chapter files vs. sections**: Should chapters be separate files (current) or sections in one large file?
2. **Auto-detection**: How much character/location tracking can be automated vs. manual entry?
3. **Series support**: Should we support linking multiple novel projects as a series?
4. **Scene granularity**: Are scenes important enough to be first-class entities?
5. **Collaboration**: Will novelists want to collaborate with editors/beta readers in-app?
6. **Subscription tier**: Should novel features require Pro subscription?

---

## Related Resources

- Standard Manuscript Format: https://www.shunn.net/format/
- EPUB specification: https://www.w3.org/publishing/epub3/
- Scrivener (competitive research): https://www.literatureandlatte.com/
- Novel writing workflows: Various writing blogs/courses

---

## Notes

- Novelists need powerful organization but simple daily writing experience
- Don't force novelists into rigid structures (allow flexibility)
- Export quality is critical for professional submission
- Performance matters for long manuscripts
- Consider mobile vs. desktop usage patterns (writing on iPad, organizing on Mac?)

---

**Status**: 📋 Specification Draft  
**Next Steps**: User research with novelists, prototype chapter management, test compilation performance  
**Estimated Effort**: Very Large (10-12 weeks for core features, ongoing for advanced features)
