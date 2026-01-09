# Feature 023: Smart Drama Creation

**Status**: Draft  
**Priority**: High  
**Estimated Effort**: TBD  
**Dependencies**: 001-project-management-ios-macos  
**Created**: 2026-01-02

## Overview

This type of project is fundamentally the same as Long Fiction, the main difference being the content of the scenes, which need to conform to the dialogue format described in this spec.

## Script Dialogue Formatting Conventions

### Standard Script Dialogue Format

There are established conventions for script dialogue:

- **Character Name**: Centered and in ALL CAPS above the dialogue
- **Dialogue**: Centered below the character name, narrower margins than action
- **Parentheticals**: Brief acting directions in parentheses between character name and dialogue (e.g., "(sarcastically)")

```
                         JOHN
              (hesitantly)
         I don't think we should go.

                         MARY
         We don't have a choice.
```

### Film Scripts vs Play Scripts - Key Differences

| Aspect | Film/Screenplay | Stage Play |
|--------|-----------------|------------|
| **Scene Headings** | INT./EXT. LOCATION - TIME (e.g., `INT. COFFEE SHOP - DAY`) | Simple act/scene numbers (e.g., `ACT I, Scene 2`) |
| **Action/Stage Directions** | Present tense, describes what camera sees | Italicized, describes stage movement and set |
| **Margins** | Dialogue ~2.5" from left, action full width | Dialogue often indented, stage directions in brackets or italics |
| **Page = Time** | 1 page ≈ 1 minute of screen time | Less precise relationship |
| **Camera Directions** | Sometimes included (CLOSE ON, POV) | Never used |
| **Set Descriptions** | Minimal, visual focus | More detailed (audience must imagine) |
| **Transitions** | CUT TO:, FADE OUT, DISSOLVE | Typically just BLACKOUT or LIGHTS UP |

### Example - Film/Screenplay Format

```
INT. LIVING ROOM - NIGHT

JOHN paces near the window. Rain streaks the glass.

                         JOHN
         She's not coming, is she?
```

### Example - Stage Play Format

```
ACT I, Scene 1

(A modest living room. JOHN stands by the window, 
agitated. Sound of rain.)

JOHN
    She's not coming, is she?
```

---

## Drama Markup Language (DML)

Scenes in Drama projects use a lightweight markup language that separates content from presentation. The same source can be rendered as Film/Screenplay format or Stage Play format based on project settings.

### Design Principles

1. **Human-readable source** - Writers can read and edit raw markup naturally
2. **Minimal syntax** - Common elements require minimal decoration
3. **Format-agnostic** - Same content renders appropriately for film or stage
4. **Industry-compatible** - Export to standard formats (Fountain, FDX) is straightforward

### Element Syntax

| Element | Syntax | Example |
|---------|--------|---------|
| **Scene Heading** | Line starting with `#` | `# ACT I, Scene 2` or `# INT. COFFEE SHOP - DAY` |
| **Character** | ALL CAPS line (auto-detected) | `JOHN` |
| **Dialogue** | Lines following a character | `I don't think we should go.` |
| **Parenthetical** | Text in parentheses after character | `(hesitantly)` |
| **Action/Direction** | Line starting with `>` | `> John paces near the window.` |
| **Transition** | Line starting with `>>` | `>> CUT TO:` or `>> FADE OUT` |
| **Note** | Line starting with `[[` and ending with `]]` | `[[Remember to add tension here]]` |
| **Location Meta** | Line starting with `@` | `@ LOCATION: Coffee Shop` |
| **Time/Atmosphere** | Line starting with `=` | `= Night, raining` |

### Complete Example - Source

```dml
# ACT I, Scene 1
@ LOCATION: Living Room
= Night, raining

> A modest living room. Rain streaks the window. JOHN stands nearby, agitated.

JOHN
(hesitantly)
I don't think we should go.

MARY
We don't have a choice.

> Mary crosses to the door. John follows.

JOHN
Wait—

>> BLACKOUT
```

### Rendering - Film/Screenplay Format

When project type is set to **Film/Screenplay**, the above renders as:

```
INT. LIVING ROOM - NIGHT

A modest living room. Rain streaks the window. JOHN stands
nearby, agitated.

                         JOHN
              (hesitantly)
         I don't think we should go.

                         MARY
         We don't have a choice.

Mary crosses to the door. John follows.

                         JOHN
         Wait—

                                                        CUT TO:
```

