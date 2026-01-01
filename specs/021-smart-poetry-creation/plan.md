# Feature 021: Smart Poetry Creation - Implementation Plan

**Branch**: `021-smart-poetry-creation` | **Date**: 2025-12-30 | **Spec**: [spec.md](spec.md)

## Summary

Provide intelligent poetry creation assistance for Poetry projects including form selection at file creation, structural templates, form reference panels, and real-time metrics (line count, syllable count, stress pattern analysis).

## Technical Context

**Language/Version**: Swift 5.9+  
**Primary Dependencies**: SwiftUI, SwiftData, Observation framework  
**Storage**: SwiftData with CloudKit sync  
**Testing**: XCTest  
**Target Platform**: iOS 17+, macOS 14+ (Mac Catalyst)  
**Performance Goals**: Metrics display within 500ms (syllables) / 1s (stress)  
**Constraints**: Offline-capable, all form data stored locally  
**Scale/Scope**: 10+ predefined poetry forms, real-time analysis

## Project Structure

### Documentation (this feature)

```
specs/021-smart-poetry-creation/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Syllable/stress algorithm research
└── checklists/
    └── requirements.md  # Quality checklist
```

### Source Code

```
WrtingShedPro/Writing Shed Pro/
├── Models/
│   ├── PoetryForm.swift           # NEW: Poetry form definitions
│   └── BaseModels.swift           # MODIFY: Add poetryForm to TextFile
├── Services/
│   ├── PoetryFormService.swift    # NEW: Form templates & definitions
│   ├── SyllableCounter.swift      # NEW: Syllable counting logic
│   └── StressAnalyzer.swift       # NEW: Stress pattern analysis
├── Views/
│   ├── Poetry/                    # NEW: Poetry-specific views
│   │   ├── PoetryFormPicker.swift
│   │   ├── PoetryFormReference.swift
│   │   ├── PoetryMetricsBar.swift
│   │   ├── PoetryMetricsDashboard.swift
│   │   └── StressPatternView.swift
│   └── AddFileSheet.swift         # MODIFY: Add form selection for Poetry
└── Resources/
    └── PoetryForms.json           # NEW: Predefined form definitions

WritingShedProTests/
├── PoetryFormServiceTests.swift   # NEW
├── SyllableCounterTests.swift     # NEW
└── StressAnalyzerTests.swift      # NEW
```

---

## Implementation Phases

### Phase 1: Data Model & Form Definitions (Week 1)
**Goal:** Create PoetryForm model and predefined form library

#### Task 1.1: PoetryForm Model
- [ ] Create `PoetryForm.swift` with properties:
  - `id: UUID`
  - `name: String`
  - `lineCount: Int?`
  - `syllablePattern: [Int]?` (e.g., [5, 7, 5] for haiku)
  - `rhymeScheme: String?` (e.g., "ABAB CDCD EFEF GG")
  - `meterPattern: String?` (e.g., "iambic pentameter")
  - `description: String`
  - `templateContent: String`
  - `isCustom: Bool`
- [ ] Make PoetryForm conform to Codable for JSON storage
- [ ] Add unit tests for PoetryForm model

#### Task 1.2: Predefined Forms JSON
- [ ] Create `PoetryForms.json` resource file
- [ ] Define Sonnet (Shakespearean) with template
- [ ] Define Sonnet (Petrarchan) with template
- [ ] Define Haiku (5-7-5 syllables)
- [ ] Define Tanka (5-7-5-7-7 syllables)
- [ ] Define Limerick (AABBA rhyme)
- [ ] Define Villanelle (19 lines, ABA pattern with refrains)
- [ ] Define Ghazal (couplets with refrain)
- [ ] Define Free Verse (no constraints)
- [ ] Define Blank Verse (unrhymed iambic pentameter)
- [ ] Define Custom (user-defined placeholder)
- [ ] Validate JSON loads correctly

