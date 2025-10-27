# Phase 005: Text Formatting - Tasks

**Status**: Ready for Implementation  
**Created**: 2025-10-26  
**Updated**: 2025-10-27

## Task List

### Phase 1: Foundation & Data Model (Week 1)

#### Data Model Updates
- [ ] **T1.1**: Add `formattedContent: Data?` property to Version model
- [ ] **T1.2**: Add computed property `attributedContent: NSAttributedString?`
- [ ] **T1.3**: Update SwiftData schema version
- [ ] **T1.4**: Test model changes with CloudKit sync

#### Serialization Service
- [ ] **T1.5**: Create `AttributedStringSerializer.swift`
- [ ] **T1.6**: Implement `toRTF()` method
- [ ] **T1.7**: Implement `fromRTF()` method
- [ ] **T1.8**: Implement `toPlainText()` method
- [ ] **T1.9**: Add error handling for serialization failures
- [ ] **T1.10**: Create `AttributedStringSerializerTests.swift`
- [ ] **T1.11**: Test round-trip conversion (string → RTF → string)
- [ ] **T1.12**: Test with various formatting combinations

#### Number Format Model
- [ ] **T1.13**: Create `NumberFormat.swift` enum
- [ ] **T1.14**: Define all format cases (none, decimal, roman, etc.)
- [ ] **T1.15**: Make Codable for persistence
- [ ] **T1.16**: Add NSAttributedString key extension
- [ ] **T1.17**: Create `NumberFormatTests.swift`
- [ ] **T1.18**: Test serialization/deserialization

**Phase 1 Exit Criteria**:
- [ ] All tests passing
- [ ] formattedContent syncs to CloudKit
- [ ] RTF round-trip preserves formatting

---

### Phase 2: UITextView Wrapper (Week 2)

#### FormattedTextEditor Component
- [ ] **T2.1**: Create `FormattedTextEditor.swift` (UIViewRepresentable)
- [ ] **T2.2**: Implement `makeUIView()` to create UITextView
- [ ] **T2.3**: Implement `updateUIView()` for binding updates
- [ ] **T2.4**: Create Coordinator for UITextViewDelegate
- [ ] **T2.5**: Handle `textViewDidChange(_:)` callback
- [ ] **T2.6**: Handle `textViewDidChangeSelection(_:)` callback
- [ ] **T2.7**: Add @Binding for NSAttributedString
- [ ] **T2.8**: Add @Binding for selected range
- [ ] **T2.9**: Configure UITextView appearance (fonts, colors, etc.)
- [ ] **T2.10**: Handle keyboard show/hide notifications

#### FileEditView Integration
- [ ] **T2.11**: Replace TextEditor with FormattedTextEditor
- [ ] **T2.12**: Convert plain text to NSAttributedString on load
- [ ] **T2.13**: Update save logic to store RTF data
- [ ] **T2.14**: Maintain undo/redo integration
- [ ] **T2.15**: Preserve view refresh logic (forceRefresh toggle)
- [ ] **T2.16**: Test typing and text editing
- [ ] **T2.17**: Test selection and cursor movement

#### Keyboard Detection
- [ ] **T2.18**: Create `KeyboardObserver.swift` service
- [ ] **T2.19**: Detect on-screen keyboard vs external
- [ ] **T2.20**: Publish keyboard state as @Published property
- [ ] **T2.21**: Test on iPad with/without keyboard
- [ ] **T2.22**: Test on Mac Catalyst

**Phase 2 Exit Criteria**:
- [ ] Typing works smoothly in FormattedTextEditor
- [ ] Selection and cursor positioning correct
- [ ] Text saves and loads properly
- [ ] No performance issues
- [ ] Keyboard detection reliable

---

### Phase 3: Formatting Toolbar (Week 3)

#### Toolbar Component
- [ ] **T3.1**: Create `FormattingToolbar.swift`
- [ ] **T3.2**: Design button layout (HStack with ScrollView)
- [ ] **T3.3**: Implement InputAccessoryView positioning (iOS on-screen keyboard)
- [ ] **T3.4**: Implement bottom toolbar positioning (iOS external keyboard)
- [ ] **T3.5**: Implement top toolbar positioning (Mac Catalyst)
- [ ] **T3.6**: Handle toolbar visibility based on keyboard state
- [ ] **T3.7**: Add toolbar background and styling

