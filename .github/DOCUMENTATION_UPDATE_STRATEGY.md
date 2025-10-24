# Documentation Update Strategy

**Created**: 21 October 2025  
**Purpose**: Guide for keeping documentation in sync as project evolves  
**Status**: Active

---

## Overview

The Writing Shed Pro project uses a living documentation approach where all guides are updated as the project progresses through phases. This document describes how documentation evolves with the codebase.

---

## Documentation Files & Update Schedule

### Tier 1: Continuously Updated (During Phase Development)

These files change as you work on each phase:

| File | Location | Update Frequency | When to Update |
|------|----------|------------------|-----------------|
| **spec.md** | `specs/00X-*/spec.md` | Continuous | Requirements clarifications, user story refinements |
| **tasks.md** | `specs/00X-*/tasks.md` | Per task completion | Mark tasks done, add discovered tasks |
| **plan.md** | `specs/00X-*/plan.md` | During planning | Architecture decisions, discovered patterns |

**Update Trigger**: As you work on each phase

---

### Tier 2: Major Updates (Phase Completion)

These files receive significant updates when each phase completes:

| File | Location | What Changes | Example |
|------|----------|--------------|---------|
| **README.md** | Root | Phase status, milestones, achievements | "Phase 003: Text Editing ✅ Complete (18 tests)" |
| **IMPLEMENTATION_GUIDE.md** | Root | Architecture sections, new patterns, code examples | Add TextEditor pattern, update test stats |
| **QUICK_REFERENCE.md** | Root | New common patterns, debugging tips | Add "Auto-save pattern", new error scenarios |
| **COMPLETION_SUMMARY.md** | Root | Phase completion records | New phase entry with stats and dates |

**Update Trigger**: When user says "Phase X complete"

---

### Tier 3: Static Reference (Historical)

These files are immutable records:

| File | Reason |
|------|--------|
| **REPLAY_CHECKLIST.md** | Process documentation - update only if build/test process changes |
| **Previous phase specs** | Historical reference - don't modify |
| **Git commits** | Immutable history - never change |

**Update Trigger**: Only for critical fixes or process changes

---

## Update Process

### 1. When User Reports Phase Completion

**User says**: 
```
"Phase 003 complete - text editing with 18 tests
- TextEditorView.swift (NEW)
- ContentSyncService.swift (NEW)  
- Fixed 2 CloudKit bugs"
```

**I will do**:

#### A. Update README.md
```markdown
# Before
### Phase 003: Coming Soon 🔮
- Text editing in files
- Auto-save on keystroke

# After
### Phase 003: Text Editing ✅ Complete (21 Oct 2025)
- [x] Rich text editing (TextEditorView.swift)
- [x] Auto-save on keystroke (ContentSyncService.swift)
- [x] CloudKit content sync
- Tests: +18 new (84/84 total passing)
- Coverage: 95% maintained
```

#### B. Update IMPLEMENTATION_GUIDE.md

**Architecture section**:
```markdown
# Before
Views/ (Phase 002)
├── FileDetailView.swift       # File metadata

# After
Views/ (Phase 002-003)
├── FileDetailView.swift       # File metadata
├── TextEditorView.swift       # Rich text editing (NEW Phase 003)
├── ContentSyncService.swift   # Auto-save (NEW Phase 003)
```

**Testing section**:
```markdown
# Before
Phase 002: 21 tests
Total: 66 tests

# After
Phase 002: 21 tests
Phase 003: 18 tests (new)
Total: 84 tests
```

**New section for Phase 003 patterns**:
```markdown
## Phase 003: Text Editing Patterns

### Auto-Save Pattern
```swift
// Save content to file on change
@State private var autoSaveTimer: Timer?

func scheduleAutoSave() {
    autoSaveTimer?.invalidate()
    autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) {
        saveContent()
    }
}
```

### CloudKit Content Sync
[New pattern documentation]
```

#### C. Update QUICK_REFERENCE.md

**Add new section**:
```markdown
### Auto-Save Implementation
```swift
// Debounce save operations
@State private var saveTask: Task<Void, Never>?

func saveWithDebounce() {
    saveTask?.cancel()
    saveTask = Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        try await save()
    }
}
```

**Add debugging section**:
```markdown
| Issue | Solution | File |
|-------|----------|------|
| Content not syncing | Check CloudKit entitlements | ContentSyncService.swift |
| Auto-save lag | Verify timer isn't firing too often | TextEditorView.swift |
```

#### D. Update COMPLETION_SUMMARY.md

**Add Phase 003 entry**:
```markdown
### Phase 003: Text Editing ✅ Complete (21 Oct 2025)

