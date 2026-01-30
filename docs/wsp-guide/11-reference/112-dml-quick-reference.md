# DML Quick Reference

Quick reference for Drama Markup Language (DML) used in Drama projects.

## Basic Structure

```
# ACT ONE

## Scene 1

INT. COFFEE SHOP - DAY

> The shop is busy. EMMA, 30s, sits at a corner table.

EMMA
(nervously)
Is this seat taken?

DAVID
No, please. Sit.

> He gestures to the empty chair.
```

## Element Prefixes

| Prefix | Element | Example |
|--------|---------|---------|
| `#` | Act heading | `# ACT ONE` |
| `##` | Scene heading | `## Scene 1` |
| (none) | Scene heading (Film) | `INT. OFFICE - DAY` |
| (none) | Character name | `DAVID` |
| `>` | Action/Stage direction | `> She exits.` |
| `()` | Parenthetical | `(softly)` |
| (none) | Dialogue | Plain text after character name |

## Scene Headings

### Film Format
```
INT. LOCATION - TIME
EXT. LOCATION - TIME
INT./EXT. LOCATION - TIME
```

Examples:
```
INT. LIVING ROOM - NIGHT
EXT. BEACH - SUNSET
INT./EXT. CAR - DAY
```

### Stage Format
```
## Scene 1
## Scene 2: The Reveal
```

## Character Names

Write in ALL CAPS on their own line:

```
EMMA
DAVID
DOCTOR MILLER
VOICE (O.S.)
```

### Character Extensions
```
EMMA (V.O.)      Voice over
EMMA (O.S.)      Off screen
EMMA (CONT'D)    Continuing
EMMA (O.C.)      Off camera
```

## Dialogue

Plain text following a character name:

```
EMMA
I never thought I'd see you again.
```

Multi-line:
```
DAVID
You know, I've been thinking about that day.
The way the light came through the window.
It changed everything for me.
```

## Parentheticals

In parentheses, on their own line:

```
EMMA
(hesitant)
Are you sure about this?

DAVID
(laughing, then serious)
No. But when has that ever stopped us?
```

## Action Lines

Prefix with `>`:

```
> She sets down her coffee cup.

> DAVID enters through the front door. He's soaking wet.

> Beat.

> They stare at each other.
```

## Transitions

Film transitions:

```
CUT TO:
DISSOLVE TO:
FADE OUT.
FADE IN:
SMASH CUT TO:
```

## Special Elements

### Montage
```
MONTAGE:

> EMMA jogs through the park.

> DAVID works late at the office.

> EMMA stares at her phone.

END MONTAGE.
```

### Flashback
```
FLASHBACK:

INT. CHILDHOOD HOME - DAY (1995)

> Young EMMA opens a gift.

END FLASHBACK.
```

### Intercut
```
INTERCUT - PHONE CONVERSATION

INT. EMMA'S APARTMENT - NIGHT

EMMA
Where are you?

INT. AIRPORT - CONTINUOUS

DAVID
About to board. I'll be home soon.
```

## Song Lyrics (Stage)

```
EMMA
(singing)
♪ When the morning comes around
♪ And the sky is turning gold
♪ I'll remember what we found
♪ And the stories left untold ♪
```

## Stage Directions (Stage)

Detailed directions for stage:

```
> SL: Sofa and coffee table. SR: Kitchen counter with stools. 
> UC: Large window showing city skyline (projected).
```

Abbreviations:
- SL: Stage Left
- SR: Stage Right
- UC: Upstage Center
- DC: Downstage Center

## Common Patterns

### Character Introduction
```
> EMMA (30s, nervous energy, vintage dress) enters with a stack of files.
```

### Quick Dialogue Exchange
```
EMMA
Did you take it?

DAVID
Take what?

EMMA
You know what.
```

### Dramatic Pause
```
DAVID
I think we should—

> Long pause.

DAVID (CONT'D)
—never mind.
```

## Film vs Stage Output

Same DML produces different formatting:

### Film Output
- Scene headings in CAPS
- Technical transitions
- Camera-oriented terminology

### Stage Output
- Act/Scene structure emphasized
- Stage direction styling
- Theatre conventions

## Common Mistakes

| Wrong | Right |
|-------|-------|
| `Emma` (lowercase) | `EMMA` |
| `She exits` (no prefix) | `> She exits.` |
| `[softly]` | `(softly)` |
| `ACT 1` | `# ACT ONE` |

## Tips

1. **Character names**: Always CAPS
2. **Action lines**: Always start with `>`
3. **Keep it simple**: Don't over-format
4. **Preview often**: Check both Film and Stage output
5. **Consistency**: Same format throughout

## See Also
- [DML Reference](../08-drama-features/04-dml-reference.md)
- [Script Formatting](../08-drama-features/02-script-formatting.md)
- [Film vs Stage](../08-drama-features/03-film-vs-stage.md)

---
