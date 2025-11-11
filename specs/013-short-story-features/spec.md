# Feature Specification: Short Story-Specific Features

**Feature ID**: 012  
**Created**: 9 November 2025  
**Status**: Planning / Future Enhancement  
**Priority**: Medium-Low  
**Dependencies**: Core text editing, publication system (008b)

---

## Overview

Features tailored for short story writers, focusing on compact storytelling, anthology management, and literary magazine submissions.

---

## Goals

- Support single-file short stories (already works)
- Manage collections/anthologies of multiple stories
- Track submissions to literary magazines
- Provide word count targets for specific markets
- Support flash fiction, short stories, and novellas
- Enable themed collection organization

---

## Potential Features

### 1. Story Collections / Anthologies

**Description**: Group related stories into collections

**Use Cases**:
- Themed anthology (all horror stories)
- Best-of collection (favorite stories)
- Submission-ready collection
- Published anthology tracking

**Features**:
- Create collection (folder or tag-based)
- Order stories in collection
- Collection metadata (title, theme, target audience)
- Export entire collection as single document
- Table of contents generation
- Collection word count totals

**Data Model**:
```swift
@Model
class StoryCollection {
    var id: UUID
    var name: String
    var theme: String?
    var stories: [TextFile]          // Ordered list
    var notes: String?
    var targetLength: Int?           // Total word count target
    var project: Project
}
```

### 2. Story Metadata

**Description**: Track story-specific information

**Fields**:
- Genre/subgenre (literary, sci-fi, horror, romance, etc.)
- Target word count (flash fiction: <1000, short story: 1000-7500, novelette: 7500-17500, novella: 17500-40000)
- Tone/mood tags
- Point of view (1st person, 3rd limited, 3rd omniscient)
- Setting era (contemporary, historical, futuristic)
- Target market/publication
- Age rating
- Trigger warnings (if applicable)

**Storage**:
```swift
extension TextFile {
    var genre: String?
    var subgenre: String?
    var targetWordCount: Int?
    var actualWordCount: Int         // Already exists
    var tone: [String]?              // ["dark", "humorous", "suspenseful"]
    var pointOfView: POV?
    var settingEra: String?
    var targetPublication: String?
}

enum POV {
    case firstPerson
    case thirdLimited
    case thirdOmniscient
    case secondPerson
}
```

### 3. Market Research & Submission Tracking

**Description**: Track which markets accept which story types

**Integration with Feature 008b (Publications)**:
- Publications have genre preferences
- Publications have word count limits
- Publications have reading periods (open/closed dates)
- Publications have response time estimates

**Enhanced Publication Model**:
```swift
extension Publication {
    var acceptedGenres: [String]?         // ["sci-fi", "fantasy"]
    var minWordCount: Int?                // Minimum story length
    var maxWordCount: Int?                // Maximum story length
    var readingPeriodStart: Date?         // When they accept submissions
    var readingPeriodEnd: Date?           // When submissions close
    var averageResponseDays: Int?         // Historical avg
    var paymentType: PaymentType?         // pro, semi-pro, token, none
}

enum PaymentType {
    case professional          // >$0.08/word
    case semiProfessional     // >$0.03/word
    case token                // <$0.03/word
    case nonPaying
    case otherCompensation    // contributor copies, etc.
}
```

**Features**:
- Filter publications by story's genre and word count
- Show only publications currently open for submissions
- Warn if story doesn't meet market requirements
- Track payment rates
- Note simultaneous submission policies

### 4. Flash Fiction Tools

**Description**: Tools specifically for very short stories (<1000 words)

**Features**:
- Word count warning as approaching limit
- Every word counts mode (show redundancies, weak words)
- Compression suggestions
- Opening/closing strength analyzer
- Micro-pacing tools

**Target Lengths**:
- Micro fiction: <100 words
- Flash fiction: 100-1000 words
- Sudden fiction: 750-1500 words

### 5. Opening/Closing Analysis

**Description**: Analyze story openings and endings