| Metric | Value |
|--------|-------|
| New Tests | 18 |
| Total Tests | 84/84 ✅ |
| Code Coverage | 95% |
| Files Created | 2 (TextEditorView, ContentSyncService) |
| Files Modified | 1 (FileDetailView) |
| Bugs Fixed | 2 (CloudKit sync, autosave timing) |
| Git Commit | [new commit hash] |

**Key Features**:
- Rich text editing in files
- Auto-save on keystroke (2s debounce)
- CloudKit sync for content changes
- Word count display

**Architecture Decisions**:
- Used Timer for auto-save (debounce pattern)
- Content sync via CloudKitSyncService
- Separated concerns: TextEditorView (UI) vs ContentSyncService (persistence)
```

#### E. Commit Updates
```bash
git add README.md IMPLEMENTATION_GUIDE.md QUICK_REFERENCE.md COMPLETION_SUMMARY.md
git commit -m "Update documentation for Phase 003 completion

- Added Phase 003 status to README
- Updated architecture overview in IMPLEMENTATION_GUIDE  
- Added auto-save and content sync patterns to QUICK_REFERENCE
- Recorded Phase 003 completion metrics in COMPLETION_SUMMARY
- All guides reflect 84/84 tests passing"
```

---

## 2. When Adding New Feature (Mid-Phase)

**User says**:
```
"Just implemented auto-save feature
- Debounce pattern (2s delay)
- Fixed 1 CloudKit sync bug"
```

**I will do**:
1. Add pattern to QUICK_REFERENCE.md (immediate)
2. Update IMPLEMENTATION_GUIDE.md "Debugging" section if needed
3. Update specs/003-*/tasks.md to mark task complete
4. No full README update until phase complete

---

## 3. When Fixing Build/Test Issues

**User says**:
```
"Build was failing due to CloudKit entitlements
Updated Xcode project, tests now passing"
```

**I will do**:
1. Update QUICK_REFERENCE.md "Troubleshooting" section
2. Update REPLAY_CHECKLIST.md if verification steps changed
3. Update IMPLEMENTATION_GUIDE.md "Debugging" section
4. Commit with: "Fix documentation for CloudKit entitlements issue"

---

## Information to Provide for Updates

To make documentation updates efficient, provide:

```markdown
Phase: 003 - Text Editing
Status: ✅ Complete / 🔄 In Progress / ⚠️ Blocked

Tests: +18 new (84 total)
Code Coverage: 95%

New Files:
  - TextEditorView.swift
  - ContentSyncService.swift

Modified Files:
  - FileDetailView.swift

Bugs Fixed:
  - CloudKit content sync not working
  - Auto-save firing too frequently

New Patterns:
  - Auto-save with debounce
  - Content sync architecture

Key Decisions:
  - Timer-based debounce vs Combine
  - Sync strategy (push vs pull)
```

---

## Documentation Maintenance Checklist

### After Each Phase Completion

- [ ] Update README.md phase status
- [ ] Add to IMPLEMENTATION_GUIDE.md architecture
- [ ] Add patterns to QUICK_REFERENCE.md
- [ ] Record phase completion in COMPLETION_SUMMARY.md
- [ ] Update test counts everywhere
- [ ] Commit all changes with clear message
- [ ] Verify all docs still build/render correctly

### Before Deployment

- [ ] Run through REPLAY_CHECKLIST.md verification
- [ ] Check all documentation still accurate
- [ ] Verify all links in docs still work
- [ ] Check code examples compile (if applicable)

### During Phase Development

- [ ] Mark tasks complete in specs/*/tasks.md
- [ ] Add discoveries to specs/*/plan.md
- [ ] Document patterns in QUICK_REFERENCE.md as discovered

---

## Documentation Hierarchy

```
Phase Development (Continuous)
└── specs/00X-*/tasks.md
    └── Mark tasks complete
    └── Update technical specs

Phase Completion (Major Update)
├── README.md                      (High-level status)
├── IMPLEMENTATION_GUIDE.md        (Architecture & patterns)
├── QUICK_REFERENCE.md             (Common patterns & debugging)
└── COMPLETION_SUMMARY.md          (Historical record)

