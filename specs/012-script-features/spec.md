# Feature Specification: Screenplay/Script-Specific Features

**Feature ID**: 011  
**Created**: 9 November 2025  
**Status**: Planning / Future Enhancement  
**Priority**: Medium  
**Dependencies**: Core text editing, formatting features

---

## Overview

Specialized features for writing screenplays, stage plays, and TV scripts with industry-standard formatting and script-specific tools.

---

## Goals

- Support industry-standard script formatting (Hollywood standard, BBC format, etc.)
- Automate script element formatting (dialogue, action, transitions, etc.)
- Provide script-specific navigation and breakdown tools
- Enable collaboration features for production teams
- Export in professional formats (PDF with proper spacing, Final Draft format)

---

## Potential Features

### 1. Script Formatting Engine

**Description**: Automatic formatting for script elements

**Script Elements**:
- **Scene Heading** (INT. COFFEE SHOP - DAY)
- **Action** (narrative description)
- **Character** (character name before dialogue)
- **Dialogue** (what character says)
- **Parenthetical** ((nervously), (shouting))
- **Transition** (CUT TO:, FADE OUT.)
- **Shot** (CLOSE ON:)

**Features**:
- Auto-detect element type as user types
- Apply proper indentation and capitalization
- Tab/Enter to cycle through element types
- Keyboard shortcuts for each element type
- Templates for different script formats

**Formatting Rules**:
```
Scene Heading:    ALL CAPS, left margin
Action:           Left margin, normal case
Character:        Centered-ish (3.7" from left)
Dialogue:         Indented, below character
Parenthetical:    Indented more, in parentheses
Transition:       Right-aligned, ALL CAPS
```

### 2. Smart Script Navigation

**Description**: Navigate by scenes, characters, or dialogue

**Features**:
- Scene list view (all scene headings)
- Jump to any scene instantly
- Character list (all speaking characters)
- View all lines for specific character
- Search by dialogue content
- Page number navigation
- Script breakdown view

### 3. Character Tracking for Scripts

**Description**: Track which characters appear in which scenes

**Data Model**:
```swift
@Model
class ScriptCharacter {
    var id: UUID
    var name: String
    var role: CharacterRole      // lead, supporting, day player
    var description: String?     // Character breakdown
    var scenes: [Scene]          // Scenes where character appears
    var dialogueCount: Int       // Number of lines
    var firstAppearance: Scene?
    var costume: String?         // Costume notes
    var notes: String?           // Actor notes, backstory
}
```

**Features**:
- Auto-detect characters from script
- Character scene breakdown
- Dialogue count per character
- Character sides (all scenes for one character)
- Cast list generation

### 4. Scene Breakdown Tools

**Description**: Production breakdown for each scene

**Scene Metadata**:
- INT/EXT
- Day/Night
- Location name
- Page count
- Characters present
- Props needed
- Special requirements (stunts, VFX, etc.)
- Estimated shooting time

**Features**:
- Scene breakdown sheets
- Shooting schedule suggestions (group by location)
- Day/night scenes report
- Location list
- Props list
- Cast availability tracking

### 5. Revision Tracking (Script-Specific)

**Description**: Track script revisions with colored pages

**Features**:
- Revision colors (white, blue, pink, yellow, green, goldenrod, etc.)
- Revision marks (* in right margin for changes)
- Revision date tracking
- Compare revisions
- Lock previous revisions
- Generate revision report

**Industry Standard**: Each revision level has a specific color for printed pages

### 6. Dual Dialogue

**Description**: Format two characters speaking simultaneously

**Layout**:
```
      CHARACTER 1              CHARACTER 2
      Dialogue for             Dialogue for
      character 1              character 2
      continues...             continues...
```

**Implementation**: Special formatting mode for overlapping dialogue

### 7. Title Page & Cover Sheet

**Description**: Professional script title page

**Elements**:
- Script title (centered)
- Written by line
- Author name(s)
- Contact information (bottom left)
- Draft date (bottom right)
- Registration numbers (WGA, copyright)

**Templates**:
- Feature film title page
- TV episode title page
- Stage play title page

### 8. Page Count & Timing

**Description**: Estimate runtime from page count

**Rules of Thumb**:
- Feature screenplay: 1 page ≈ 1 minute
- TV hour-long: 45-50 pages ≈ 45 min
- TV half-hour: 22-25 pages ≈ 22 min
- Stage play: varies by format

**Features**:
- Real-time page count
- Estimated runtime
- Act break markers with timing
- Scene length analysis
- Pacing visualization

### 9. Script Export Formats

**Description**: Export in industry-standard formats

**Formats**:
- **PDF** - Industry standard, locked formatting
- **Final Draft (.fdx)** - For compatibility with Final Draft
- **Fountain** - Plain text screenplay format
- **Celtx** - For compatibility with Celtx
- **HTML** - For web preview

**Requirements**:
- Exact page breaks preserved
- Proper margins and spacing
- Font: Courier/Courier New 12pt (industry standard)
- Include scene numbers (optional)
- Include revision marks (optional)

### 10. Production Documents

**Description**: Generate documents for production team

**Documents**:
- **One-liner** - Single sentence per scene
- **Scene list** - All scenes with page counts
- **Character breakdown** - All characters with scene appearances
- **Location breakdown** - All locations needed
- **Day out of Days** - Actor schedule grid
- **Call sheet** (basic) - Who's needed when

### 11. Collaboration Features

**Description**: Share scripts and track notes