**Features**:
- First sentence/paragraph analysis
- Opening hook strength
- Starting in media res detection
- Closing satisfaction checker
- Resolution vs. ambiguity balance

**Technical**: Could use NLP for sentiment analysis, sentence structure analysis

### 6. Theme & Motif Tracking

**Description**: Track recurring themes and symbols

**Features**:
- Identify themes in story
- Tag sections with theme markers
- Theme consistency checker
- Symbol tracking
- Metaphor catalog

**Use Case**: Ensure thematic coherence in collection

### 7. Contest & Anthology Call Tracker

**Description**: Track writing contests and anthology submission opportunities

**Data Model**:
```swift
@Model
class WritingContest {
    var id: UUID
    var name: String
    var type: ContestType             // contest, anthology call, award
    var deadline: Date
    var theme: String?
    var wordCountMin: Int?
    var wordCountMax: Int?
    var entryFee: Decimal?
    var prize: String?
    var url: String?
    var notes: String?
    var genre: [String]?
    var hasEntered: Bool              // Did I submit?
    var submission: Submission?       // Link to my submission
}

enum ContestType {
    case contest
    case anthologyCall
    case award
    case fellowship
}
```

**Features**:
- Contest/call list with deadlines
- Filter by genre, word count, deadline
- Entry tracking
- Results tracking
- Notification reminders for deadlines

### 8. Story Format Templates

**Description**: Templates for different story submission formats

**Templates**:
- Standard manuscript format (like novels but for short form)
- Literary magazine format
- Contest submission format
- Ebook short story format

**Formatting**:
- Author contact info header
- Word count in header
- Proper title page
- END or # # # markers

### 9. Linked Stories / Series Tracking

**Description**: Track stories that share characters/settings

**Use Cases**:
- Connected short stories (same world)
- Character appears across multiple stories
- Prequel/sequel relationships
- Shared universe

**Features**:
- Link stories together
- Shared character database across linked stories
- Chronological order of linked stories
- Continuity checking across linked stories

**Data Model**:
```swift
@Model
class StoryLink {
    var id: UUID
    var stories: [TextFile]
    var linkType: LinkType
    var chronologicalOrder: [TextFile]  // Reading order
    var notes: String?
}

enum LinkType {
    case series
    case sharedWorld
    case sharedCharacters
    case parallel
}
```

### 10. Critique & Feedback Management

**Description**: Track feedback from critique partners/beta readers

**Features**:
- Attach feedback notes to stories
- Track who gave feedback and when
- Categorize feedback (plot, character, prose, etc.)
- Mark feedback as addressed
- Compare drafts with feedback incorporated

**Data Model**:
```swift
@Model
class Feedback {
    var id: UUID
    var story: TextFile
    var version: Version            // Which draft
    var critiquer: String           // Name
    var date: Date
    var category: FeedbackCategory
    var text: String
    var isAddressed: Bool
}

enum FeedbackCategory {
    case plot
    case character
    case prose
    case pacing
    case dialogue
    case opening
    case ending
    case general
}
```

---

## User Stories (Draft)

### US-012-001: Create Story Collection

**As a** short story writer  
**I want to** group my sci-fi stories into a collection  
**So that** I can organize them thematically

**Acceptance Criteria**:
- Create new collection with name
- Add stories to collection
- Reorder stories in collection
- Export collection as single document

### US-012-002: Filter Markets by Story

**As a** short story writer  
**I want to** see which magazines accept 5000-word horror stories  
**So that** I know where to submit my story

**Acceptance Criteria**:
- Set story genre and word count
- View filtered publication list
- Only shows publications accepting that genre/length
- Shows if publication currently open for submissions

### US-012-003: Track Contest Deadlines

**As a** short story writer  
**I want to** add writing contest with deadline Nov 30  
**So that** I don't forget to submit

**Acceptance Criteria**:
- Add contest with name, deadline, requirements
- View contest list sorted by deadline
- Get reminder notification 7 days before deadline
- Mark contest as entered when submitted

