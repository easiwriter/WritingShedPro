# Phase 005: Text Formatting - Implementation Plan

**Status**: Ready for Implementation  
**Created**: 2025-10-26  
**Updated**: 2025-10-27

## Overview

Phase 005 implements text formatting capabilities using NSAttributedString and UITextView. The implementation is structured in 6 major phases to allow incremental development and testing.

## Implementation Phases

### Phase 1: Foundation & Data Model (Week 1)
**Goal**: Set up data structures and basic infrastructure

#### 1.1 Update Data Models
- Add `formattedContent: Data?` to Version model
- Keep existing `content: String?` for plain text
- Add computed property for NSAttributedString conversion
- Update SwiftData schema

#### 1.2 Create RTF Serialization Service
- `AttributedStringSerializer.swift`
  - `toRTF(_ attributedString: NSAttributedString) -> Data?`
  - `fromRTF(_ data: Data) -> NSAttributedString?`
  - `toPlainText(_ attributedString: NSAttributedString) -> String`
- Handle serialization errors gracefully
- Unit tests for round-trip conversion

#### 1.3 Create Number Format Model
- `NumberFormat.swift` enum
  - `none`, `decimal`, `lowercaseRoman`, `uppercaseRoman`
  - `lowercaseLetter`, `uppercaseLetter`
  - `footnoteSymbols`, `bulletSymbols`
- Store as custom NSAttributedString attribute
- Codable for persistence

**Deliverables**:
- ✅ Updated BaseModels.swift with formattedContent
- ✅ AttributedStringSerializer service with tests
- ✅ NumberFormat model
- ✅ All unit tests passing

---

### Phase 2: UITextView Wrapper (Week 2)
**Goal**: Replace SwiftUI TextEditor with formatted text support

#### 2.1 Create FormattedTextEditor
- `FormattedTextEditor.swift` (UIViewRepresentable)
- Wrap UITextView for SwiftUI
- Binding to NSAttributedString
- Handle delegate methods:
  - `textViewDidChange(_:)`
  - `textViewDidChangeSelection(_:)`
- Keyboard handling (show/hide)
- Focus management

#### 2.2 Integrate with FileEditView
- Replace existing TextEditor
- Maintain undo/redo integration
- Preserve existing view refresh logic
- Handle toolbar visibility
- Test typing and selection

#### 2.3 Keyboard Detection
- `KeyboardObserver.swift` service
- Detect on-screen vs external keyboard
- Publish keyboard state changes
- Use for toolbar positioning

**Deliverables**:
- ✅ FormattedTextEditor wrapper working
- ✅ FileEditView using new editor
- ✅ Typing and selection functional
- ✅ Keyboard detection service
- ✅ No regressions in existing features

---

### Phase 3: Formatting Toolbar (Week 3)
**Goal**: Build formatting toolbar with basic controls

#### 3.1 Create Toolbar Component
- `FormattingToolbar.swift`
- Position based on keyboard state:
  - InputAccessoryView (on-screen keyboard)
  - Bottom toolbar (external keyboard)
  - Top toolbar (Mac Catalyst)
- Horizontal ScrollView layout
- Button states (enabled/disabled based on selection)

#### 3.2 Implement Toolbar Buttons
- Paragraph Style button (¶) → Sheet
- Bold (B) toggle
- Italic (I) toggle
- Underline (U) toggle
- Strikethrough (S̶) toggle
- Insert (+) placeholder → "Coming Soon" alert

#### 3.3 Character Formatting Logic
- `TextFormatter.swift` service
- Apply/remove bold to selection
- Apply/remove italic to selection
- Apply/remove underline to selection
- Apply/remove strikethrough to selection
- Handle partial formatting (mixed styles)
- Update toolbar button states

**Deliverables**:
- ✅ FormattingToolbar component
- ✅ All toolbar buttons functional
- ✅ Character formatting working
- ✅ Button states reflect current selection
- ✅ Keyboard-aware positioning

---

### Phase 4: Paragraph Styles (Week 4)
**Goal**: Implement paragraph style picker and application

