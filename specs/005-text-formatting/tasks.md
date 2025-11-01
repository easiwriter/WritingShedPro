# Phase 005: Text Formatting - Tasks

**Status**: Phase 4 Complete - Paragraph Styles Working  
**Created**: 2025-10-26  
**Updated**: 2025-11-01

## Task List

### Phase 1: Foundation & Data Model (Week 1) ✅ COMPLETE

#### Data Model Updates
- [X] **T1.1**: Add `formattedContent: Data?` property to Version model
- [X] **T1.2**: Add computed property `attributedContent: NSAttributedString?`
- [X] **T1.3**: Update SwiftData schema version
- [X] **T1.4**: Test model changes with CloudKit sync

#### Serialization Service
- [X] **T1.5**: Create `AttributedStringSerializer.swift`
- [X] **T1.6**: Implement `toRTF()` method
- [X] **T1.7**: Implement `fromRTF()` method
- [X] **T1.8**: Implement `toPlainText()` method
- [X] **T1.9**: Add error handling for serialization failures
- [X] **T1.10**: Create `AttributedStringSerializerTests.swift`
- [X] **T1.11**: Test round-trip conversion (string → RTF → string)
- [X] **T1.12**: Test with various formatting combinations

#### Number Format Model
- [X] **T1.13**: Create `NumberFormat.swift` enum
- [X] **T1.14**: Define all format cases (none, decimal, roman, etc.)
- [X] **T1.15**: Make Codable for persistence
- [X] **T1.16**: Add NSAttributedString key extension
- [X] **T1.17**: Create `NumberFormatTests.swift`
- [X] **T1.18**: Test serialization/deserialization

**Phase 1 Exit Criteria**:
- [X] All tests passing
- [X] formattedContent syncs to CloudKit
- [X] RTF round-trip preserves formatting

---

### Phase 2: UITextView Wrapper (Week 2) ✅ COMPLETE

#### FormattedTextEditor Component
- [X] **T2.1**: Create `FormattedTextEditor.swift` (UIViewRepresentable)
- [X] **T2.2**: Implement `makeUIView()` to create UITextView
- [X] **T2.3**: Implement `updateUIView()` for binding updates
- [X] **T2.4**: Create Coordinator for UITextViewDelegate
- [X] **T2.5**: Handle `textViewDidChange(_:)` callback
- [X] **T2.6**: Handle `textViewDidChangeSelection(_:)` callback
- [X] **T2.7**: Add @Binding for NSAttributedString
- [X] **T2.8**: Add @Binding for selected range
- [X] **T2.9**: Configure UITextView appearance (fonts, colors, etc.)
- [X] **T2.10**: Handle keyboard show/hide notifications

#### FileEditView Integration
- [X] **T2.11**: Replace TextEditor with FormattedTextEditor
- [X] **T2.12**: Convert plain text to NSAttributedString on load
- [X] **T2.13**: Update save logic to store RTF data
- [X] **T2.14**: Maintain undo/redo integration
- [X] **T2.15**: Preserve view refresh logic (forceRefresh toggle)
- [X] **T2.16**: Test typing and text editing - *Working correctly after fixes*
- [X] **T2.17**: Test selection and cursor movement - *Arrow keys work perfectly; tap positioning has UITextView limitations (documented)*

#### Keyboard Detection
- [X] **T2.18**: Create `KeyboardObserver.swift` service
- [X] **T2.19**: Detect on-screen keyboard vs external
- [X] **T2.20**: Publish keyboard state as @Published property
- [X] **T2.21**: Test on iPad with/without keyboard - *Formatting toolbar working*
- [X] **T2.22**: Test on Mac Catalyst - *Formatting toolbar working*

**Phase 2 Exit Criteria**:
- [X] Typing works smoothly in FormattedTextEditor
- [X] Selection and cursor positioning - *Arrow keys work perfectly; tap has UITextView platform limitations (documented)*
- [X] Text saves and loads properly
- [X] No performance issues
- [X] Keyboard detection reliable