#### Toolbar Buttons
- [ ] **T3.8**: Create Paragraph Style button (¶ icon)
- [ ] **T3.9**: Create Bold button (B)
- [ ] **T3.10**: Create Italic button (I)
- [ ] **T3.11**: Create Underline button (U with underline)
- [ ] **T3.12**: Create Strikethrough button (S with line through)
- [ ] **T3.13**: Create Insert button (+) with "Coming Soon" alert
- [ ] **T3.14**: Style buttons (SF Symbols, colors, states)
- [ ] **T3.15**: Handle button enabled/disabled states

#### TextFormatter Service
- [ ] **T3.16**: Create `TextFormatter.swift` service
- [ ] **T3.17**: Implement `toggleBold(in range:)` method
- [ ] **T3.18**: Implement `toggleItalic(in range:)` method
- [ ] **T3.19**: Implement `toggleUnderline(in range:)` method
- [ ] **T3.20**: Implement `toggleStrikethrough(in range:)` method
- [ ] **T3.21**: Implement `getFormattingState(at range:)` for button states
- [ ] **T3.22**: Handle partial formatting (mixed styles in selection)
- [ ] **T3.23**: Create `TextFormatterTests.swift`
- [ ] **T3.24**: Test each formatting operation
- [ ] **T3.25**: Test mixed formatting scenarios

#### Integration
- [ ] **T3.26**: Add FormattingToolbar to FileEditView
- [ ] **T3.27**: Connect toolbar buttons to TextFormatter
- [ ] **T3.28**: Update button states on selection change
- [ ] **T3.29**: Test on iPhone (portrait/landscape)
- [ ] **T3.30**: Test on iPad with different keyboard modes
- [ ] **T3.31**: Test on Mac Catalyst

**Phase 3 Exit Criteria**:
- [ ] Toolbar appears in correct position
- [ ] All formatting buttons functional
- [ ] Button states reflect current selection
- [ ] Performance acceptable (button updates < 50ms)
- [ ] Works on all platforms

---

### Phase 4: Paragraph Styles (Week 4)

#### Style Picker Sheet
- [ ] **T4.1**: Create `StylePickerSheet.swift`
- [ ] **T4.2**: List all UIFont.TextStyle options
- [ ] **T4.3**: Add preview for each style
- [ ] **T4.4**: Add style names (localized)
- [ ] **T4.5**: Handle style selection
- [ ] **T4.6**: Dismiss sheet after selection
- [ ] **T4.7**: Style sheet with .medium detent

#### Paragraph Style Logic
- [ ] **T4.8**: Extend TextFormatter with `applyStyle()` method
- [ ] **T4.9**: Implement paragraph boundary detection
- [ ] **T4.10**: Apply font for UIFont.TextStyle
- [ ] **T4.11**: Apply paragraph style attributes
- [ ] **T4.12**: Handle multiple paragraphs in selection
- [ ] **T4.13**: Preserve existing character formatting (bold, italic, etc.)
- [ ] **T4.14**: Update toolbar to show current paragraph style

#### Testing & Persistence
- [ ] **T4.15**: Test each style applies correctly
- [ ] **T4.16**: Test styles persist to RTF
- [ ] **T4.17**: Test styles load from RTF
- [ ] **T4.18**: Test CloudKit sync with styled text
- [ ] **T4.19**: Test style changes with undo (basic)

**Phase 4 Exit Criteria**:
- [ ] Style picker shows all styles with previews
- [ ] Styles apply correctly to paragraphs
- [ ] Styles persist across app restarts
- [ ] Styles sync via CloudKit
- [ ] Character formatting preserved when changing paragraph style

---

### Phase 5: Edit Menu & Style Editor (Week 5)

#### Edit Menu Customization
- [ ] **T5.1**: Research UIMenuController customization (iOS)
- [ ] **T5.2**: Add "Edit Style" menu item
- [ ] **T5.3**: Handle menu item selection
- [ ] **T5.4**: Present StyleEditorSheet
- [ ] **T5.5**: Test menu appears on text selection
- [ ] **T5.6**: Test on Mac Catalyst (context menu)

