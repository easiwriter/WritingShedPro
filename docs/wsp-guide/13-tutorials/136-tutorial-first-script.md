# Tutorial: Writing Your First Script with DML

This tutorial walks you through writing a short script in Writing Shed Pro using Drama Markup Language (DML). You'll learn the basic markup, preview formatted output, switch between film and stage formats, and organize scenes into acts.

**Time**: 30–40 minutes  
**Project Type**: Drama  
**Difficulty**: Beginner

## What You'll Learn

- Creating a Drama project
- Writing with DML: scene headings, dialogue, parentheticals, stage directions, transitions
- Previewing formatted output
- Switching between Film and Stage format
- Organizing scenes into acts
- Viewing scenes grouped by act

## What Is DML?

Drama Markup Language (DML) is Writing Shed Pro's simple markup for scripts. You write plain text with a few special characters, and it renders as a properly formatted screenplay or stage play. The same source works for both formats — only the output styling changes.

## Step 1: Create a Drama Project

1. From the project list, tap **+**
2. Name it **"The Waiting Room"**
3. Select **Drama** as the project type
4. Optionally select a story structure (or leave as Freeform)
5. Tap **Create**

The project opens with Drama folders: Scenes, Acts, Plot Elements, Characters, Locations, and more.

## Step 2: Create Your First Scene

1. Open **Scenes**
2. Tap **+**
3. Name it: **"Opening"**
4. Tap **Create**

The scene opens in the editor. Unlike other project types, Drama scenes use DML markup.

## Step 3: Learn the DML Basics

Type the following into your scene. Each line type is explained below.

```
# Scene 1
@ INT. WAITING ROOM - DAY
= A sterile, fluorescent-lit room with plastic chairs. A clock ticks loudly.

> Two people sit at opposite ends. ANNA (30s, crisp suit, checking her phone) and BEN (40s, paint-stained jeans, fidgeting).

> The clock ticks. Beat.

BEN
(clearing his throat)
Been waiting long?

ANNA
(not looking up)
Depends what you mean by long.

BEN
I mean... hours? Minutes?

ANNA
(finally looks up)
I stopped counting.

> Ben shifts in his chair. The clock seems louder.

BEN
I'm Ben, by the way.

ANNA
I didn't ask.

~ CUT TO:
```

### What Each Marker Means

| Marker | Purpose | Example |
|--------|---------|---------|
| `#` | Scene heading / slug line | `# Scene 1` |
| `@` | Location line (INT./EXT.) | `@ INT. WAITING ROOM - DAY` |
| `=` | Scene description / setting | `= A sterile room...` |
| `>` | Stage direction / action | `> Two people sit...` |
| `NAME` | Character name (all caps on its own line) | `BEN` |
| `(text)` | Parenthetical (in brackets, after character name) | `(clearing his throat)` |
| Text after name | Dialogue lines | `Been waiting long?` |
| `~` | Transition | `~ CUT TO:` |

That's the core of DML. Six markers cover most script writing needs.

## Step 4: Preview Your Formatted Output

Now see how your markup looks as a proper script:

1. Tap the **Preview** toggle in the toolbar (the eye icon)
2. The raw DML transforms into formatted script output

In **Film format**, you'll see:
- Scene headings left-aligned and underlined
- Character names centered
- Dialogue in a narrow column
- Parentheticals indented under character names
- Transitions right-aligned

Toggle back to source view to continue editing.

## Step 5: Switch Between Film and Stage Format

The same DML produces different output depending on format:

### Switch Format
1. Open **Project Settings** (⚙️)
2. Find **Script Format**
3. Switch from **Film** to **Stage** (or vice versa)
4. Return to your scene and preview again

### Differences You'll See

| Element | Film Format | Stage Format |
|---------|-------------|-------------|
| Scene headings | INT./EXT. slug lines | ACT/Scene headings |
| Character names | Centered, caps | Left-aligned, caps |
| Dialogue | Narrow center column | Full-width |
| Stage directions | Full-width, italicized | Italicized, indented |
| Transitions | Right-aligned | Centered |

