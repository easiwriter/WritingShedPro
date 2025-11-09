# Technical Debt: Localization & Accessibility

**Created**: 9 November 2025  
**Status**: Documented - Not Yet Addressed  
**Priority**: High (but scheduled for later)  
**Estimated Effort**: 2-3 weeks

---

## Problem Statement

The existing codebase (Features 001-008a) was developed **before** localization and accessibility standards were established. This results in:

1. **100+ hard-coded user-facing strings** throughout the app
2. **Missing accessibility labels** on buttons and interactive elements
3. **No VoiceOver support** for custom views
4. **No localization files** (.strings, .stringsdict)

---

## Impact

### User Impact
- **Non-English users**: Cannot use app in their language
- **VoiceOver users**: Cannot navigate app effectively
- **Users with disabilities**: Poor accessibility experience

### Development Impact
- **New features**: Must maintain two standards (old vs new)
- **Code quality**: Inconsistent patterns across codebase
- **App Store**: May not meet accessibility guidelines

### Business Impact
- **Market reach**: Limited to English-speaking markets
- **App Store**: Could affect review ratings
- **Legal**: Potential accessibility compliance issues

---

## Scope of Work

### Files Affected (Preliminary Audit)
Minimum 50+ files with hard-coded strings, including:

**Views:**
- FileListView.swift
- MoveDestinationPicker.swift
- TrashView.swift
- FolderFilesView.swift
- FileEditView.swift
- FolderEditableList.swift
- FolderDetailView.swift
- TextStyleEditorView.swift
- ImageStyleSheetEditorView.swift
- ProjectsListView.swift (likely)
- AddProjectView.swift (likely)
- Many more...

**Components:**
- All custom buttons
- All alert dialogs
- All form labels
- All empty states
- All error messages

---

## Proposed Solution

### Phase 1: Infrastructure (Week 1)
1. Create Localizable.strings file
2. Create Localizable.stringsdict for plurals
3. Extract all strings to keys
4. Add base English translations
5. Set up localization project structure

### Phase 2: Systematic Replacement (Week 2-3)
Work through files systematically:

**Priority 1 (Week 2):**
- User-facing errors and alerts
- Main navigation and titles
- Form labels and placeholders
- Button labels

**Priority 2 (Week 3):**
- Empty states
- Help text
- Validation messages
- Status indicators

**Priority 3 (As time permits):**
- Debug strings (can remain hard-coded)
- Developer-facing messages
- Internal logs

### Phase 3: Accessibility (Week 3-4)
1. Add .accessibilityLabel() to all buttons
2. Add .accessibilityHint() where needed
3. Make custom views accessible
4. Test with VoiceOver
5. Fix navigation issues

### Phase 4: Testing & Validation
1. VoiceOver testing on all screens
2. Pseudo-localization testing
3. Dynamic Type testing
4. Color contrast validation
5. Accessibility audit

---

## Enforcement Going Forward

### Code Review Requirements
Starting with Feature 008b Phase 2:
- [ ] All new code MUST be localized
- [ ] All new code MUST be accessible
- [ ] No hard-coded strings in pull requests
- [ ] VoiceOver testing required for UI changes

### Automated Checks
Consider adding:
- SwiftLint rule to catch hard-coded strings
- Build-time warnings for Text("literal")
- Pre-commit hooks to enforce standards

---

## Proposed Timeline

### Option A: Separate Feature (RECOMMENDED)
- **When**: After Feature 008b is complete
- **Feature ID**: 016 (Localization & Accessibility Retrofit)
- **Duration**: 3-4 weeks
- **Benefit**: Doesn't block current work

### Option B: Gradual Migration
- **When**: Fix each file as we touch it
- **Duration**: 6-12 months
- **Risk**: New violations could slip in

### Option C: Immediate Fix
- **When**: Now (pause Feature 008b)
- **Duration**: 3-4 weeks
- **Risk**: Delays Feature 008b significantly

---

## Recommendation

**Go with Option A**: Document now, fix later as Feature 016

**Rationale:**
1. ✅ Feature 008b momentum maintained
2. ✅ Standards documented and enforced going forward
3. ✅ All new code (Phase 2+) will be compliant
4. ✅ Systematic cleanup can be properly planned
5. ✅ Lower risk of breaking working features

**Timeline:**
- **Now**: Complete Feature 008b with proper localization/accessibility
- **After 008b**: Create Feature 016 specification
- **Next Sprint**: Tackle localization retrofit systematically

---

## Tracking

### Current Status
- ⚠️ **Features 001-008a**: Non-compliant (hard-coded strings, missing accessibility)
- ✅ **Feature 008b Phase 1**: Compliant (models only, no UI yet)
- 🎯 **Feature 008b Phase 2+**: Will be fully compliant
- 📋 **Feature 016**: Planned (retrofit existing code)

### Compliance by Feature
| Feature | Localization | Accessibility | Status |
|---------|--------------|---------------|--------|
| 001 Project Management | ❌ | ❌ | Needs retrofit |
| 002 Folder Creation | ❌ | ❌ | Needs retrofit |
| 003 File Creation | ❌ | ❌ | Needs retrofit |
| 004 Undo/Redo | ❌ | ❌ | Needs retrofit |
| 005 Text Formatting | ❌ | ❌ | Needs retrofit |
| 006 Image Support | ❌ | ❌ | Needs retrofit |
| 007 Word/Line Count | ❌ | ❌ | Needs retrofit |
| 008a File Movement | ❌ | ❌ | Needs retrofit |
| 008b Publications (Phase 1) | ✅ | ✅ | Compliant |
| 008b Publications (Phase 2+) | 🎯 | 🎯 | In progress |

---

## Resources Needed

### Skills
- Swift/SwiftUI expertise
- Localization experience
- Accessibility knowledge
- VoiceOver testing experience

### Tools
- Xcode localization tools
- Accessibility Inspector
- VoiceOver
- SwiftLint (optional)

### Time
- Development: 2-3 weeks
- Testing: 3-5 days
- Review: 2-3 days
- **Total**: 3-4 weeks

---

## Success Criteria

### Localization
- [ ] All user-facing strings use localization keys
- [ ] Localizable.strings file created and populated
- [ ] Plurals handled with .stringsdict
- [ ] No hard-coded strings in UI code
- [ ] Ready for translation to other languages

### Accessibility
- [ ] All buttons have .accessibilityLabel()
- [ ] All custom views properly labeled
- [ ] VoiceOver navigation works on all screens
- [ ] Dynamic Type supported
- [ ] Color contrast meets WCAG AA standards

### Quality
- [ ] No regressions in existing features
- [ ] All manual tests still pass
- [ ] VoiceOver test suite passes
- [ ] Pseudo-localization testing complete

---

## Notes

This technical debt accumulated because:
1. Project started before standards were established
2. Early focus on feature development over i18n
3. No accessibility requirements initially
4. Learning curve on proper iOS practices

Going forward, these standards are **mandatory** and enforced through:
- Code review checklist
- Development notes
- Copilot instructions
- (Future) Automated linting

---

**Decision**: Defer to Feature 016, ensure all Feature 008b code is compliant from start  
**Owner**: To be assigned when Feature 016 is scheduled  
**Review Date**: After Feature 008b completion