#### 4.1 Create Style Picker Sheet
- `StylePickerSheet.swift`
- List all UIFont.TextStyle options:
  - Body, Headline, Subheadline
  - Title 1, 2, 3
  - Caption 1, 2
  - Callout, Footnote, Large Title
- Show preview of each style
- Apply to current paragraph(s)

#### 4.2 Paragraph Style Logic
- Extend TextFormatter service
- `applyStyle(_ style: UIFont.TextStyle, to range: NSRange)`
- Find paragraph boundaries
- Apply font and paragraph style
- Update all paragraphs in selection
- Handle undo/redo

#### 4.3 Style Persistence
- Ensure styles stored in RTF
- Test round-trip (save/load/display)
- Verify CloudKit sync

**Deliverables**:
- ✅ Style picker sheet functional
- ✅ Styles apply correctly to paragraphs
- ✅ Styles persist and sync
- ✅ Undo/redo works with styles

---

### Phase 5: Edit Menu & Style Editor (Week 5)
**Goal**: Implement comprehensive style editing

#### 5.1 Customize Edit Menu
- Add "Edit Style" menu item
- Show on text selection
- Use UIMenuController (iOS) or EditMenu (SwiftUI)
- Present StyleEditorSheet

#### 5.2 Create Style Editor Sheet
- `StyleEditorSheet.swift`
- Sections:
  - **Font**: Family picker, size stepper
  - **Character**: Bold, Italic, Underline, Strikethrough toggles
  - **Color**: Color picker
  - **Number Format**: Dropdown (none, decimal, roman, etc.)
  - **Alignment**: Left, Center, Right, Justified buttons
  - **Indents**: First line, left, right steppers
  - **Spacing**: Line spacing, before, after steppers
- Live preview at top
- Cancel/Done buttons

#### 5.3 Advanced Formatting Logic
- Font family and size changes
- Text color application
- Paragraph alignment
- Indentation (first line, left, right margins)
- Line spacing
- Space before/after paragraphs
- Number format attribute (stored, not applied)

**Deliverables**:
- ✅ Edit Style menu item appears
- ✅ Style editor sheet complete
- ✅ All formatting options functional
- ✅ Live preview updates
- ✅ Changes apply correctly

---

### Phase 6: Undo/Redo Integration (Week 6)
**Goal**: Integrate formatting with existing undo system

#### 6.1 Update Command Pattern
- Modify `FormatApplyCommand`
  - Store old/new NSAttributedString for range
  - `execute()`: Apply new formatting
  - `undo()`: Restore old formatting
- Modify `FormatRemoveCommand`
  - Strip formatting from range
  - Restore plain text

#### 6.2 Typing Coalescing with Formatting
- Update TextFileUndoManager
- Detect format changes during typing
- Flush typing buffer on format change
- Preserve formatting in coalesced commands
- Test complex scenarios (type, format, type, undo)

#### 6.3 Integration Testing
- Format + undo + redo workflows
- Multiple format changes
- Partial format removal
- Mixed format scenarios
- Performance with large documents

**Deliverables**:
- ✅ FormatApplyCommand fully implemented
- ✅ FormatRemoveCommand fully implemented
- ✅ Typing coalescing preserves formatting
- ✅ All undo/redo tests passing
- ✅ No performance issues

---

## Timeline Summary

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 1. Foundation & Data Model | 1 week | Week 1 |
| 2. UITextView Wrapper | 1 week | Week 2 |
| 3. Formatting Toolbar | 1 week | Week 3 |
| 4. Paragraph Styles | 1 week | Week 4 |
| 5. Edit Menu & Style Editor | 1 week | Week 5 |
| 6. Undo/Redo Integration | 1 week | Week 6 |
| **Total** | **6 weeks** | |

*Note: Timeline assumes full-time development. Adjust for part-time or interrupted work.*

## Key Files to Create/Modify

### New Files
- `Services/AttributedStringSerializer.swift`
- `Models/NumberFormat.swift`
- `Views/Components/FormattedTextEditor.swift`
- `Views/Components/FormattingToolbar.swift`
- `Views/Components/StylePickerSheet.swift`
- `Views/Components/StyleEditorSheet.swift`
- `Services/TextFormatter.swift`
- `Services/KeyboardObserver.swift`

