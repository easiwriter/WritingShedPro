# Phase 009: Poetry Features - Implementation Plan

**Feature**: Poetry-specific writing tools and formatting  
**Status**: Starting  
**Date**: 11 November 2025  
**Estimated Duration**: 2-3 sessions  

## Overview

Phase 009 adds specialized tools for poetry writing, including templates, form validation, syllable counting, and poetry-specific metadata. This feature enhances the writing experience for poets working with structured forms.

## Phased Implementation Strategy

### Phase 009.1: Poetry Metadata & Line Break Preservation (Session 1)
**Priority**: HIGH - Foundation for all other features  
**Time**: 1-2 hours

**Goals**:
- Add poetry-specific fields to TextFile model
- Implement line break preservation in editor
- Create poetry project template selection
- Display poetry metadata in file list

**Tasks**:
1. Extend TextFile model with:
   - `poetryForm: PoetryForm?`
   - `lineCount: Int` (computed)
   - `stanzaCount: Int` (computed)
   - `theme: String?`
   - `occasion: String?`

2. Create PoetryForm enum:
   - haiku, sonnet, villanelle, limerick, freeVerse, custom

3. Enhance TextFileEditorView:
   - Preserve line breaks exactly as entered
   - Display line numbers (optional toggle)
   - Show line and stanza count in editor header

4. Update project creation:
   - Add "Poetry" project type (already exists)
   - Store poetry form preference

**Deliverables**:
- Enhanced TextFile model
- Line break preservation in editor
- Poetry metadata display
- 5+ unit tests

---

### Phase 009.2: Poetry Forms & Validation (Session 1-2)
**Priority**: HIGH - Core feature  
**Time**: 1.5-2 hours

**Goals**:
- Create poetry form templates
- Implement form validation
- Show validation warnings in editor
- Create form-specific UI

**Tasks**:
1. Create FormValidation system:
   ```swift
   struct PoetryFormValidator {
       let form: PoetryForm
       func validate(_ text: String) -> ValidationResult
       func getLineStructure(_ text: String) -> LineStructure
   }
   ```

2. Define form rules:
   - Haiku: 3 lines, 5-7-5 syllables
   - Sonnet: 14 lines, ABAB CDCD EFEF GG rhyme scheme
   - Limerick: 5 lines, AABBA rhyme scheme
   - Villanelle: 19 lines, specific repetition pattern

3. Enhance editor UI:
   - Show form requirements as floating badge
   - Display validation warnings
   - Show current vs. required structure
   - Color-code lines (✓ valid, ⚠️ warning)

4. Create form validation tests:
   - Test haiku validation
   - Test sonnet validation
   - Test limerick validation

**Deliverables**:
- FormValidator implementation
- Form templates system
- Editor UI enhancements
- 8+ unit tests

---

### Phase 009.3: Syllable Counter (Session 2)
**Priority**: MEDIUM - High-impact feature  
**Time**: 1.5-2 hours

**Goals**:
- Implement real-time syllable counting
- Display syllable counts per line
- Support multiple languages (English primary)
- Performance optimized for typing

**Tasks**:
1. Create SyllableCounter:
   ```swift
   struct SyllableCounter {
       func countSyllables(_ word: String) -> Int
       func countLine(_ line: String) -> Int
       func analyze(_ text: String) -> [LineAnalysis]
   }
   ```

2. Implement syllable counting algorithm:
   - Use CMU Pronouncing Dictionary pattern (if available)
   - Fallback heuristics (vowel groups, common patterns)
   - Cache results for performance
   - Support English with extensibility for other languages

3. Editor integration:
   - Show syllable count next to each line (for haiku, etc.)
   - Real-time updates as user types
   - Visual indicator (✓/⚠️)
   - Highlight lines not meeting requirements

4. Performance optimization:
   - Debounce counting during rapid typing
   - Cache syllable counts
   - Background task for full document analysis
   - Minimize main thread blocking

**Deliverables**:
- SyllableCounter implementation
- Performance-optimized UI updates
- Real-time counting in editor
- 6+ unit tests

---

### Phase 009.4: Stanza Management & UI Polish (Session 2-3)
**Priority**: MEDIUM - Quality of life feature  
**Time**: 1-1.5 hours

**Goals**:
- Create stanza visualization
- Enable stanza-level operations
- Improve editor UI for poetry
- Add line numbering

**Tasks**:
1. Stanza detection and visualization:
   - Identify blank lines as stanza separators
   - Visual stanza containers in editor
   - Optional stanza numbering

2. Stanza operations:
   - Stanza-level selection
   - Move stanzas up/down
   - Delete stanza
   - Duplicate stanza
   - Undo/redo support

3. Editor enhancements:
   - Optional line numbering
   - Stanza spacing adjustments
   - Rhyme scheme visual guide (optional)
   - Theme/occasion tags

4. Tests:
   - Stanza detection tests
   - Stanza operations tests
   - Undo/redo with stanzas

**Deliverables**:
- Stanza management system
- Enhanced editor UI
- Line numbering
- 5+ unit tests

