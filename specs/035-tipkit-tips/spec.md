# Feature 035: TipKit Tips

**Status:** Planning  
**Branch:** TBD  
**Date:** 2026-02-08  
**Priority:** Pre-release (polish)

## Overview

Integrate Apple's TipKit framework to provide contextual, non-intrusive tips that guide users through Writing Shed Pro's features. Tips appear at relevant moments — when a user first encounters a feature, or when they could benefit from a workflow they haven't discovered. Tips are dismissible, respect user preferences, and never repeat once acknowledged.

---

## Requirements

### Functional Requirements

#### FR-1: TipKit Infrastructure
- [ ] FR-1.1: Add `import TipKit` and configure `Tips.configure()` in app entry point
- [ ] FR-1.2: Use `.modelContainer` and `Tips.configure()` with appropriate `DatastoreLocation`
- [ ] FR-1.3: Support tip reset during development via `Tips.resetDatastore()` in DEBUG builds
- [ ] FR-1.4: Tips persist across launches (TipKit handles this automatically)
- [ ] FR-1.5: Provide a Settings option to "Reset All Tips" for users who want to see them again

#### FR-2: Project & Navigation Tips
- [ ] FR-2.1: **First Project** — When the project list is empty: "Tap + to create your first writing project. Choose from Prose, Poetry, Fiction, or Drama." → 📖 Guide: `22-creating-your-first-project`
- [ ] FR-2.2: **Project Types** — When creating a project: "Each project type provides specialised folders and tools. Prose for essays and articles, Fiction for novels with chapters and scenes, Poetry with verse forms, and Drama with acts and stage directions." → 📖 Guide: `31-project-types-overview`
- [ ] FR-2.3: **Long-Press Back** — When navigating 2+ levels deep in a fiction/drama project: "Long-press the back button to jump straight back to the project list."
- [ ] FR-2.4: **Folder Organisation** — When a folder contains 5+ files: "Drag files to reorder them, or use the sort options in the toolbar." → 📖 Guide: `35-organizing-your-work`

#### FR-3: Editor Tips
- [ ] FR-3.1: **Formatting Toolbar** — On first file open: "Use the toolbar below to apply styles. Tap the paragraph style button (¶) to set headings, block quotes, and more." → 📖 Guide: `42-text-formatting`
- [ ] FR-3.2: **Markdown Toggle** — On first RTF file open (non-Poetry, non-Drama): "You can switch between Rich Text and Markdown views using the format toggle in the toolbar." → 📖 Guide: `96-markdown-features`
- [ ] FR-3.3: **Stylesheet** — When the user first applies a paragraph style: "Styles come from your project's stylesheet. You can customise fonts, sizes, and colours in Project Settings → Stylesheet." → 📖 Guide: `102-stylesheet-editor`
- [ ] FR-3.4: **Page Preview** — After editing for 5+ sessions without using pagination: "Want to see how your work looks on the page? Try Page Preview mode from the toolbar menu." → 📖 Guide: `103-page-setup`
- [ ] FR-3.5: **Word Count** — On first file open: "Tap the word count bar at the bottom to see detailed statistics including reading time and line count." → 📖 Guide: `47-word-count-and-statistics`

#### FR-4: Poetry Tips
- [ ] FR-4.1: **Poetry Form** — When creating a poem: "Choose a poetry form to get guided structure with syllable counts and rhyme scheme hints." → 📖 Guide: `65-forms-and-templates`
- [ ] FR-4.2: **Syllable Counter** — When editing a poem with a form applied: "The numbers on the right show your syllable count vs. the target for each line." → 📖 Guide: `62-syllable-counting`
- [ ] FR-4.3: **CMU Dictionary** — When the syllable count shows a mismatch: "The syllable counter uses the CMU Pronouncing Dictionary. Tap a line to see alternative pronunciations." → 📖 Guide: `62-syllable-counting`

#### FR-5: Fiction Tips
- [ ] FR-5.1: **Scenes & Chapters** — When opening a fiction project for the first time: "Add scenes to build your story, then organise them into chapters. Scenes can be moved between chapters freely." → 📖 Guide: `73-scene-organization`
- [ ] FR-5.2: **Plot Elements** — When the Plot folder is first opened: "Track characters, locations, and plot threads here. Link them to scenes to see where each element appears." → 📖 Guide: `71-fiction-mode-overview`
- [ ] FR-5.3: **Scene Info** — When viewing the scene list: "Tap the info button on any scene to add a synopsis, set status, or link plot elements." → 📖 Guide: `73-scene-organization`
- [ ] FR-5.4: **Verse Novel** — When creating a Verse Novel fiction project: "In a Verse Novel, chapters are called Books and scenes are Episodes. Episodes use the poetry editor." → 📖 Guide: `71-fiction-mode-overview`