### Modified Files
- `Models/BaseModels.swift` (add formattedContent to Version)
- `Views/FileEditView.swift` (use FormattedTextEditor)
- `Services/Undo/TextFileUndoManager.swift` (formatting support)
- `Services/Undo/Commands/FormatApplyCommand.swift` (implement)
- `Services/Undo/Commands/FormatRemoveCommand.swift` (implement)

### Test Files
- `AttributedStringSerializerTests.swift`
- `NumberFormatTests.swift`
- `TextFormatterTests.swift`
- `FormattedTextEditorTests.swift`
- `FormatCommandTests.swift`
- Update existing `UndoRedoTests.swift`

## Risk Assessment

### High Risk
1. **UITextView Wrapper Complexity**
   - **Risk**: SwiftUI <-> UIKit bridge can be fragile
   - **Mitigation**: Extensive testing, follow Apple best practices, handle edge cases
   - **Fallback**: Keep plain text editor available as backup

2. **Performance with Large Documents**
   - **Risk**: Attributed strings are memory-intensive
   - **Mitigation**: Test with 10,000+ word documents, optimize rendering, lazy loading if needed
   - **Fallback**: Disable formatting for very large files

3. **CloudKit Sync with Binary Data**
   - **Risk**: RTF data might not sync reliably
   - **Mitigation**: Extensive sync testing, conflict resolution strategy, data validation
   - **Fallback**: Store as base64 string if Data sync fails

### Medium Risk
1. **Keyboard Detection Reliability**
   - **Risk**: External keyboard detection might be inconsistent
   - **Mitigation**: Test on multiple devices, provide manual toggle
   - **Fallback**: Default to bottom toolbar placement

2. **Undo/Redo Complexity**
   - **Risk**: Formatting + typing coalescing is complex
   - **Mitigation**: Comprehensive unit tests, clear flush conditions
   - **Fallback**: Disable coalescing for formatted text

3. **Mac Catalyst Differences**
   - **Risk**: Toolbar behavior differs on macOS
   - **Mitigation**: Test on Mac early, platform-specific code paths
   - **Fallback**: Simplified toolbar for Mac

### Low Risk
1. **RTF Serialization**
   - **Risk**: Edge cases might not serialize correctly
   - **Mitigation**: Unit tests with various formatting combinations
   - **Fallback**: Switch to NSKeyedArchiver

2. **Edit Menu Customization**
   - **Risk**: System menu might conflict with custom items
   - **Mitigation**: Follow Apple HIG, test thoroughly
   - **Fallback**: Use separate formatting menu

## Success Metrics

### Phase Completion Criteria
Each phase must meet these criteria before moving to next:
- [ ] All code compiles without warnings
- [ ] All unit tests passing
- [ ] Manual testing checklist complete
- [ ] No crashes or major bugs
- [ ] Performance acceptable (< 100ms for formatting operations)
- [ ] Code reviewed and documented

### Overall Success Criteria (from spec.md)
- [ ] User can select text and see Edit Menu with "Edit Style"
- [ ] Formatting toolbar appears and positions correctly
- [ ] All character formatting options work (B, I, U, S)
- [ ] Paragraph styles apply from picker
- [ ] Style editor allows full customization
- [ ] Formatted text persists across app restarts
- [ ] Formatted text syncs via CloudKit
- [ ] Formatting changes can be undone/redone
- [ ] No lag when typing in formatted documents
- [ ] All tests passing (unit, integration, UI)

## Notes

### Development Approach
- **TDD**: Write tests before implementation
- **Incremental**: Each phase builds on previous
- **Testable**: Can pause after any phase with working features
- **Reversible**: Can roll back to plain text if needed

### Future Considerations (Phase 006+)
- Automatic list numbering
- Comments and annotations
- Index entries
- Footnote management
- Page breaks
- Table support

### Testing Strategy
- Unit tests for each service/model
- Integration tests for formatting + undo/redo
- UI tests for toolbar and style editor
- Manual testing on iOS and Mac Catalyst
- Performance testing with large documents
- Sync testing across multiple devices