#### Style Editor Sheet
- [ ] **T5.7**: Create `StyleEditorSheet.swift`
- [ ] **T5.8**: Add Font section (family picker, size stepper)
- [ ] **T5.9**: Add Character section (B, I, U, S toggles)
- [ ] **T5.10**: Add Color section (color picker)
- [ ] **T5.11**: Add Number Format section (dropdown)
- [ ] **T5.12**: Add Alignment section (L, C, R, J buttons)
- [ ] **T5.13**: Add Indents section (first, left, right steppers)
- [ ] **T5.14**: Add Spacing section (line, before, after steppers)
- [ ] **T5.15**: Add live preview at top
- [ ] **T5.16**: Add Cancel/Done buttons
- [ ] **T5.17**: Handle done action (apply changes)
- [ ] **T5.18**: Handle cancel action (discard changes)

#### Advanced Formatting Logic
- [ ] **T5.19**: Extend TextFormatter with `setFont()` method
- [ ] **T5.20**: Implement font family/size changes
- [ ] **T5.21**: Implement text color changes
- [ ] **T5.22**: Implement alignment changes
- [ ] **T5.23**: Implement indentation changes (first line, margins)
- [ ] **T5.24**: Implement line spacing changes
- [ ] **T5.25**: Implement space before/after changes
- [ ] **T5.26**: Implement number format attribute (store only)
- [ ] **T5.27**: Update live preview as changes made

#### Testing
- [ ] **T5.28**: Test each formatting option
- [ ] **T5.29**: Test preview updates correctly
- [ ] **T5.30**: Test cancel discards changes
- [ ] **T5.31**: Test done applies changes
- [ ] **T5.32**: Test complex formatting combinations
- [ ] **T5.33**: Test persistence of advanced formatting

**Phase 5 Exit Criteria**:
- [ ] Edit Style menu item appears and works
- [ ] Style editor shows all current formatting
- [ ] All formatting options functional
- [ ] Live preview accurate
- [ ] Changes apply correctly to text
- [ ] Advanced formatting persists

---

### Phase 6: Undo/Redo Integration (Week 6)

#### Update Command Pattern
- [ ] **T6.1**: Review existing FormatApplyCommand
- [ ] **T6.2**: Implement FormatApplyCommand.execute()
- [ ] **T6.3**: Implement FormatApplyCommand.undo()
- [ ] **T6.4**: Store old/new NSAttributedString for range
- [ ] **T6.5**: Review existing FormatRemoveCommand
- [ ] **T6.6**: Implement FormatRemoveCommand.execute()
- [ ] **T6.7**: Implement FormatRemoveCommand.undo()
- [ ] **T6.8**: Handle format stripping logic

#### Typing Coalescing Updates
- [ ] **T6.9**: Update TextFileUndoManager for attributed strings
- [ ] **T6.10**: Detect format changes during typing
- [ ] **T6.11**: Flush typing buffer on format change
- [ ] **T6.12**: Preserve formatting in coalesced commands
- [ ] **T6.13**: Test typing → format → typing → undo sequence
- [ ] **T6.14**: Test format → undo → redo sequence

#### Integration Testing
- [ ] **T6.15**: Create `FormatCommandTests.swift`
- [ ] **T6.16**: Test FormatApplyCommand execute/undo/redo
- [ ] **T6.17**: Test FormatRemoveCommand execute/undo/redo
- [ ] **T6.18**: Update `UndoRedoTests.swift` for formatting
- [ ] **T6.19**: Test typing coalescing with formatting
- [ ] **T6.20**: Test multiple format changes + undo
- [ ] **T6.21**: Test partial format removal + undo
- [ ] **T6.22**: Test complex undo/redo scenarios

#### Performance & Polish
- [ ] **T6.23**: Profile undo/redo performance
- [ ] **T6.24**: Optimize attributed string copying if needed
- [ ] **T6.25**: Test with large documents (10,000+ words)
- [ ] **T6.26**: Test with heavily formatted text
- [ ] **T6.27**: Fix any memory leaks
- [ ] **T6.28**: Fix any performance issues

**Phase 6 Exit Criteria**:
- [ ] All format commands work with undo/redo
- [ ] Typing coalescing preserves formatting
- [ ] No performance degradation
- [ ] No memory leaks
- [ ] All tests passing (100% of unit + integration tests)

