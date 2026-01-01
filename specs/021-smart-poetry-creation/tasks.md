# Feature 021: Smart Poetry Creation - Task Breakdown

## Task List (72 tasks across 8 phases)

### Phase 1: Data Model & Form Definitions (13 tasks)

**1.1 PoetryForm Model (4 tasks)**
- [x] Create PoetryForm.swift with properties: id, name, lineCount, syllablePattern, rhymeScheme, meterPattern, description, templateContent, isCustom
- [x] Make PoetryForm conform to Codable for JSON serialization
- [x] Add computed properties: hasSyllableRequirements, hasMeterRequirements, hasRhymeScheme
- [x] Write unit tests for PoetryForm model (initialization, encoding/decoding)

**1.2 Predefined Forms JSON (5 tasks)**
- [x] Create PoetryForms.json resource file with all form definitions
- [x] Define syllable-based forms: Haiku (5-7-5), Tanka (5-7-5-7-7)
- [x] Define rhyme-based forms: Limerick (AABBA), Villanelle (ABA refrains), Ghazal (couplets)
- [x] Define meter-based forms: Sonnet Shakespearean (14 lines, iambic pentameter, ABAB CDCD EFEF GG), Sonnet Petrarchan (ABBAABBA CDECDE), Blank Verse (unrhymed iambic pentameter)
- [x] Define flexible forms: Free Verse (no constraints), Custom (user-defined placeholder)

**1.3 PoetryFormService (3 tasks)**
- [x] Create PoetryFormService.swift with loadPredefinedForms() from JSON bundle
- [x] Implement getForm(byId:) and getForm(byName:) lookup methods with in-memory cache
- [x] Write unit tests for PoetryFormService (load all forms, lookup by id/name)

**1.4 TextFile Extension (1 task)**
- [x] Add poetryFormId: UUID? and poetryFormName: String? to TextFile in BaseModels.swift, ensure CloudKit sync

---

### Phase 2: Form Selection UI (9 tasks)

**2.1 PoetryFormPicker View (4 tasks)**
- [x] Create PoetryFormPicker.swift SwiftUI view with list of available forms
- [x] Group forms by category: Japanese (Haiku, Tanka), Rhymed (Limerick, Villanelle, Ghazal), Metered (Sonnets, Blank Verse), Free (Free Verse, Custom)
- [x] Display form preview card with line count, syllable pattern, rhyme scheme, meter info
- [x] Add selection binding and "Free Verse" as default highlighted option

**2.2 AddFileSheet Integration (3 tasks)**
- [x] Modify AddFileSheet.swift to detect Poetry project type and show form picker section
- [x] Pass selected PoetryForm to file creation and set poetryFormId on new TextFile
- [x] Apply template content from selected form to file.content on creation

**2.3 Template Generation (2 tasks)**
- [x] Implement generateTemplate(for:title:) in PoetryFormService with line placeholders
- [x] Test template rendering for all 10+ forms (verify line counts, hints appear correctly)

---

### Phase 3: Form Reference Panel (8 tasks)

**3.1 PoetryFormReference View (4 tasks)**
- [x] Create PoetryFormReference.swift sheet view with form name and description header
- [x] Display line count requirement section (if form has lineCount)
- [x] Display syllable pattern section (if form has syllablePattern)
- [x] Display rhyme scheme and meter pattern sections (if applicable)

**3.2 FileEditView Integration (3 tasks)**
- [x] Add "Form Reference" toolbar button to FileEditView for Poetry project files
- [x] Show current form name in navigation subtitle or toolbar area
- [x] Present PoetryFormReference as sheet, handle files with no form (show "Free Verse")

**3.3 Change Form After Creation (1 task)**
- [x] Add "Change Form" option in file context menu, present PoetryFormPicker, update poetryFormId without modifying content

---

### Phase 4: Line & Syllable Counting (10 tasks)

**4.1 SyllableCounter Service (5 tasks)**
- [x] Create SyllableCounter.swift with countSyllables(in word:) -> Int method
- [x] Implement vowel-group counting algorithm (a, e, i, o, u, y groups)
- [x] Add silent-e detection (remove trailing e if preceded by consonant+vowel)
- [x] Add special pattern handling (tion=1, le=1 after consonant, etc.)
- [x] Write unit tests with 50+ words of known syllable counts