---

### Phase 009.5: Poetry-Specific File List & Filtering (Session 3)
**Priority**: MEDIUM - Information architecture  
**Time**: 1 hour

**Goals**:
- Show poetry metadata in file list
- Enable filtering by form/theme
- Display poetry-specific information

**Tasks**:
1. Enhance TextFileRowView:
   - Show poetry form badge (if poetry project)
   - Show line count
   - Show theme/occasion tag
   - Display validation status (if form selected)

2. Create filtering/sorting:
   - Filter by poetry form
   - Filter by theme
   - Sort by line count
   - Search poetry metadata

3. Create poetry file detail view:
   - Show all metadata
   - Show form requirements
   - Show validation status
   - Quick-edit metadata

**Deliverables**:
- Enhanced file list for poetry
- Filtering system
- Metadata display
- 4+ unit tests

---

## Technical Architecture

### Data Model

```swift
// Extend TextFile
extension TextFile {
    @Transient var poetryForm: PoetryForm?
    @Transient var theme: String?
    @Transient var occasion: String?
    
    var lineCount: Int {
        // Computed from content
    }
    
    var stanzaCount: Int {
        // Computed from content
    }
    
    var lines: [String] {
        // Split by line breaks, preserving empty lines
    }
}

// New types
enum PoetryForm: String, Codable {
    case freeVerse
    case haiku
    case sonnet
    case villanelle
    case limerick
    case custom
}

// Form validation
protocol PoetryValidator {
    func validate(_ text: String) -> ValidationResult
    var requiredLineCount: Int { get }
    var requiresSyllableCount: Bool { get }
    var targetSyllables: [Int]? { get }  // Per line
}

struct ValidationResult {
    let isValid: Bool
    let warnings: [ValidationWarning]
    let lineValidation: [LineValidation]
}

struct LineValidation {
    let lineNumber: Int
    let isValid: Bool
    let syllableCount: Int
    let syllableTarget: Int?
    let message: String?
}
```

### Service Layer

```swift
// SyllableCountingService
class SyllableCountingService {
    func countWord(_ word: String) -> Int
    func countLine(_ line: String) -> Int
    func analyzePoem(_ text: String, form: PoetryForm) -> AnalysisResult
}

// PoetryFormService
class PoetryFormService {
    func getValidator(for form: PoetryForm) -> PoetryValidator
    func createTemplate(for form: PoetryForm) -> String
    func analyze(_ text: String, for form: PoetryForm) -> AnalysisResult
}

// StanzaService
class StanzaService {
    func detectStanzas(in text: String) -> [Stanza]
    func moveStanza(from: Int, to: Int, in text: String) -> String
    func deleteStanza(at index: Int, in text: String) -> String
}
```

### UI Components

**New Views**:
- `PoetryFormSelector` - Choose form when creating file
- `PoetryEditorView` - Enhanced editor for poetry
- `PoetryMetadataView` - Display/edit poetry metadata
- `StanzaView` - Visual stanza container
- `LineValidationIndicator` - Show validation status

**Enhanced Views**:
- `TextFileEditorView` - Add poetry-specific features
- `TextFileRowView` - Display poetry metadata
- `ProjectSettingsView` - Poetry project configuration

## Implementation Dependencies

### External Libraries (Potential)
- CMU Pronouncing Dictionary (via API or bundled data)
- NLToolbox (built-in) for tokenization
- TextKit2 (built-in) for text handling

### Internal Dependencies
- TextFile model updates
- Version system (for content storage)
- Undo/redo system (already exists)
- Project system

## Success Criteria

✅ Poetry metadata stored and displayed  
✅ Line breaks preserved exactly  
✅ Form validation working  
✅ Syllable counting accurate  
✅ Stanza management functional  
✅ UI polished and responsive  
✅ All unit tests passing  
✅ Documentation complete  

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Syllable accuracy | Medium | Use reputable dictionary, fallback heuristics |
| Performance (real-time counting) | Medium | Debounce, caching, background processing |
| Text storage complexity | Low | Use NSAttributedString properly |
| Form validation edge cases | Low | Comprehensive test coverage |

## Timeline Estimate

- **Phase 009.1**: 1-2 hours (Session 1)
- **Phase 009.2**: 1.5-2 hours (Session 1-2)
- **Phase 009.3**: 1.5-2 hours (Session 2)
- **Phase 009.4**: 1-1.5 hours (Session 2-3)
- **Phase 009.5**: 1 hour (Session 3)

**Total**: 6-8.5 hours across 2-3 sessions

## Next Steps

1. ✅ Review specification
2. ⏳ Start Phase 009.1: Poetry metadata & line breaks
3. Create TextFile extensions
4. Enhance editor for poetry
5. Add unit tests
6. Proceed to Phase 009.2

---

**Ready to begin Phase 009.1?**

Shall I start with:
1. Creating the data model extensions?
2. Building the SyllableCountingService?
3. Enhancing the TextFileEditorView?