#### Task 1.3: PoetryFormService
- [ ] Create `PoetryFormService.swift`
- [ ] Implement `loadPredefinedForms() -> [PoetryForm]`
- [ ] Implement `getForm(byName:) -> PoetryForm?`
- [ ] Implement `generateTemplate(for:) -> String`
- [ ] Cache forms in memory for performance
- [ ] Add unit tests for PoetryFormService

#### Task 1.4: TextFile Extension
- [ ] Add `poetryFormId: UUID?` property to TextFile in BaseModels.swift
- [ ] Add `poetryFormName: String?` for display (denormalized)
- [ ] Ensure CloudKit sync includes new properties
- [ ] Add migration if needed for existing files
- [ ] Test sync with CloudKit

---

### Phase 2: Form Selection UI (Week 1-2)
**Goal:** Add poetry form picker to file creation flow

#### Task 2.1: PoetryFormPicker View
- [ ] Create `PoetryFormPicker.swift` SwiftUI view
- [ ] Display list of available forms with descriptions
- [ ] Group forms by category (Japanese, Rhymed, Metered, Free)
- [ ] Show form preview (line count, syllable pattern, rhyme scheme)
- [ ] Highlight "Free Verse" as default
- [ ] Add search/filter for forms

#### Task 2.2: AddFileSheet Integration
- [ ] Modify `AddFileSheet.swift` to detect Poetry project type
- [ ] Add form picker section when in Poetry project
- [ ] Pass selected form to file creation
- [ ] Apply template content when form is selected
- [ ] Set poetryFormId on new TextFile
- [ ] Test file creation with various forms

#### Task 2.3: Template Application
- [ ] Generate template content based on selected form
- [ ] Insert line placeholders with numbers
- [ ] Add rhyme scheme hints as comments (optional)
- [ ] Ensure template is fully editable
- [ ] Test template rendering for all 10+ forms

---

### Phase 3: Form Reference Panel (Week 2)
**Goal:** Display form rules while editing

#### Task 3.1: PoetryFormReference View
- [ ] Create `PoetryFormReference.swift` sheet/popover
- [ ] Display form name and description
- [ ] Show line count requirement (if any)
- [ ] Show syllable pattern (if any)
- [ ] Show rhyme scheme (if any)
- [ ] Show meter pattern (if any)
- [ ] Add dismiss button

#### Task 3.2: FileEditView Integration
- [ ] Add toolbar button to access form reference (Poetry files only)
- [ ] Show current form name in subtitle or toolbar
- [ ] Present PoetryFormReference as sheet
- [ ] Handle files with no assigned form (show "Free Verse")
- [ ] Test reference panel access

#### Task 3.3: Change Form After Creation
- [ ] Add "Change Form" option in file settings/context menu
- [ ] Present PoetryFormPicker for re-selection
- [ ] Update poetryFormId without modifying content
- [ ] Refresh reference panel after change
- [ ] Test form change preserves content

---

### Phase 4: Line & Syllable Counting (Week 2-3)
**Goal:** Real-time line and syllable metrics

#### Task 4.1: SyllableCounter Service
- [ ] Create `SyllableCounter.swift`
- [ ] Implement basic syllable counting algorithm:
  - Count vowel groups (a, e, i, o, u, y)
  - Handle silent 'e' at end of words
  - Handle common patterns (tion, le, etc.)
- [ ] Add dictionary lookup for common words (optional enhancement)
- [ ] Return count with confidence indicator (~)
- [ ] Optimize for real-time performance
- [ ] Add unit tests with known syllable counts

#### Task 4.2: PoetryMetricsBar View
- [ ] Create `PoetryMetricsBar.swift` compact view
- [ ] Display total line count
- [ ] Display syllable count for current line
- [ ] Compare against form requirements (if applicable)
- [ ] Use color coding (green = matches, yellow = close, red = far)
- [ ] Position at bottom of editor or in toolbar

