# Script Formatting

Writing Shed Pro handles script formatting automatically through Drama Markup Language (DML). This guide explains how your writing becomes professionally formatted scripts.

## Automatic Formatting

When you write in DML:
1. You focus on content (dialogue, action, scene headings)
2. Writing Shed Pro applies industry-standard formatting
3. Output matches professional script conventions

### What Gets Formatted
- **Character names**: Centered, uppercase
- **Dialogue**: Specific margins, proper spacing
- **Parentheticals**: Centered, between name and dialogue
- **Action/directions**: Full width or indented (by format)
- **Scene headings**: Proper capitalization and spacing
- **Transitions**: Right-aligned (film) or centered (stage)

## Script Elements

### Scene Headings
Begin with `#`:
```
# INT. COFFEE SHOP - DAY
```

For stage plays:
```
# ACT II, Scene 3
```

### Character Names
Write in ALL CAPS on their own line:
```
JOHN
```

The character speaks the following lines until another character or element appears.

### Dialogue
Lines following a character name are dialogue:
```
JOHN
I've been waiting for this moment.
```

### Parentheticals
Acting directions in parentheses:
```
JOHN
(softly)
I've been waiting for this moment.
```

### Action/Stage Directions
Begin with `>`:
```
> John crosses to the window and stares out at the rain.
```

### Transitions
Begin with `>>`:
```
>> CUT TO:
>> FADE OUT
```

## Format-Specific Output

### Film/Screenplay Rendering
```
INT. COFFEE SHOP - DAY

John sits at a corner table, nursing a cold coffee.

                         JOHN
              (softly)
         I've been waiting for this moment.

                                              CUT TO:
```

### Stage Play Rendering
```
ACT II, Scene 3

(A coffee shop. JOHN sits at a corner table.)

JOHN
    (softly)
I've been waiting for this moment.

                    BLACKOUT
```

## Formatting Rules

### Dialogue Margins
- Film: ~2.5 inches from left margin
- Stage: Varies by convention
- Automatically applied by Writing Shed Pro

### Character Name Positioning
- Film: Centered
- Stage: Left-aligned or centered (by convention)
- Uppercase in both formats

### Action Line Width
- Film: Full page width
- Stage: Often indented, may be italicized
- Present tense in both

### Page = Time (Film)
In screenplays, roughly 1 page = 1 minute of screen time. This helps estimate runtime.

## Customizing Format

While DML provides defaults, you can adjust:

### Stylesheet Settings
- Font choices (Courier is traditional for film)
- Margins and spacing
- Character name styling

### Project Settings
- Default format (Film or Stage)
- Header/footer content
- Page numbering

## Best Practices

### Be Consistent
Use the same conventions throughout your script:
- Scene heading format
- Parenthetical usage
- Transition styles

### Keep Action Brief
Action lines should be concise:
- ✓ "John enters."
- ✗ "John slowly walks into the room, his eyes scanning every corner as if looking for something he lost long ago..."

### Use Parentheticals Sparingly
Only when truly needed:
- ✓ "(whispering)" for unexpected delivery
- ✗ "(angrily)" when the dialogue makes it obvious

### Format for Your Audience
- Spec scripts: Minimal formatting, easy read
- Shooting scripts: May include more technical detail
- Stage scripts: Follow theater conventions

## Preview and Export

### Checking Your Format
1. Toggle to Preview mode
2. Review formatted output
3. Check all elements appear correctly

### Exporting
1. Choose PDF or print
2. Script renders in selected format
3. Professional output ready for sharing

## Troubleshooting Format

### Character Names Not Formatting
- Ensure they're on their own line
- Write in ALL CAPS
- No punctuation after the name

### Dialogue Running Together
- Ensure blank lines between speakers
- Check for stray characters

### Scene Headings Not Working
- Start the line with `#`
- Include location and time for film format

### Weird Spacing
- Check your DML source
- Look for extra blank lines
- Review parenthetical placement

## See Also
- [Drama Mode Overview](01-drama-mode-overview.md)
- [Film vs Stage Formats](03-film-vs-stage-formats.md)
- [DML Reference](04-dml-reference.md)