#### FR-6: Drama Tips
- [ ] FR-6.1: **Drama Structure** — When opening a drama project: "Drama projects use Acts and Scenes. Add stage directions and character dialogue using the formatting toolbar." → 📖 Guide: `81-drama-mode-overview`

#### FR-7: Import/Export Tips
- [ ] FR-7.1: **Word Import** — When the Prose/Scenes folder is empty: "You can import .docx files — tap the + button and choose 'Import Word Document'." → 📖 Guide: `91-export-options`
- [ ] FR-7.2: **Manuscript Assembly** — When a fiction project has 3+ chapters: "Ready to compile? Use Manuscript Assembly to combine your chapters into a single document for export." → 📖 Guide: `74-manuscript-formatting`
- [ ] FR-7.3: **PDF Export** — After using Page Preview: "You can export your paginated document as a PDF from the share menu." → 📖 Guide: `92-pdf-export`

#### FR-8: Workflow Tips
- [ ] FR-8.1: **Collections** — After creating 10+ files across folders: "Use Collections to group related files from different folders — great for tracking submissions or thematic groupings." → 📖 Guide: `104-collections`
- [ ] FR-8.2: **Submissions** — When the Submissions folder is first opened: "Track your submissions to publishers and agents here. Record dates, responses, and link to the files you submitted." → 📖 Guide: `95-submission-tracking`
- [ ] FR-8.3: **Comments** — After 3+ editing sessions: "You can add comments to your text — select a passage and choose 'Add Comment' from the context menu." → 📖 Guide: `46-comments`
- [ ] FR-8.4: **Footnotes** — When editing an academic or non-fiction file: "Add footnotes from the Insert menu. They auto-number and appear at the bottom of each page in Page Preview." → 📖 Guide: `45-footnotes`
- [ ] FR-8.5: **Search & Replace** — After 5+ editing sessions: "Use ⌘F to search within a file, or use the project-wide search to find text across all files." → 📖 Guide: `101-search-and-replace`

#### FR-9: Guide Link Buttons
- [ ] FR-9.1: Tips marked with 📖 include a "Learn More" action button that opens the relevant guide section
- [ ] FR-9.2: Tapping "Learn More" navigates to the guide project, opens the referenced file, and dismisses the tip
- [ ] FR-9.3: If the guide project is not installed (deleted by user), the button is hidden gracefully
- [ ] FR-9.4: FR-2.3 (Long-Press Back) has no guide link — it is self-contained
- [ ] FR-9.5: The guide file reference is stored as the guide filename stem (e.g., `42-text-formatting`) so it works regardless of guide version
- [ ] FR-9.6: Use TipKit's `actions` property to add the button (appears as a tappable action below the tip message)

---

### Non-Functional Requirements

#### NFR-1: Frequency & Behaviour
- [ ] NFR-1.1: Each tip appears at most once (unless user resets tips)
- [ ] NFR-1.2: Tips do not appear during the first 30 seconds of app launch (allow orientation)
- [ ] NFR-1.3: No more than one tip visible at a time
- [ ] NFR-1.4: Tips use `.popoverTip()` for inline contextual tips attached to UI elements
- [ ] NFR-1.5: Tips use `TipView()` for standalone tips in empty states or list headers
- [ ] NFR-1.6: Tip display style is consistent with system appearance (light/dark mode)