#### Task 4.3: FileEditView Metrics Integration
- [ ] Add PoetryMetricsBar to FileEditView for Poetry files
- [ ] Track cursor position to determine current line
- [ ] Update metrics on text change (debounced)
- [ ] Toggle metrics visibility via toolbar
- [ ] Persist visibility preference in UserDefaults
- [ ] Test real-time updates

---

### Phase 5: Stress Pattern Analysis (Week 3-4)
**Goal:** Detect and display stressed/unstressed syllables

#### Task 5.1: StressAnalyzer Service
- [ ] Create `StressAnalyzer.swift`
- [ ] Implement stress detection algorithm:
  - Use CMU Pronouncing Dictionary data (embedded subset)
  - Fallback: algorithmic heuristics for unknown words
  - Mark syllables as stressed (1), unstressed (0), or secondary (2)
- [ ] Return stress pattern as array per word
- [ ] Handle multi-word analysis for full lines
- [ ] Add ambiguity indicators for heteronyms
- [ ] Add unit tests for common words

#### Task 5.2: CMU Dictionary Integration
- [ ] Embed subset of CMU Pronouncing Dictionary (~20k common words)
- [ ] Create efficient lookup structure (Dictionary<String, [Int]>)
- [ ] Load dictionary on first use (lazy loading)
- [ ] Add fallback for words not in dictionary
- [ ] Test dictionary lookup performance

#### Task 5.3: StressPatternView
- [ ] Create `StressPatternView.swift`
- [ ] Display line with stress notation (˘ ´ or visual marks)
- [ ] Option: inline display vs. separate analysis panel
- [ ] Color code stressed vs. unstressed syllables
- [ ] Show expected pattern for metered forms
- [ ] Indicate deviations from expected meter
- [ ] Add toggle to show/hide stress marks

#### Task 5.4: Stress Analysis Integration
- [ ] Add stress analysis toggle to PoetryMetricsBar
- [ ] Compute stress pattern for current line
- [ ] Display pattern in StressPatternView
- [ ] Compare against expected meter (if form has one)
- [ ] Debounce analysis for performance (1s delay)
- [ ] Test with sonnets and blank verse

---

### Phase 6: Metrics Dashboard (Week 4)
**Goal:** Unified metrics overview panel

#### Task 6.1: PoetryMetricsDashboard View
- [ ] Create `PoetryMetricsDashboard.swift` as sheet/inspector
- [ ] Summary section:
  - Total lines
  - Lines matching form requirements
  - Lines with meter deviations
- [ ] Per-line breakdown:
  - Line number
  - Syllable count (actual vs. expected)
  - Stress pattern
  - Conformance indicator (✓/✗)
- [ ] Form reference section (embedded)

#### Task 6.2: Dashboard Integration
- [ ] Add dashboard access button to FileEditView toolbar
- [ ] Present as sheet (iOS) or inspector (macOS)
- [ ] Update dashboard when text changes
- [ ] Navigate to line from dashboard row (tap to scroll)
- [ ] Test dashboard with various form types

#### Task 6.3: Metrics Export (Optional)
- [ ] Add "Copy Metrics" action
- [ ] Format metrics as plain text summary
- [ ] Include form name, line counts, conformance %
- [ ] Test copy to clipboard

---

### Phase 7: Polish & Edge Cases (Week 5)
**Goal:** Handle edge cases, optimize performance, finalize UX

#### Task 7.1: Performance Optimization
- [ ] Profile syllable counting on long poems (100+ lines)
- [ ] Profile stress analysis on 14-line sonnets
- [ ] Optimize debounce timing for real-time feel
- [ ] Cache computed metrics per line (invalidate on change)
- [ ] Test on older devices (iPhone 12, 2020 iPad)

#### Task 7.2: Edge Case Handling
- [ ] Handle empty files gracefully
- [ ] Handle very long lines (500+ characters)
- [ ] Handle non-English words (show "?" for syllables)
- [ ] Handle contractions ("don't" = 1 syllable)
- [ ] Handle hyphenated words
- [ ] Handle numbers and symbols
- [ ] Test paste of large content