**Features**:
- Share script with production team
- Add production notes to scenes
- Lock script for filming (prevent changes)
- Distribute revised pages only
- Track who made which changes
- Comments on specific scenes/lines

**Privacy**: Team collaboration, not public sharing

### 12. Auto-Completion & Suggestions

**Description**: Speed up script writing with smart suggestions

**Features**:
- Character name auto-completion
- Location name auto-completion
- Consistent character name capitalization
- Suggest matching parentheticals
- Common transition phrases
- Learn from user's script vocabulary

---

## User Stories (Draft)

### US-011-001: Format Dialogue Automatically

**As a** screenwriter  
**I want to** type a character name and have it automatically center and format  
**So that** I don't have to manually adjust formatting

**Acceptance Criteria**:
- Type character name in ALL CAPS → Auto-centers
- Press Enter → Next line becomes dialogue (indented)
- Tab key cycles through element types
- Formatting matches industry standard

### US-011-002: Navigate by Scene

**As a** screenwriter  
**I want to** see a list of all my scenes and jump to any scene  
**So that** I can quickly navigate my 120-page script

**Acceptance Criteria**:
- Scene list shows all scene headings
- Click scene heading to jump to that scene
- Shows page number for each scene
- Indicates INT/EXT and DAY/NIGHT

### US-011-003: Generate Character Breakdown

**As a** screenwriter  
**I want to** export a list of all characters with their scenes  
**So that** I can share it with casting director

**Acceptance Criteria**:
- Lists all speaking characters
- Shows scenes where each character appears
- Includes dialogue line count
- Exports as PDF or CSV

### US-011-004: Export as PDF with Scene Numbers

**As a** screenwriter  
**I want to** export my script as PDF with scene numbers  
**So that** I can send it to production team

**Acceptance Criteria**:
- PDF exactly matches script format
- Scene numbers on left and right margins
- Proper page breaks (no orphaned dialogue)
- Courier 12pt font
- Exports within 30 seconds for 120-page script

---

## Technical Considerations

### Formatting Engine
- Custom NSTextView/UITextView for auto-formatting
- Paragraph styles for each script element
- Tab stops for precise indentation
- Widow/orphan control (keep dialogue together)

### Page Breaks
- Calculate page breaks based on courier 12pt metrics
- Never split dialogue across pages (move character name to next page)
- Never split scene heading from first action line
- Handle title page as separate page 1

### Export
- PDF generation with exact script spacing
- FDX (Final Draft XML) export for compatibility
- Fountain format for plain text scripts

### Performance
- Real-time formatting must be fast
- Smooth scrolling in long scripts (120+ pages)
- Quick scene list generation

---

## Data Model Extensions

```swift
// Script project type
extension Project {
    var scriptType: ScriptType?
    var logline: String?             // One-sentence summary
    var episodeNumber: Int?          // For TV scripts
    var seasonNumber: Int?           // For TV scripts
    var seriesTitle: String?         // For TV scripts
}

enum ScriptType: String, Codable {
    case feature              // Feature film
    case tvHour              // 1-hour TV episode
    case tvHalfHour          // 30-minute TV episode
    case pilot               // TV pilot
    case stagePlay
    case webSeries
}

// Script elements (stored as attributes in NSAttributedString)
enum ScriptElement {
    case sceneHeading
    case action
    case character
    case dialogue
    case parenthetical
    case transition
    case shot
    case general             // Default
}

// Scene data
@Model
class ScriptScene {
    var id: UUID
    var heading: String          // "INT. COFFEE SHOP - DAY"
    var intExt: IntExt
    var dayNight: DayNight
    var location: String
    var pageNumber: Int
    var characters: [ScriptCharacter]
    var estimatedTime: TimeInterval
    var notes: String?
}

enum IntExt { case interior, exterior }
enum DayNight { case day, night, dawn, dusk }
```

---

## Out of Scope

- ❌ Storyboarding tools
- ❌ Shot list generation
- ❌ Budgeting tools
- ❌ Casting management
- ❌ Production calendar/scheduling
- ❌ Script coverage / analysis
- ❌ Table reads / recording dialogue

---

## Dependencies

- **Feature 003**: Text file creation
- **Feature 005**: Advanced text formatting
- **Custom text engine**: For auto-formatting
- **PDF generation**: For exports
- **FDX library**: For Final Draft compatibility

---

## Success Metrics

- Formatting speed: instant element detection
- Export quality: 100% match to Final Draft output
- Navigation speed: jump to any scene < 1 second
- Page count accuracy: within 1 page of Final Draft
- Learning curve: proficient formatting in < 30 minutes

---

## Implementation Phases

### Phase 1: Core Formatting
- Script element detection and formatting
- Basic scene headings
- Character/dialogue formatting

### Phase 2: Navigation
- Scene list view
- Character tracking
- Quick navigation

### Phase 3: Production Tools
- Scene breakdown
- Character breakdown
- Export enhancements

### Phase 4: Advanced Features
- Revision tracking with colors
- Collaboration features
- Production document generation

---

## Related Resources

- BBC Writers Room Script Format Guide
- Final Draft software (competitive research)
- Fountain format specification: https://fountain.io/
- Screenwriting books: "The Screenwriter's Bible" by David Trottier

---

**Status**: 📋 Specification Draft  
**Next Steps**: Research auto-formatting algorithms, prototype element detection, test PDF export quality  
**Estimated Effort**: Large (8-10 weeks for core features)
