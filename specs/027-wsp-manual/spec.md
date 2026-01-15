# Feature 027: WSP User Guide

**Status**: Draft  
**Priority**: Medium  
**Estimated Effort**: TBD  
**Dependencies**: 024-hyperlinks, 025-manual-project-type, 026-wsp-reader  
**Created**: 2026-01-10

## Overview

Create the official Writing Shed Pro User Guide as a WSP project, written in WSP itself. This demonstrates the app's capabilities (dogfooding) and provides comprehensive documentation for users.

## Goals

1. **Comprehensive Documentation**: Cover all WSP features
2. **Dogfooding**: Use WSP to create its own guide, proving capabilities
3. **Living Document**: Easy to update with new features
4. **Distribution**: Accessible in-app and via WSP Reader

## Naming Convention

| Item | Name |
|------|------|
| WSP Project file | `WSP Guide.wsp` |
| Project name (in app) | "Writing Shed Pro Guide" |
| HTML file | `Writing Shed Pro Guide.html` |
| Menu command | "Import User Guide" |

## Guide Structure

### Proposed Table of Contents

```
Writing Shed Pro Guide (Project)
│
├── Welcome (Folder)
│   ├── Introduction
│   ├── What's New
│   └── Quick Start Guide
│
├── Getting Started (Folder)
│   ├── Installation
│   ├── Creating Your First Project
│   ├── The Interface Tour
│   └── iCloud Sync
│
├── Projects (Folder)
│   ├── Project Types Overview
│   ├── Creating Projects
│   ├── Project Settings
│   ├── Folders and Files
│   └── Organizing Your Work
│
├── Writing (Folder)
│   ├── The Editor
│   ├── Text Formatting
│   ├── Headings and Styles
│   ├── Images
│   ├── Footnotes
│   ├── Comments
│   └── Word Count and Statistics
│
├── Poetry Features (Folder)
│   ├── Poetry Mode Overview
│   ├── Syllable Counting
│   ├── Rhyme Tools
│   ├── Verse Highlighting
│   └── Forms and Templates
│
├── Fiction Features (Folder)
│   ├── Fiction Mode Overview
│   ├── Chapter Management
│   ├── Scene Organization
│   └── Manuscript Formatting
│
├── Drama Features (Folder)
│   ├── Drama Mode Overview
│   ├── Script Formatting
│   ├── Film vs Stage Formats
│   └── DML Reference
│
├── Publishing (Folder)
│   ├── Export Options
│   ├── PDF Export
│   ├── RTF Export
│   ├── Printing
│   └── Submission Tracking
│
├── Advanced Features (Folder)
│   ├── Search and Replace
│   ├── Stylesheet Editor
│   ├── Page Setup
│   ├── Collections
│   ├── Keyboard Shortcuts
│   └── Tips and Tricks
│
├── Reference (Folder)
│   ├── Keyboard Shortcut List
│   ├── DML Quick Reference
│   ├── Troubleshooting
│   ├── FAQ
│   └── Contact Support
│
└── Appendices (Folder)
    ├── Version History
    ├── Credits
    └── Legal
```

## Content Guidelines

### 1. Writing Style

#### Tone
- Friendly but professional
- Direct and practical
- Encouraging for new users
- Respectful of reader's time

#### Voice
- Active voice preferred
- Second person ("You can...")
- Present tense

#### Examples
```
✓ "To create a new project, tap the + button in the toolbar."
✗ "A new project can be created by the user by tapping the + button."

✓ "Your changes sync automatically via iCloud."
✗ "Changes will be synced automatically by the iCloud system."
```

### 2. Page Structure

Each chapter should follow a consistent format:

```
# Chapter Title

Brief introduction explaining what this chapter covers.

## First Topic

Explanation with context for why this matters.

### How to Do It

Step-by-step instructions:
1. First step
2. Second step
3. Third step

### Tips
- Helpful tip 1
- Helpful tip 2

## Second Topic
...

## See Also
- [Related Chapter](internal link)
- [Another Chapter](internal link)
```

### 3. Visual Elements

#### Screenshots
- Include screenshots for complex UI
- Consistent sizing and styling
- Annotate with callouts when helpful
- Both iOS and macOS where different

#### Diagrams
- Flowcharts for processes
- Structure diagrams for concepts
- Keep simple and clear

#### Tables
- Use for comparisons
- Keyboard shortcuts in tables
- Feature comparisons

### 4. Cross-References

Heavy use of hyperlinks (024):
- "See [Chapter Name] for more details"
- "Related: [Another Feature]"
- Link technical terms to glossary
- "Learn about [feature] in [chapter]"

### 5. Feature Coverage

Each feature should document:
- What it does
- Why you'd use it
- How to access it
- Step-by-step usage
- Tips and best practices
- Known limitations (if any)

## Content Creation Process

### Option A: Write in WSP
- True dogfooding
- Final format from start
- Harder to collaborate/version control
- May miss bugs in WSP itself

### Option B: Write in Markdown → Convert
- Git-friendly source
- Easy collaboration
- Requires conversion tool/process
- Markdown → WSP conversion needed

### Option C: Hybrid Approach (Recommended)
1. Draft content in Markdown (quick iteration)
2. Review and edit in Markdown
3. Convert to WSP for final polish
4. Maintain both versions:
   - Markdown: source of truth for text
   - WSP: final distribution format

