# Film vs Stage Formats

Writing Shed Pro supports both film/screenplay and stage play formats. This guide explains the differences and when to use each.

## Key Differences

| Aspect | Film/Screenplay | Stage Play |
|--------|-----------------|------------|
| Scene Headings | INT./EXT. LOCATION - TIME | ACT I, Scene 2 |
| Camera | Sometimes referenced | Never used |
| Action | What camera sees | Stage movement and set |
| Margins | Specific industry standard | More flexible |
| Page = Time | ~1 page = 1 minute | Less precise |
| Transitions | CUT TO:, FADE OUT | BLACKOUT, LIGHTS UP |

## Film/Screenplay Format

### When to Use
- Writing for movies
- Television scripts
- Web series
- Video content

### Scene Headings
Always include:
- INT. (interior) or EXT. (exterior)
- LOCATION
- TIME OF DAY

```
INT. COFFEE SHOP - DAY
EXT. CITY STREET - NIGHT
INT./EXT. CAR (MOVING) - CONTINUOUS
```

### Action Lines
Describe what the camera sees:
- Present tense
- Visual focus
- Minimal internal thoughts

```
> John stares at the letter. His hands tremble.
```

### Dialogue
Centered with specific margins:
```
                         JOHN
              (reading)
         "I'm sorry. I can't do this anymore."
```

### Transitions
Right-aligned:
```
                                              CUT TO:
                                              FADE OUT.
                                              DISSOLVE TO:
```

### Camera Directions (Use Sparingly)
```
> CLOSE ON: John's face as he reads.
> ANGLE ON: The letter falling to the floor.
```

Most spec scripts minimize these—directors prefer to make their own choices.

## Stage Play Format

### When to Use
- Theater productions
- Radio plays
- Readings and performances
- Educational theater

### Scene Headings
Act and scene structure:
```
ACT I
Scene 1

ACT II, Scene 3

EPILOGUE
```

### Stage Directions
Describe stage action and set:
- Often italicized or in parentheses
- Describes what audience sees
- Includes set information

```
> (A modest living room. Evening. Rain is heard outside. JOHN stands by the window, his back to the audience.)
```

### Dialogue
Varies by convention:
```
JOHN
    I can't stay here any longer.

MARY
    (entering from upstage)
    Then don't.
```

### Transitions
Theatrical terms:
```
>> BLACKOUT
>> LIGHTS UP
>> CURTAIN
```

## Writing for Both

DML lets you write once and render in either format:

### Common Elements
- Character names (work in both)
- Dialogue (works in both)
- Basic action/directions

### Format-Specific Elements
Some things translate differently:

#### Locations
DML:
```
@ LOCATION: Coffee Shop
= Day
```

Film renders as: `INT. COFFEE SHOP - DAY`
Stage renders as: `(A coffee shop. Day.)`

#### Transitions
DML:
```
>> CUT TO:
```

Film renders as: right-aligned `CUT TO:`
Stage might render as: `(Transition to next scene)` or be adapted

### Testing Both Formats
1. Write your scene in DML
2. Preview in Film format
3. Switch to Stage format
4. Adjust source if needed for both

## Choosing Your Format

### Write for Film When:
- Targeting movie/TV production
- Story relies on visual elements
- Camera work is important
- Quick cuts and montages

### Write for Stage When:
- Targeting theater production
- Story works with limited settings
- Dialogue is primary
- Live performance suits the story

### Hybrid Projects
Some stories work both ways:
- Write in DML
- Export for primary target
- Adapt for secondary format

## Technical Differences

### Page Count
- Film: 1 page ≈ 1 minute (important for industry)
- Stage: Relationship varies (less critical)

### Action Line Length
- Film: Keep brief, visual, specific
- Stage: Can include more atmosphere

### Parentheticals
- Film: Very brief ("(whispers)")
- Stage: May be more detailed ("(crossing to the window, looking out)")

### Sound and Music
- Film: Minimal (sound designer's job)
- Stage: Often included in directions

## Industry Standards

### Film Resources
- Standard screenplay format guides
- Specific margin measurements
- Font requirements (usually Courier 12pt)

### Stage Resources
- Varies more by tradition
- Different standards for different theaters
- Often more flexible than film

## See Also
- [Drama Mode Overview](81-drama-mode-overview.md)
- [Script Formatting](82-script-formatting.md)
- [DML Reference](84-dml-reference.md)

---