Code Deployment (Verification)
└── REPLAY_CHECKLIST.md            (Verification process)
    └── Run through checklist
    └── Update if process changes
```

---

## Files That Never Change

These are immutable historical records:

```
.github/DOCUMENTATION_UPDATE_STRATEGY.md  ← You are reading this
git log --oneline                         ← Git history
Previous phase specs/                     ← Historical reference
COMPLETION_SUMMARY.md (past entries)      ← Historical records
```

---

## Tools for Documentation

### View Current State
```bash
# See what phase we're on
grep -E "^### Phase" README.md

# Check test counts
grep -E "Tests:|total" README.md

# See recent documentation updates
git log --oneline -- README.md IMPLEMENTATION_GUIDE.md
```

### Update Efficiently
```bash
# Create branch for doc updates
git checkout -b update/phase-003-docs

# Edit files
# ... update README, guides, etc ...

# Review changes
git diff README.md

# Commit
git commit -m "Update docs for Phase 003"

# Push
git push origin update/phase-003-docs
```

---

## Preventing Documentation Drift

### Weekly Review
```bash
# Check if documentation is current
git log --oneline -1 -- README.md
git log --oneline -1 -- specs/
git log --oneline -1 -- IMPLEMENTATION_GUIDE.md

# If last update > 1 week ago and code updated, refresh
```

### Per-Commit Checks
```bash
# Before committing code
echo "Did I update specs/*/tasks.md?" 
echo "Did I document new patterns?"
echo "Are test counts current?"
```

---

## Example: Full Phase 003 Update

### Stage 1: Mid-Phase (Discovery)
```
User: "Working on text editor, found auto-save pattern"
Action: Add pattern to QUICK_REFERENCE.md
Commit: "Add auto-save debounce pattern"
```

### Stage 2: Feature Complete
```
User: "Auto-save working, 18 tests passing"
Action: Update IMPLEMENTATION_GUIDE.md architecture
Commit: "Add auto-save architecture to implementation guide"
```

### Stage 3: Phase Complete
```
User: "Phase 003 complete - all 18 tests passing, CloudKit sync working"
Action: 
  - Update README.md with Phase 003 status
  - Update IMPLEMENTATION_GUIDE.md full architecture
  - Update QUICK_REFERENCE.md with all patterns
  - Update COMPLETION_SUMMARY.md with metrics
  - All in one commit
Commit: "Phase 003 complete: text editing with auto-save (84/84 tests)"
```

### Stage 4: Ready for Phase 004
```
Documentation is fully current
All patterns documented
All decisions recorded
Ready to start next phase
```

---

## Questions to Ask

When updating docs, use these questions to ensure completeness:

- [ ] Is the high-level status clear? (README)
- [ ] Are architecture decisions documented? (IMPLEMENTATION_GUIDE)
- [ ] Are common patterns documented? (QUICK_REFERENCE)
- [ ] Are debugging guides current? (QUICK_REFERENCE)
- [ ] Are completion metrics recorded? (COMPLETION_SUMMARY)
- [ ] Are test counts accurate everywhere?
- [ ] Are code examples still correct?
- [ ] Is git commit history clear?

---

## Success Criteria

Documentation is well-maintained if:

✅ README.md current within 1 day of phase completion  
✅ IMPLEMENTATION_GUIDE.md reflects current architecture  
✅ QUICK_REFERENCE.md has all patterns developers use  
✅ Test counts consistent across all docs  
✅ Anyone can clone repo and understand current state  
✅ Git history tells story of development  
✅ New developers can get up to speed in 2 hours  

---

## Related Documents

- **README.md** - Start here for project overview
- **IMPLEMENTATION_GUIDE.md** - Technical deep dive
- **QUICK_REFERENCE.md** - Quick lookup
- **REPLAY_CHECKLIST.md** - Verification
- **COMPLETION_SUMMARY.md** - Historical milestones

---

## Summary

**Document as you build**:
1. Work on feature (update specs/tasks)
2. Discover pattern (add to QUICK_REFERENCE)
3. Fix bug (add to Debugging section)
4. Complete phase (update all major docs)
5. Commit everything

**Keep documentation alive** - it's the story of your development journey.

---

**Last Updated**: 21 October 2025  
**Status**: Active & Evolving  
**Next Review**: After Phase 003 completion