### Conversion Considerations
If using Markdown source:
- Need MD → WSP converter
- Handle images (copy to WSP project)
- Convert MD links to WSP internal links
- Apply WSP styling/formatting

## Distribution

The guide is distributed in two formats with two access methods:

### 1. HTML Guide (Quick Reference)
- **File**: `Writing Shed Pro Guide.html` in app Resources folder
- **Access**: Help button (questionmark.circle) in main toolbar
- **Purpose**: Quick reference, searchable, always available
- **Display**: Opens in a WebKit view within the app
- **Updates**: Bundled with app releases
- **Generation**: Exported from the WSP Guide project as HTML Manuscript

### 2. WSP Guide Project (Editable Example)
- **File**: `WSP Guide.wsp` in app Resources folder  
- **Access**: Settings menu → "Import User Guide"
- **Purpose**: 
  - Example of a well-structured WSP Prose project
  - Users can annotate with their own notes
  - Users can export to PDF, RTF, etc.
  - Demonstrates WSP capabilities (dogfooding)
- **Behavior**:
  - Shows confirmation dialog before import
  - If guide already exists, offers to replace (with warning about losing notes)
  - Creates a regular project named "Writing Shed Pro Guide"
  - User can delete and re-import anytime
  - Syncs via iCloud like any other project

### 3. Bundled with Reader App
- Include same `WSP Guide.wsp`
- Demonstrates Reader capabilities
- First-run experience?

### 4. Online Version (Future)
- Same HTML export hosted on website
- SEO benefits
- Accessible without app

### HTML Generation Workflow

The HTML guide is generated from the WSP Guide project:

1. Open WSP Guide project in Writing Shed Pro
2. Use "Export Manuscript as HTML" feature (to be added)
3. Save as `Writing Shed Pro Guide.html`
4. Add to Xcode project Resources folder
5. Bundle with app release

This ensures single source of truth - the WSP project is the master, HTML is derived.

### Implementation Status

The following stubs have been implemented:

| Component | File | Status |
|-----------|------|--------|
| Help button | `ContentViewToolbar.swift` | ✅ Added |
| HTML viewer | `HTMLManualView.swift` | ✅ Added |
| Import User Guide menu | `ContentViewToolbar.swift` | ✅ Added |
| Import service | `UserGuideImportService.swift` | ✅ Added |
| Replace existing check | `UserGuideImportService.swift` | ✅ Added |
| State properties | `ContentViewState.swift` | ✅ Added |
| Sheet bindings | `ContentViewBody.swift` | ✅ Added |

**Still needed:**
- [ ] Add "Export Manuscript as HTML" feature
- [ ] Create the `WSP Guide.wsp` project with full guide content
- [ ] Export to `Writing Shed Pro Guide.html`
- [ ] Connect `UserGuideImportService` to existing WSP import logic
- [ ] Add both files to Xcode project Resources folder

## Localization (Future)

### Phase 1: English Only
- Write comprehensive English manual
- Establish structure and conventions

### Phase 2: Key Languages
- Consider Spanish, French, German, Japanese, Chinese
- Separate manual projects per language
- Professional translation recommended

## Maintenance Plan

### Update Triggers
- New feature added → new chapter/section
- Feature changed → update relevant sections
- UI changes → update screenshots
- User feedback → clarify confusing areas

### Version Alignment
- Manual version matches app version
- "What's New" chapter updated each release
- Version number in manual metadata

### Review Schedule
- Full review before major releases
- Spot-check screenshots after UI changes
- Quarterly review of FAQ/Troubleshooting

## Quality Checklist

Before release, verify:
- [ ] All features documented
- [ ] All screenshots current
- [ ] All internal links working
- [ ] Table of contents accurate
- [ ] No placeholder text remaining
- [ ] Consistent formatting throughout
- [ ] Spell-check completed
- [ ] Tested in WSP Reader
- [ ] Tested on iOS and macOS
- [ ] Version number correct

## Open Questions

1. Who writes the manual? Developer? Technical writer? Combination?
2. Should manual include video tutorials? (Or separate tutorial project?)
3. How to handle platform-specific differences? (Separate chapters or notes inline?)
4. Should there be a "quick reference card" as separate short document?
5. Integrate with in-app help? (Contextual "?" buttons linking to manual sections)
6. How to gather user feedback on manual? (Feedback link?)

## Success Metrics

1. Reduced support requests for documented features
2. User feedback ("manual was helpful")
3. Manual completion rate (analytics if added to Reader)
4. Time-to-first-success for new users

## Implementation Phases

### Phase 1: Structure
1. Create manual project in WSP
2. Set up folder/file structure per TOC
3. Add placeholder content for all chapters

### Phase 2: Core Content
1. Write Getting Started section
2. Write Projects section
3. Write Writing section
4. Add essential screenshots

### Phase 3: Feature Sections
1. Write Poetry Features
2. Write Fiction Features
3. Write Drama Features
4. Write Publishing section

### Phase 4: Reference Material
1. Complete Advanced Features
2. Build Reference section
3. Create Appendices

### Phase 5: Polish
1. Add all cross-reference links
2. Review for consistency
3. Final screenshot pass
4. Quality checklist review

### Phase 6: Release
1. Bundle in Pro app
2. Bundle in Reader app
3. Announce availability
