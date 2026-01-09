# Drama Markup Language (DML) Reference

## Film Scripts vs Play Scripts - Key Differences

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

```
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