#### NFR-2: Tip Rules & Events
- [ ] NFR-2.1: Use TipKit `Rule` and `Event` system for conditional display
- [ ] NFR-2.2: Tips requiring repeated usage (e.g., "after 5 sessions") use `Event` with `donations`
- [ ] NFR-2.3: Tips with prerequisites (e.g., "after creating a project") use parameter-based `Rule`
- [ ] NFR-2.4: Tips can be invalidated programmatically when the user performs the action (e.g., dismiss "try Page Preview" once they've used it)

#### NFR-3: Platform
- [ ] NFR-3.1: Tips work on both iOS and Mac Catalyst
- [ ] NFR-3.2: Popover tips anchor appropriately on iPad/Mac (toolbar items, list rows)
- [ ] NFR-3.3: On iPhone, tips use inline style where popovers would be too small

---

## Technical Design

### Tip Definitions

Each tip is a struct conforming to `Tip`:

```swift
import TipKit

struct MarkdownToggleTip: Tip {
    var title: Text { Text("Switch Between Formats") }
    var message: Text? { Text("Toggle between Rich Text and Markdown views using this button.") }
    var image: Image? { Image(systemName: "arrow.left.arrow.right") }
    
    /// The guide section this tip links to (nil = no Learn More button)
    static let guideSection: String? = "96-markdown-features"
    
    // Only show for non-poetry, non-drama projects
    @Parameter
    static var supportsMarkdown: Bool = false
    
    var rules: [Rule] {
        #Rule(Self.$supportsMarkdown) { $0 == true }
    }
    
    var actions: [Action] {
        if Self.guideSection != nil {
            Action(id: "learn-more", title: "Learn More")
        }
    }
}
```

### Guide Navigation from Tips

When the user taps "Learn More", the app:

```swift
// In the view using the tip:
TipView(markdownToggleTip) { action in
    if action.id == "learn-more",
       let section = MarkdownToggleTip.guideSection {
        GuideNavigationService.shared.openGuideSection(section)
    }
}

// Or for popover tips:
.popoverTip(markdownToggleTip) { action in
    if action.id == "learn-more",
       let section = MarkdownToggleTip.guideSection {
        GuideNavigationService.shared.openGuideSection(section)
    }
}
```

`GuideNavigationService` finds the "Writing Shed Pro Guide" project in the database, locates the file whose name starts with the section identifier, and navigates to it.

```swift
class GuideNavigationService {
    static let shared = GuideNavigationService()
    
    func openGuideSection(_ sectionId: String) {
        // 1. Find the guide project by name
        // 2. Search all files for one whose name starts with sectionId
        // 3. Navigate: project → folder → file
        // 4. Open file in markdown preview mode
    }
}
```

### Tip Organisation

```
Tips/
├── ProjectTips.swift        // FR-2: Project & navigation tips
├── EditorTips.swift         // FR-3: Editor tips
├── PoetryTips.swift         // FR-4: Poetry tips
├── FictionTips.swift        // FR-5: Fiction tips
├── DramaTips.swift          // FR-6: Drama tips
├── ImportExportTips.swift   // FR-7: Import/export tips
└── WorkflowTips.swift       // FR-8: Workflow tips
```

### App Configuration

```swift
@main
struct WritingShedProApp: App {
    init() {
        try? Tips.configure([
            .displayFrequency(.weekly),
            .datastoreLocation(.applicationDefault)
        ])
    }
}
```

### Settings Integration

```swift
// In Settings view
Button("Reset All Tips") {
    try? Tips.resetDatastore()
}
```

---

## Implementation Phases

### Phase 1: Infrastructure + Core Tips
- TipKit configuration
- Settings reset option
- FR-2.1 (First Project)
- FR-3.1 (Formatting Toolbar)
- FR-3.2 (Markdown Toggle)
- FR-3.5 (Word Count)

### Phase 2: Project-Type Tips
- FR-4.1–4.2 (Poetry)
- FR-5.1–5.3 (Fiction)
- FR-5.4 (Verse Novel)
- FR-6.1 (Drama)

### Phase 3: Workflow & Discovery Tips
- FR-2.3 (Long-Press Back)
- FR-7.1–7.3 (Import/Export)
- FR-8.1–8.5 (Workflow)

### Phase 4: Event-Based Tips
- FR-3.3 (Stylesheet — after first style application)
- FR-3.4 (Page Preview — after 5+ sessions)
- FR-8.3 (Comments — after 3+ sessions)
- FR-8.5 (Search — after 5+ sessions)

---

## Dependencies

- iOS 17.0+ / macOS 14.0+ (TipKit minimum deployment target)
- No third-party dependencies

---

## Notes

- TipKit automatically handles persistence, deduplication, and display frequency
- Tips should be written in the same tone as the User Guide (friendly, concise)
- All tip text should be localised using `LocalizedStringResource`
- The tip list above is a starting point — tips can be added/removed based on user testing and analytics
- Consider A/B testing tip content if analytics are available
