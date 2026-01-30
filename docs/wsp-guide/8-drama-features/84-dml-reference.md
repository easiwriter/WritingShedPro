# DML Reference

Drama Markup Language (DML) is Writing Shed Pro's lightweight markup for script writing. This reference covers all DML syntax elements.

## Design Philosophy

DML is designed to be:
- **Human-readable**: Easy to read and write
- **Minimal**: Common elements require little decoration
- **Format-agnostic**: Same source works for film and stage
- **Intuitive**: Mirrors how you'd naturally write

## Quick Reference

| Element | Syntax | Example |
|---------|--------|---------|
| Scene Heading | `#` | `# INT. OFFICE - DAY` |
| Character | ALL CAPS | `JOHN` |
| Dialogue | Lines after character | `Hello there.` |
| Parenthetical | `( )` after character | `(whispering)` |
| Action | `>` | `> John enters.` |
| Transition | `>>` | `>> CUT TO:` |
| Location | `@` | `@ LOCATION: Office` |
| Time/Atmosphere | `=` | `= Night, rain` |
| Note | `[[ ]]` | `[[Check this scene]]` |

## Detailed Syntax

### Scene Headings

Start a line with `#` for scene headings:

```
# INT. COFFEE SHOP - DAY
# EXT. BEACH - SUNSET
# ACT II, Scene 3
```

**Film format**: Include INT./EXT., location, time
**Stage format**: Use ACT/Scene notation

### Character Names

Write character names in ALL CAPS on their own line:

```
JOHN
MARY
DR. SMITH
OFFICER #1
```

Everything following a character name (until another element) is their dialogue.

### Dialogue

Lines following a character name are dialogue:

```
JOHN
I've been thinking about what you said.
And I think you're right.
```

Multiple lines of dialogue are fine—they'll be formatted together.

### Parentheticals

Acting directions go in parentheses after the character name:

```
JOHN
(hesitantly)
I don't know about this.

MARY
(turning away)
Neither do I.
```

Parentheticals can also appear mid-dialogue:

```
JOHN
I think I love you.
(beat)
No, I know I do.
```

### Action / Stage Directions

Start with `>` for action or stage directions:

```
> John crosses to the window and looks out at the rain.
> Mary enters from the kitchen, carrying a tray.
> The lights dim. Thunder rumbles in the distance.
```

These render as:
- Film: Full-width action paragraphs
- Stage: Stage directions (often italicized)

### Transitions

Start with `>>` for transitions:

```
>> CUT TO:
>> FADE OUT
>> DISSOLVE TO:
>> BLACKOUT
```

These render as:
- Film: Right-aligned transitions
- Stage: Theatrical transitions (centered or as appropriate)

### Location Metadata

Use `@` for location information:

```
@ LOCATION: Sarah's Apartment
@ LOCATION: The Beach House
```

This helps DML construct scene headings, especially for stage format.

### Time/Atmosphere

Use `=` for time of day and atmospheric conditions:

```
= Day
= Night, stormy
= Late afternoon, golden light
= Morning, mist
```

Combined with location:
```
@ LOCATION: Office
= Night, empty building
```

Film renders as: `INT. OFFICE - NIGHT`
Stage renders as: `(An office. Night. The building is empty.)`

### Notes

Writer's notes that don't render in output:

```
[[Remember to add more tension here]]
[[Check with director about this scene]]
[[TODO: Research police procedures]]
```

Notes are for your reference only—they won't appear in exports.

## Complete Example

```dml
# ACT I, Scene 1
@ LOCATION: Living Room
= Night, raining

> A modest living room. Rain streaks the windows. JOHN stands 
> near the window, agitated. A half-empty glass of whiskey 
> sits on the side table.

JOHN
(to himself)
She should be here by now.

> He checks his watch, then resumes pacing.

[[Consider cutting the whiskey reference]]

> The door opens. MARY enters, soaking wet.

MARY
(shaking off rain)
The roads are terrible.

JOHN
I was worried.

MARY
(softening)
I know. I'm sorry.

> She crosses to him. They embrace.

>> BLACKOUT

# ACT I, Scene 2
@ LOCATION: Kitchen
= The next morning

> Bright sunlight. MARY makes coffee. JOHN enters in a robe.

JOHN
Did you sleep?

MARY
Not really.
(beat)
We need to talk about last night.

>> END OF ACT ONE
```

## Rendering Differences

### Film Output
The example above renders with:
- Scene headings like `INT. LIVING ROOM - NIGHT`
- Centered character names
- Specific dialogue margins
- Right-aligned transitions

### Stage Output
The same source renders with:
- Scene headings like `ACT I, Scene 1`
- Stage directions in parentheses or italics
- Different margin conventions
- Theatrical transitions

## Tips for Writing DML

### Keep It Simple
DML is meant to be invisible. Write naturally—don't over-mark.

### Blank Lines
Use blank lines to separate elements:
- Between speakers
- Between action and dialogue
- Before and after transitions

### Consistency
Choose conventions and stick with them:
- Parenthetical style
- Action line detail level
- Note format

### Read Your Output
Check the rendered preview often. Adjust if elements don't render as expected.

## Common Mistakes

### Forgetting `>` for Action
```
Wrong:
John enters.

Right:
> John enters.
```

### Character Name Not in Caps
```
Wrong:
John
I'm here.

Right:
JOHN
I'm here.
```

### Missing Blank Lines
```
Wrong:
JOHN
Hello.
MARY
Hi.

Right:
JOHN
Hello.

MARY
Hi.
```

## See Also
- [Drama Mode Overview](01-drama-mode-overview.md)
- [Script Formatting](02-script-formatting.md)
- [Film vs Stage Formats](03-film-vs-stage-formats.md)
- [DML Quick Reference](../09-reference/02-dml-quick-reference.md)

---
