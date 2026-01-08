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

<!-- Additional requirements to be completed after overview -->

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