### US-012-004: Manage Linked Stories

**As a** short story writer  
**I want to** link my three detective stories together  
**So that** I can track the character's continuity

**Acceptance Criteria**:
- Create story series
- Add stories to series
- Set chronological reading order
- View all stories in series

---

## Technical Considerations

### Data Model
- Most features extend existing TextFile model
- New models: StoryCollection, WritingContest, StoryLink, Feedback
- Integration with Publication model (Feature 008b)

### Analysis
- NLP for theme detection
- Sentiment analysis for opening/closing
- Pattern matching for motif tracking

### Export
- Collection compilation similar to novel compilation
- Standard manuscript format for short stories
- Table of contents for collections

### Performance
- Short stories are smaller than novels (faster processing)
- Collection compilation should be very fast
- Market filtering needs efficient queries

---

## Data Model Extensions

```swift
// Short story specific fields
extension TextFile {
    var genre: String?
    var subgenre: String?
    var targetWordCount: Int?
    var tone: [String]?
    var pointOfView: POV?
    var settingEra: String?
    var targetPublication: String?
    var storyCollection: StoryCollection?
    var linkedStories: StoryLink?
}

@Model class StoryCollection { /* see above */ }
@Model class WritingContest { /* see above */ }
@Model class StoryLink { /* see above */ }
@Model class Feedback { /* see above */ }

// Enhanced Publication for markets
extension Publication {
    var acceptedGenres: [String]?
    var minWordCount: Int?
    var maxWordCount: Int?
    var readingPeriodStart: Date?
    var readingPeriodEnd: Date?
    var averageResponseDays: Int?
    var paymentType: PaymentType?
    var simultaneousSubmissions: Bool?
}
```

---

## Out of Scope

- ❌ AI story generation
- ❌ Writing prompts generator
- ❌ Public story sharing/community
- ❌ Direct submission to magazines (email integration)
- ❌ Payment tracking from publications
- ❌ Rights management / reprint tracking
- ❌ Professional editing marketplace

---

## Dependencies

- **Feature 003**: Text file creation
- **Feature 007**: Word count
- **Feature 008b**: Publication/submission system
- **Feature 010**: May share some features with novel tools (character tracking for linked stories)

---

## Success Metrics

- Story organization improves with collections
- Market filtering reduces submission time by 50%
- Contest tracking prevents missed deadlines
- Linked story tracking maintains continuity
- 80% of short story writers use metadata fields

---

## Implementation Phases

### Phase 1: Basic Organization
- Story metadata (genre, word count targets)
- Story collections
- Collection export

### Phase 2: Market Integration
- Enhanced publication filtering
- Word count/genre requirements
- Reading period tracking

### Phase 3: Advanced Tools
- Contest/call tracker
- Linked stories
- Feedback management

### Phase 4: Analysis Tools
- Opening/closing analysis
- Theme tracking
- Flash fiction tools

---

## Open Questions

1. **Overlap with novel features**: How much character/plot tracking do short story writers need?
2. **Collection management**: Should collections be folders, tags, or separate entities?
3. **Market database**: Should we provide built-in magazine database or user-entered only?
4. **Payment tracking**: Important enough for Phase 1?
5. **Simultaneous submissions**: How to track which stories are submitted where simultaneously?

---

## Related Resources

- Duotrope (market database - competitive research)
- The Grinder (submission tracker - competitive research)
- Ralan.com (market listings)
- SFWA (Science Fiction & Fantasy Writers Association) - market info
- "Writing the Short Story" by Jack Bickham

---

## Notes

- Short story features should be lighter-weight than novel features
- Focus on submission tracking (more important for short stories)
- Many writers write both novels and short stories - keep UI consistent
- Market research is critical for short story success

---

**Status**: 📋 Specification Draft  
**Next Steps**: Survey short story writers, research market tracking needs, prototype collection management  
**Estimated Effort**: Medium (4-6 weeks for core features)