**Known Issues**:
- Tap-to-position cursor has UITextView platform limitations (consistent with Apple's Pages)
- Long-press + drag required for precise positioning
- Arrow key navigation works perfectly
- Documented in KNOWN_ISSUES.md

**Status**: ✅ COMPLETE (Committed: 659b2cc)

---

### Phase 3: Formatting Toolbar (Week 3) ✅ COMPLETE

#### Toolbar Component
- [X] **T3.1**: Create `FormattingToolbar.swift`
- [X] **T3.2**: Design button layout (HStack with ScrollView)
- [X] **T3.3**: Implement InputAccessoryView positioning (iOS on-screen keyboard)
- [X] **T3.4**: Implement bottom toolbar positioning (iOS external keyboard)
- [X] **T3.5**: Implement top toolbar positioning (Mac Catalyst)
- [X] **T3.6**: Handle toolbar visibility based on keyboard state
- [X] **T3.7**: Add toolbar background and styling

#### Toolbar Buttons
- [X] **T3.8**: Create Paragraph Style button (¶ icon)
- [X] **T3.9**: Create Bold button (B)
- [X] **T3.10**: Create Italic button (I)
- [X] **T3.11**: Create Underline button (U with underline)
- [X] **T3.12**: Create Strikethrough button (S with line through)
- [X] **T3.13**: Create Insert button (+) with "Coming Soon" alert
- [X] **T3.14**: Style buttons (SF Symbols, colors, states)
- [X] **T3.15**: Handle button enabled/disabled states

#### TextFormatter Service
- [X] **T3.16**: Create `TextFormatter.swift` service
- [X] **T3.17**: Implement `toggleBold(in range:)` method
- [X] **T3.18**: Implement `toggleItalic(in range:)` method
- [X] **T3.19**: Implement `toggleUnderline(in range:)` method
- [X] **T3.20**: Implement `toggleStrikethrough(in range:)` method
- [X] **T3.21**: Implement `getFormattingState(at range:)` for button states
- [X] **T3.22**: Handle partial formatting (mixed styles in selection)
- [X] **T3.23**: Create `TextFormatterTests.swift`
- [X] **T3.24**: Test each formatting operation
- [X] **T3.25**: Test mixed formatting scenarios

#### Integration
- [X] **T3.26**: Add FormattingToolbar to FileEditView
- [X] **T3.27**: Connect toolbar buttons to TextFormatter
- [X] **T3.28**: Update button states on selection change
- [X] **T3.29**: Test on iPhone (portrait/landscape)
- [X] **T3.30**: Test on iPad with different keyboard modes
- [X] **T3.31**: Test on Mac Catalyst

**Phase 3 Exit Criteria**:
- [X] Toolbar appears in correct position
- [X] All formatting buttons functional
- [X] Button states reflect current selection
- [X] Performance acceptable (button updates < 50ms)
- [X] Works on all platforms

**Status**: ✅ COMPLETE

---

### Phase 4: Paragraph Styles (Week 4) ✅ COMPLETE

#### Style Picker Sheet
- [X] **T4.1**: Create `StylePickerSheet.swift`
- [X] **T4.2**: List all UIFont.TextStyle options
- [X] **T4.3**: Add preview for each style
- [X] **T4.4**: Add style names (localized)
- [X] **T4.5**: Handle style selection
- [X] **T4.6**: Dismiss sheet after selection
- [X] **T4.7**: Style sheet with .medium detent

#### Paragraph Style Logic
- [X] **T4.8**: Extend TextFormatter with `applyStyle()` method
- [X] **T4.9**: Implement paragraph boundary detection
- [X] **T4.10**: Apply font for UIFont.TextStyle (via TextStyleModel)
- [X] **T4.11**: Apply paragraph style attributes (alignment, spacing)
- [X] **T4.12**: Handle multiple paragraphs in selection
- [X] **T4.13**: Preserve existing character formatting (bold, italic, etc.)
- [X] **T4.14**: Update toolbar to show current paragraph style

#### Database-Driven Styles
- [X] **T4.15a**: Create TextStyleModel for database storage
- [X] **T4.15b**: Create StyleSheet model for style collections
- [X] **T4.15c**: Implement StyleSheetService for style resolution
- [X] **T4.15d**: Create TextStyleEditorView for editing styles
- [X] **T4.15e**: Create StyleSheetManagementView for managing stylesheets
- [X] **T4.15f**: Integrate database styles with TextFormatter
- [X] **T4.15g**: Implement reapplyAllStyles() to update documents when styles change

#### Testing & Persistence
- [X] **T4.16**: Test each style applies correctly
- [X] **T4.17**: Test styles persist to RTF (via AttributedStringSerializer)
- [X] **T4.18**: Test styles load from RTF
- [X] **T4.19**: Test CloudKit sync with styled text
- [X] **T4.20**: Test style changes with undo
- [X] **T4.21**: Test database-driven style updates
- [X] **T4.22**: Fix cleanParagraphStyles removing valid paragraph styles
- [X] **T4.23**: Fix FormattedTextEditor layout invalidation for paragraph styles
- [X] **T4.24**: Implement onAppear style reapplication when returning to documents

**Phase 4 Exit Criteria**:
- [X] Style picker shows all styles with previews from database
- [X] Styles apply correctly to paragraphs
- [X] Styles persist across app restarts
- [X] Styles sync via CloudKit
- [X] Character formatting preserved when changing paragraph style
- [X] Database-driven style system fully functional
- [X] Style changes in editor reflect in open documents
- [X] Manage Stylesheets opens as sheet with Done button

**Major Improvements**:
- ✅ Database-driven style system with TextStyleModel and StyleSheet
- ✅ Full style editor with font, size, color, alignment, spacing, traits
- ✅ Style management interface for creating/editing/duplicating stylesheets
- ✅ Automatic style reapplication when documents are opened
- ✅ Fixed paragraph style preservation (cleanParagraphStyles bug)
- ✅ Fixed UITextView rendering of paragraph styles (layout invalidation)
- ✅ Sheet-based UI for style management
- ✅ Project-level stylesheet assignment

**Status**: ✅ COMPLETE (Commits: multiple, final: 7b40dd7)

---

### Phase 5: Edit Menu & Style Editor (Week 5) ✅ COMPLETE (Repurposed)

#### Edit Menu Customization
- [~] **T5.1**: Research UIMenuController customization (iOS) - *Deferred: using dedicated UI instead*
- [~] **T5.2**: Add "Edit Style" menu item - *Not needed with current UI approach*
- [~] **T5.3**: Handle menu item selection - *Not needed with current UI approach*
- [~] **T5.4**: Present StyleEditorSheet - *Implemented via Manage Stylesheets button*
- [~] **T5.5**: Test menu appears on text selection - *Not applicable*
- [~] **T5.6**: Test on Mac Catalyst (context menu) - *Not applicable*

#### Style Editor Sheet (Completed in Phase 4)
- [X] **T5.7**: Create `TextStyleEditorView.swift` (style editor)
- [X] **T5.8**: Add Font section (family picker, size stepper)
- [X] **T5.9**: Add Character section (B, I, U, S toggles)
- [X] **T5.10**: Add Color section (color picker)
- [X] **T5.11**: Add Number Format section (dropdown) - *Stored in model, display TBD*
- [X] **T5.12**: Add Alignment section (L, C, R, J buttons)
- [X] **T5.13**: Add Indents section (first, left, right steppers)
- [X] **T5.14**: Add Spacing section (line, before, after steppers)
- [X] **T5.15**: Add live preview at top
- [X] **T5.16**: Add Cancel/Done buttons
- [X] **T5.17**: Handle done action (apply changes)
- [X] **T5.18**: Handle cancel action (discard changes)

#### Advanced Formatting Logic (Completed in Phase 4)
- [X] **T5.19**: Extend TextFormatter with `setFont()` method - *Via TextStyleModel*
- [X] **T5.20**: Implement font family/size changes
- [X] **T5.21**: Implement text color changes
- [X] **T5.22**: Implement alignment changes
- [X] **T5.23**: Implement indentation changes (first line, margins)
- [X] **T5.24**: Implement line spacing changes
- [X] **T5.25**: Implement space before/after changes
- [X] **T5.26**: Implement number format attribute (store only)
- [X] **T5.27**: Update live preview as changes made

#### Testing
- [X] **T5.28**: Test each formatting option
- [X] **T5.29**: Test preview updates correctly
- [X] **T5.30**: Test cancel discards changes
- [X] **T5.31**: Test done applies changes
- [X] **T5.32**: Test complex formatting combinations
- [X] **T5.33**: Test persistence of advanced formatting

**Phase 5 Exit Criteria**:
- [X] Style editor shows all current formatting
- [X] All formatting options functional
- [X] Live preview accurate
- [X] Changes apply correctly to text
- [X] Advanced formatting persists
- [~] Edit menu integration - *Deferred: dedicated UI approach preferred*

**Note**: Phase 5 was largely completed during Phase 4 implementation. The database-driven style system provides more comprehensive functionality than originally planned with the Edit Menu approach. Edit menu integration deferred as dedicated style management UI is more user-friendly.

**Status**: ✅ COMPLETE (via Phase 4 implementation)

---

### Phase 6: Undo/Redo Integration (Week 6) ⏳ PARTIAL
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
- [X] **T6.1**: Review existing FormatApplyCommand
- [X] **T6.2**: Implement FormatApplyCommand.execute()
- [X] **T6.3**: Implement FormatApplyCommand.undo()
- [X] **T6.4**: Store old/new NSAttributedString for range
- [~] **T6.5**: Review existing FormatRemoveCommand - *Not implemented, not needed*
- [~] **T6.6**: Implement FormatRemoveCommand.execute() - *Not needed*
- [~] **T6.7**: Implement FormatRemoveCommand.undo() - *Not needed*
- [~] **T6.8**: Handle format stripping logic - *Toggle operations handle this*

#### Typing Coalescing Updates
- [ ] **T6.9**: Update TextFileUndoManager for attributed strings - *Needs review*
- [ ] **T6.10**: Detect format changes during typing - *Needs implementation*
- [ ] **T6.11**: Flush typing buffer on format change - *Needs implementation*
- [ ] **T6.12**: Preserve formatting in coalesced commands - *Needs implementation*
- [ ] **T6.13**: Test typing → format → typing → undo sequence
- [X] **T6.14**: Test format → undo → redo sequence - *Basic functionality working*

#### Integration Testing
- [X] **T6.15**: Create `FormattingCommandTests.swift`
- [X] **T6.16**: Test FormatApplyCommand execute/undo/redo
- [~] **T6.17**: Test FormatRemoveCommand execute/undo/redo - *Not applicable*
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
- [X] Basic format commands work with undo/redo
- [ ] Typing coalescing preserves formatting - *Needs work*
- [ ] No performance degradation
- [ ] No memory leaks
- [ ] All tests passing (100% of unit + integration tests)

**Status**: ⏳ PARTIAL - Basic undo/redo working, typing coalescing needs refinement

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

### Week 1: Foundation ✅
- [X] T1.1-T1.18 completed
- [X] All Phase 1 tests passing
- [X] Peer review complete

### Week 2: UITextView Wrapper ✅
- [X] T2.1-T2.22 completed
- [X] All Phase 2 implementation complete
- [X] Build successful with no errors
- [X] Committed: 659b2cc

### Week 3: Formatting Toolbar ✅
- [X] T3.1-T3.31 completed
- [X] All Phase 3 implementation complete
- [X] All platforms tested

### Week 4: Paragraph Styles ✅
- [X] T4.1-T4.24 completed
- [X] Database-driven style system implemented
- [X] Style management UI complete
- [X] All major bugs fixed

### Week 5: Style Editor ✅ (Completed in Week 4)
- [X] T5.7-T5.33 completed during Phase 4
- [X] Full style editor with all formatting options
- [X] Comprehensive testing complete

### Week 6: Undo/Redo ⏳
- [X] T6.1-T6.16 partially completed
- [ ] T6.9-T6.13 typing coalescing needs work
- [ ] T6.18-T6.28 comprehensive testing needed

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
