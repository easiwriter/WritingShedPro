# Writing Shed Pro — Support Knowledge Base

Extracted from the in-app user guide. For use by support agents answering user questions.

---

## 1. APP OVERVIEW

- **Writing Shed Pro** is a professional creative writing app for iPhone, iPad, and Mac (Mac Catalyst).
- **System requirements**: iOS 17+, iPadOS 17+, macOS 14 (Sonoma)+.
- **Purchase model**: One-time in-app purchase (no subscription). Free trial with file limit.
- **Universal**: Same app across iPhone, iPad, and Mac. UI adapts to each platform.
- **Data storage**: All projects stored in iCloud Drive. Auto-save. Works offline (changes queue for sync).
- **Privacy**: The developer does not read, analyze, or share user content. Diagnostic logs never contain document content.

---

## 2. PROJECT TYPES

Four project types. **Cannot be changed after creation** — user must copy content to a new project of a different type.

| Type | Purpose | Special Tools |
|------|---------|---------------|
| **Prose** | Essays, articles, general writing | Sections for grouping files |
| **Poetry** | Poems, verse | Syllable counting, rhyme detection, stress analysis, 30+ form templates, verse highlighting, collections |
| **Fiction** | Novel, Short Fiction, Verse Novel | Chapters/Books/Stories, Scenes/Episodes, Plot Elements, Characters, Locations, Story Structures |
| **Drama** | Screenplays, stage plays | DML (Drama Markup Language), Film/Stage format toggle, Acts/Scenes, Story Structures |

### Fiction Sub-types
- **Novel**: Chapters → Scenes
- **Short Fiction**: Stories → Scenes
- **Verse Novel**: Books → Episodes (uses poetry editor)

### Story Structures (Fiction & Drama)
- **Freeform**: No predefined stages
- **Three-Act Structure**: Setup, Confrontation, Resolution
- **Monomyth (Vogler)**: 12 stages (Ordinary World, Call to Adventure, etc.)

---

## 3. WORKFLOW & FILE STATUSES

Files progress through statuses:
- **Draft**: Work in progress (default)
- **Ready**: Finished work
- **Set Aside**: Inactive but preserved
- **Trash**: Deleted (recoverable until emptied)
- **Published**: For tracking published work

Poetry and Short Fiction also support: **Collections**, **Publications**, **Submissions**.

---

## 4. iCLOUD SYNC

- Must enable iCloud Drive in device Settings > Apple ID > iCloud > iCloud Drive.
- Syncs automatically across all devices signed into the same Apple ID.
- **Auto-save**: Constant. No need to manually save (⌘S forces immediate sync).
- **Offline support**: Full editing offline; changes sync when reconnected.
- **Conflict resolution**: Most recent version wins; both versions are preserved.
- **First sync**: May take time for large projects. Be patient.
- **Troubleshooting sync**:
  1. Check internet on both devices
  2. Ensure iCloud is enabled and not full
  3. Verify same Apple ID on both devices
  4. Wait a few minutes — sync isn't instant
  5. Force quit and reopen the app
  6. Check iCloud status at apple.com/support/systemstatus

---

## 5. THE EDITOR

### Rich Text Features
- Bold (⌘B), Italic (⌘I), Underline (⌘U), Strikethrough
- Paragraph styles: Body, Heading 1–3, Subheadline, Caption, Footnote, Block Quote, Large Title, Lists (bulleted/numbered)
- Undo (⌘Z) / Redo (⌘⇧Z)
- Zoom: ⌘+ / ⌘- / ⌘0 (reset), pinch on touch
- Auto-save (constant)