Both render from the same DML source, so you can write once and output in either format.

## Step 6: Write a Second Scene

1. Go back to **Scenes**
2. Tap **+**
3. Name it: **"The Reveal"**
4. Write:

```
# Scene 2
@ INT. WAITING ROOM - CONTINUOUS
= The same room. The clock has stopped.

> Anna stands and walks to the clock. She taps it. Nothing.

ANNA
(to herself)
That's odd.

BEN
It stopped about an hour ago. Maybe two. Hard to tell.

ANNA
And you didn't think to mention that?

BEN
(smiling)
I was waiting for the right moment.

> Anna looks at Ben properly for the first time. Something shifts.

ANNA
What are we waiting for, exactly?

BEN
(standing)
I was hoping you could tell me.

> They face each other. The fluorescent light flickers.

= BLACKOUT
```

### New Elements

- `= BLACKOUT` uses the scene description marker for a stage direction that ends the scene
- Dialogue flows naturally — just character name, optional parenthetical, then dialogue lines
- Continuous scene headings (`CONTINUOUS`) tell the reader we're in the same location

## Step 7: Create Acts and Organize Scenes

For longer scripts, you'll want to organize scenes into acts.

### Create Acts
1. Open the **Acts** folder
2. Tap **+**
3. Name it: **"Act I"**
4. Tap **Create**

### Assign Scenes to Acts
1. Open a scene's details
2. Tap **Act**
3. Select **"Act I"**

Assign both scenes to Act I. For a longer script, you might have:
- **Act I**: Setup and inciting incident
- **Act II**: Complications and rising action
- **Act III**: Climax and resolution

### Reorder Scenes Within Acts
1. Open an act
2. Tap **Edit**
3. Drag scenes into performance order
4. Tap **Done**

## Step 8: View Scenes Grouped by Act

In the main Scenes view:

1. Open **Scenes**
2. Scenes appear grouped under their assigned act in collapsible sections
3. Expand or collapse acts to focus on specific sections
4. Unassigned scenes appear separately

This view helps you see the overall structure of your script at a glance.

## Step 9: Add More DML Features

As your script grows, you'll want these additional DML features:

### Simultaneous Dialogue (Dual Column)
```
BEN                    | ANNA
I think we should —    | No, listen —
```

### Emphasis
```
BEN
I *really* don't think that's a good idea.
```

### Notes (Not Printed in Output)
```
// TODO: Add more tension to this exchange
```

### For the Full Reference
See **[DML Reference](../8-drama-features/84-dml-reference.md)** for every available markup option, including lyrics, sound effects, and more.

## Step 10: Export Your Script

1. Open **Export Options**
2. Select **PDF**
3. Choose your script format (Film or Stage)
4. Preview the output
5. Export

The PDF uses industry-standard formatting appropriate for the chosen format — ready for a table read, submission, or production.

## What You've Learned

- Creating a Drama project for script writing
- The six core DML markers: `#`, `@`, `=`, `>`, `~`, and character names
- Previewing formatted output from DML source
- Switching between Film and Stage format
- Organizing scenes into acts
- Viewing scenes grouped by act

## DML Quick Reference

| Marker | Purpose |
|--------|---------|
| `#` | Scene heading |
| `@` | Location |
| `=` | Setting / scene description |
| `>` | Stage direction / action |
| `CHARACTER` | Character name (caps, own line) |
| `(text)` | Parenthetical |
| `~` | Transition |
| `//` | Note (hidden in output) |
| `*text*` | Emphasis |

## What's Next

- **[DML Reference](../8-drama-features/84-dml-reference.md)** — Complete markup reference
- **[Film vs Stage Formats](../8-drama-features/83-film-vs-stage-formats.md)** — Detailed format comparison
- **[Drama Mode Overview](../8-drama-features/81-drama-mode-overview.md)** — Full feature reference
- **[Tutorial: Formatting a Professional Manuscript](138-tutorial-professional-manuscript.md)** — Advanced export for scripts

---