**4.2 PoetryMetricsBar View (3 tasks)**
- [x] Create PoetryMetricsBar.swift compact SwiftUI view for bottom of editor
- [x] Display: total lines, current line syllable count, comparison to form requirement
- [x] Add color coding: green (matches), yellow (±1 off), red (>1 off)

**4.3 FileEditView Metrics Integration (2 tasks)**
- [x] Add PoetryMetricsBar to FileEditView for Poetry files, toggle visibility via toolbar
- [x] Implement real-time updates on text change (debounced 300ms), track cursor for current line

---

### Phase 5: Stress Pattern Analysis (12 tasks)

**5.1 StressAnalyzer Service (6 tasks)**
- [x] Create StressAnalyzer.swift with analyzeWord(word:) -> [StressLevel] method
- [x] Define StressLevel enum: unstressed (0), stressed (1), secondary (2)
- [x] Embed CMU Pronouncing Dictionary subset (20k common words) as JSON or plist
- [x] Implement dictionary lookup with lazy loading
- [x] Add heuristic fallback for words not in dictionary (stress penultimate syllable for 2+ syllables)
- [x] Write unit tests for 30+ common words with known stress patterns

**5.2 StressPatternView (3 tasks)**
- [x] Create StressPatternView.swift to display stress notation (˘ for unstressed, ´ for stressed)
- [x] Add visual highlighting mode (bold/color for stressed syllables)
- [x] Show expected pattern for metered forms with deviation indicators

**5.3 Stress Analysis Integration (3 tasks)**
- [x] Add analyzeLine(text:) -> [WordStress] method to StressAnalyzer
- [x] Add stress toggle to PoetryMetricsBar, show StressPatternView for current line
- [x] Implement debounced analysis (1s delay) for performance

---

### Phase 6: Metrics Dashboard (7 tasks)

**6.1 PoetryMetricsDashboard View (4 tasks)**
- [x] Create PoetryMetricsDashboard.swift as sheet/inspector view
- [x] Add summary section: total lines, lines matching requirements, conformance percentage
- [x] Add per-line breakdown: line number, text preview, syllable count (actual/expected), stress pattern, ✓/✗ indicator
- [x] Embed form reference section at top of dashboard

**6.2 Dashboard Integration (2 tasks)**
- [x] Add "Metrics Dashboard" toolbar button to FileEditView, present as sheet (iOS) or inspector (macOS)
- [x] Implement tap-to-navigate: tap line row to scroll editor to that line

**6.3 Metrics Export (1 task)**
- [x] Add "Copy Metrics" action to export summary as plain text to clipboard

---

### Phase 7: Polish & Edge Cases (8 tasks)

**7.1 Performance Optimization (2 tasks)**
- [x] Profile syllable/stress analysis on 100+ line poems, target <500ms total
- [x] Add per-line caching with invalidation on text change

**7.2 Edge Case Handling (3 tasks)**
- [x] Handle contractions ("don't"=1, "they're"=1), hyphenated words (split and sum)
- [x] Handle non-English words, numbers, symbols (show "?" or skip)
- [x] Handle empty files, very long lines (500+ chars), large paste operations

**7.3 Accessibility (2 tasks)**
- [x] Add VoiceOver labels to PoetryMetricsBar, PoetryFormPicker, StressPatternView
- [x] Test with Dynamic Type (large fonts) and adjust layouts

**7.4 Preferences (1 task)**
- [x] Add poetry preferences to Settings: showMetricsBar (default on), showStressAnalysis (default off), persist in UserDefaults

---

### Phase 8: Testing & Documentation (5 tasks)

**8.1 Unit Tests (1 task)**
- [x] Achieve >80% code coverage for PoetryFormService, SyllableCounter, StressAnalyzer

**8.2 Integration Tests (1 task)**
- [x] Test full workflows: create file with form, change form, metrics update, CloudKit sync

**8.3 UI Tests (1 task)**
- [x] Test form selection in AddFileSheet, metrics bar toggle, dashboard open/close