**Film rendering rules:**
- Scene heading constructed from Location + Time metadata (or used verbatim if INT./EXT. format)
- Action/directions at full width, present tense
- Character names centered, ALL CAPS
- Dialogue centered with narrower margins (~2.5" indent)
- Parentheticals centered between character and dialogue
- Transitions right-aligned

### Rendering - Stage Play Format

When project type is set to **Stage Play**, the same source renders as:

```
ACT I, Scene 1

(A modest living room. Rain streaks the window. 
JOHN stands nearby, agitated.)

JOHN
    (hesitantly)
    I don't think we should go.

MARY
    We don't have a choice.

(Mary crosses to the door. John follows.)

JOHN
    Wait—

(BLACKOUT)
```

**Stage rendering rules:**
- Scene heading used verbatim (ACT/Scene format)
- Stage directions in parentheses, often italicized
- Character names left-aligned, ALL CAPS
- Dialogue indented below character name
- Parentheticals inline with dialogue
- Transitions become stage directions (BLACKOUT, LIGHTS UP)

### View Modes

The editor provides three view modes, toggled via toolbar button:

| Mode | Description | Use Case |
|------|-------------|----------|
| **Source** | Raw DML markup | Writing and editing |
| **Formatted** | Live preview with proper styling | Review during writing |
| **Print Preview** | Paginated, industry-standard layout | Final review before export |

### Parser Rules

1. **Blank lines** separate elements; consecutive non-blank lines after a character are dialogue
2. **Character detection**: A line is a character name if:
   - It is ALL CAPS
   - It is not preceded by `>`, `>>`, `#`, `@`, `=`, or `[[`
   - It is followed by dialogue or parenthetical
3. **Parentheticals** must immediately follow a character name (same line or next line)
4. **Notes** (`[[...]]`) are stripped from rendered output but visible in Source mode
5. **Escaped prefixes**: Use `\#`, `\>`, etc. if literal text must start with a reserved character

### Metadata Handling

The `@` and `=` lines capture structured metadata that can be used for:
- Automatic scene heading generation (Film mode)
- Scene breakdown reports
- Location/time tracking across the script
- Smart scene list with filtering

### Import/Export

| Format | Import | Export |
|--------|--------|--------|
| **Fountain (.fountain)** | ✓ Maps to DML elements | ✓ Full support |
| **Final Draft (.fdx)** | ✓ XML parsing | ✓ XML generation |
| **PDF** | — | ✓ Industry-standard pagination |
| **Plain Text** | ✓ Best-effort parsing | ✓ Formatted output |

---

## User Stories

<!-- To be completed after overview -->

## Functional Requirements

### FR1: Folder Structure

**Drama Projects:**
- Section 1 - Story Structure: Manuscript, Acts, Scenes, Characters, Locations, Plot
- Section 2 - Organization & Support: Collections, Submissions, Research
- Section 3 - Publications: Publishers, Agents, Other
- Section 4 - System: Trash

**Display Order:** Manuscript, Acts, Scenes, Characters, Locations, Plot // Collections, Submissions, Research // Publishers, Agents, Other // Trash

*Note: Workflow status (Draft, Ready, Set Aside) is a property on individual files, not separate folders.*

### FR2: Drama Scene Editor

The scene editor for drama projects uses DML (Drama Markup Language) with three view modes:

1. **Source Mode**: Raw DML markup with syntax highlighting for editing
2. **Formatted Mode**: Live preview rendered according to script type (Film/Stage)
3. **Print Preview Mode**: Paginated display matching industry-standard formatting

### FR3: Script Type Toggle

Each drama project stores a script type preference (Film or Stage) that determines:
- How DML elements are rendered
- Margin and alignment rules applied
- Transition formatting

### FR4: DML Toolbar

A toolbar provides quick insertion of DML elements:
- Scene Heading (`#`)
- Action/Stage Direction (`>`)
- Character (ALL CAPS auto-detection)
- Parenthetical (`()`)
- Transition (`>>`)
- Note (`[[]]`)
- Location metadata (`@`)
- Time metadata (`=`)

### FR5: Fountain Import/Export

Support for Fountain format (.fountain) enables:
- Import from Final Draft, Highland, and other screenplay software
- Export for industry-standard submission

---

## Implementation Status

### Completed Files

| File | Purpose |
|------|---------|
| `Drama/DramaMarkupTypes.swift` | Enums and type definitions for DML |
| `Drama/DramaMarkupParser.swift` | Parses DML source to structured elements |
| `Drama/DramaMarkupRenderer.swift` | Renders DML to styled NSAttributedString |
| `Drama/DramaSceneEditorView.swift` | SwiftUI editor with mode toggle |
| `Drama/DramaMarkupToolbar.swift` | Quick-insert toolbar for DML elements |
| `Drama/FountainConverter.swift` | Import/export Fountain format |

### Model Changes

- Added `dramaScriptTypeRaw` property to `Project` model in `BaseModels.swift`
- Added localization strings in `Localizable.strings`

### Next Steps

1. Add Drama folder to Xcode project (drag into project navigator)
2. Integrate `DramaSceneEditorView` with navigation flow for drama projects
3. Add Fountain import/export to file menu
4. Implement Final Draft (.fdx) XML import/export
5. Add PDF export with proper screenplay pagination

---

## Non-Functional Requirements

<!-- To be completed after overview -->

## Key Entities

<!-- To be completed after overview -->

## Edge Cases

<!-- To be completed after overview -->

## Success Criteria

<!-- To be completed after overview -->

## Assumptions

<!-- To be completed after overview -->