#### Task 7.3: Accessibility
- [ ] Add VoiceOver labels to metrics displays
- [ ] Ensure stress patterns are readable by VoiceOver
- [ ] Test with Dynamic Type (large fonts)
- [ ] Add accessibility hints for form picker

#### Task 7.4: Preferences
- [ ] Add poetry metrics preferences to Settings:
  - Show metrics bar (on/off)
  - Show stress analysis (on/off)
  - Syllable counting method (basic/enhanced)
- [ ] Persist preferences in UserDefaults
- [ ] Sync preferences via CloudKit (optional)

---

### Phase 8: Testing & Documentation (Week 5-6)
**Goal:** Comprehensive tests and user guidance

#### Task 8.1: Unit Tests
- [ ] PoetryForm model tests
- [ ] PoetryFormService tests (all 10+ forms)
- [ ] SyllableCounter tests (word list with known counts)
- [ ] StressAnalyzer tests (common words, edge cases)
- [ ] Achieve >80% code coverage for new code

#### Task 8.2: Integration Tests
- [ ] Create file with form → verify template applied
- [ ] Change form → verify content preserved
- [ ] Metrics update on text change
- [ ] Form reference displays correctly
- [ ] CloudKit sync includes poetryFormId

#### Task 8.3: UI Tests
- [ ] Form selection flow in AddFileSheet
- [ ] Metrics bar visibility toggle
- [ ] Dashboard open/close
- [ ] Form reference access

#### Task 8.4: Manual Testing Checklist
- [ ] Test all 10+ poetry forms create correctly
- [ ] Test syllable counts for haiku (5-7-5)
- [ ] Test stress patterns for sonnets
- [ ] Test on iPhone, iPad, Mac
- [ ] Test with VoiceOver enabled
- [ ] Test offline functionality

#### Task 8.5: User Documentation
- [ ] Add tooltips/help text in form picker
- [ ] Document supported poetry forms in app
- [ ] Add "About Poetry Metrics" help section
- [ ] Document stress notation (˘ ´) meaning

---

## Dependencies

| Phase | Depends On | External Dependencies |
|-------|------------|----------------------|
| Phase 1 | None | None |
| Phase 2 | Phase 1 | None |
| Phase 3 | Phase 1, 2 | None |
| Phase 4 | Phase 1 | None (can parallel with 2-3) |
| Phase 5 | Phase 4 | CMU Dict subset (~500KB) |
| Phase 6 | Phase 4, 5 | None |
| Phase 7 | Phase 1-6 | None |
| Phase 8 | Phase 1-7 | None |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Syllable counting accuracy <85% | Medium | Low | Use as estimate only, show "~" prefix |
| Stress analysis slow on long poems | Medium | Medium | Debounce, cache per line, analyze on demand |
| CMU dictionary too large | Low | Medium | Embed 20k most common words only |
| Form templates don't fit all use cases | Low | Low | Allow "Custom" form with user notes |
| CloudKit sync issues with new fields | Low | High | Test migration thoroughly, use optional fields |

## Milestones

| Milestone | Target | Deliverable |
|-----------|--------|-------------|
| M1: Forms Library | End Week 1 | 10+ forms defined, TextFile extended |
| M2: Form Selection | End Week 2 | Create poetry files with templates |
| M3: Basic Metrics | End Week 3 | Line + syllable counts working |
| M4: Stress Analysis | End Week 4 | Stress patterns displayed |
| M5: Feature Complete | End Week 5 | Dashboard, polish, edge cases |
| M6: Release Ready | End Week 6 | Tests passing, documentation complete |

## Estimated Effort

- **Total**: 5-6 weeks
- **Phase 1-2**: 1.5 weeks (Foundation)
- **Phase 3-4**: 1.5 weeks (Core Features)
- **Phase 5-6**: 1.5 weeks (Advanced Metrics)
- **Phase 7-8**: 1.5 weeks (Polish & Testing)