**8.4 Manual Testing (1 task)**
- [x] Test all 10+ forms on iPhone, iPad, Mac; test with VoiceOver; test offline

**8.5 Documentation (1 task)**
- [x] Add tooltips in form picker, "About Poetry Metrics" help section, document ˘ ´ notation

---

## Task Summary by Phase

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1: Data Model & Forms | 13 | ✅ Complete |
| Phase 2: Form Selection UI | 9 | ✅ Complete |
| Phase 3: Form Reference Panel | 8 | ✅ Complete |
| Phase 4: Line & Syllable Counting | 10 | ✅ Complete |
| Phase 5: Stress Pattern Analysis | 12 | ✅ Complete |
| Phase 6: Metrics Dashboard | 7 | ✅ Complete |
| Phase 7: Polish & Edge Cases | 8 | ✅ Complete |
| Phase 8: Testing & Documentation | 5 | ✅ Complete |
| **TOTAL** | **72 tasks** | **✅ Complete** |

## Priority Tasks (Must Have for MVP)

1. ✅ Phase 1: Data model and form definitions
2. ✅ Phase 2: Form selection in file creation
3. ✅ Phase 3: Form reference panel
4. ✅ Phase 4: Line and syllable counting
5. ✅ Phase 8: Core testing

## Optional Tasks (Now Complete)

- ✅ **Phase 5**: Stress pattern analysis
- ✅ **Phase 6**: Metrics dashboard with Issues tab
- ✅ **Phase 7**: Polish items, validation overlay, accessibility

## Critical Path

```
Phase 1 → Phase 2 → Phase 3 ──────────────────→ Phase 8
              ↓                                   ↑
          Phase 4 → Phase 5 → Phase 6 → Phase 7 ─┘
```
All phases complete.

## Task Dependencies

- **Phase 2** depends on Phase 1 (need PoetryForm model and service)
- **Phase 3** depends on Phase 1, 2 (need forms and file creation working)
- **Phase 4** depends on Phase 1 (can parallel with 2-3 once model exists)
- **Phase 5** depends on Phase 4 (builds on syllable infrastructure)
- **Phase 6** depends on Phase 4, 5 (aggregates all metrics)
- **Phase 7** depends on Phase 1-6 (polish requires features to exist)
- **Phase 8** can start unit tests early, integration tests after Phase 4+

## MVP vs Full Feature

### MVP (Phases 1-4 + 8): ~16 days
- Form selection with templates
- Form reference panel
- Line and syllable counting
- Core tests

### Full Feature (All Phases): ~33 days
- Adds stress pattern analysis
- Adds unified metrics dashboard
- Full polish and edge cases

## Files to Create

| File | Phase | Purpose |
|------|-------|---------|
| `Models/PoetryForm.swift` | 1 | Poetry form data model |
| `Resources/PoetryForms.json` | 1 | Predefined form definitions |
| `Services/PoetryFormService.swift` | 1 | Form loading and lookup |
| `Services/SyllableCounter.swift` | 4 | Syllable counting logic |
| `Services/StressAnalyzer.swift` | 5 | Stress pattern analysis |
| `Views/Poetry/PoetryFormPicker.swift` | 2 | Form selection UI |
| `Views/Poetry/PoetryFormReference.swift` | 3 | Form rules display |
| `Views/Poetry/PoetryMetricsBar.swift` | 4 | Compact metrics display |
| `Views/Poetry/StressPatternView.swift` | 5 | Stress visualization |
| `Views/Poetry/PoetryMetricsDashboard.swift` | 6 | Full metrics panel |

## Files to Modify

| File | Phase | Change |
|------|-------|--------|
| `Models/BaseModels.swift` | 1 | Add poetryFormId, poetryFormName to TextFile |
| `Views/AddFileSheet.swift` | 2 | Add form picker for Poetry projects |
| `Views/FileEditView.swift` | 3, 4 | Add toolbar buttons, metrics bar |

## Next Steps

1. **Start Phase 1, Task 1.1:** Create PoetryForm.swift model
2. **Create PoetryForms.json** with all 10+ form definitions
3. **Build PoetryFormService** to load and cache forms
4. **Extend TextFile** with poetry form properties
5. **Proceed to Phase 2** for UI integration