---

## Final Testing & Polish

### Comprehensive Testing
- [ ] **T7.1**: Run all unit tests (target: 100% pass)
- [ ] **T7.2**: Run all integration tests (target: 100% pass)
- [ ] **T7.3**: Manual testing checklist on iPhone
- [ ] **T7.4**: Manual testing checklist on iPad
- [ ] **T7.5**: Manual testing checklist on Mac Catalyst
- [ ] **T7.6**: Test CloudKit sync (2+ devices)
- [ ] **T7.7**: Test with external keyboard
- [ ] **T7.8**: Test accessibility features

### Bug Fixes & Polish
- [ ] **T7.9**: Fix any discovered bugs
- [ ] **T7.10**: Optimize performance issues
- [ ] **T7.11**: Polish UI/UX (animations, feedback, etc.)
- [ ] **T7.12**: Add loading states if needed
- [ ] **T7.13**: Add error messages for edge cases
- [ ] **T7.14**: Update localization strings

### Documentation
- [ ] **T7.15**: Document all new classes/methods
- [ ] **T7.16**: Update README if needed
- [ ] **T7.17**: Create user guide for formatting features
- [ ] **T7.18**: Document known limitations
- [ ] **T7.19**: Update quickstart.md

---

## Task Summary

| Phase | Tasks | Estimated Hours |
|-------|-------|-----------------|
| Phase 1: Foundation | 18 tasks | 40 hours |
| Phase 2: UITextView Wrapper | 22 tasks | 40 hours |
| Phase 3: Formatting Toolbar | 31 tasks | 40 hours |
| Phase 4: Paragraph Styles | 19 tasks | 40 hours |
| Phase 5: Style Editor | 33 tasks | 40 hours |
| Phase 6: Undo/Redo | 28 tasks | 40 hours |
| Final Testing | 19 tasks | 20 hours |
| **Total** | **170 tasks** | **260 hours** |

*Estimate: 6-7 weeks full-time or 3-4 months part-time*

---

## Progress Tracking

### Week 1: Foundation ✅ / ⚠️ / ❌
- [ ] T1.1-T1.18 completed
- [ ] All Phase 1 tests passing
- [ ] Peer review complete

### Week 2: UITextView Wrapper ✅ / ⚠️ / ❌
- [ ] T2.1-T2.22 completed
- [ ] All Phase 2 tests passing
- [ ] Peer review complete

### Week 3: Formatting Toolbar ✅ / ⚠️ / ❌
- [ ] T3.1-T3.31 completed
- [ ] All Phase 3 tests passing
- [ ] Peer review complete

### Week 4: Paragraph Styles ✅ / ⚠️ / ❌
- [ ] T4.1-T4.19 completed
- [ ] All Phase 4 tests passing
- [ ] Peer review complete

### Week 5: Style Editor ✅ / ⚠️ / ❌
- [ ] T5.1-T5.33 completed
- [ ] All Phase 5 tests passing
- [ ] Peer review complete

### Week 6: Undo/Redo ✅ / ⚠️ / ❌
- [ ] T6.1-T6.28 completed
- [ ] All Phase 6 tests passing
- [ ] Peer review complete

### Final: Testing & Polish ✅ / ⚠️ / ❌
- [ ] T7.1-T7.19 completed
- [ ] All tests passing
- [ ] Ready for release

---

## Notes

### Task Conventions
- **Task ID Format**: `T[Phase].[Number]` (e.g., T1.5)
- **Dependencies**: Tasks within a phase should generally be done in order
- **Blocking Tasks**: Tasks marked with 🚫 block other tasks
- **Optional Tasks**: Tasks marked with 🔹 are enhancements

### Testing Philosophy
- Write tests before implementation (TDD)
- Each service/component has dedicated test file
- Integration tests cover cross-component interactions
- Manual testing validates real-world usage

### When to Pause/Pivot
- After Phase 2: Have basic formatted text editing
- After Phase 3: Have usable formatting toolbar
- After Phase 4: Have complete paragraph styling
- After Phase 5: Have advanced style editor
- After Phase 6: Have production-ready feature

Can stop after any phase and still have working features!