### Markdown Mode
- Toggle between Rich Text and Markdown via toolbar button (# icon / document icon)
- Markdown mode shows an indicator bar at the bottom
- **Not available** for Poetry or Drama projects
- Standard Markdown syntax supported
- Toggling converts content between formats (some complex formatting may simplify)

### Insert Menu Items
Image, Footnote, Endnote, Comment, Glossary Term, Reference, Index Entry, Figure Reference, List, Page Break, Mark Section (poetry only)

### Images
- Insert from Photos, Files, or Camera
- Settings: Scale, Alignment (left/center/right), Caption (with optional prefix)
- Captions appear in the List of Figures (back matter)

### Footnotes
- Auto-numbered markers inserted at cursor position
- Content appears at page bottom in PDF export
- Can be configured as endnotes (collected at end) in export settings
- Footnote numbering: per file or continuous across project

### Comments
- Non-printing revision notes
- Inserted via ⌘⇧C or Insert menu
- Visible in editor, excluded from export/print

### Word Count & Statistics
- Displayed in toolbar/status area
- Counts words, characters, paragraphs
- Footnotes/comments may be counted separately

### File Versions
- Create snapshots of a file at any point
- Navigate between versions
- Submission system records which version was sent
- Versions locked after submission

---

## 6. PROSE FEATURES

- **Sections**: Group related files (like chapters for non-fiction)
- Files appear grouped by section in collapsible views
- Sections can be reordered; files within sections can be reordered
- Sections added to Body Matter for manuscript assembly
- Best for: user guides, essay collections, multi-part articles, research projects, memoirs

---

## 7. POETRY FEATURES

### Syllable Counting
- Real-time count per line
- Powered by CMU Pronouncing Dictionary (US English) and UK pronunciation data
- US/UK dialect selection affects counts (e.g., "fire": 1 syllable US, 2 syllables UK)
- Works for standard English; proper nouns and unusual words may need manual counting

### Stress Analysis
- Shows stressed/unstressed syllable patterns
- Helps verify meter (e.g., iambic pentameter)
- Bold/highlighted display for stressed syllables

### Rhyme Tools
- Select a word to see rhyming suggestions
- Detects perfect rhymes, near rhymes, slant rhymes
- Based on CMU dictionary phonetic data
- Proper nouns may not be in the dictionary

### Verse Highlighting
- Color-codes rhyme groups
- Shows green/warning indicators for syllable count compliance
- Visual overview of form structure

### Forms & Templates (30+)
Haiku, Tanka, Senryū, Cinquain, Shakespearean Sonnet, Petrarchan Sonnet, Spenserian Sonnet, Villanelle, Pantoum, Sestina, Ghazal, Limerick, Ballad, Rondeau, Ballade, Triolet, Cywydd, Englyn, Ottava Rima, Terza Rima, Spenserian Stanza, Free Verse, Prose Poetry, and more.

### Custom Forms
Create with: name, category, description, line count, stanza count, syllable pattern, rhyme scheme, meter, template text.

### Mark Section
Used for non-verse lines within a poem (epigraphs, prose interludes, etc.)

### Poetry Collections
- Virtual groupings of poems (poems can belong to multiple collections)
- **Only available in Poetry projects**
- Collections don't move poems — they reference them
- Used for: chapbooks, submission packages, themed sets, reading selections
- Can be added to Body Matter for manuscript assembly
- Deleting a collection does NOT delete the poems

---

## 8. FICTION FEATURES

### Characters
- Fields: Name, Role, Details
- Details is a single freeform text field used for backstory, appearance, personality traits, and occupation notes.
- Characters can be linked to scenes
- Shared across all scenes in a project

### Locations
- Fields: Name, Details
- Details is a single freeform text field used for descriptive setting notes (visuals, sounds, atmosphere, sensory details).
- Can be linked to scenes

### Plot Elements
- Tied to chosen story structure stages
- Types: Setups, Conflicts, Resolutions
- Scenes link to plot elements to track story coverage

### Scenes
- Basic writing unit for all fiction types
- Can link to: Plot Element, Characters, Locations
- Assigned to Chapters (Novel), Stories (Short Fiction), or Books (Verse Novel)
- Grouped view shows scenes under their chapter/story/book
- Unassigned scenes appear separately
- Status controls manuscript inclusion (only "Ready" scenes included)

### Chapters / Stories / Books
- **Novel**: Chapters contain scenes
- **Short Fiction**: Stories contain scenes (a scene can only belong to one story)
- **Verse Novel**: Books contain episodes (uses poetry editor)
- Reorder scenes within containers; reorder containers in Body Matter

---

## 9. DRAMA FEATURES

### DML (Drama Markup Language)
Plain text markup that renders as formatted screenplay or stage play.

| Marker | Element | Example |
|--------|---------|---------|
| `#` | Act/Scene heading | `# ACT ONE` |
| `##` | Scene heading | `## Scene 1` |
| (none, INT./EXT.) | Film scene heading | `INT. OFFICE - DAY` |
| ALL CAPS on own line | Character name | `EMMA` |
| `>` | Action/Stage direction | `> She exits.` |
| `()` | Parenthetical | `(softly)` |
| Plain text after name | Dialogue | |
| `~` | Transition | `~ CUT TO:` |
| `@` | Location | `@ INT. WAITING ROOM - DAY` |
| `=` | Setting/atmosphere | `= A sterile room...` |
| `//` | Note (hidden in output) | `// TODO: fix this` |
| `*text*` | Emphasis | |

### Character Extensions
`EMMA (V.O.)` — Voice over, `(O.S.)` — Off screen, `(CONT'D)` — Continuing, `(O.C.)` — Off camera

### Film vs Stage Format
- Same DML source produces either format
- Toggle in Project Settings > Script Format
- Film: centered character names, narrow dialogue column, right-aligned transitions
- Stage: left-aligned character names, full-width dialogue, emphasized act/scene structure

### Acts
- Group scenes into acts
- Scenes viewed grouped by act in the Scenes list

### Story Structures in Drama
- Drama projects support the same story structures as Fiction: Freeform, Three-Act, and Monomyth (Vogler)
- Choose a story structure in Project Settings
- Use plot elements to track story beats across scenes

### Common DML Mistakes
- Character names must be ALL CAPS
- Action lines must start with `>`
- Parentheticals use `()` not `[]`
- Act headings use `#` prefix

---

## 10. MANUSCRIPT STRUCTURE

### Front Matter (appears before main content)
- Title Page, Copyright, Dedication, Epigraph, Table of Contents, Foreword, Preface, Acknowledgments
- Only files with content are included in export

### Body Matter (main content)
- Project-type specific: Sections (Prose), Collections/Poems (Poetry), Chapters (Novel), Stories (Short Fiction), Books (Verse Novel), Acts (Drama)
- Items reorderable in Body Matter view
- Controls final manuscript reading order

### Back Matter (appears after main content)
**Auto-generated**: Endnotes, Glossary, References/Bibliography, Table of Figures, Index
**User-created**: Contributors, About the Author, Also By, custom files

### Scene/Section Break Styles
Page Break, Section Mark, Double Space, None

---

## 11. EXPORT & IMPORT

### Export Formats
| Format | Best For | Notes |
|--------|----------|-------|
| **PDF** | Submissions, print, sharing | Preserves all formatting, recommended for most uses |
| **RTF** | Editable documents | Opens in Word; no inline images |
| **Markdown** | Blogs, GitHub, plain text tools | Basic formatting only; complex formatting simplified |
| **Plain Text** | Universal compatibility | No formatting |
| **HTML** | Web publishing | Basic conversion |
| **WSP** | Complete project archive | Native format; includes all project data |

### PDF Export Details
- Uses Page Setup settings (paper size, margins, headers/footers)
- Footnotes at page bottom; endnotes collected at end
- Widow/orphan control automatic
- Front matter can use Roman numerals; body uses Arabic

### RTF Export
- No inline images
- Preserves text formatting
- Editable in Word and other word processors

### Markdown Export
- Converts: bold, italic, strikethrough, headings, links, code
- Does NOT convert: complex formatting, images (become reference links), footnotes (become inline notes), page layout

### Markdown Import
- Import .md files via Import button in a folder
- Maps Markdown headings to stylesheet styles (# → Title 1, ## → Title 2, etc.)
- Blockquotes → Callout style, code blocks → Caption 1

### WSP Import
- Settings → Import
- Includes all project data, versions, settings
- Does NOT include: stylesheets, reference entries (regenerated from markers), trash contents

### Printing
- AirPrint on iOS, all printers on Mac
- Check Page Setup matches printer paper

---

## 12. SEARCH AND REPLACE

- **Scope**: Current file, Collection, or Entire project
- **Open**: ⌘F (find), ⌘⌥F (find and replace)
- **Navigation**: ⌘G (next), ⌘⇧G (previous)
- **Options**: Case sensitive, Whole word, Regular expressions
- **Project-wide**: Results grouped by file with context; can select/deselect files for Replace All
- **Safety**: Preview before replacing, undo support, confirmation with count
- **Regex support**: Standard patterns (`.`, `*`, `+`, `\d`, `\w`, `\s`, `^`, `$`, capture groups)

---

## 13. STYLESHEET EDITOR

- Access: Project Settings → Stylesheet
- Controls appearance of all paragraph styles (Body, Headings, etc.)
- **Font settings**: Family, size, bold, italic
- **Text appearance**: Color, underline, strikethrough
- **Paragraph**: Alignment (left/center/right/justified), first-line indent, left/right margin
- **Spacing**: Line spacing, space before/after paragraph
- **Numbering**: Auto-numbering with format options (decimal, Roman, letter), adornments, parent styles for hierarchy
- **Custom styles**: Create via + button; can base on existing styles (inheritance)

### Automatic Heading Numbering
- Any heading or custom style can have automatic numbering enabled via the Stylesheet Editor
- Numbers are rendered dynamically — they are NOT stored in the document text
- Numbers appear in the editor, pagination preview, and PDF export
- **To enable**: Open Stylesheet Editor → select a style → enable Numbering → choose format and adornment
- **Number formats**: Decimal (1, 2, 3), Lowercase Roman (i, ii, iii), Uppercase Roman (I, II, III), Lowercase Letter (a, b, c), Uppercase Letter (A, B, C)
- **Adornments**: Plain (1), Period (1.), Parentheses ((1)), Right Paren (1)), Dash Before (-1), Dash After (1-), Dash Both (-1-)
- **Hierarchical numbering**: Set a parent style in the Stylesheet Editor to create compound numbers like 1.1, 1.2, 1.a, 1.b
  - Example: Heading 2 with Heading 1 as parent → numbers display as 1.1, 1.2, 2.1, etc.
  - Child counters reset automatically when the parent number changes
- Numbers increment automatically across files in manuscript preview and PDF export
- Reordering content automatically renumbers headings — no manual updating needed
- Numbered and bullet lists also use the numbering system (toolbar buttons for list styles)
- **Delete**: Cannot delete built-in styles; text using deleted style reverts to Body
- **Reset**: Reset individual styles to defaults
- Stylesheet travels with project (exports include style definitions)

---

## 14. PAGE SETUP

- Access: Project Settings → Page Setup
- **Paper sizes**: Letter (8.5×11"), A4 (210×297mm), Legal, A5, Custom
- **Orientation**: Portrait (default) or Landscape
- **Margins**: Top, Bottom, Left (Inside), Right (Outside) — standard manuscript: 1" all sides
- **Headers/Footers**: Custom text (author name, title), page numbers (plain, total, Roman), left/center/right aligned
- **First Page Different**: Toggle to suppress header/footer on first page
- **Page breaks**: Automatic + manual; widow/orphan control automatic
- **Pagination View**: Preview in editor to verify layout before export

---

## 15. INDEX GENERATION

- Enable in Back Matter settings
- Invisible markers inserted at cursor position (⇧⌘X)
- **Hierarchical**: Up to 3 levels of nested entries
- **Cross-references**: "See" (redirects, no page numbers) and "See also" (related terms, with page numbers)
- **Primary references**: Bold page numbers for main discussions
- **Page ranges**: Consecutive pages auto-collapsed (e.g., "45–47")
- **Find Occurrences**: Search entire manuscript for additional mentions of a keyword; review in context; batch-mark
- **Live preview**: In Back Matter → Index file with calculated page numbers
- Export included in PDF, RTF, HTML, Plain Text

---

## 16. LIST OF FIGURES (TABLE OF FIGURES)

- Auto-generated from images in manuscript
- Shows: figure number, caption text, page number
- Settings: numbered prefix (customizable text), dot leaders, separator style, show/hide uncaptioned images
- Missing captions: show placeholder or summary of uncaptioned pages
- Requires image captions to be enabled on individual images

---

## 17. TABLE OF CONTENTS

- Auto-generated from manuscript folder/file structure
- Hierarchical: Parts → Chapters → Scenes/Sections
- Settings: include/exclude front matter, back matter, parts, chapters, scenes
- Configurable: title text, entry styles per level, dot leaders, page number display
- Page numbers calculated by pagination engine (same as export)
- Manual TOC option: write your own entries (no auto page numbers)
- Can be placed in Front Matter

---

## 18. CONTRIBUTORS (BACK MATTER)

- For magazine editors, anthology publishers, multi-author works
- Fields: First Name, Surname, Biography
- Auto-sorted alphabetically by surname
- Add/edit/delete individual entries
- Export format: "Surname, First Name" followed by biography paragraph

---

## 19. SUBMISSION TRACKING

### Publications
- Types: Magazine or Competition
- Fields: Name, Type, URL, Notes, Deadline
- Deadline reminders (system notifications)

### Submissions
- Link collection/files to a publication
- Statuses: Pending → Accepted / Rejected / Withdrawn
- Records: which files (and versions) were submitted, date, publication
- Follow-up reminders (notification at chosen date)
- Simultaneous submissions: create separate submissions per publication; withdraw others when one accepts

### Reports
- Total submissions, pending vs. completed, acceptance rate, response times

---

## 20. KEYBOARD SHORTCUTS (COMPLETE LIST)

### File Operations
| Shortcut | Action |
|----------|--------|
| ⌘N | New file |
| ⌘S | Force save/sync |
| ⌘W | Close file |

### Editing
| Shortcut | Action |
|----------|--------|
| ⌘Z | Undo |
| ⌘⇧Z | Redo |
| ⌘X | Cut |
| ⌘C | Copy |
| ⌘V | Paste |
| ⌘A | Select all |

### Formatting
| Shortcut | Action |
|----------|--------|
| ⌘B | Bold |
| ⌘I | Italic |
| ⌘U | Underline |
| ⌘⌥0 | Body style |
| ⌘⌥1 | Heading 1 |
| ⌘⌥2 | Heading 2 |
| ⌘⌥3 | Heading 3 |

### Find
| Shortcut | Action |
|----------|--------|
| ⌘F | Open Find |
| ⌘G | Find next |
| ⌘⇧G | Find previous |
| ⌘⌥F | Find and Replace |
| Esc | Close Find/Replace |

### Navigation
| Shortcut | Action |
|----------|--------|
| ⌘↑ | Document start |
| ⌘↓ | Document end |
| ⌘← | Line start |
| ⌘→ | Line end |
| ⌥← | Word left |
| ⌥→ | Word right |
| ⌥↑ | Paragraph up |
| ⌥↓ | Paragraph down |

### Selection
| Shortcut | Action |
|----------|--------|
| ⇧ + arrow | Extend selection |
| ⌘⇧←/→ | Select to line start/end |
| ⌘⇧↑/↓ | Select to document start/end |
| ⌥⇧←/→ | Select word left/right |
| ⌥⇧↑/↓ | Select paragraph up/down |

### Zoom
| Shortcut | Action |
|----------|--------|
| ⌘+ or ⌘= | Zoom in |
| ⌘- | Zoom out |
| ⌘0 | Reset zoom |

### Text Entry
| Shortcut | Action |
|----------|--------|
| Return | New paragraph |
| ⇧Return | Line break (soft return) |
| ⌘⇧C | Insert comment |
| ⇧⌘X | Add index entry |
| Tab | Increase list indent |
| ⇧Tab | Decrease list indent |

### Touch Gestures (iPhone/iPad)
| Gesture | Action |
|---------|--------|
| Shake (iPhone) | Undo |
| Three-finger swipe left | Undo |
| Three-finger swipe right | Redo |
| Double-tap | Select word |
| Triple-tap | Select paragraph |
| Pinch | Zoom |
| Two-finger tap (iPad) | Context menu |

### Key Symbol Legend
⌘ = Command, ⌥ = Option/Alt, ⇧ = Shift, ⌃ = Control

---

## 21. APPLICATION SETTINGS

Access: Main screen → Settings (gear icon)

| Setting | Description |
|---------|-------------|
| **Appearance** | System/Light/Dark (iOS only) |
| **Stylesheet Editor** | Customize project styles |
| **Import** | Import .wsp project archives |
| **Sync Diagnostics** | Troubleshoot iCloud sync |
| **Contact Support** | Report bugs, suggestions, questions |
| **Rate This App** | App Store rating |
| **Manage Purchases** | View/restore in-app purchase |
| **About** | App version, credits, licenses |

---

## 22. TIPS & TRICKS

### Hidden Features
- **Long-press back button**: Jump directly to project root from nested view
- **Pinch to zoom**: In editor for comfortable reading/precise editing
- **Shake to undo** (iPhone)
- **Three-finger swipe**: Left = undo, Right = redo

### Writing Tips
- Write first, format later
- Let auto-save work — stop hitting ⌘S
- Use the right project type from the start
- One poem per file for easier organization/submission

### Organization Tips
- Use Collections (not copies) for multiple groupings
- Change status to Ready as a psychological commitment
- Empty Trash regularly

### Sync Tips
- Trust iCloud — no need to force sync
- Wait a few seconds after changes before switching devices
- Export important finished work as PDFs for backup

---

## 23. TROUBLESHOOTING

### Sync Issues
| Problem | Solutions |
|---------|-----------|
| **Files not syncing** | Check internet, ensure iCloud enabled, wait a few minutes, force quit app, check iCloud storage, verify same Apple ID |
| **Sync conflicts** | Review both versions, keep correct one, delete duplicate |
| **"Unable to Sync"** | Check internet, check iCloud status (apple.com/support/systemstatus), sign out/in iCloud, restart device |
| **Slow sync** | First sync takes time; large projects take longer; poor internet slows sync |

### App Performance
| Problem | Solutions |
|---------|-----------|
| **Running slowly** | Close other apps, restart app, restart device, check storage space |
| **Crashes** | Update app/OS, restart device, contact support with reproduction steps |
| **Won't open** | Force quit and retry, restart device, check for updates, reinstall (data in iCloud) |

### Editing Issues
| Problem | Solutions |
|---------|-----------|
| **Text not appearing** | Check zoom level (⌘0), check text/background colors, scroll to cursor |
| **Formatting lost** | Undo (⌘Z) immediately, check file version history |
| **Undo not working** | Undo has limits; resets after save/close; check file versions |
| **Cursor jumping** | May be auto-scroll; check accidental touches; disable autocorrect |

### Export & Print Issues
| Problem | Solutions |
|---------|-----------|
| **PDF looks wrong** | Check Page Setup, preview in Pagination View, check font availability |
| **Print problems** | Check printer connection, paper size match, printer margins; try Print to PDF |
| **Export fails** | Check storage space, try different location, check permissions |

### iCloud Issues
| Problem | Solutions |
|---------|-----------|
| **Can't enable iCloud** | Sign into iCloud in Settings, enable iCloud Drive, allow app |
| **Files missing** | Check Trash in app, Recently Deleted in Files app, iCloud Drive in Files app; files may still be downloading |
| **Files stuck downloading** | Tap to force download, check internet, check storage |

### Poetry Issues
| Problem | Solutions |
|---------|-----------|
| **Syllable count wrong** | Check pronunciation; custom words may need dictionary; some words have multiple valid counts; trust your ear |
| **Rhyme not detected** | Check spelling; may be slant/imperfect rhyme; proper nouns may not be in dictionary; regional differences |

### Fiction Issues
| Problem | Solutions |
|---------|-----------|
| **Scenes not linking** | Verify both scene and element exist; link from scene settings; save after linking |
| **Word count wrong** | May exclude certain text; check settings; footnotes/comments counted separately |

### Drama Issues
| Problem | Solutions |
|---------|-----------|
| **DML not formatting** | Check prefix syntax (> for action); character names ALL CAPS; check for extra spaces; preview to debug |
| **Output format wrong** | Check Film vs Stage setting in project settings |

### Markdown Issues
| Problem | Solutions |
|---------|-----------|
| **Import not recognizing formatting** | Ensure proper syntax (no spaces in markers); check for invisible characters; some extended features unsupported |
| **Export missing features** | Markdown is intentionally limited; use RTF/PDF for full formatting |
| **Headings not styled** | Verify stylesheet has mapped styles; use # syntax not underlines |

### Stylesheet Issues
| Problem | Solutions |
|---------|-----------|
| **Style not applying** | Ensure cursor in correct paragraph; text may have manual overrides; reapply style |
| **Wrong font** | Font may not be available on device; similar font substituted |
| **Changes not showing** | Save style changes; they apply to existing text using that style |

### Page Setup Issues
| Problem | Solutions |
|---------|-----------|
| **Content cut off** | Margins too small for printer; increase margins |
| **Headers/footers missing** | Check they're enabled; check "First Page Different" setting; preview in Pagination View |
| **Page numbers wrong** | Check starting number; check first page settings; verify in Pagination View |

### Recovery
| Problem | Solutions |
|---------|-----------|
| **Lost work** | Check undo, file versions, other devices, Time Machine (Mac), iCloud versions |
| **Deleted file** | Check Trash in app; Empty Trash requires confirmation; iCloud may retain briefly; contact Apple Support |

---

## 24. FAQ

### General
- **What is it?** Professional writing app for creative writers (prose, poetry, fiction, drama).
- **Devices?** iPhone (iOS 17+), iPad (iPadOS 17+), Mac (macOS 14+).
- **Sync?** Yes, via iCloud across all Apple devices with same Apple ID.
- **Offline?** Yes, full editing offline. Changes sync on reconnect.
- **Backup?** iCloud automatic backup. Export as PDF/RTF for extra safety.
- **Web/Windows/Android?** No. Native Apple platforms only.
- **Files app access?** WSP uses its own storage. Export files if needed in Files app.
- **External keyboards?** Yes, full shortcut support on iPad and Mac.

### Projects
- **Change project type?** No. Copy content to new project of different type.
- **Copy files between projects?** Yes. Long-press (or right-click) a file and choose "Copy to Project". Copies to another project of the same type. Content, formatting, status, and metadata are preserved.
- **Move files between projects?** No direct move, but copy to the other project then delete the original.
- **Draft/Ready/Trash?** Draft = WIP, Ready = finished, Trash = deleted (recoverable).
- **Share a project?** Export files as PDF/RTF and share via share sheet.

### Writing
- **Spell check?** Yes, system spell checker active while writing.
- **Word count goal?** Word count displayed but no built-in goal tracking.
- **Images?** Insert → Image. From Photos, Files, or Camera.
- **Footnotes?** Yes. Insert via Format menu or toolbar. Page bottom in PDF.

### Poetry
- **Syllable accuracy?** Very accurate for standard English. Some proper nouns/unusual words may need manual counting.
- **CMU Dictionary?** Carnegie Mellon Pronouncing Dictionary — powers syllable counting and rhyme detection.
- **Custom forms?** Select from 30+ built-in forms. Custom form creation supported.

### Fiction
- **Chapters and scenes?** Scenes = individual files. Chapters = folders containing scenes.
- **Plot elements?** Track story structure (Setups, Conflicts, Resolutions). Scenes link to them.
- **Character management?** Basic character notes supported.

### Drama
- **DML?** Drama Markup Language — simple plain text markup that auto-formats as screenplay/stage play.
- **Story structures in Drama?** Yes. Drama supports Freeform, Three-Act, and Monomyth (Vogler) — the same structures available in Fiction.
- **Final Draft export?** Currently PDF and RTF. Industry-specific formats may come later.
- **Film or Stage?** Choose based on target production. Preview both from same source.

### Export
- **Formats?** PDF (recommended), RTF. Also Markdown, Plain Text, HTML, WSP.
- **Word (.docx)?** RTF exports open in Word. Direct .docx may come later.
- **Print?** Standard Print option. Mac and iPad with compatible printers.

### Storage
- **iCloud storage needed?** Text = minimal. Images = more. Most users < 1GB.
- **Without iCloud?** Yes, but no cross-device sync. Data stays on device.
- **New device?** Sign into iCloud with same Apple ID. Install app. Projects appear.

### Purchase
- **Free trial?** Check App Store for current offerings.
- **Subscription?** Check App Store for current pricing.
- **Refund?** Contact Apple for App Store refunds.

### Support
- **Report a bug?** Contact support with detailed reproduction steps.
- **Feature requests?** Submit through in-app support channel.
- **Beta testing?** May be announced through app website or newsletter.
- **Updates?** Regular. Enable auto-updates in App Store settings.

---

## 25. CONTACT SUPPORT FLOW

### In-App Support (Primary Method)
1. Open Writing Shed Pro
2. Go to **Settings**
3. Tap **Support** or **Contact Us**
4. Choose report type: Bug, Suggestion, or Question
5. Fill out the form
6. Tap **Send**
7. **Response is immediate** (automated). Device and app info included automatically.
8. If the immediate response doesn't resolve the issue, tap **Ask Developer** to email the developer directly.

### For Urgent/Time-Sensitive Issues
Use the Contact Support form and mention the time constraint. If the immediate response isn't sufficient, tap **Ask Developer** and include "URGENT" so it can be prioritized.

### Good Bug Reports Include
1. What happened (exact behavior)
2. What you expected
3. Steps to reproduce
4. Frequency (every time? sometimes?)
5. Workaround (if found)
6. Device model, OS version, app version (found in Settings → About)

### Feature Requests
Use Contact Support form → choose "Suggestion". Include: what feature, how you'd use it, why it would help.

### Emergency Data Loss
1. Don't panic
2. Check Trash in app
3. Check other devices
4. Check iCloud Drive in Files app
5. Contact support immediately

---

## 26. TUTORIALS AVAILABLE (IN-APP GUIDE)

| Tutorial | Project Type | Difficulty | Time |
|----------|-------------|------------|------|
| Your First Poem (Sonnet) | Poetry | Beginner | 20-30 min |
| Assembling a Poetry Chapbook | Poetry | Intermediate | 30-40 min |
| Planning and Writing a Novel | Fiction (Novel) | Intermediate | 45-60 min |
| Writing Short Fiction | Fiction (Short) | Beginner-Intermediate | 20-30 min |
| Writing a Verse Novel | Fiction (Verse Novel) | Intermediate | 30-40 min |
| Writing Your First Script (DML) | Drama | Beginner | 30-40 min |
| Submitting Your Work | Poetry/any | Intermediate | 20-30 min |
| Formatting a Professional Manuscript | Any | Advanced | 40-50 min |
| Organizing a Large Prose Project | Prose | Intermediate | 30-40 min |

---

## 27. VERSION INFORMATION

- **Current version**: 1.0 (2025)
- **Versioning**: Semantic (Major.Minor.Patch)
- **Check version**: Settings → About (iPhone/iPad) or Menu → About (Mac)
- **Update**: App Store → search → Update (or enable auto-updates)

### Credits
- CMU Pronouncing Dictionary (BSD License) — syllable counting and rhyme detection
- Built with Swift and SwiftUI
- Open source attributions in Settings → Licenses
